# B65 BASIC v0.3-dev (changelog, draft)

Changes since v0.2 (tag v0.2 on 46cf09e). To be released with the K325T
step-7 core (feature level 4: XCTL2 `$FFD71F1` bit 0, 4-pixel painting);
until then this file grows with every change.

## For BASIC 65: OBJ65

- `docs/OBJ65.md` part 1: the v3 object table and the collision engine
  from BASIC 65 with POKEs only; four recipes on the D81 (OBJ65R1: the
  core and its registers; R2: one object; R3: 32 objects in one batch
  under HOLD; R4: the collision page polled, incl. object 300).
  Verified on the board.
- The OBJ65 library (part 2): B65's frame-interrupt motion (OBJ65 at
  `$1600`) and the sine table, events and HITPIX (OBJ65X, bank 5) for
  BASIC 65 programs, generated from B65's own code and checked against
  the same Python models in Xemu (`tests/obj65test.sh`). Board budget:
  about 1000 fast bullets per frame (5.6 ms), 500-950 objects with
  limits or sub-pixel steps in half a frame; B65 is 1.13-1.27x faster.
- `examples/basic65/jumper65.bas`: the BASIC 65 twin of jumper on OBJ65;
  on the board both landing paths (HITPIX each frame, and the collision
  engine's event) end exactly as B65's jumper.
- Screen rows: a row must not start with `$FFFF` (it advances only 2
  bytes); the recipes and jumper65 use one transparent GOTOX per row.

## Step-7 core: 4-pixel painting (XCTL2)

- Every demo that switches list mode on with the fast token path (XCTL
  bits 4 and 7) also sets XCTL2 (`$FFD71F1`) bit 0, 4-pixel painting, when
  the feature level (`$FFD71FD`) is 4 or more, and clears it before it
  clears XCTL: jumper, swarm, swarm2, bounce, parallax, walkers
  (`PROCxctl2`), and for BASIC 65 OBJ65R2-R4, jumper65, bounce65,
  parallax65, walkers65 (`GOSUB 9000`). Feature levels 1-3 and Xemu
  (level 0) are untouched: nothing is written there. rrblist_b65 and
  rrblist_b65v2, SELFTEST and board_v3 switch list mode on without bit 7
  and stay as they are. The interpreter writes XCTL only for bit 0 (1 MB
  chip RAM, at start-up) and the OBJ65 library likewise; neither touches
  XCTL2.
- In the GHDL mirrors of the step-7 core, 4-pixel painting cuts the
  longest line painting from 1524 to 784 cycles (swarm2) and from 474 to
  292 (bounce); board figures follow.

## GHZ: SCROLLTEST in B65 (examples/ghz.bas, docs/GHZ.md)

A three-act showpiece, 30 s an act, about 90 s, all of it a B65 BASIC program with
small inline-assembler routines:

- **Act 1** "YOU HAVE SEEN THIS ON MEGA65": Maxice's SCROLLTEST (the Green
  Hill scroller of INTRO2.D81) frame for frame: seven parallax bands, the
  front layer's speed ramp, 64 rings on sine paths, the cycling waterfall.
  Decoded from the original's machine code into a Python model
  (`tests/ghzmodel.py`) that reproduces a memory dump of the real demo after
  965 frames; B65 matches the model frame for frame in Xemu
  (`tests/ghzcheck.py`).
- **Act 2** "BUT HAVE YOU SEEN IT IN BASIC?" (the fixed top line): the
  scene turns into a BASIC screen (the band layer paints a blue panel), a LIST of the
  program's frame loop, DMA list and ring routines scrolling under the
  caption (two text token sets per row with GOTOX Y offsets and row masks,
  1 pixel a frame), the scene going on below; then "B65 BASIC. n LINES." /
  "50 FRAMES PER SECOND.".
