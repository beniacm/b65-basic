# v3 objects from BASIC 65 (OBJ65)

The K325T step-6 core (feature level 3) draws up to 1023 objects from a
table in chip RAM and compares their boxes once per frame. Nothing of
that needs B65: it is memory and registers, and BASIC 65 reaches all of
it with `PEEK`, `POKE` and `WPOKE` on 28-bit addresses. Part 1 of this
chapter is a set of recipes, each a short BASIC 65 program on the D81
(`DLOAD "OBJ65R1"` ... `"OBJ65R4"`, sources in `examples/basic65/`).
Part 2 is the OBJ65 machine-code library: B65's frame-interrupt motion
and HITPIX for BASIC 65 programs (design: `docs/OBJ65_design.md`).

## Part 1: recipes

### Is it there? (OBJ65R1)

    100 k=0:if peek($d629)=98 then x=peek($ffd71f0):poke $ffd71f0,x or 1:k=(peek($ffd71f0) and 1)=1
    120 lv=peek($ffd71fd)

The K325T core reports model `$62` (98) at `$D629`, and its XCTL register
`$FFD71F0` keeps bit 0 (1 MB chip RAM) when it is written. Set bit 0
before the program touches chip RAM above `$5FFFF` (BASIC 65 does not set
it; without it such writes are dropped). `PEEK($FFD71FD)` is the feature
level: 3 or more for the 32-byte table of this chapter (level 4, a later
core, keeps everything here and adds to it: test `>= 3`).

### One object (OBJ65R2)

Three things in chip RAM and a few registers:

- **The glyph**: full colour (FCM), 8x8 bytes at char * 64, colour index
  0 transparent; chars from 256 on are full colour with `$D054` bit 2.
  OBJ65R2 puts char `$1800` at `$60000` (FCM glyphs must be in the first
  512 KB).
- **The token list**: the glyphs of each object row, 16-bit screen words,
  ended by `$FFFF` (`WPOKE OA,$1800,$FFFF`), and their colour words at
  the colour offset (`WPOKE $FF80000+OC,0`: no flips).
- **The table entry** n at `TB + 32*n`; the VIC-IV reads bytes 0..15:

| byte | field | OBJ65R2 |
|---|---|---|
| +0 | X 0..1023 (bit 10 REL) | `WPOKE TB,X,Y` |
| +2 | Y, signed 10 bits (bit 10 REL) | (same WPOKE) |
| +4 | draw mask (0 hides it) | 255 |
| +5 | height in character rows (0 and 1: one) | 1 |
| +6 | address bits 19..16 of the token list; bit 4 FLIPX, 5 FLIPY, 6 transparent, 7 behind | 8 (`$8xxxx`) |
| +7 | collision group mask | 0 |
| +8 | token list address bits 15..0 | `$9000` (`$89000`) |
| +10 | colour offset of the token list | `OC` |
| +12 | row stride (bytes from one object row to the next) | 0 |
| +14 | collision box width (0 = 8) | 0 |
| +15 | collides-with mask (0: the same as +7) | 0 |
| +16..+31 | not read by the VIC-IV (the OBJ65 library's motion block) | 0 |

- **The registers**: table address `$FFD71F8-FA` (20 bits), count
  `$FFD71FB` (low byte) and `$FFD728A-B` (10 bits), then XCTL `$FFD71F0`
  OR `$D9`: bit 0 (1 MB), 3 (unpainted pixels show the background), 4
  (list mode), 6 (the object table), 7 (fast tokens; always set it with
  4). Clearing them (`AND $27`) switches the objects off.

The screen is CHR16 (16-bit tokens, `$D054` bit 0), V400 with 50 rows.
The recipes give each row a single token, a transparent GOTOX to x 0
(screen word 0, colour bytes `$90,$00`), with a row length of one token
(`$D058` = 2, `$D05E` = 1): with XCTL bit 6 the objects are appended
after the row's tokens.

**A row must not start with `$FFFF`.** A row whose first token is the end
marker is a short row of 2 bytes (the RRB rule), so the next row starts
2 bytes after that `$FFFF` and paints whatever bytes it finds there (on
the board: a strip of glyph 0 in random colours). The end marker goes at
the row's end (byte LINESTEP - 2), or the row is a single GOTOX as here.
B65's demos fill their rows with tokens (jumper, swarm and swarm2 blank
glyphs, bounce GOTOX tokens).

Moving
the object is one `WPOKE TB,X,Y` a frame (`VSYNC 251` waits for the
bottom of the picture).

### Many objects in one batch (OBJ65R3)

HOLD (`$FFD71FC` = 1) keeps the VIC-IV's last snapshot of the table, so
a batch of writes appears at once:

    350 poke $ffd71fc,1:for i=0 to n-1:wpoke tb+32*i,x(i),y(i):next i:poke $ffd71fc,0
    360 vsync 251

