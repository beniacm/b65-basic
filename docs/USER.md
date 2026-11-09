# B65 BASIC user guide

B65 BASIC is an interactive BASIC for the MEGA65, derived from R.T.
Russell's BBC BASIC (Z80) v5: the language of BBC BASIC (version 5 level,
much like Acorn's BASIC V), running natively on the 45GS02 with the
MEGA65's own graphics, sound and memory. Programs are typed in, LISTed,
edited and RUN on the machine. The banner shows the version and the
hardware it found.

## Starting B65

**On a MEGA65 from the D81.** `make dist` produces `dist/b65.d81`. Copy
it to the SD card, then in BASIC 65:

    MOUNT "B65.D81"
    DLOAD "B65"
    RUN

The D81 also holds the examples as text files. In B65:

    LOAD "PARALLAX"
    RUN

**Files on the SD card.** B65 itself starts from the D81 (BASIC 65 loads
programs from disk images). B65 then finds files on the SD card's FAT32
file system first and in the D81 mounted as drive 0 second, so the `.BAS`
examples in `dist/sd/` can also be copied to the SD card root. `B65.PRG`
in `dist/sd/` is for loaders that push a PRG directly (Etherload, the
harness).

**On the K325T rig.** `tests/board.py load` (from this repository) pushes
the PRG through the harness loader and starts it; see the harness
repository https://github.com/beniacm/mega65-k325t-cm4.

**In Xemu.** `tests/run.py script.txt` types a script into B65 and prints
what it printed; `tests/run.py --rom ...` boots the MEGA65 ROM first (file
access needs it).

Keyboard: like a BBC Micro, letters come out in upper case when CAPS LOCK
is off and in lower case with SHIFT (keywords must be upper case). The
line editor knows the cursor keys, HOME, INST/DEL, recall of earlier
lines and CTRL-U. RUN/STOP is ESCAPE.

## Differences from BBC BASIC V

* **Graphics:** `MODE 0` is 80x25 text, `MODE 1` is 320x200 with 256
  colours (the only graphics mode). Coordinates are pixels from the top
  left (not OS units from the bottom left); `ORIGIN` moves the origin.
  `GCOL [m,]c` and `COLOUR c` take palette numbers (0-15 the VIC colours,
  16-255 an RGB 3-3-2 cube in MODE 1). VDU covers the common text
  controls only.
* **Sound:** `SOUND chan,amp,pitch,duration` as on the BBC (channel 0 is
  noise, 1-3 tones on the SID), `ENVELOPE` with 14 parameters: the pitch
  part (t, pi1-3, pn1-3) is played as on the BBC, the amplitude part
  becomes a SID ADSR. `ADVAL(-5..-8)` returns the free queue space.
* **Files:** names are 8.3 on the SD card (FAT32); `.BBC` is added when
  there is no extension (and `.BAS` is tried after it when loading).
  Programs are saved tokenised, the same format as BBC BASIC (Z80); `LOAD`
  also accepts plain-text programs (from the SD card or the D81: lines
  without a number are appended). Channels: `OPENIN`, `OPENOUT`,
  `OPENUP`, `BGET#`, `BPUT#`, `PRINT#`, `INPUT#`/`READ#`, `GET$#`,
  `PTR#`, `EXT#`, `EOF#`, `CLOSE#` (files up to 960 KB, 4 open at a
  time; they need attic RAM). `*CAT` lists the card, `*DELETE` deletes.
  Files are written by B65's own FAT32 code (root directory only).
* **Memory:** programs live in their own 64 KB bank (`PAGE` = `&10800`,
  about 60 KB); variables and strings share about 16 KB with the stack;
  global arrays live in attic RAM (2 MB, up to 65535 elements each).
  `INSTALL "lib"` loads a library of PROCs/FNs. B65.PRG is packed: at
  start-up (about 0.7 s) it unpacks itself into bank 0 and its overlays
  into bank 4, using bank 5 as a work area.
* **Not available:** `SYS`, `TINT`, `PUT`, star commands other than
  `*CAT`, `*DELETE` and `*INFO` (version, machine, ROM, RAM, K325T level), and BBC OS calls (`CALL &FFEE` etc.); `CALL` and
  `USR` run 45GS02 code, and the inline assembler (`[ ... ]`) assembles
  45GS02 code.

## MEGA65 extensions

