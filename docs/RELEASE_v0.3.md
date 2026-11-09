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

- Act 1 (S1): Maxice's SCROLLTEST (INTRO2.D81, the Green Hill scroller)
  frame for frame: seven parallax bands, the front layer's speed ramp, 64
  rings on sine paths, the cycling waterfall; BASIC with one chained DMA
  list a frame and a small inline-assembler routine for the rings, 50 fps
  (about 6 ms a frame). Decoded from the original's machine code into a
  Python model (`tests/ghzmodel.py`) that reproduces a memory dump of the
  real demo after 965 frames; B65 matches the model (`tests/ghzcheck.py`).
  The art comes from your own copy at run time (S1b): the program opens
  `INTRO2.D81` in the SD card root, finds SCROLLTEST in its directory,
  follows the sector chain and checks it ("ORIGINAL ART FROM INTRO2.D81",
  under a second); without it, the original generated tileset
  `B65GHZG.BBC` from dist/sd ("GENERATED ART"). Nothing of the original art
  is in the repository or the release.
- Act 2 (S2): "BUT HAVE YOU SEEN IT IN BASIC?" and then the program's own
  source scrolls up over the running scene (two text token sets per row
  with GOTOX Y offsets, 2 pixels a frame; the text from attic RAM through
  the same DMA list), closing with "B65 BASIC. n LINES." / "50 FRAMES PER
  SECOND.".
- Act 3 (S3): "NOW WITH THE K325T VIC-IV": on a K325T (level 3+) the rings
  move into the list-mode object table and ramp 64 -> 300 -> 1000, with 8
  clouds behind and 12 bushes in front (objects too: 10 layers), 4-pixel
  painting at level 4, a HUD with RINGS, FPS, OBJECTS and the VIC-IV's
  longest line ("1000 RINGS. 10 LAYERS. STILL BASIC."); the per-frame
  object work is one inline-assembler routine. Other cores: a one-line
  note, act 1's 64 rings. Then the closing card and the late frames per
  act (all three acts at 50 fps in Xemu apart from start-up and caption
  frames).
- The DMA job sources and the list's start moved into the assembler routine
  (BASIC set 52 sources by hand: 8% of the frames were late).
- Files: GHZ.BAS and its data files (B65GHZG.BBC, B65GHZS.BBC) go to the
  SD card root, next to INTRO2.D81: B65 reads data files from the SD card's
  root directory only, not from a mounted D81.

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
