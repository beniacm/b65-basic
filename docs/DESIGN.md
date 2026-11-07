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

## 5. Status (milestone 1)

Working and covered by the smoke tests:

* Immediate mode and program entry: line insert, replace and delete, tokeniser
  with abbreviations, line-number encoding after GOTO/GOSUB/THEN/ELSE/RESTORE.
* Commands: LIST [a][,b] with LISTO indentation, NEW, OLD, DELETE, RENUMBER
  (updates GOTO/GOSUB references), AUTO, RUN.
* Integer expressions with the BASIC V precedences:
  * operators: `+ - * DIV MOD AND OR EOR NOT = <> < > <= >= == << >> >>>`,
    `&hex`, `%binary`,
  * indirection: `? ! $`.
* Variables: static, dynamic integer/variant/byte/string variables and
  multi-dimensional arrays (DIM). DIM also reserves memory blocks
  (`DIM x% n`).
* Strings: `+`, comparisons, LEN, LEFT$, MID$, RIGHT$ (v5 one-argument forms
  included), CHR$, ASC, STR$(~), VAL, INSTR, STRING$, GET$, INKEY$, REPORT$,
  EVAL.
* Statements:
  * output: PRINT (@% field width, `, ; ' ~ TAB(x[,y]) SPC`), VDU, CLS,
  * assignment: LET, compound `+= -= *= /= AND= OR= EOR= MOD= DIV=`,
  * loops: FOR/NEXT [STEP], REPEAT/UNTIL, WHILE/ENDWHILE,
  * conditionals: single-line IF/THEN/ELSE and multi-line IF ... ELSE ...
    ENDIF,
  * jumps and procedures: GOTO, GOSUB/RETURN, ON n GOTO/GOSUB, DEF PROC/FN
    with parameters, LOCAL (numeric and string), ENDPROC, `=`, recursive FN,
  * data and input: READ/DATA/RESTORE [line], INPUT,
  * errors: ON ERROR / ON ERROR OFF, ERROR n,"text", REPORT, ERR, ERL,
  * other: END, STOP, CLEAR, TRACE, WIDTH, WAIT, QUIT, TIME (CIA TOD,
    0.1 s resolution).

## 6. Milestone plan

| # | Milestone | Content | Estimate |
|---|---|---|---|
| 2 | Floating point | Port the MATH.Z80 40-bit package: FADD/FSUB/FMUL/FDIV, FIX/FLOAT, comparisons, number parsing, @% G/E/F formatting, SQR, SIN, COS, TAN, ATN, ASN, ACS, EXP, LN, LOG, `^`, INT, RND(1), PI, DEG, RAD. Integer overflow promotes to float as upstream does. The hardware multiplier/divider can speed up the mantissa operations. | 3-5 days |
| 3 | Statement set to v5 parity | CASE/WHEN/OTHERWISE, EXIT, SWAP, whole-array operations, LOCAL arrays, ON ERROR LOCAL / RESTORE ERROR/DATA, `DIM LOCAL`, INSTALL, string arrays in PROC args, RETURNed parameters, `PTR/EXT/EOF`, `OPENIN/OPENOUT/BGET/BPUT` and LOAD/SAVE/CHAIN on SD-card files (Hyppo DOS traps), an ASCII font in char WOM, a better line editor (cursor keys and copy), Escape tested on real hardware | 1-2 weeks |
| 4 | 45GS02 inline assembler | `[ ... ]` with OPT, labels and P%/O%; mnemonic and addressing-mode tables for 6502, 65CE02, 4510 and 45GS02 (`[zp],z`, Q ops, long branches). Table-driven like ASMB.Z80. | 1 week |
| 5 | MEGA65 extensions | VIC-IV graphics through the HOOK entry points: MODE, CLG, GCOL, PLOT/MOVE/DRAW, CIRCLE, RECTANGLE, FILL, COLOUR/palette, sprites, using the DMA fill/copy hardware. SID SOUND/ENVELOPE with Locomotive-style queues. EVERY/AFTER timers on the raster IRQ. Memory: move the interpreter out of bank 0, 28-bit pointers for programs/heap in chip RAM (384 KB; 1 MB on the K325T) and attic RAM (8 MB, or 64 MB on the K325T) through `[zp],z`, e.g. a big-array or `DIM ... ATTIC` extension. | 2-4 weeks |

## 7. Naming

Under the zlib licence, altered versions must be marked as such. The
upstream README and every source header also say that the BBC's permission
to use the name "BBC BASIC" does not pass to forks. This project therefore
uses the neutral working name **B65 BASIC**, and its banner reads
"Derived from BBC BASIC (Z80) v5". Choosing the final name is up to the
owner. One option is to ask R.T. Russell, who has handled similar requests
from the Agon and other forks.
