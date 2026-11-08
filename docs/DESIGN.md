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
  v5, and the error numbers and messages are the same too, with one
  addition: integer constants are stored pre-encoded (see "Speed" below), so
  a B65 program saved in tokenised form needs this version or later.
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
* **Speed.** Measured with `tests/bench/bench.sh` (10000 iterations in Xemu;
  centiseconds = microseconds per iteration) and profiled with a sampling
  build (`ACMEFLAGS=-DPROF=1 python3 tools/fixbranches.py`, then
  `tests/run.py ... --memout m.bin` and `tools/prof.py m.bin 30 -pc -lst
  report`, where the report comes from `acme -DPROF=1 -r report src/b65.a`).
  * Integer constants are tokenised: LEXAN stores a decimal constant of up
    to 9 digits (not after a name character, '.', or an exponent sign, not
    followed by '.' or 'E') or a hex constant `&` + 1-8 digits (one letter
    case) as `TNUM` (`$1F`), D1 = `$40` | hex<<5 | lower case<<4 |
    chunks-1, D2 = `$40` | digits typed, then 6-bit chunks `$40` | bits,
    least significant first. Every byte after `TNUM` is in `$40-$7F` (like
    TLINO's), so the text scanners pass over it. `item` decodes it in a few
    instructions; LIST and the assembler listing print it as typed (leading
    zeros, hex case); `linnum` accepts it (LIST/DELETE/RENUMBER/AUTO
    arguments). Floats, longer numbers, binary `%` and DATA stay text.
  * Decimal/hex text constants (DATA, VAL, EVAL of floats) are read with Q
    operations; DIV/MOD use the hardware divider; integer FOR/NEXT, static
    integer variables (`@%`, `A%`-`Z%`) and operator recognition (a 256-byte
    table) have fast paths.
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

LOAD/CHAIN (overlay 3, `o_loadprg`): the name is looked up on the SD card
(Hyppo directory scan), then in the D81 mounted as drive 0; without an
extension `.BBC` is tried first, then `.BAS`. D81 access is read-only:
F011 read-sector command on drive 0 (physical track = T-1, 512-byte
sector = S/2 -> side 0 sectors 1-10 / side 1), the buffer is read at
`$FFD6000` with `$D689` bit 7 = 0 (F011 buffer; this view also works in
Xemu), logical sector = half of it; directory on track 40 from sector 3,
16-character names, SEQ/PRG/USR files. The file is loaded at PAGE; if
`chkprog` does not see a valid line structure it is text: copied to attic
RAM (`$8520000`) and entered line by line through the editor's own
`tokline`/`storeln` (CR, LF or CR LF; TAB as space; lines up to 238
characters; unnumbered lines get the highest number so far + 10). Tested
by `tests/hw/09_textload.txt` (a D81 example loaded as text gives the same
LIST as typing it; a text file written with BPUT# and loaded from FAT).
`make dist` (`tools/mkdist.py`) builds the D81: header/BAM/directory on
track 40, files allocated from track 1, examples as SEQ text.

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

### INSTALL (step 2, moved in step 3)

`INSTALL "file"` loads a program file as a library at the top of the
program bank: block = length (2), 8.3 name (11), file. The file is loaded
straight into place below the lowest library (`libase`, `$1FB8`; `PLIM` =
`$F800` when there is none) and above TOP, its line structure is checked
("Bad library"), then `libase` is lowered. FN/PROC lookup (`finddef`) scans
the program first, then each library (`libnext`), and caches the DEF
address in the PROC/FN lists as usual. Installing the same name again does
nothing. Libraries stay until the next cold start; program lines and LOAD
must fit below `libase`. Up to 32 KB per library. Tested by
`tests/hw/04_install.txt`.

### Parallax demo (`examples/parallax.bas`, BASIC 65 twin in `examples/basic65/`)

* H320, 25 rows, rows of 126 tokens (252 bytes, LINESTEP/CHRCOUNT): GOTOX +
  41 glyphs per layer. Every glyph is full colour (`$D054` CHR16 + FCM,
  glyphs `$1680+n`, 64 bytes each at `$5A000`) from an own palette: ramps
  from entry 16 on (sky, earth, rock, two greens, reds, wood, snow, warm,
  outline, blue), written nibble-swapped to `$D100-$D3FF` by one shared
  routine (`PROCpalette` / `gosub 2700`), entries 16-255 saved at start and
  restored at the end (`$5F400-$5F6FF`).
* Layer 3 (opaque, "behind"): a sky gradient (one tile per row whose eight
  lines step through the 32-entry sky ramp) and lit/shaded snowy mountains,
  rows 5-17. Layer 2 (transparent, behind): rolling hills, rows 11-21, so
  the mountains show in their dips. Layer 1 (transparent, foreground):
  tree crowns (a lit sphere over 3x3 tiles), trunks, fence, grass and earth,
  rows 13-24, so the hills show between trunks and under the crowns. Sprite
  6 (16-colour balloon, priority bit) passes behind layer 1 and in front of
  layers 2 and 3; sprite 7 (16-colour plane) is in front of all. Speeds
  1:2:6 (far to near); all map periods divide 128 so the wrap is seamless.
* Bank 5: rows `$50000`, DMA list `$53100`, cells `$53700`, maps `$54800`
  (36 rows of 512 bytes: 128 columns + the first 41 again, 256-aligned so
  that the window start is the source low byte), tiles `$5A000`, birds
  `$5F000-$5F8FF`, sprites `$5FA00/$5FC00`; colour RAM offset `$0800`.
* Per frame: 6 cell bytes (fine X, coarse window) and one DMA list of 108
  jobs: per content row "copy the coarse cell into the next job's source
  low byte", "copy the fine cell into the row's GOTOX", "copy 41 tokens"
  (each job prefixed `$0B,$00`; the list address must be written before
  every trigger: it advances). B65: 25 statements per frame, 4.6 ms (Xemu,
  without the vsync wait); BASIC 65: 19 statements, 3.9 ms; both run at 50
  frames per second.
* RRB time: 3 GOTOX + 123 FCM glyphs per line, about 1970 of the 2592
  cycles of a line (16 per FCM glyph). DBLRR is on by default (`DB%`/`db`)
  on every machine, on the V400 row schedule: with HOTREG off `$D031` bit 3
  (V400), `$D05B` = 0 (one line per glyph row), `$D07B` = 24 (25 rows),
  `$D051` = `$C0`; each glyph row is painted once and shown on two lines
  (the V200 look) with 5184 cycles per painting. DBLRR on the V200 schedule
  is broken in the VIC-IV itself (rows become 32 lines tall). All four are
  restored at the end. On a K325T six list-mode v2 birds (four shaded
  frames, two token lists in opposite phase) fly in front of all; v2 X/Y are
  masked with AND 1023.
* `tests/smoke/21_parallax.txt` (`#include` of the example) checks the
  build and 40 frames of scrolling.

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
  * The new keywords use tokens `$11`-`$16` (SPRITE is `$16`). EXTWDS must
    stay in alphabetical order (the lexer stops early). In program text these values
    are free; upstream uses `$11`-`$1B` only as message fragments in error
    texts. LIST expands them through a second keyword table.
  * All 16-bit stack pointer updates are protected against interrupts
    (`+setsp`).
* **SOUND / ENVELOPE** (`src/sound.a`), BBC syntax:
  * Channels 1-3 use SID 1 (pulse wave); channel 0 is noise on SID 2.
  * Each channel has an 8-note queue that the interrupt plays; SOUND waits
    when a queue is full. `SOUND &1x,...` flushes the queue.
  * `ADVAL(-5..-8)` gives the free queue space.
  * ENVELOPE: the amplitude part becomes a SID ADSR (attack/decay/release
    rates and sustain level). The pitch part (t, pi1-3, pn1-3) is played
    by the interrupt: every t cs (2 cs per frame, several steps per frame
    when t = 1) the pitch changes by pi_k, pn_k times per section; the three
    sections repeat unless t has bit 7 set. The queue entry keeps the BBC
    pitch and the envelope number; the IRQ computes the SID frequency.
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
  * `ELLIPSE [FILL] x,y,a,b`: half width per row = round(sqrt(a²(b²-dy²))/b)
    with the math unit and an integer square root; the outline joins each
    row to the next, so it has no gaps. a, b are clamped to 4095.
  * `FILL x,y`: scan-line flood fill (4-connected) of the area that has the
    colour of the seed pixel, with the GCOL colour. The seed stack is in
    bank 4 at `$48000` (about 10,000 seeds; more are dropped).
  * `SPRITE n,x,y[,c]`, `SPRITE n OFF`, `SPRITE OFF` (new keyword, token
    `$16`): pixel coordinates like the graphics (VIC x+24, y+50, ORIGIN not
    applied), 16-bit sprite pointers at `$5FA00` (re-set on every SPRITE,
    because a MODE change resets them), images at `&5FC00+n*64` (24x21
    hi-res, default an arrow), write them with `?`.
  * `MOUSE x,y,b` (BB4W style: b = 4 left, 1 right), `MOUSE TO x,y`,
    `MOUSE ON`/`MOUSE OFF` (sprite 0 follows the mouse). A 1351 mouse in
    port 1 is read every frame through `$D620`/`$D621` (the C64 1351
    driver's delta rule); buttons from `$DC01` (fire = left, up = right).
    Position clamped to 0..319, 0..199; MOUSE x,y subtracts ORIGIN.
* **Far memory.** `?addr`, `!addr` and `|addr` with 28-bit addresses
  (>= `&10000`) use 32-bit flat addressing, so they reach all chip RAM and
  attic RAM (`&8000000`-). `$addr` strings are limited to bank 0.
* **Big program space (step 3).** The program text lives in its own bank:
  bank 1, PAGE = `&10800`, up to `&1F7FF` (the colour RAM mirror starts at
  `&1F800`), about 60 KB minus installed libraries. Variables, heap and the
  CPU stack stay in bank 0 (LOMEM = the page after the interpreter, `&9800`
  since the speed work, to HIMEM `&CF00`, about 14 KB).
  * `tp` is a 32-bit pointer (`$48`-`$4B`) and every text read is
    `lda [tp],z` (`+ldtpy` for the few Y-indexed reads). Its bank byte is
    derived from the 16-bit address whenever the high byte is stored
    (`settph`): below `PMIN` = `$0800` it is a bank-0 buffer (ACCS, BUFFER,
    EVBUF), otherwise the program bank. So all 16-bit text pointers kept in
    stack frames, DEF lists, DATA pointers etc. stay valid.
  * Code that walks program lines through ptr1/2/3 (line store, LIST,
    RENUMBER, DELETE, OLD, findl, gettop, finddef, libraries, DATA search,
    RETURN-parameter scan, ERL) reads/writes with `lp1y`..`sp3y`, which go
    through the 32-bit program pointer `pp` (`$4C`, bank byte fixed at 1).
  * PAGE and TOP return 28-bit addresses (`&10800`...), so `?PAGE` etc. work
    through the far indirection. `PAGE=` takes the low 16 bits (>= `&800`).
  * LOAD/CHAIN load into bank 1 and refuse files that do not fit ("No
    room"); SAVE writes from bank 1.
  * INSTALL puts libraries at the top of bank 1 (below `&1F800`): no stack
    move any more; HIMEM is unchanged.
  * Tested by `tests/hw/07_bigprog.txt` (a 38.5 KB program written with
    BPUT#, loaded, edited at both ends, run with GOSUB/PROC to its end,
    RENUMBERed, saved, reloaded, 30 KB deleted).
  * Arrays in attic RAM (see below) take the big data out of the 16 KB
    heap. Later, if needed: more heap by moving cold code (LIST, RENUMBER,
    editor, errors) into overlays.
* **Arrays in attic RAM.** Global arrays (not LOCAL ones) are allocated in
  attic RAM when there is some: `$8600000`-`$87FFFFF` (2 MB), in 256-byte
  pages. The 2-byte array variable then holds a handle `$E000`-`$FFFF`
  (address = `$8600000 + (handle-$E000)*256`); values below `$E000` are
  bank-0 blocks (LOCAL arrays on the stack, or no attic RAM). `CLEAR` (RUN,
  NEW, LOAD, CHAIN) frees them all.
  * `blkap` turns a block value into a 32-bit address in `ap` (`$3C`);
    header reads use `[ap],z`. `setel` turns an element address into a
    variable: near -> `vptr`; far -> `farad`/`farflag` and a copy in
    `FARBUF` (`farld`), written back by `storevar` (`farst`, now also for
    string descriptors: `farsz` = 4 for strings).
  * Whole-array expressions (overlay 2, `arrarith`/`arrpre`): `a()=b() OP
    c()`, `b() OP n`, `n OP b()` (n = one item), `-b()`, `b().c()`; string
    arrays with `+` (concatenation; the string scalar is kept in PARBUF
    slot 5 at `$1A00`). Operand element types may differ (each array is
    read with its own type). Tested by `tests/smoke/19_array_ops.txt`.
  * Whole-array code (copy, `a()=expr` / init lists / `op=`, SUM, SUMLEN,
    DIM(), arithmetic, dot product) walks elements with 32-bit cursors
    (`aelp`/`aelq` at `$1FBC`, `XP` at `$1FC8` in overlay 2) and
    `setel`/`storevar` per element. `a$()=b$()` now copies the strings
    (it used to copy the descriptors, so both arrays shared their text).
  * At most 65535 elements per array (the subscript index is 16-bit), so
    up to 320 KB for a real array; "DIM space" when the 2 MB are used up.
  * Far elements work with LET/compound ops, INPUT/READ, INPUT#/READ#,
    RETURN parameters (the copy-back frame is 11 bytes and keeps the 28-bit
    address), SWAP (swaps through 32-bit addresses), `^a(i)` (returns the
    28-bit address). A far element as a FOR variable gives "Bad FOR
    variable". Tested by `tests/smoke/18_far_arrays.txt`.

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
| `$1E00`-`$1EFF` | FN result slot |
| `$1F00`-`$1FAB` | pitch envelopes (16 x 8), channel pitch state, sound IRQ temporaries, mouse |
| `$1FB0`-`$1FB7` | testmode, lexmode, AUTO number/step, TRACE limit (moved out of zero page) |
| `$1FB8`-`$1FDF` | libase/libcur, array cursors aelp/aelq, arrtop, avt2, RETURN far capture, overlay-2 element addresses |
| `$2001`-`$97FF` | PRG stub + resident interpreter (the overlay images follow the code directly in the PRG, up to `$CF00`, and are copied to bank 4 at start-up) |
| `$9800`-`$CEFF` | LOMEM..HIMEM: variables, heap, CPU stack from the top |
| `$E000`-`$FFFF` | overlay window (MAP) |
| bank 1 `$10800`-`$1F7FF` | program text (PAGE..TOP), libraries at the top |
| bank 1 `$10000` | test script as loaded by Xemu, copied to attic `$8020000` at start-up |
| bank 4 `$48000`-`$4EFFF` | Xemu test transcript (test mode only) |
| attic `$8508000` | FILL seed stack |
| attic `$8600000`-`$87FFFFF` | global arrays (2 MB, 256-byte pages) |
| bank 4 `$40000`-`$47FFF` | overlay images (assembler, graphics, array arithmetic, files) |
| bank 4 `$4F700`/`$4F800` | line history / font |
| attic `$8100000`-`$84FFFFF` | file channel buffers (1 MB each) |
| bank 5 `$50000`-`$5F9FF` | MODE 1 bitmap |

### Hardware status (QMTECH K325T board, run by the lead)

Verified on the board (all smoke tests and `tests/hw/*` transcripts equal
to the Xemu results; card checked with a read-only `fsck.fat` before and
after every write test, no new findings, only B65* files changed):

* VIC-IV set-up (no stray pixels), key queue flushed at start, keyboard
  input; smoke 18/18 at commit 04abfba, 22/22 at 4df985b (incl.
  19_array_ops, 20_lang_gaps, 21_parallax, 22_userguide).
* SD reading (LOAD, CHAIN, *CAT, OPENIN/BGET of existing files) and writing
  with our FAT32 writer (SAVE new/overwrite, OPENOUT/OPENUP/PRINT#/BPUT#,
  a 602 KB file), INSTALL, the 38 KB program in bank 1.
* MODE 1 graphics incl. ELLIPSE/FILL, sprites (position exact), SOUND with
  a pitch envelope (recorded: 570-720 Hz triangle warble), MOUSE with
  injected 1351 POT values and buttons.
* Attic arrays: 230 cs vs 218 cs (bank 0) for 5000 read-modify-writes
  (K325T attic = DDR3 behind a cache; an original MEGA65's HyperRAM may
  differ).

Still open or only partly checked:

* The parallax demo's 256-colour rework (DBLRR on the V400 schedule,
  sprite priority between the layers, list-mode birds) on the board.
* `tests/hw/09_textload.txt` (LOAD of text programs from the mounted D81,
  F011 reads): waits for `dist/b65.d81` on the served card.

* Keyboard feel (repeat, RUN/STOP as Escape) by a person; TIME on NTSC.
* An original MEGA65 (R3/R6): HyperRAM timing, its SD controller, model
  detection paths other than K325T.
* SID by ear beyond the recorded envelope test (noise channel, ADSR).

## 7. Naming

Under the zlib licence, altered versions must be marked as such. The
upstream README and every source header also say that the BBC's permission
to use the name "BBC BASIC" does not pass to forks. This project therefore
uses the neutral working name **B65 BASIC**, and its banner reads
"Derived from BBC BASIC (Z80) v5". Choosing the final name is up to the
owner. One option is to ask R.T. Russell, who has handled similar requests
from the Agon and other forks.