- **Act 3** "NOW WITH THE K325T VIC-IV" (K325T core, feature level 3 or
  more): the rings move into the list-mode object table and ramp
  64 -> 300 -> 1000, with 8 clouds behind and 12 bushes in front as objects
  too (10 layers), 4-pixel painting at level 4, a HUD row with RINGS, FPS,
  OBJECTS and the VIC-IV's longest painting: "1000 RINGS. 10 LAYERS. STILL
  BASIC." Other cores: a one-line note and act 1's 64 rings. Then the
  closing card ("B65 BASIC FOR MEGA65 AND K325T",
  github.com/beniacm/b65-basic) and one line per act with its frames and
  late frames (on a K325T also the longest painting and the late pixels).
- **The art comes from your own copy** at run time: the program opens
  `INTRO2.D81` in the SD card root (every card from the filehost has it),
  finds SCROLLTEST in its directory, follows its sector chain with `PTR#`
  and the new block `BGET#`, checks it and takes the tiles, palette and
  tables from it ("ORIGINAL ART FROM INTRO2.D81", under a second). Without
  it the original generated tileset `B65GHZG.BBC` ("GENERATED ART").
  Nothing of the original art is in the repository or the release; act 3's
  rings, clouds and bushes are original art in `B65GHZS.BBC`.
- **Files:** GHZ.BAS, `B65GHZG.BBC` and `B65GHZS.BBC` (dist/sd) go to the
  SD card root, next to INTRO2.D81: B65 reads data files from the SD card's
  root directory only, not from a mounted D81.

Board figures (QMTECH K325T, step-7 core, level 4; art from INTRO2.D81;
`LOAD "GHZ"` / `RUN` from the card):

| run | result |
|---|---|
| act 1, 1500 frames (c4dca80) | 3010 cs (3000 at 50 fps; the extra frames are the start-up) |
| act 2, 3600 frames (c4dca80) | 7212 cs |
| the whole demo (ddfdaa5), 175 s | act 1: 3000 frames, 3 late; act 2: 2970 frames, 0 late; act 3: 1001 frames, 3 late (the caption frames) |
| act 3 HUD at 1000 rings | RINGS 1000, FPS 50, OBJECTS 1020, LINE 1895 (pixel cycles of 5184, DBLRR) |
| before the job sources moved into the assembler routine (4c88bae) | act 1, 1500 frames: 3192 cs (6% late) |

All screen updates run in the vertical blank (RING waits for raster
line 254); the scroll speed ramps in act 1 only. Late frames are counted from each act's 11th frame through the VIC-IV's
frame counter `$D7FA`. In Xemu (stock core path): act 1 4 late (start-up),
act 2 0, act 3 0.

## B65

- Version string v0.3-dev (`*INFO` tells it from the release).
- `BGET#c,addr,n`: a block read, n bytes from `PTR#` (fewer at the end of
  the file) to memory at addr (28-bit; below &10000 bank 0), `PTR#` moves
  on; about 0.5 ms a KB instead of a BASIC `BGET#` loop
  (`tests/hw/03_chan.txt`).
- The compiled-expression cache has 16 ways instead of 4: a loop with more
  hot expressions than ways in one cache group (a matter of where its lines
  lie in memory) recompiled them on every pass; GHZ's act 3 missed up to
  226 of 400 frames in some layouts, none now. Benchmarks unchanged.
- Test mode: INKEY/INKEY$ at the end of a test script return "no key" (the
  program goes on) instead of ending the session (on the board a polling
  program was abandoned after its first INKEY).

## Build and tests

- `tools/fixbranches.py` builds OBJ65 and OBJ65X too and creates
  `build/`; `make dist` puts OBJ65, OBJ65X and the new BASIC 65 programs
  on the D81.
- `tests/smoke.sh` ends with `tests/farcheck.sh`: the OBJFAR build (B65
  with OBJ65's far-pointer integrator) from a clean checkout, checked
  against the model.

## To come before the release

- Board figures for XCTL2 (swarm2, bounce: XCTL $D9 against $D9 + XCTL2
  $01).