The snapshot is taken only at a frame start while HOLD is 0: release it
before waiting for the frame, or the picture freezes. The table is
cleared with one DMA fill, `EDMA 3,32*N,0,TB`. BASIC 65 moves about 32
objects at 50 frames per second this way; more need the library.

### Collisions (OBJ65R4)

The engine compares every pair of objects with a draw mask and a group
once per frame: A and B collide if A's group (+7) shares a bit with B's
collides-with mask (+15, 0 = its +7) and the other way round, and their
boxes overlap (X..X+W-1, Y..Y+8H-1, edges included). Bullets as group 2
with 1 and the player as group 1 with 2: bullets hit the player and
never each other. The results of the last pass, in the v3 page:

| address | |
|---|---|
| `$FFD7280` | status: bit 0 a pass found a collision (latched; write 1 to clear), bit 1 interrupt enable, bit 7 pending |
| `$FFD7282-3` | object number (10 bits), written before reading the partner |
| `$FFD7284-5` | its first (lowest-numbered) partner, `$3FF` = none |
| `$FFD7286-7` | number of objects that collided |
| `$FFD7200-$FFD727F` | a bit per object: byte n/8, bit n AND 7 |

Polled once a frame:

    320 if (peek($ffd7280) and 1)=0 then 360
    330 poke $ffd7282,mod(o,256),int(o/256):p=peek($ffd7284)+256*(peek($ffd7285) and 3)
    340 poke $ffd7280,1

The pass uses the frame's snapshot, so its results describe the
positions of the frame before: a fast object that touches another for
one frame only may have moved on when the program reads them (B65's
HITPIX, and later the library's, confirms such a contact on the
pixels).

### Notes for BASIC 65

- `PEEK`/`POKE`/`WPOKE` with an address of `$10000` and above are flat
  28-bit addresses (`$FFD71F0` is the K325T register page, `$FF80000`
  colour RAM, 64 KB on the K325T); several values after one `POKE` go to
  consecutive bytes.
- Chip RAM above `$5FFFF` needs XCTL bit 0 first (recipe 1).
- Every recipe saves the VIC-IV registers it changes and puts them back
  (lines 900-980), and stops after a fixed number of frames.
- The table, token lists and glyphs of the recipes sit at `$60000`-
  `$8CFFF`: above BASIC 65's banks 0-5, so they survive NEW and RUN.

## Part 2: the OBJ65 library

Two files on the D81, both made from B65's own code (the motion of
`src/obj.a`, generated for 32-bit table pointers by `tools/mkobjfar.py`;
HITPIX of `src/hitpix.a`, by `tools/mkhit65.py`), so they move and test
pixels exactly as B65 does (`tests/obj65test.sh` checks both against the
Python models):

- **OBJ65** (2.5 KB, `$1600-$1FE7`): the motion of every object once per
  frame from the KERNAL's raster interrupt. It lives in BASIC 65's free
  area `$1600-$1EFF` and uses `$1F00-$1FFF`, BASIC's bitmap-graphics base
  page, so it does not go with BASIC's bitmap graphics (SCREEN, LINE,
  ...); text and RRB screens are fine. NEW and RUN keep it.
  The KERNAL's raster interrupt comes at line 255, below the picture,
  and on the K325T the step sets HOLD while it runs: a step that takes
  more than about 3.5 ms is still holding at the next frame top, the
  VIC-IV skips its snapshot and the objects stand still. Keep the step
  short: with the costs in docs/USER.md ("The motion": 1023 objects 4.0
  ms in the fast mode, 8.4 ms cartesian, B65's figures; OBJ65's far
  pointers cost a little more) that is roughly 400 cartesian objects or
  900 in the fast mode, fewer with limits or polar motion (jumper65 moves
  7). B65 itself steps after the frame top and has the whole frame.
