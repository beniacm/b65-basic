# B65 BASIC v0.2-dev (release notes, draft)

Draft: to be published together with the K325T step-6 core (list mode v3:
32-byte object table entries). Before publishing (the version string is
already v0.2-dev): rebuild `b65.prg` / `b65.d81` (`make dist`),
run the smoke and card tests and SELFTEST on the board with the step-6
bitstream, and fill in the board numbers marked TBD.

## The flag day: 32-byte object entries

The step-6 K325T core reads its object table with 32-byte entries (list
mode v3): bytes 0..15 are the v2 fields, bytes 16..31 belong to B65's
motion code. There is no v2 (16-byte) mode any more, so this release and
the step-6 bitstream go together:

- All examples that use list-mode objects (bounce, swarm, swarm2, jumper,
  rrblist_b65v2, the K325T parts of parallax and walkers, the BASIC 65
  twins) are written for 32-byte entries. Do not run them on K325T
  bitstreams of feature levels 1-2 (they show garbage). The first line of
  every example says what it needs (`1 REM Core: ...`); `*INFO` shows the
  feature level (`?&FFD71FD`).
- Own programs that build a v2 table by hand: entry n moves from
  `base + 16*n` to `base + 32*n`.
- Without the K325T core the object statements and the motion still run
  (the table is then in chip RAM at `$58000`), nothing is drawn.

## New since v0.1-dev.1

### Speed (5-6 times BASIC 65)

v0.1-dev.1 ran at about BASIC 65's speed. Per statement on the board
(40.5 MHz, loop removed), BASIC 65 / v0.1-dev.1 / v0.2-dev: POKE 135 /
140 / 24 us, integer add and IF 142 / 160 / about 24 us per statement,
a 4-byte `!` write 162 / 180 / 40 us, a MOD/AND expression 328 / 360 /
62 us (board figures of 2026-11-08; the later changes TBD). How:

- Integer constants pre-encoded when a line is entered, integers without
  the floating point package, an integer FOR...NEXT path, DIV/MOD and `*`
  on the math unit, static integer variables read and written directly.
- A compiler for numeric expressions, assignments and single-line IFs
  (overlay 4): compiled code cached by text address (four ways), cleared
  by RUN/CLEAR/edits; array elements, `?`/`!` reads, shifts, COLLIDE(),
  MOD and DIV compiled.
- GOTO/GOSUB targets and PROC/FN definitions cached; PROC/FN arguments
  straight into the parameter slots, formals bound from a cached list
  (kept between calls of the same DEF), LOCAL frames copied directly.
- REM/DATA/ELSE skipped by the line length.
- Xemu, us per call: GOSUB 28, PROCa 40, PROCb(1,2) 86, FNd(3) 116.

### List mode v3 objects (K325T step-6 core)

B65 owns the object table (up to 1024 objects) and moves the objects in
its frame interrupt, so BASIC only starts and steers them:

    OBJECT n,x,y,tokens[,colour,stride,height,mask,group,with]
    OBJVEL n,vx,vy[,ax,ay]      OBJMOVE n,speed,heading[,turn[,dspeed]]
    OBJORBIT n,parent,r,omega   OBJSPRING n,anchor,k
    OBJLIFE n,frames            OBJLIMITS set,x0,y0,x1,y1,action
    OBJBOUNDS n,set             OBJKILL n
    OBJUPDATE / OBJUPDATE ON    ON OBJEVENT PROCname / OFF
    OBJX(n) OBJY(n) OBJVX(n) OBJVY(n) OBJEVENT(n) OBJEVENT(-1)
    HITPIX(a,b[,dx,dy])

- Motion modes: cartesian (with an acceleration), a whole-pixel fast mode,
  polar (straight bullets cost as much as cartesian ones; turns of
  1/2^k radian per frame by rotation, other turns exact), orbits around
  another object, springs; limits with wrap, bounce (optionally half
  restitution) or kill, lifetimes, events for killed objects.
- Cost in Xemu for 1023 objects: 4 ms per frame in the fast mode, 8-16 ms
  cartesian, 14-25 ms polar (see USER.md "Objects").
- HITPIX(a,b): the pixel test after a box collision (full colour index 0
  and mono bit 0 are transparent, flips and heights honoured); with
  dx,dy object a as if moved (the jumper stands on a platform while a
  platform pixel is under one of its own).
- The motion is checked byte for byte against a Python model
  (`tests/objcheck.py`), HITPIX too (`tests/hitcheck.py`).

### The K325T collision engine

`ON COLLISION PROCname` / `OFF` and `COLLIDE(n)` (first partner of object
n): the hardware compares the boxes of the objects once per frame, B65
runs the PROC between statements.

### Diagnostics

- `*INFO`: one line with the B65 version, machine, ROM, chip/attic RAM
  and the K325T feature level.
- `examples/selftest.bas` (SELFTEST on the D81): one PASS/FAIL line per
  subsystem (arithmetic, strings, procedures, attic arrays, files,
  timers, events, sound, graphics, sprites, objects, HITPIX, the K325T
  collision engine). Reports from a standard MEGA65 are very welcome:
  paste `*INFO` and the SELFTEST output into an issue at
  https://github.com/beniacm/b65-basic/issues.

### Language and other changes

- Whole arrays: the B65 extension `A%()=B%() AND C%()` / `AND n`;
  integer `+ - AND` of whole arrays run a tight loop (about 6 us an
  element); whole-array assignment inside loops fixed.
- `WAIT` waits for the VIC-IV frame counter (`$D7FA`): no lost frames
  when the frame interrupt runs long.
- PROC/FN names with a type suffix (`DEF FNs$(T$)`) fixed.
- The PRG is packed (LZH): the boot code unpacks the interpreter into
  bank 0 and the overlays into bank 4 at start-up (about 0.8 s).
- New examples: `bounce.bas` (64 balls off each other, four parallax
  star planes), `swarm.bas` (255 objects), `swarm2.bas` (about 1000
  bullets moved by the frame interrupt), `jumper.bas` (gravity, double
  jump, pixel-accurate platforms), `selftest.bas`; a BASIC 65 twin of
  bounce for comparison.

## Compatibility

- Tokenised programs SAVEd by v0.2-dev do not run in v0.1-dev.1
  (constants are pre-encoded); keep text copies to move programs between
  versions.
- Variables, strings and the stack now share about 11 KB of bank 0
  (LOMEM `$A300`, HIMEM `$CF00`; v0.1-dev.1: about 16 KB); programs are
  still in their own bank, global arrays in attic RAM.
- A program that changes its own text may run stale compiled code until
  `CLEAR`.
- OBJECT's height is the number of rows (1..63), as the VIC-IV reads
  table byte +5.

## Verified

TBD at release: smoke 32/32 in Xemu, the check scripts, card tests, and
on the K325T rig with the step-6 bitstream: SELFTEST, bounce, swarm,
swarm2, jumper, parallax. A standard MEGA65 has not been tested yet.