**Timers** (Locomotive BASIC style, four timers 0-3, t in 1/50 s):

    10 EVERY 50,1 GOSUB 100 : REM every second on timer 1
    20 AFTER 250 GOSUB 200 : REM once, after 5 s (timer 0)
    30 REPEAT : UNTIL FALSE
    100 PRINT "tick ";TIME : RETURN
    200 PRINT "five seconds" : RETURN

`TIMELEFT(n)` returns what is left of timer n (and stops it); `DI`/`EI`
disable/enable the events. `TIME` counts centiseconds.

**Sound:**

    ENVELOPE 1,2,1,-1,0,4,4,0,126,-4,0,-126,126,100
    SOUND 1,1,100,40 : REM 2 s of warbling tone on channel 1

**Graphics:**

    MODE 1 : GCOL 5 : CIRCLE FILL 160,100,50
    GCOL 7 : ELLIPSE 160,100,120,40 : GCOL 3 : FILL 10,10
    LINE 0,0,319,199 : PRINT POINT(160,100)

**Sprites** (24x21 images at `&5FC00 + n*64`, written with `?`; the
default is an arrow):

    SPRITE 0,100,80,2 : REM sprite 0 at x 100, y 80 in red
    SPRITE 0 OFF

**Mouse** (1351 mouse in port 1):

    MOUSE ON : REM arrow pointer follows the mouse
    MOUSE X,Y,B : PRINT X,Y,B : REM B: 4 left, 1 right button
    MOUSE TO 160,100

**Far memory:** `?`, `!` and `|` take 28-bit addresses: `&10000` and up is
chip RAM (bank 1 and up), `&8000000` is attic RAM, `&FF80000` colour RAM,
`&FFD3000` the VIC-IV registers in their 28-bit place.

    !&8000000=12345 : PRINT !&8000000
    ?&FF80000=7 : REM colour of the top-left character

**Attic arrays:** global arrays are in attic RAM automatically:

    DIM A(60000), B$(1000) : A(60000)=PI : B$(1000)="far"

Whole arrays: `A()=B()+C()`, `A()=B()*2`, `A()=2-B()`, `A()=-B()`,
`A()=B().C()` (matrix product), `A$()=B$()+"!"`, `SUM(A())`,
`SUMLEN(A$())`, `DIM(A(),1)`. B65 extension: `A%()=B%() AND C%()` or
`AND n` (for example `Q%()=P%() AND &3FF03FF` to mask packed X/Y). Integer
`+`, `-` and `AND` of whole arrays run a tight loop (about 6 us an element
in Xemu).

**Hardware info:** `?&6E0` = model id (`$D629`), `?&6E1` = `&FF` on a
K325T, `?&6E2`/`?&6E3` = chip RAM in KB, `?&6E4` = attic RAM in MB.

**K325T RRB list mode** (only with the K325T core; from the step-6 core on the
object table has 32-byte entries -- the examples are written for it and do
not run on older cores): the VIC-IV paints
"objects" from a table that is moved like sprites; see
`docs/rrb_list_mode.md` in the harness repository and the examples
`rrblist_b65.bas` (v1) and `rrblist_b65v2.bas` (v2). HOLD (`?&FFD71FC=1`)
keeps the VIC-IV's last snapshot of the table while a program rewrites it,
so a batch of moves appears at once; the snapshot is only taken at a frame
start while HOLD is 0. So HOLD must be 0 at some frame start: release it
and wait for the next frame (`WAIT`) before setting it again. A loop that
takes longer than a frame and releases HOLD only briefly (for example
just before `VSYNC` to a line in the middle of the picture) never gets a
new snapshot and shows a frozen picture. The VIC-IV does not clear its
raster line buffer: where a row paints nothing, the pixels of an earlier
row stay. A sparse row (GOTOX tokens and a few glyphs) therefore needs an
opaque base first (GOTOX 0, colour flags `&10`, then full-width glyphs),
unless the bitstream has XCTL bit 3 (`?&FFD71F0` OR 8, reads back 0 where it
is missing): then unpainted pixels show the background colour. XCTL bit 7
is the fast token path (cheaper full-colour glyphs); set it with list mode.
BASIC 65 programs on the K325T must set XCTL bit 0 (`POKE $FFD71F0,
PEEK($FFD71F0) OR 1`, 1 MB chip RAM) before they use memory above 384 KB
(`$60000` and up): without it writes there are dropped (B65 sets it).