- **OBJ65X** (1.8 KB, loaded at `$52000`, using bank 5 up to `$57FFF`):
  the sine table builder, events and HITPIX, called with `BANK 5:SYS
  $2000+3*k:BANK 128` (bank 5's `$2000-$7FFF` is mapped while it runs).
  Bank 5 is BASIC's graphics area too.
- **Attic RAM**: the sine table (2 KB) is at `$87FF800`. Every MEGA65 has
  the HyperRAM (attic RAM); Xemu has it as well.

    10 bload "obj65":bload "obj65x",p($52000)
    20 bank 5:sys $2000:bank 128      : rem the sine table (once)
    30 sys $1600,8,$c0,n,0             : rem install: table $8C000, n objects
    40 sys $1609,1                     : rem the frame interrupt moves them

### Calls

| call | registers | |
|---|---|---|
| `SYS $1600,A,X,Y,Z` | A = table address bits 19..16, X = bits 15..8 (the table is page aligned), Y/Z = number of objects (low/high) | install: hooks the interrupt (once), clears the events, K325T: writes the table address and count registers; motion off |
| `SYS $1603` | | remove: the KERNAL's interrupt vector back, motion off (do it before the program ends) |
| `SYS $1606` | | one step now; the interrupt's steps stop (`SYS $1609,1` restarts them) |
| `SYS $1609,A` | A = 1 on, 0 off | the frame interrupt moves the objects (or not) |
| `SYS $160C,0,X,Y` | X/Y = number of objects | a new count (also the registers) |
| `BANK 5:SYS $2000:BANK 128` | | the sine table in attic RAM (once after loading) |
| `BANK 5:SYS $2003,0,X,Y:BANK 128:RREG A,X,Y` | X/Y = object, or 255/255 | A = 1 if its event bit was set (it is cleared); with 255/255: A = 1 and X/Y = the lowest object with an event, A = 0 if none |
| `WPOKE $52009,A,B,DX,DY:BANK 5:SYS $2006:BANK 128:RREG R` | objects a, b, a moved by dx, dy (negative: + 65536) | HITPIX: R = 1 if their pixels touch, 0 if not, 255 for a number above 1023 |

Fixed addresses in bank 0: `$160F` table address (4 bytes), `$1613`
count, `$1615` bit 7 = motion on, `$1616` $FF on the K325T, `$1617` the
feature level, `$1618` the limit sets (4 x 9 bytes: x0, y0, x1, y1 as 16
bits, then the action), `$163C` the event bits (object n: byte n/8, bit n
AND 7; a kill sets it).

### The motion block (entry bytes 16..31)

The library moves an object as B65 does (USER.md "Objects"); BASIC 65
writes the fields directly (WPOKE values from 32768 on are negative
numbers + 65536):

| byte | | BASIC 65 |
|---|---|---|
| +16 | mode: 0 static, 1 cartesian, 2 polar (exact), 3 orbit, 4 fast (whole pixels), 5 polar to cartesian; bit 4 spring (with 1); bits 6..5 limit set | `POKE E+16,1` |
| +17 | limit action (bits 1..0 X, 3..2 Y: 1 wrap, 2 bounce, 3 kill), bit 4 the lifetime counts, bit 5 half restitution, bit 6 the acceleration is added | `POKE E+17,$6A` (bounce both, half, acceleration) |
| +18/+20 | VX, VY in 1/256 pixel (cartesian, fast: the high byte is the step); polar: speed, heading (65536 = a full turn) | `WPOKE E+18,768` (3 px a frame) |
| +22/+24 | AX, AY (1/256 px per frame); polar: speed change, turn | `WPOKE E+24,89` (gravity 0.35) |
| +26 | lifetime in frames | |
| +28 | orbit parent / spring anchor; cartesian: a turn of 1/2^k radian per frame (bits 2..0 k, bit 7 negative) | |
| +30/+31 | X/Y fractions | |

Writing a 16-bit field with `WPOKE` while the interrupt moves the object
can tear for one frame; for several fields at once switch the motion off
(`SYS $1609,0`) around them, as jumper65 does for a landing.

### Budget

The motion costs per frame, for 1023 objects, measured on the K325T board
(`tests/bench/objstep.txt`); B65 does the same work 1.13-1.27 times
faster (its figure in brackets):

| mode | ms per frame | objects in half a frame (10 ms) |
|---|---|---|
| static (no motion) | 1.6 (1.2) | |
| fast (whole pixels), no limits | 5.6 (4.4) | about 1800 |
| fast with wrap limits | 11.6 (9.6) | about 880 |
| cartesian | 10.8 (8.8) | about 950 |
| cartesian with an acceleration | 13.6 (11.2) | about 750 |
| cartesian with wrap limits | 20.0 (16.4) | about 510 |
| polar, straight, with limits | 16.4 (14.4) | about 620 |
| polar, curving (k = 5), with limits | 27.2 (23.6) | about 380 |
| polar, exact, with limits | 29.2 (25.2) | about 350 |
| orbit, with limits | 32.0 (28.4) | about 320 |
| spring, with limits | 36.0 (32.0) | about 280 |

So with OBJ65 budget about 1000 fast bullets per frame (whole-pixel
steps, lifetimes instead of limits: 5.6 ms, 28 % of a 20 ms frame), or
500-950 objects with limits or sub-pixel steps in half a frame. HITPIX:
about 0.15 ms for two objects whose boxes are apart, 0.2-0.4 ms for two
8x8 objects, plus BASIC 65's call (a few hundred microseconds).

(Xemu measures 1.19-1.36x between the two builds, the board 1.13-1.27x;
Xemu's figures for OBJ65: fast 6.0, cartesian 11.6, cartesian + wrap
22.0, exact polar 31.6 ms.)

### jumper65

`examples/basic65/jumper65.bas` (on the D81 as JUMPER65, with OBJ65 and
OBJ65X) is the BASIC 65 twin of B65's jumper: the library moves the
player, BASIC 65 reads the stick, polls the collision engine for the
platform touched (K325T) and confirms the landing with HITPIX over the
last two frames' fall; without the K325T (or in its test, `BN` > 0) it
tests HITPIX against every platform each frame. Its landing script ends
exactly as B65's (`tests/obj65check.py --jumper`).
