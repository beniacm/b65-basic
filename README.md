# B65 BASIC for MEGA65 (working name)

B65 BASIC is an interactive BASIC interpreter for the MEGA65's 45GS02 CPU.
It is an altered 45GS02 re-implementation of R.T. Russell's BBC BASIC (Z80)
v5 (zlib licence, see LICENSE). It is not a compiler: you get immediate
mode, line editing, LIST and RUN on the machine. The main target is a
standard MEGA65 (R3 to R6, standard core). See docs/DESIGN.md for the design.

## Features

| Area | Status |
|---|---|
| Immediate mode, program entry/editing, LIST/LISTO, NEW/OLD, AUTO, DELETE, RENUMBER | done |
| Tokeniser and program format identical to BBC BASIC (Z80) v5 | done |
| Integer, float (40-bit BBC format), string, byte variables; arrays | done |
| Floating point: + - * / ^, SQR SIN COS TAN ATN ASN ACS EXP LN LOG INT ABS SGN PI DEG RAD RND(1), @% G/E/F formats | done (math unit + exact correction) |
| PRINT (@%, `, ; ' ~`, TAB, SPC), INPUT, VDU, CLS | done |
| FOR/NEXT, REPEAT/UNTIL, WHILE/ENDWHILE, IF/THEN/ELSE (single and multi-line), CASE/WHEN/OTHERWISE, EXIT, GOTO/GOSUB/ON | done |
| DEF PROC/FN, LOCAL, recursion, array parameters, LOCAL a() | done |
| RETURNed parameters (`DEF PROCx(RETURN a)`) | missing |
| ON ERROR [LOCAL], RESTORE ERROR, ERROR, REPORT/REPORT$, ERR, ERL | done |
| READ/DATA/RESTORE [n/+n], LOCAL DATA, RESTORE DATA/LOCAL | done |
| String functions (LEFT$/MID$/RIGHT$ incl. assignment, INSTR, STRING$, STR$, VAL, CHR$, ASC, LEN, EVAL, GET$, INKEY$) | done |
| Whole-array: init lists, copy, fill, op=, SUM, SUMLEN, DIM() | done |
| Whole-array arithmetic a()=b()+c(), dot product, string array expressions | missing |
| SWAP, `^` address-of, `?` `!` `$` `\|` indirection, `<< >> >>>` | done |
| DIM var LOCAL n, INSTALL, ELSE IF ... THEN; | missing |
| Files: LOAD, CHAIN, RUN "f", OPENIN, BGET#, GET$#, EOF#, PTR#, CLOSE#, *CAT, *DELETE | done (needs the ROM-booted DOS) |
| SAVE | partial (new files depend on Hyppo mkfile, which is work in progress) |
| OPENOUT, OPENUP, BPUT#, INPUT#, PRINT#, EXT# | missing |
| 45GS02 inline assembler, CALL, USR | done |
| Own ASCII 8x8 font, line editor (cursor keys, HOME, DEL, INST, recall, ctrl-U) | done |
| Hardware detection banner (standard MEGA65 / K325T, chip and attic RAM), info block at &6E0 | done (K325T path needs hardware test) |
| Raster-interrupt TIME, EVERY/AFTER/TIMELEFT/DI/EI timer events | done |
| SOUND (SID, per-channel queues), ENVELOPE (ADSR), ADVAL(-5..-8) | done (pitch envelopes missing) |
| Graphics MODE 1 320x200x256: CLG GCOL COLOUR ORIGIN MOVE DRAW PLOT LINE CIRCLE [FILL] RECTANGLE [FILL] POINT, text in graphics | done |
| FILL (flood), ELLIPSE, sprites, MOUSE | missing |
| 28-bit `?` `!` `\|` indirection to chip RAM and attic RAM | done |
| Interpreter fully out of bank 0 / big program space | partial (overlays in bank 4; about 18 KB for programs) |

## Build

You need ACME 0.97 or later (`brew install acme`) and python3. Then run
`make`. This produces `build/b65.prg`, which loads at $2001; in BASIC 65 type
`RUN` (the program starts with a `BANK0:SYS8212` line).

## Test (headless Xemu)

    make test                      # smoke tests (no ROM needed); XEMU=/path/to/xmega65.native
    tests/run.py script.txt        # feed keystrokes, print transcript
    tests/smoke_rom.sh             # optional: file tests, needs an onboarded card image (CARD=...)

Xemu: build from https://github.com/lgblgblgb/xemu (`make` in
`targets/mega65`).