**K325T collision engine** (list mode v2, K325T core only). Objects that
share a bit in their collision group mask (object table `+7`) are compared
once per frame; the box is X..X+W-1 by Y..Y+8*H-1 (`+14` = width W, 0 = 8;
H from `+5`), edges count, objects with draw mask 0 never collide. The box
test fires a little early for round shapes at the diagonals: confirm a pair
with a centre-distance test (`dx*dx+dy*dy <= (2*r)*(2*r)`) before reacting,
and a box narrower than the glyph (for an 8-pixel ball width 6) helps.

    10 ON COLLISION PROChit : REM after each pass that found a collision
    ...
    100 DEF PROChit : LOCAL I%,Q%
    110 FOR I%=0 TO 63 : Q%=COLLIDE(I%) : IF Q%>I% THEN PROCpair(I%,Q%)
    120 NEXT : ENDPROC

`ON COLLISION PROCname` enables the engine's interrupt; when a pass finds a
collision, B65's interrupt handler acknowledges it at once (writes `3` to
`&FFD71C0`: clear, interrupt stays on) and the PROC runs between statements
like an EVERY/AFTER handler (one at a time, held back by `DI`). It reads
the results of the last completed pass: `COLLIDE(n)` is the first
(lowest-numbered) partner of object n or -1 (also -1 without the engine),
`?(&FFD71A0+n DIV 8) AND 1<<(n AND 7)` tells whether object n collided.
`ON COLLISION OFF` (also RUN and the prompt) switches it off. Pairs: call
the handler work once per pair (the lower object number). Without the
K325T core `ON COLLISION` is accepted but never fires.

