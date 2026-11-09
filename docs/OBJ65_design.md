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

## Open points (to settle before code)

- Where the library lives in bank 0 under BASIC 65 (code about 3.5 KB,
  plus 2 KB sine table, plus a page of base page and buffers): the
  BASIC 65 memory map has to be checked (candidates: the area below
  `$2001`, or high in bank 0 with the program kept below it).
- Whether the KERNAL IRQ path preserves B and Z for the chained handler
  (the stub saves and restores both, as B65's handler does).
- Xemu with the MEGA65 ROM (`tests/run.py --prg`) is the test bed: an
  OBJ65 smoke (install, motion against the model, HITPIX, remove) and the
  BASIC 65 twin of jumper as the demo.
