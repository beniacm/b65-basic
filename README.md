# B65 BASIC for MEGA65 (working name)

B65 BASIC is an interactive BASIC interpreter for the MEGA65's 45GS02 CPU.
It is an altered 45GS02 version of R.T. Russell's BBC BASIC (Z80) v5
(zlib licence, see LICENSE). It is not a compiler: you get immediate mode,
line editing, LIST and RUN on the machine.

Status: milestone 1 is done. Integers, strings, the main control structures,
PROC/FN/LOCAL and arrays work. Floating point and the inline assembler are
not done yet. See docs/DESIGN.md.

## Build

You need ACME 0.97 or later (`brew install acme`) and python3. Then run
`make`. This produces `build/b65.prg`, which loads at $2001; in BASIC 65 type
`RUN` (the program starts with a `BANK0:SYS8212` line).

## Test (headless Xemu)

    make test                      # smoke tests; XEMU=/path/to/xmega65.native
    tests/run.py myscript.txt      # feed keystrokes, print transcript

Xemu: build from https://github.com/lgblgblgb/xemu (`make` in
`targets/mega65`). No ROM or SD-card image is needed for the tests.