**Objects (list mode v3, 32-byte table entries).** B65 owns the object table:
`objbase` = `&E0000` (chip RAM) on the K325T, elsewhere `&58000` (chip
RAM: the statements and the motion run, nothing is shown). Entry n is at
`objbase+32*n` (n = 0..1023). OBJECT also writes the table address and the object count
into the list-mode registers (`&FFD71F8-FB`; from feature level 3 the count
also into `&FFD728A-B`). The program still switches list mode on (XCTL
`&FFD71F0` bits 4, 6, 7; bit 3 if present).

    OBJECT n,x,y,tokens[,colour,stride,height,mask,group,with]
    OBJVEL n,vx,vy[,ax,ay]       : REM pixels/frame, pixels/frame^2
    OBJMOVE n,speed,heading[,turn[,dspeed]] : REM degrees, 0 = right, 90 = down
    OBJORBIT n,parent,r,omega    : REM around object parent, degrees/frame
    OBJSPRING n,anchor,k         : REM a = -k*(position - anchor's)
    OBJLIFE n,frames             : REM killed (and an event) at 0
    OBJLIMITS set,x0,y0,x1,y1,action : OBJBOUNDS n,set : REM sets 0..3
    OBJKILL n                    : REM draw mask 0, motion off
    OBJUPDATE                    : REM one step now; the frame interrupt stops
    OBJUPDATE ON                 : REM the frame interrupt moves the objects again
    OBJX(n) OBJY(n) OBJVX(n) OBJVY(n) OBJEVENT(n) OBJEVENT(-1)
    HITPIX(a,b)                  : REM TRUE if their pixels touch
    ON OBJEVENT PROCname / ON OBJEVENT OFF

`tokens` is the 20-bit screen address of the object's token list, `colour`
its colour RAM offset, `height` in character rows (1..63, stored in +5 as it is: the VIC-IV reads 0 as 1), `mask`, `group`
and `with` the draw mask and the collision masks. Omitted arguments of
OBJVEL keep their value (a double jump is `OBJVEL n,,-9`); OBJVEL keeps an
OBJSPRING's pull. OBJMOVE without a speed change computes the velocity
once (mode 5, then cartesian: a straight polar bullet costs as much as a
cartesian one) and rounds its turn to the nearest 1/2^k radian per frame,
k = 1..7 (28.6, 14.3, 7.2, 3.6, 1.8, 0.9, 0.45 degrees): the velocity is
then rotated with shifts only (Minsky: VX -= VY >> k, then VY += VX >> k);
turns outside 0.32 .. 40 degrees per frame or a speed change keep the
exact polar mode 2. OBJVX/OBJVY read back the (rotated) velocity. `action` (and table byte +17): bits 1..0 for X, bits
3..2 for Y: 0 none, 1 wrap, 2 bounce, 3 kill; bit 5 halves the speed on a
bounce. OBJEVENT(n) is TRUE once after object n was killed by its limits or
its lifetime (and clears it); OBJEVENT(-1) is the lowest object with an
event, -1 if none. RUN and the prompt remove all objects.

**HITPIX(a,b)** is TRUE if a pixel of object a that is not transparent lies
on such a pixel of object b, FALSE if not: the confirmation of a box
collision for shapes that are not boxes (the jumper's player lands on a
platform when its pixels touch it, not when its box does). It looks at
the intersection of the two boxes only (X..X+W-1, Y..Y+8H-1, as the
collision engine's) and reads the glyphs as the VIC-IV draws them: object
row r's tokens at the token list address + r * stride (colour bytes at
the colour offset + r * stride), 8 pixels a glyph token, GOTOX tokens
skipped, up to `$FFFF`; FLIPX/FLIPY of the object (+6 bits 4/5) XORed
into each glyph's flips (colour byte 0 bits 6/7), FLIPY also reverses the
object rows. A glyph is full colour (64 bytes at char * 64, index 0
transparent) or mono (8 bytes at CHARPTR `$D068` + char * 8, bit 0
transparent) as `$D054` bits 1 (chars 0..255) and 2 (chars 256 and up)
say. An object with draw mask 0 never touches; REL positions, NCM glyphs
and width trims are not followed (X and Y as OBJX/OBJY read them). Cost
(Xemu, `tests/bench/hitpix.txt`, the call included): boxes apart 0.12
ms, two 8x8 glyphs 0.2 ms (a hit in the first row) to 0.36 ms (no hit),
24x24 objects up to 1.8 ms. `tests/hitmodel.py` is a model of it,
`tests/hitcheck.py` compares it with B65 on random scenes.

Table entry (bytes 0..15 are read by the VIC-IV, 16..31 only by B65):

| byte | field |
|---|---|
| +0 | X 9..0 (bit 10 REL, as v2) |
| +2 | Y 9..0, signed (bit 10 REL) |
| +4 .. +15 | draw mask, height, address 19..16 / flags, group, token list, colour offset, stride, box width, collides-with (as v2) |
| +16 | mode: bits 3..0 = 0 static, 1 cartesian, 2 polar, 3 orbit, 5 polar to cartesian (the velocity from +18/+20 once), 4 fast (whole-pixel steps: the high bytes of VX/VY; OBJVEL chooses it when there are no fractions, no acceleration and no bounce; it clears the flag bits of +1/+3, no REL); bit 4 harmonic (with 1); bits 6..5 limit set; bit 7 pixel-collision hint |
| +17 | limit action (bits 3..0 as above), bit 4 lifetime counts (kill at 0), bit 5 half restitution, bit 6 the acceleration (+22/+24) is added (OBJVEL sets it) |
| +18 | cartesian VX / polar speed / orbit radius (16-bit signed, 8.8 pixels) |
| +20 | cartesian VY / polar heading / orbit angle (16-bit; angles in 1/65536 turn) |
| +22 | cartesian AX (8.8 per frame) / polar speed change / harmonic k (8.8) |
| +24 | cartesian AY / polar and orbit turn per frame (1/65536 turn) |
| +26 | lifetime in frames (16-bit, 0 = unlimited) |
| +28 | orbit parent / harmonic anchor (object number) / cartesian turn: bits 2..0 k (a turn of 1/2^k radian per frame), bit 7 negative, 0 none |
| +30 | X fraction (1/256 pixel) |
| +31 | Y fraction |

The statements write an entry with interrupts off (SEI .. CLI), so the
frame interrupt never sees half a field; a program or `CALL` routine that
writes bytes 16..31 itself should do the same.

**The motion** runs in B65's frame interrupt for every object with a mode
(or once per `OBJUPDATE`, which also stops the interrupt's run until
`OBJUPDATE ON`), with interrupts off, the table mapped 8 KB at a time at
`$E000` (K325T: HOLD set around it). Per frame: cartesian v += a (or the
OBJSPRING pull a = -k*d, d = position - anchor's, both axes), position
+= v; polar speed += change, heading += turn, v = speed*(cos, sin)
heading; orbit angle += turn, position = parent's + r*(cos, sin) angle.
Positions keep 10 integer bits (X 0..1023, Y -512..511, wrapping) and 8
fraction bits (+30/+31); the flag bits of +1/+3 are kept. Then the
limits (an axis outside the set: none, wrap by the set's size, bounce to
the limit with the velocity or heading reflected, or kill) and the
lifetime (count down; at 0 kill if +17 bit 4). A kill sets the draw mask
and the mode to 0 and the object's event bit (ON OBJEVENT). The sine
table (1024 quarter-wave magnitudes, 16 bits) is built at start-up in
bank 0, the 2 KB after the interpreter (LOMEM starts after it). `tests/objmodel.py` is a Python model of the step,
`tests/objcheck.py` compares it with B65 byte for byte. Cost (Xemu, 1023
objects, `tests/bench/objstep.txt`, ms per frame / cycles per object):
static 1.2 / 47, fast 4.0 / 158, fast with wrap limits 9.6 / 380,
cartesian 8.4 / 332, with acceleration 10.8 / 428, plus limits 16.4 / 649,
with wrap limits: polar straight (mode 5) 14.4 / 570, polar curving
(k = 5) 23.6 / 931, exact polar 24.8 / 982, orbit 28.8 / 1140, spring
32 / 1267 (for 50 fps: a few
hundred moving objects, more in the fast mode without limits).

## Examples

| file | what |
|---|---|
| `examples/parallax.bas` | three overlapping RRB layers of full-colour glyphs, own 256-colour palette, 16-colour sprites between the layers, DMA-list scrolling; birds on a K325T |
| `examples/basic65/parallax65.bas` | the same in BASIC 65 |
| `examples/rrblist_b65.bas` | RRB list mode v1: bouncing balls (K325T only) |
| `examples/rrblist_b65v2.bas` | RRB list mode v2: bouncing balls, V400 (K325T only) |
| `examples/jumper.bas` | gravity, double jump and bounce (list mode v3 objects, step-6 core): the frame interrupt moves the player (OBJVEL with an acceleration, limits with bounce and half restitution), BASIC reads the stick (`OBJVEL 0,,-7` jumps, twice in the air); platforms by the collision engine, the landing confirmed with HITPIX (without the K325T core: HITPIX against every platform) |
| `examples/selftest.bas` | one PASS/FAIL line per subsystem (with `*INFO` first): for bug reports, see the README |
| `examples/swarm2.bas` | 1000 bullets moved by B65's frame interrupt (list mode v3 objects, step-6 core): BASIC only spawns 8 a frame (6 straight ones in the fast mode, 2 curving polar ones), OBJLIFE removes them; 50 fps in Xemu |
| `examples/swarm.bas` | 254 bullets and a player (K325T list mode v2, 255 objects): three spawners (spiral, aimed stream, sprinkler), motion with whole-array operations (`P%()=P%()+V0%()`, `Q%()=P%() AND &3FF03FF`), the object table filled by 4 chained DMA jobs from the array in attic RAM; player with the mouse or a joystick in port 2, ON COLLISION counts hits (bullets and player in different collision groups). 4.7 ms a frame in Xemu: 50 fps |
| `examples/bounce.bas` | 64 shaded balls that bounce off the walls and off each other: list mode v2 objects, the K325T collision engine (ON COLLISION, COLLIDE); elsewhere 8 sprites. Behind them four parallax star planes (1/4, 1/2, 1, 2 pixels a frame) as sparse RRB rows: per row 6 stars a plane, each a GOTOX token and one full-colour glyph (48 tokens a row; without XCTL bit 3 an opaque black base first: GOTOX 0 and 80 black glyphs, 129 tokens); per frame one DMA list (8 plane jobs into a staging area, 50 row copies) rewrites all GOTOX positions from ramp tables (K325T: chip RAM banks 9-11, else attic RAM; 0.6 ms in B65). B65: about 14 ms a frame in Xemu plus about 1.3 ms per colliding pair, so 50 fps; BASIC 65 twin (`examples/basic65/bounce65.bas`, 32 balls): 25 fps |
| `examples/basic65/bounce65.bas` | the same in BASIC 65 with 32 balls (polls the engine) |

ESCAPE stops a demo; the parallax demo then returns to the text screen.
