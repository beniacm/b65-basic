# B65 BASIC for MEGA65

B65 BASIC is an interactive BASIC interpreter for the MEGA65's 45GS02 CPU.
It is an altered 45GS02 re-implementation of R.T. Russell's BBC BASIC (Z80)
v5 (zlib licence, see LICENSE). It is not a compiler: you get immediate
mode, line editing, LIST and RUN on the machine. The main target is a
standard MEGA65 (R3 to R6, standard core). See docs/DESIGN.md for the design.

## Features

Version: **v0.1-dev** (shown in the start-up banner; the string lives only in
`src/version.a`).

| Area | Status |
|---|---|
| Immediate mode, program entry/editing, LIST/LISTO, NEW/OLD, AUTO, DELETE, RENUMBER | done |
| Tokeniser and program format identical to BBC BASIC (Z80) v5 | done |
| Integer, float (40-bit BBC format), string, byte variables; arrays | done |
| Floating point: + - * / ^, SQR SIN COS TAN ATN ASN ACS EXP LN LOG INT ABS SGN PI DEG RAD RND(1), @% G/E/F formats | done (math unit + exact correction) |
| PRINT (@%, `, ; ' ~`, TAB, SPC), INPUT, VDU, CLS | done |
| FOR/NEXT, REPEAT/UNTIL, WHILE/ENDWHILE, IF/THEN/ELSE (single and multi-line), ELSE IF ... THEN chains, CASE/WHEN/OTHERWISE, EXIT, GOTO/GOSUB/ON | done |
| DEF PROC/FN, LOCAL, recursion, array parameters, LOCAL a(), RETURN parameters (`DEF PROCx(RETURN a)`) | done |
| `DIM var LOCAL n` (and `-1`), LOCAL arrays on the stack | done |
| ON ERROR [LOCAL], RESTORE ERROR, ERROR, REPORT/REPORT$, ERR, ERL | done |
| READ/DATA/RESTORE [n/+n], LOCAL DATA, RESTORE DATA/LOCAL | done |
| String functions (LEFT$/MID$/RIGHT$ incl. assignment, INSTR, STRING$, STR$, VAL, CHR$, ASC, LEN, EVAL, GET$, INKEY$) | done |
| Whole-array: init lists, copy, fill, op=, SUM, SUMLEN, DIM() | done |
| Whole-array arithmetic `a()=b()+c()`, `a()=b()*n`, `a()=n-b()`, `a()=-b()`, dot product `a()=b().c()` | done (a leading scalar must be one item: number, variable, function or bracketed expression) |
| String array expressions `a$()=b$()+c$()`, `a$()=b$()+"x"`, `a$()="x"+b$()` | done |
| SWAP, `^` address-of, `?` `!` `$` `\|` indirection, `<< >> >>>` | done |
| INSTALL "library" (FN/PROC searched after the program) | done |
| Files: LOAD, CHAIN, RUN "f", SAVE, *CAT, *DELETE | done (reading through Hyppo DOS, writing with B65's own FAT32 writer) |
| LOAD/CHAIN of plain-text programs (`.BAS`), and read-only from the D81 mounted as drive 0 | done |
| File channels: OPENIN, OPENOUT, OPENUP, BGET#, BPUT#, PRINT#, INPUT#, READ#, GET$#, EOF#, PTR#(=), EXT#, CLOSE# | done (files up to 960 KB, buffered in attic RAM) |
| 45GS02 inline assembler, CALL, USR | done |
| Own ASCII 8x8 font, line editor (cursor keys, HOME, DEL, INST, recall, ctrl-U) | done |
| Hardware detection banner (standard MEGA65 / K325T, chip and attic RAM), info block at &6E0 | done |
| Raster-interrupt TIME, EVERY/AFTER/TIMELEFT/DI/EI timer events | done |
| SOUND (SID, per-channel queues), ENVELOPE (ADSR and pitch envelopes), ADVAL(-5..-8) | done |
| Graphics MODE 1 320x200x256: CLG GCOL COLOUR ORIGIN MOVE DRAW PLOT LINE CIRCLE/ELLIPSE/RECTANGLE [FILL], FILL (flood), POINT, text in graphics | done |
| SPRITE n,x,y[,c] / OFF; MOUSE x,y,b / TO / ON / OFF (1351 in port 1) | done |
| 28-bit `?` `!` `\|` indirection to chip RAM and attic RAM | done |
| Program space | done: program text in its own bank (PAGE=&10800), about 60 KB |
| Variable space | about 16 KB in bank 0 for variables and strings; global arrays in attic RAM (2 MB, up to 65535 elements each) |

## Hardware status

Everything above has been verified on a QMTECH K325T board running the
MEGA65 K325T core (smoke tests, SD card writing checked with `fsck.fat`,
graphics, sprites, sound, mouse, big programs, attic arrays); see
"Hardware status" in docs/DESIGN.md. A standard MEGA65 (R3 to R6) has not
been tested yet: its HyperRAM timing, SD controller and model detection
paths are untested. The K325T core, the list-mode documentation and the
loader used by `tests/board.py` live in the harness repository
https://github.com/beniacm/mega65-k325t-cm4.

## Build

You need ACME 0.97 or later (`brew install acme`) and python3. Then run
`make`. This produces `build/b65.prg`, which loads at $2001; in BASIC 65 type
`RUN` (the program starts with a `BANK0:SYS8212` line).

## Distribution and examples

`make dist` writes `dist/b65.d81` and `dist/sd/` (both ignored by git):

* `dist/b65.d81` holds `B65` (the PRG) and every `examples/*.bas` as a
  plain-text SEQ file `NAME.BAS`. On a MEGA65: mount the D81, `DLOAD "B65"`,
  `RUN`; then in B65 `LOAD "NAME"` (or `LOAD "NAME.BAS"`) and `RUN`.
* `dist/sd/` has the same files for copying to the SD card root.

B65 looks for a file on the SD card first, then in the D81 mounted as
drive 0 (read-only). A file that is not a tokenised program is read as
text and entered line by line, exactly as if typed (lines without a
number get the highest number so far + 10). Text files need attic RAM.

Examples (`examples/`): `rrblist_b65.bas` and `rrblist_b65v2.bas` (RRB
list mode v1/v2; K325T core only), `parallax.bas` (three-layer RRB
parallax: 80 columns, fine scroll through GOTOX, coarse scroll through one
self-modifying DMA list per frame, two sprites between/in front of the
layers, six list-mode v2 birds on a K325T; 50 frames per second).
`examples/basic65/parallax65.bas` is the BASIC 65 twin (same picture and
motion; not part of the D81). To try it in Xemu:

    tools/tok65.py examples/basic65/parallax65.bas /tmp/p.prg
    tests/run.py - --prg /tmp/p.prg --realtime --timeout 60 --screenshot /tmp/p.png

## Test (headless Xemu)

    make test                      # smoke tests (no ROM needed); XEMU=/path/to/xmega65.native
    tests/run.py script.txt        # feed keystrokes, print transcript
    tests/smoke_rom.sh             # smoke tests booted through the MEGA65 ROM (CARD=...)
    tests/cardtest.py              # file tests on a copy of an onboarded card image (CARD=...)
    tests/board.py load|smoke|run  # on the K325T rig (needs the harness)

Xemu: build from https://github.com/lgblgblgb/xemu (`make` in
`targets/mega65`).
