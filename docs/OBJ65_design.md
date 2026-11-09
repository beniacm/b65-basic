# OBJ65: v3 objects for BASIC 65 (design note, S5)

Goal: a BASIC 65 program on the K325T step-6 core can use the v3 object
table, the frame-interrupt motion, HITPIX and the collision page without
B65. Two parts: POKE recipes (no code) and a small machine-code library.

## 1. POKE recipes (USER.md-style chapter, `docs/OBJ65.md`)

Everything the hardware needs is plain memory and registers, so a BASIC
65 program can do it with `POKE`/`WPOKE` on 28-bit addresses (as
`examples/basic65/bounce65.bas` already does):

- feature level `PEEK($FFD71FD)` >= 3, XCTL `$FFD71F0` bits 4, 6, 7 (and
  3 if it reads back), HOLD `$FFD71FC`, table address `$FFD71F8-FA`,
  count `$FFD71FB` and the 10-bit count `$FFD728A-B`;
- the 32-byte entry (bytes 0..15 for the VIC-IV; 16..31 only matter with
  the library), with a `WPOKE` per field and a ready-made subroutine
  "define object n";
- the collision page: status/acknowledge `$FFD7280` (bit 0 latched, bit 1
  IRQ enable, bit 7 pending; write 1 to clear), index `$FFD7282-3`,
  partner `$FFD7284-5` (`$3FF` none), count `$FFD7286-7`, a bit per object
  at `$FFD7200`; polling it once per frame as bounce65 does.

## 2. The library `OBJ65` (one PRG, loaded with `BLOAD`)

The same motion code as B65 (`src/obj.a` OBJSTEP: all modes, limits,
lifetimes, events, the rounded rotation) and HITPIX (`src/hitpix.a`),
assembled a second time with `-DOBJ65=1` into a stand-alone binary, so
the two never drift apart and `tests/objcheck.py` / `tests/hitcheck.py`
can check OBJ65 in Xemu the same way (a BASIC 65 driver instead of B65).

Differences from B65's build:

- No MAP: B65 maps the table 8 KB at a time at `$E000`, but an interrupt
  in BASIC 65 cannot restore the KERNAL's mapping (the 45GS02 cannot read
  MAP back). OBJ65 reads the table with 32-bit `[zp],z` pointers instead
  (slower: an estimated 1.3-1.5x B65's cycles per object; measured before
  any promise).
- Its own base page (one page inside the library, B register set around
  the step), so it touches no BASIC 65 zero page.
- The sine table (2 KB) is built by an install call into the library's
  own memory (the recurrence of B65's BOOT).
- Interrupt: `install` hooks the KERNAL IRQ vector (`$0314/$0315`), steps
  the table once per raster frame and continues to the old vector;
  `remove` puts it back. The multiplier save/restore of B65's integrator
  stays (BASIC 65's own arithmetic uses the math unit too).

Entry points (`SYS base+3*k`, arguments in A/X/Y/Z as BASIC 65's `SYS
addr,a,x,y,z` passes them, results with `RREG`):

| k | call | arguments / result |
|---|---|---|
| 0 | install | table address (bank in Z, high/low byte in Y/X); builds the sine table, hooks the IRQ, motion on |
| 1 | remove | unhooks the IRQ |
| 2 | step | one step now (motion stays off in the IRQ until `auto`) |
| 3 | auto | A = 0 off / 1 on |
| 4 | count | X/Y = number of objects (also written to the registers) |
| 5 | hitpix | X/Y = a, Z/A = b (dx, dy in a parameter block); RREG A = 0/1 |
| 6 | event | X/Y = n (or $FFFF: the first with an event); RREG A = 0/1, X/Y = n |
| 7 | move | the OBJMOVE helper: quantise a turn to 1/2^k, or exact polar |

The statements' unit conversions (degrees to 1/65536 turn, pixels to
8.8) stay in BASIC: the recipes give one-line formulas.

## Placement (settled)

The MEGA65 Book's BASIC 65 memory map: 0.1600-0.1EFF is guaranteed unused
by the KERNAL and BASIC (2304 bytes) and survives NEW and RUN; 0.1F00-
0.1FFF is BASIC's bitmap-graphics base page; banks 4/5 hold BASIC's
bitmap graphics and utilities; `SYS` reaches bank-0 code only at $0000-
$1FFF (`SYS TO ... O()` maps $2000-$7FFF to any of the first 384 KB).
So:

- the core (integrator about 1.9 KB, the entry table, the IRQ stub, the
  event bits) at 0.1600-0.1EFF, its private zero page in the top bytes
  of the $1E page (base page $1E, bytes $E8-$FF);
- the sine table (2 KB) through a 32-bit pointer in attic RAM (the K325T,
  a stock R3 and Xemu have it; a far read costs the same there as from
  chip RAM);
- HITPIX (about 1.5 KB) as a second module in banks 4/5, called with
  `SYS TO addr,O(...)`; it clashes with BASIC's bitmap SCREEN graphics,
  which an object game in text/RRB mode does not use.

## Cost of the 32-bit pointer (measured)

`tools/mkobjfar.py` generates `src/objfar.a` from B65's integrator: Y as
the field index of `(oP),y` becomes Z with `[oP],z` (Y stays where an
absolute `,y` table uses it), the 8 KB MAP windows become a 32-bit
pointer walk, the sine table is read far. Built into B65 with
`ACMEFLAGS=-DOBJFAR=1` it passes `tests/objcheck.py` (seeds 1, 5, 15, 16,
21 with 40 objects, 2, 3, 7, 9 with 70) byte for byte. Xemu,
`tests/bench/objstep.txt`, 1023 objects, ms per frame, B65 (MAP) / far
pointer:

| mode | B65 | far | |
|---|---|---|---|
| static | 0.8 | 2.0 | (loop overhead: the 32-bit step) |
| fast | 4.4 | 6.0 | 1.36x |
| fast + wrap | 10.0 | 12.8 | 1.28x |
| cartesian | 8.8 | 11.6 | 1.32x |
| cartesian + accel | 11.2 | 15.2 | 1.36x |
| cartesian + wrap | 16.4 | 22.0 | 1.34x |
| polar straight + wrap | 14.4 | 18.0 | 1.25x |
| polar curving (k = 5) + wrap | 23.6 | 29.2 | 1.24x |
| exact polar + wrap | 24.8 | 31.6 | 1.27x |
| orbit + wrap | 28.8 | 34.4 | 1.19x |
| spring + wrap | 32.0 | 38.4 | 1.20x |

(The board numbers of both builds are to come: Xemu's cycle model of
`[zp],z` may differ from the board's 10 cycles.)

**Go.** With half a frame (10 ms) for the motion, OBJ65 moves about 1700
fast (whole-pixel) objects, 800 fast with wrap limits, 880 cartesian,
460 cartesian with limits, 570 straight polar, 330 curving or exact
polar, 300 orbiting; 1000 fast bullets take 6 ms (30 % of a frame). So
the 1000-bullet case fits only in the fast mode (no limits: lifetimes
instead); with limits or sub-pixel steps about 450-800.

## Open points (to settle before code)

- Whether the KERNAL IRQ path preserves B and Z for the chained handler
  (the stub saves and restores both, as B65's handler does).
- Xemu with the MEGA65 ROM (`tests/run.py --prg`) is the test bed: an
  OBJ65 smoke (install, motion against the model, HITPIX, remove) and the
  BASIC 65 twin of jumper as the demo.
