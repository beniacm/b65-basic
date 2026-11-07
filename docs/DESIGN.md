# B65 BASIC: design notes

B65 BASIC is an interactive BASIC for the MEGA65 (45GS02 CPU). It is a
45GS02 re-implementation that follows R.T. Russell's BBC BASIC (Z80)
version 5, with MEGA65 extensions planned on top.

"B65 BASIC" is a placeholder name. See [Naming](#naming).

## 1. Upstream and licence

| Item | Value |
|---|---|
| Upstream | https://github.com/rtrussell/BBCZ80 (BBC BASIC (Z80) v5, the latest v5 line) |
| Commit used | `1e932b5ad88e13edda54c785d0ce26ff6fa42089` (2026-10-28, "Another RESTORE DATA fix"). EXEC.Z80 says "VERSION 5.5, 28-10-2026" |
| Licence | zlib, `licence.txt` in the repo: "Copyright (c) 2024, Richard T. Russell". Altered versions must be plainly marked as altered. The notice must stay in source distributions. |
| Naming | README and every module header: "the name 'BBC BASIC' is used by permission of the British Broadcasting Corporation and is not transferrable to a derived or forked work." |

How B65 uses upstream:

* `tools/gen_tables.py` takes these tables from `MAIN.Z80` byte for byte and
  writes them to `src/tables.a`:
  * the keyword/token table `KEYWDS` (token values, abbreviation rules,
    conditional-keyword markers),
  * the immediate-command table `COMNDS`,
  * the compressed error-message table `ERRWDS` (error numbers and texts),
  * the LIST indentation tables.

  As a result, tokenised programs use the same encoding as BBC BASIC (Z80)
  v5, and the error numbers and messages are the same too.
* All code is new 45GS02 assembly. It keeps the upstream structure:
  * routine names `LEXAN`, `LEX`, `GETVAR`, `LOCATE`, `CREATE`, `FINDL`,
    `GETTOP`, `CLEAN`, `XEQ`, `NEWLIN`, `LISTIT`, `ENCODE`/`DECODE` and so on,
  * the same program format: `[len][lineno lo,hi][tokens][CR]`, ending in
    `00 FF FF`,
  * the same variable format: one linked list per initial letter with
    entries `[link][name tail][0][value]`. Static `@%`..`Z%` sit at `STAVAR`.
    Values are 5 bytes, with the integer kept when the exponent is 0.
    Strings are stored as descriptors.
  * the same control-structure model: FOR, REPEAT, WHILE, GOSUB, PROC/FN and
    LOCAL frames on the CPU stack.

  This is an *altered version* in the zlib sense, and every source file says
  so.
* Nothing comes from Acorn's 6502 BBC BASIC (source or ROM).

### Existing 6502 ports (checked, not used)

* Acorn's original 6502 BBC BASIC, including the 65C02 "Basic4" source on
  mdfs.net: the rights are unclear (Acorn/successors). **Not used.**
* "BeebEater" (65C02 BBC BASIC for Ben Eater's breadboard computer) is a port
  of Acorn's code, and no licence was found. **Not used.**
* A RISC OS Open forum thread ("6502 BBC BASIC license?") shows a MEGA65
  porter giving up on Acorn's 6502 BASIC because nobody could grant a licence.
* No open-licence 6502/65xx port of R.T. Russell's BASIC was found. This
  re-implementation therefore starts from the Z80 v5 sources.

## 2. Upstream structure (BBCZ80, 15,119 lines of Z80 assembly)

| File | Lines | Role | B65 counterpart |
|---|---|---|---|
| MAIN.Z80 | 2235 | commands, line editor/store, tokeniser LEXAN/LEX, LIST, errors, GETVAR/LOCATE/CREATE | `src/main.a`, `src/vars.a`, generated `src/tables.a` |
| EXEC.Z80 | 3294 | statement dispatch table (CMDTAB, tokens &C0..&10) and statements | `src/exec.a` (same dispatch order) |
| EVAL.Z80 | 2591 | expression evaluator, functions (FUNTBL) | `src/eval.a`, `src/funcs.a` |
| MATH.Z80 | 2255 | 40-bit floating-point package | **todo** (milestone 2) |
| ASMB.Z80 | 1009 | Z80 inline assembler (`[ ... ]`), opcode table OPCODS | **todo**: replaced by a 45GS02 assembler (milestone 4) |
| HOOK.Z80 | 67 | stubs for CLG, COLOUR, DRAW, GCOL, MODE, PLOT, SOUND, CIRCLE, ... | MEGA65 graphics/sound (milestone 5) |
| DATA.Z80 | 68 | RAM workspace layout | `src/zp.a` |
| CMOS.Z80 / DIST.Z80 | 1500 / 227 | CP/M host layer (OSWRCH, OSRDCH, OSLINE, files) | `src/os.a` (MEGA65 hardware) |
| ACORN.Z80 / AMOS.Z80 | 755 / 1118 | Acorn Z80 second-processor host layer | not used |

The generic interpreter is MAIN, EXEC, EVAL, ASMB, MATH, HOOK and DATA, about
11.5k lines that fit in 16 KB of Z80 code. The 45GS02 version is
currently about 15 KB without floating point or the assembler.

## 3. Architecture decisions

* **Assembler: ACME 0.97** with `!cpu m65`. It supports the 65CE02/4510 modes,
  `[zp],z` 32-bit flat addressing, the Q-register instructions
  (`ldq`/`stq`/`adcq`/...) and 16-bit `lbxx` branches. Its gaps: no `asrq`, no
  `bitq`, and no `ldq (zp),z` form. Note that ca65 handles the 4510 but not
  the 45GS02 Q opcodes. `tools/fixbranches.py` changes any short branch that
  ends up out of range into a long branch automatically.
* **Interpreter, not compiler.** Programs are tokenised into memory and
  interpreted, as in upstream. Immediate mode, line editing, LIST, RUN, AUTO,
  DELETE, RENUMBER and OLD all exist.
* **No KERNAL.** The program maps out every ROM (`MAP` cleared, `$D030=0`,
  `$01=$35`) and drives the hardware itself:
  * VIC-IV in 80x25 text mode at `$0800`, using the lowercase char ROM
    (CHARPTR `$1800`),
  * keyboard through the hardware ASCII queue `$D610`,
  * the hardware multiplier `$D770` for `*`, array indexing and DIM,
  * CPU at 40 MHz.
* **16-bit stack.** `CLE` gives the 65CE02 a 16-bit stack pointer. As in the
  Z80 version, the machine stack runs downward from HIMEM (`$CF00`) and holds
  the control frames, so recursion depth is limited by memory and not by
  page 1. Statement handlers are entered by `JMP` (never `JSR`), which keeps
  the newest frame on top of the stack, as on the Z80.
* **Numbers.** Values use 5 bytes: a 4-byte mantissa (or integer) plus an
  exponent byte, where exponent 0 means a 32-bit integer. This is the
  BBC BASIC (Z80) layout, so the later floating-point package fits in without
  changing variable storage. For now only integers are implemented. Overflow,
  `/`, `^`, real constants and the transcendental functions raise
  "Floating point not implemented yet" (ERR 254).
* **Zero-page Z register.** The 45GS02 `lda (zp)` instruction is really
  `lda (zp),z`, so the code keeps the invariant Z=0. LDQ/STQ overwrite A, X, Y
  and Z (several bugs were caused by this); every Q sequence ends with
  `ldz #0`.

### Memory map (bank 0, ROMs mapped out)

| Range | Use |
|---|---|
| `$0000-$00FF` | zero page (interpreter registers: `tp` text pointer, `acc`/`arg` accumulators, ...) |
| `$0200` | ACCS string accumulator (256) |
| `$0300` | BUFFER, the tokenised input line |
| `$0400` | STAVAR (`@%`, `A%`-`Z%`), DYNVAR list heads, FN/PROC list heads |
| `$0500` / `$0600` / `$0700` | string scratch / number buffer / EVAL buffer |
| `$0800-$0FCF` | 80x25 screen |
| `$1000-$1FFF` | PARBUF (FN/PROC argument passing) |
| `$2001-` | PRG: BASIC stub `BANK0:SYS8212`, then the interpreter |
| PAGE (after the code, about `$5900`) ... HIMEM `$CF00` | program, variables, heap. CPU stack grows down from HIMEM |
| `$D000-$DFFF` | I/O |
| bank 1 `$10000` / `$18000` | test script / output transcript (test mode only) |

## 4. Testing with Xemu (headless, automated)

Xemu is built from https://github.com/lgblgblgb/xemu (master
`40dfef0d`) with Homebrew SDL2, using only `targets/mega65`
(`make` in `targets/mega65`).

**Booting without ROM, card image or onboarding.** The Xemu option
`-extonboard FILE` replaces the onboarding utility that Hyppo runs on a fresh
virtual SD card. Hyppo copies the image from `$40000` to `$07FF` and starts it
at `$080D` in hypervisor mode. The stub `tests/boot.a`:

1. copies the interpreter (image offset `$100`) to `$2001`,
2. copies the test script (image offset `$8000`, prefixed with the magic
   `B65T`) to `$10000`,
3. clears the transcript buffer,
4. sets the hypervisor return registers (`$D640-$D652`, PC=`$2017`) and writes
   `$D67F`. The CPU leaves hypervisor mode and enters the interpreter's test
   entry.

In test mode, `OSRDCH` reads keystrokes from the script and `OSWRCH` also
writes every byte to the transcript at `$18000`. When the script runs out,
the interpreter writes `$42` to `$D6CF`, which makes Xemu exit when it runs
with `-testing`. `tests/run.py` then reads the transcript from `-dumpmem`.

```
tests/run.py SCRIPT [--screenshot out.png] [--screen] [--peek sym:n,...]
tests/smoke.sh            # builds, runs tests/smoke/*.txt, diffs with *.expected
```

Xemu command used: `xmega65.native -skipconfigfile -headless -sleepless
-besure -testing -virtsd -sdimg <empty dir> -extonboard <image> -dumpmem
<file> -uartmon <sock>`. If the run times out, the harness asks the uartmon
for the registers (`r`) and prints them, which helps with debugging hangs.
One run takes about 0.5 s. Each run gets a private `HOME`/`XDG_DATA_HOME`
(temporary directory), so parallel Xemu instances never share
`~/.local/share/xemu-lgb`.

The normal start path (C65 mode, BASIC 65 `RUN` of the PRG) was also checked
with the real MEGA65 ROM and an onboarded card image (private copy, not in
git):
`XEMU_SKIP_ONBOARDING=1 xmega65.native -skipconfigfile -headless -sdimg
card.img -prg build/b65.prg -screenshot x.png`.

`tools/xemu-skip-onboarding.patch` is an experimental local Xemu patch that
presets the "onboarded" flag in a freshly formatted virtual SD card. Hyppo
2025-06 did not honour it, and the extonboard approach above made it
unnecessary.

## 5. Status

See the feature table in README.md. In short:

* **M1** (interactive core): done.
* **M2** (floating point): done.
* **M3** (statements, ASCII font, line editor, files): done except for the
  items marked partial or missing.
* **M4** (inline assembler): done.
* **M5** (MEGA65 extensions): see below.

### Floating point (M2)

`src/fp.a` and `src/fp2.a` are a port of MATH.Z80. They use the same 5-byte
format and the same algorithms:

* rounding: unbiased, from a 16-bit extension,
* normalisation,
* POWR10, the CON number parser, STR with @% G/E/F formats, MOD48 range
  reduction,
* the same polynomial coefficients for SIN, COS, EXP, LN and ATN,
* the literal SQRA/SQRB square root,
* IPOW/FPOW for `^`,
* integer to float promotion on overflow, including IMUL's truncated
  64-bit path.

The mantissa operations use the MEGA65 math unit:

* **Multiply.** `$D770`-`$D77F` give the exact 32x32->64 product. The code
  waits on the MULBUSY bit.
* **Divide.** The hardware divider (`$D768`) is an iterative Goldschmidt
  divider; see `fast_divide.vhdl` in mega65-core. On real hardware it rounds,
  so its quotient is only an *estimate*. The quotient is then corrected
  exactly with the multiplier (remainder = N - q*d, adjust q by +-1). That
  makes the result bit-identical to the restoring division in MATH.Z80
  whatever the divider returns.

Test and benchmark switch: `?&AF=1` selects the pure software
multiply/divide. `?&AF=&80` or `&81` deliberately perturbs the hardware
estimate by +1 or -1 to exercise the correction. `tests/smoke/06_fp_paths`
checks that all paths give identical results on 400 random operand pairs.

Benchmark (`tests/bench_fp.txt`, Xemu at real speed, frames of 1/50 s,
loop overhead included):

| | 5000 `C=A*B` | 5000 `C=A/B` | 1000 `SIN` | empty loop |
|---|---|---|---|---|
| math unit | 28 | 29 | 13 | 8 |
| software | 44 | 48 | 30 | 8 |

### Inline assembler (M4)

`src/asm.a` runs in code overlay 0 and takes its instruction table from
`src/asmtab.a`, generated by `tools/gen_opcodes.py`: 366 forms covering
6502, 65C02, 65CE02/4510 and 45GS02.

* 45GS02 extensions: Q instructions (`LDQ`, `STQ`, `ADCQ`, ... with the
  `$42 $42` prefix), `[zp],Z` 32-bit flat addressing (`$EA` prefix), 16-bit
  branches (`LBxx`, `BSR`), `BBR`/`BBS`/`RMB`/`SMB`, `PHW`, `RTN`, `MAP`/`EOM`.
* Mnemonics that the tokeniser turned into BASIC keywords (`AND`, `EOR`, `OR`
  in `ORA`, `ORQ`, ...) are expanded back to text.
* Directives: `OPT` (bit 0 listing, bit 1 errors, bit 2 assemble at `O%`),
  labels `.name` (BASIC variables), `EQUB`/`EQUW`/`EQUD`/`EQUS` (with lists).
* When OPT bit 1 is clear, undefined labels take the value of P%.
* `tests/smoke/09_assembler` checks the output byte for byte against ACME.
* `CALL addr` and `USR(addr)` pass A%, X%, Y%, Z% and C% (carry). USR returns
  A + X<<8 + Y<<16 + Z<<24.

### Code overlays

Rarely used modules are assembled with `!pseudopc $E000`, copied at start-up
to chip RAM bank 4 (`$40000 + n*$2000`), and mapped into CPU block 7
(`$E000`-`$FFFF`) with the 45GS02 `MAP` instruction when they are needed
(`ovjmp` / `ovjsr` in `src/ovl.a`). This keeps the resident core in bank 0
(`$2000`-`$7EFF`) and leaves PAGE..HIMEM for programs, while larger modules
are added.

### Files (M3, rewritten in step 2)

Reading uses the Hyppo DOS traps (setname, loadfile, opendir/readdir,
findfile, openfile, readfile). **Writing does not**: on the board, Hyppo's
`mkfile` (work in progress upstream) failed with "Disk fault", so files are
written by our own FAT32 code in overlay 3 (`src/fat.a`):

* SD sector I/O through `$D680` exactly as Hyppo does it: write gate `$57`
  before every `$03`; sector 0 (MBR) is never written; buffer at `$DE00`
  (`$D689` bit 7 = SD buffer, `$D030` bit 0 cleared); ready = `$D680` bits
  0-1 clear, error = bit 6, ~4 s timeout (then reset and "Disk fault").
* Mounted fresh for every write: the first partition of type `$0B`/`$0C`,
  512-byte sectors only. Only the **root directory**, only **8.3 names**
  (no long names are created; an existing file with a long name keeps it).
* A file is written as: find the 8.3 entry (or the first free one), free the
  old cluster chain, allocate clusters from the FSInfo next-free hint
  (bounded by the real cluster count, wraps once to cluster 2), write the
  data, update **both FATs**, then the directory entry, then FSInfo (free
  count adjusted by the net change, next-free hint). Directories, volume
  labels and read-only files are never touched ("Bad name").
* Dates are fixed at 2025-01-01 00:00 (no RTC dependency).
* Tested by `tests/cardtest.py` on a copy of an FDISK-formatted MEGA65 card
  image (4 KB clusters, multi-cluster root with long names): fsck.fat
  findings unchanged, all B65 files readable with mtools, a 602,400-byte
  file spanning several FAT sectors.

SAVE uses this writer for new and existing files (an existing file is
replaced, also when it gets shorter). `.BBC` is added when the name has no
extension (SAVE, LOAD, CHAIN, OPENxx alike).

Channels (OPENIN, OPENUP, OPENOUT; BGET#, BPUT#, PRINT#, INPUT#, READ#,
GET$#, PTR# and PTR#=, EXT#, EOF#, CLOSE#) are buffered whole in attic RAM:
channel n uses `$8100000 + (n-1)*$100000`, files up to 960 KB, 4 channels.
OPENIN/OPENUP read the file at open time (Hyppo readfile); CLOSE# writes a
changed file back with the FAT writer (if that fails, the channel stays open
so CLOSE# can be retried). PRINT# writes the Z80 format (numbers 5 bytes,
mantissa LSB first then exponent; strings + CR), INPUT#/READ# read it.
BPUT#c,s$ writes s$ + LF (no LF with `;`). GET$# ends a line at CR, LF or
CR LF. PTR#= beyond EXT extends a writable file with zeros; on a read-only
one it stops at EXT. Writing to an OPENIN channel gives "Access denied".
Files stay open after END/errors (as in BBC BASIC); CLOSE#0 closes all.

### MEGA65 extensions (M5)

* **Hardware detection** (`src/m65.a`) runs at start-up, and the banner
  shows the result (for example "MEGA65 (model $03), 384K chip RAM, 8MB
  attic RAM").
  * K325T: `$D629 = $62`, confirmed by writing bit 0 of XCTL `$FFD71F0` and
    reading it back (the original value is restored if the read fails). On
    success the 1 MB chip RAM bit is left set. Attic size is probed by
    writing 64 to `$BFFFFFC`; this only happens on a confirmed K325T.
  * On a standard MEGA65, XCTL is never touched.
  * Information block, readable with `?`: `&6E0` = model id, `&6E1` = &FF on
    K325T, `&6E2`/`&6E3` = chip RAM in KB, `&6E4` = attic RAM in MB.
  * In Xemu, `-model 98` takes the K325T path, because Xemu's I/O page reads
    the XCTL value back.
* **Raster interrupt** (line 251) at 50/60 Hz:
  * TIME in centiseconds; NTSC adds 2,2,1 per frame.
  * Four Locomotive-BASIC-style timers: `EVERY t[,n] GOSUB line`,
    `AFTER t[,n] GOSUB line`, `TIMELEFT(n)` (like Locomotive REMAIN: returns
    what is left and stops the timer), `DI`/`EI`.
  * Events are dispatched between statements, higher timer number first. A
    handler ends with RETURN.
  * The new keywords use tokens `$11`-`$15`. In program text these values
    are free; upstream uses `$11`-`$1B` only as message fragments in error
    texts. LIST expands them through a second keyword table.
  * All 16-bit stack pointer updates are protected against interrupts
    (`+setsp`).
* **SOUND / ENVELOPE** (`src/sound.a`), BBC syntax:
  * Channels 1-3 use SID 1 (pulse wave); channel 0 is noise on SID 2.
  * Each channel has an 8-note queue that the interrupt plays; SOUND waits
    when a queue is full. `SOUND &1x,...` flushes the queue.
  * `ADVAL(-5..-8)` gives the free queue space.
  * ENVELOPE becomes a SID ADSR (attack/decay/release rates and sustain
    level). Pitch envelopes are not supported.
* **Graphics** (overlay 1, `src/gfx.a`):
  * `MODE 1` is 320x200 in 256 colours. It uses VIC-IV full-colour
    characters: 1000 cells of 64 bytes in chip RAM at `$50000`, with 16-bit
    character numbers in the text screen RAM.
  * Palette: colours 0-15 are the VIC defaults, 16-255 an RGB 3-3-2 cube.
    Colour 255 shows the colour RAM foreground (full-colour mode rule), so
    use 254 for white.
  * Statements: `MODE 0/1`, `CLG`, `GCOL [m,]c`, `COLOUR c` (text colour,
    both modes), `ORIGIN`, `MOVE`, `DRAW`, `PLOT 4/5/69,x,y`, `LINE`,
    `CIRCLE [FILL]`, `RECTANGLE [FILL]`, and the `POINT(x,y)` function.
  * Coordinates are pixels, origin top left.
  * Text output works in graphics mode (40x25, own font). CLG and scrolling
    use the DMA controller (F018B job lists).
  * FILL (flood fill), ELLIPSE, sprites and MOUSE are not implemented.
* **Far memory.** `?addr`, `!addr` and `|addr` with 28-bit addresses
  (>= `&10000`) use 32-bit flat addressing, so they reach all chip RAM and
  attic RAM (`&8000000`-). `$addr` strings are limited to bank 0.
* **Interpreter out of bank 0.** Done only in part: the assembler and
  graphics run from bank 4 through the overlay mechanism, while the core
  (`$2000`-`$86FF`, about 26 KB) stays in bank 0. Program space is
  PAGE=`$8700` to HIMEM=`$CF00`, about 18 KB. Next steps:
  * move FP formatting/transcendentals and LIST/RENUMBER/editor/files into
    overlays,
  * move the text screen and PARBUF out of bank 0 and start the core at
    `$0800`,
  * allocate arrays and strings in chip/attic RAM through 28-bit pointers.

### Memory map (current)

| Range | Use |
|---|---|
| `$0000`-`$00FF` | zero page |
| `$0200`/`$0300` | ACCS / BUFFER |
| `$0400`-`$04FF` | STAVAR, variable list heads |
| `$0500`/`$0600` | STRBUF / NUMBUF |
| `$0640`-`$06FF` | MISC variables, channel table, IRQ state, `HWINFO` at `$06E0` |
| `$0700`-`$07FF` | EVAL buffer / dirent, STR digit stack, FP stack |
| `$0800`-`$0FCF` | text screen, or the 16-bit character map in MODE 1 |
| `$1000`-`$1BFF` | PARBUF: 6 parameter slots; during file writes also FAT/dir sector buffers and FAT state (`$1000`-`$147F`) |
| `$1C00`-`$1DFF` | sound queues, envelopes, graphics argument buffer |
| `$1E00`-`$1FFF` | FN result slot |
| `$2001`-`$86FF` | PRG stub + resident interpreter |
| `$8700`-`$CEFF` | PAGE..HIMEM (program, variables, CPU stack from the top) |
| `$E000`-`$FFFF` | overlay window (MAP) |
| bank 1 `$10000`/`$18000` | test script / transcript (test mode only) |
| bank 4 `$40000`-`$47FFF` | overlay images (assembler, graphics, array arithmetic, files) |
| bank 4 `$4F700`/`$4F800` | line history / font |
| attic `$8100000`-`$84FFFFF` | file channel buffers (1 MB each) |
| bank 5 `$50000`-`$5F9FF` | MODE 1 bitmap |

### Needs a hardware test

These cannot be checked in Xemu, or only partly:

* Keyboard and line editor with real key repeat and RUN/STOP (Escape),
  GET/INKEY timing.
* TIME: based on the CIA TOD clock, 0.1 s resolution. Xemu feeds TOD from
  the host clock.
* VIC-IV set-up on real boards: 80x25 text, CHARPTR to our font in chip RAM
  at `$5F000`, and the XSCROLL=1 compensation for the VIC-III 2-pixel shift.
* Math unit timing: the code polls MULBUSY/DIVBUSY (`$D70F`), and the
  divider correction path. The multiplier is also used without polling in
  screen and array code, which relies on its 1-cycle latency.
* SD writes with our FAT32 writer (SAVE, CLOSE# of changed files) on the
  real card: `tests/hw/02_save.txt`, `tests/hw/03_chan.txt`.
* 16-bit stack (CLE) with deep recursion on real silicon.
* The MAP-based overlays on real hardware.
* K325T: detection through `$D629`/XCTL `$FFD71F0`, enabling 1 MB chip RAM,
  and the 64 MB attic probe. These can only be checked on the board itself.
* Raster IRQ timing and TIME on PAL and NTSC; EVERY/AFTER rates.
* SID output: audio mixer routing after a cold start through the PRG, the
  noise channel, ENVELOPE ADSR mapping, and pitch accuracy (the table assumes
  the PAL SID clock).
* MODE 1 on real VIC-IV: the full-colour character layout, the HOTREG-based
  geometry recompute, the palette, and DMA F018B job lists read from bank 4.

## 7. Naming

Under the zlib licence, altered versions must be marked as such. The
upstream README and every source header also say that the BBC's permission
to use the name "BBC BASIC" does not pass to forks. This project therefore
uses the neutral working name **B65 BASIC**, and its banner reads
"Derived from BBC BASIC (Z80) v5". Choosing the final name is up to the
owner. One option is to ask R.T. Russell, who has handled similar requests
from the Agon and other forks.
