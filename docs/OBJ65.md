# v3 objects from BASIC 65 (OBJ65)

The K325T step-6 core (feature level 3) draws up to 1023 objects from a
table in chip RAM and compares their boxes once per frame. Nothing of
that needs B65: it is memory and registers, and BASIC 65 reaches all of
it with `PEEK`, `POKE` and `WPOKE` on 28-bit addresses. Part 1 of this
chapter is a set of recipes, each a short BASIC 65 program on the D81
(`DLOAD "OBJ65R1"` ... `"OBJ65R4"`, sources in `examples/basic65/`).
Part 2 (to come) is the OBJ65 machine-code library: B65's frame-interrupt
motion and HITPIX for BASIC 65 programs (`docs/OBJ65_design.md`).

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

The screen is CHR16 (16-bit tokens, `$D054` bit 0), V400 with 50 rows, a
row of 40 tokens at `S + 80*row` (`$D058` = 80); with XCTL bit 3 each row
can just start with `$FFFF`, and the objects are appended there. Moving
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
