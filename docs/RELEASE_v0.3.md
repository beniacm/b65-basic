# B65 BASIC v0.3 (release notes)

Changes since v0.2 (tag v0.2 on 46cf09e). B65 BASIC v0.3 goes together with
the K325T step-7 core (feature level 4: XCTL2 `$FFD71F1` bit 0, 4-pixel
painting).

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
  292 (bounce).
- On the board (batch 4 core, one 3-5 s window per run, the counters
  cleared with the demo running):

  | demo | XCTL | XCTL2 | longest painting (cycles) | port collisions | late pixels |
  |---|---|---|---|---|---|
  | bounce | $D9 | $01 | 326 | 0 | 0 |
  | bounce | $D9 | $00 | 578 | 0 | 0 |
  | swarm2 (moving) | $D9 | $01 | 651 | 0 | 0 |
  | swarm2 (moving) | $D9 | $00 | 1592 | 0 | 0 |

  The swarm2 pair was measured with the integrator fix (see "Fixed"
  below), the swarm moving; an earlier pair (387 against 844) came from
  the frozen-snapshot case and is void. The core's diagnostic counter 26
  (line start to the first object part) does not count in 4-pixel mode on
  this core (fixed in the next core build; diagnostic only).

## GHZ: SCROLLTEST in B65 (examples/ghz.bas, docs/GHZ.md)

A three-act showpiece, all of it one B65 BASIC program with small
inline-assembler routines, 50 frames per second throughout. Acts of 30 s,
30 s and 28 s, then a closing card.

video: (link follows)

- **Act 1** "YOU HAVE SEEN THIS ON MEGA65": Maxice's SCROLLTEST (the Green
  Hill scroller of INTRO2.D81) frame for frame: seven parallax bands, the
  front layer's speed ramp, 64 rings on sine paths, the cycling waterfall.
  Decoded from the original's machine code into a Python model
  (`tests/ghzmodel.py`) that reproduces a memory dump of the real demo after
  965 frames; B65 matches the model frame for frame in Xemu
  (`tests/ghzcheck.py`).
- **Act 2** "BUT HAVE YOU SEEN IT IN BASIC?" (a fixed top line): a LIST of
  the program's frame loop, DMA list and ring routines scrolls up pixel by
  pixel straight over the running scene, white with a black shadow on a
  transparent background; then "B65 BASIC. n LINES." / "50 FRAMES PER
  SECOND.". Text is always in front: in acts 1-2 the text is the last token
  set of every row; in act 3 the rings are kept out of a caption's row while
  it shows, as row 0 is kept free for the HUD.
- **Act 3** "NOW WITH THE K325T VIC-IV": the rings move into the K325T's
  list-mode object table and ramp 64 -> 300 -> 1000, with 8 clouds behind
  and 12 bushes in front as objects too (10 layers), a HUD row with RINGS,
  FPS, OBJECTS and the VIC-IV's longest painting, and "1000 RINGS. 10
  LAYERS. STILL BASIC." Then the closing card ("B65 BASIC FOR MEGA65 AND
  K325T", github.com/beniacm/b65-basic) and one line per act with its
  frames and late frames (on a K325T also the longest painting and the
  late pixels).
- **The art comes from your own copy** at run time: the program opens
  `INTRO2.D81` in the SD card root (every card from the filehost has it),
  finds SCROLLTEST in its directory, follows its sector chain with `PTR#`
  and the new block `BGET#`, checks it and takes the tiles, palette and
  tables from it ("ORIGINAL ART FROM INTRO2.D81", under a second). Without
  it, the original generated tileset `B65GHZG.BBC` ("GENERATED ART").
  Nothing of the original art is in the repository or the release; act 3's
  rings, clouds and bushes are original art in `B65GHZS.BBC`.
- **Files:** GHZ.BAS, `B65GHZG.BBC` and `B65GHZS.BBC` (dist/sd) go to the
  SD card root, next to INTRO2.D81: B65 reads data files from the SD card's
  root directory only, not from a mounted D81.
- **Which machine:** acts 1 and 2 use only VIC-IV features of a standard
  MEGA65 (RRB rows with GOTOX, row masks, DBLRR, DMA); act 3 needs the K325T
  core's list mode (feature level 3 or more; recorded at level 4, which adds
  4-pixel painting). On another core act 3 shows a one-line note and act 1's
  64 rings. **A standard MEGA65 has not been tested:** acts 1 and 2 should
  look the same there. If you have one, please run GHZ and paste the closing
  lines (frames and late frames per act), `*INFO` and the SELFTEST output
  into an issue at https://github.com/beniacm/b65-basic/issues.

Recorded on 2026-11-10 on the QMTECH K325T board (feature level 4; art from
INTRO2.D81; `LOAD "GHZ"` / `RUN` from the card), the release build
ab024b7 (same binaries as 118aa99):

| act | frames | late frames | longest painting (pixel cycles) | late pixels |
|---|---|---|---|---|
| 1 | 1500 | 3 | 1076 | 0 |
| 2 | 1500 | 0 | 1602 | 0 |
| 3 | 1401 | 27 | 1635 | 0 |

0 one-frame glitches in the 105 s video. 668bf11 (S9) removed the waterfall
magenta of the first 19 frames (the palette is complete before the display
goes on, at frame 12) and the static run at act 1 -> 2 (the act changes'
code runs once at the start, display off). The S9 and S10 board takes then
reported act 3 with 294 and 283 late frames although their videos show no
lost frame: a counting fault. BASIC read the frame counter `$D7FA` after
RING returned, and in act 3 RING returns right at the frame top, where the
counter steps. When one frame's read fell just after the step and the
next one's just before, the difference was 0 and `(Q%-LQ%-1) AND 255`
added 255 (283 = 255 + 28; in Xemu with the K325T path forced 296 = 255 +
41, 541 = 2 x 255 + 31, 800 = 3 x 255 + 35). Which side a read fell on
moved with a few cycles of interpreter timing, so any change to the
program or the interpreter could flip it. S11 (see below) takes the count
at a fixed raster position. S10 also dropped S9's run of one act-3 frame
in the warm-up: it moved a stall of about 15-19 frames (a cache flush and
recompile) from act 3's start to the end of act 2 (S9's 16-frame stall at
64 s), no gain.

**Late frames and the HUD's FPS (S11).** RING reads the VIC-IV frame
counter `$D7FA` when its wait for raster line 254 ends, below the picture,
and keeps it at OV%+131. From each act's 11th frame, every pass adds that
count minus the previous pass's count minus 1 (mod 256) to the act's late
frames: the frames in which RING did not run, i.e. the picture did not
move. The HUD (every 25 passes) shows FPS = 1250 / (frames since its last
update) from the same count. S11 in Xemu: act 1 / 2 / 3 4 / 0 / 14 late
frames with the K325T path forced, 4 / 0 / 2 stock, 3 / 0 / 18 with the
K325T routine on the stock core. S11 also does act 3's switch below the
picture: S10 turned list mode on mid-frame, and as the VIC-IV takes its
table snapshot only at a frame top with list mode on, the rows below the
switch were painted from a stale snapshot for one frame (black blocks and
stray glyphs at the act 2 -> 3 change). PROCact3 now waits for line 254,
writes CHRCOUNT and the list-mode registers and runs RING at once, so the
next frame is act 3's throughout.

50 fps throughout (late frames are counted from each act's 11th frame
through the VIC-IV's frame counter `$D7FA`); the act-3 HUD reached RINGS
1000. The take of the final layout (79a66ee, act 2 transparent, text in
front) had 0 one-frame glitches in 105 s, the listing legible over the
scene and both act-3 captions free of rings; 238201f then moved act 3's
set-up to the start so the scene does not stop between the acts. In Xemu
the shipped demo (S11) has the late frames given above.

**Programming note: the RRB row budget.** Every token of a row costs painting
time wherever its X is, also when it is parked off the screen (a
full-colour or NCM glyph 16 pixel cycles on a standard VIC-IV). A row of
186 tokens (GHZ act 2: two layers, 30 ring slots and two 40-character
text layers) needs 3200-3580 cycles: that fits DBLRR's two lines per
painting ($D051 bit 6, 5184 cycles) but not one line (2592); without DBLRR
every row is cut where the painter stands. Any write to `$D051` with bit 6
clear switches DBLRR off (the register also holds the raster-X compare
MSB). So: keep DBLRR set (GHZ writes `$D051=&40` every frame), set
CHRCOUNT (`$D05E`) to the tokens an act really uses (GHZ: 104 in act 1, 186
in act 2, 145 in act 3; LINESTEP stays, no data moves), and on a K325T the
fast RRB and token paths (XCTL bits 4 and 7) bring the same row to
1209-1686 cycles.

## B65

- Version string v0.3 (banner and `*INFO`).
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

## Fixed

- The v3 object integrator (B65's frame interrupt) held the VIC-IV's table
  snapshot across the frame top when an update took more than about 3.9
  ms: the interrupt came at raster line 251, set HOLD for the whole
  update, and a longer update was still holding at the next frame start,
  where the snapshot is taken only with HOLD 0. On the K325T the objects
  stood still (the program, TIME and the frame counter ran on); swarm2's
  1000 bullets (about 10 ms a frame) never moved on the board. v0.2 has
  the same fault, its 1000-object demo included. The frame interrupt now
  comes at raster line 16, just after the frame top (PAL raster 0, NTSC
  7) and after the snapshot, so an update has the rest of the frame
  (about 18.9 ms PAL, 15.8 ms NTSC). TIME, EVERY/AFTER, sound, keyboard
  and mouse keep their rates (one interrupt a frame); WAIT uses the frame
  counter `$D7FA` and is unchanged. An update longer than the frame (1000
  curving polar objects: 23.6 ms) still freezes the picture, as the next
  update starts at once (docs/USER.md, "The motion"); releasing HOLD
  between the 8 KB windows near the frame top is a follow-up after v0.3.
- OBJ65 (BASIC 65) has the same exposure: it steps from the KERNAL's
  raster interrupt, which comes at line 255 (measured in Xemu), so an
  update over about 3.5 ms freezes the picture on the K325T. Its
  examples move few objects and stay far below that; docs/OBJ65.md says
  so. A frame interrupt of its own after the frame top is a follow-up.

## Build and tests

- `tools/fixbranches.py` builds OBJ65 and OBJ65X too and creates
  `build/`; `make dist` puts OBJ65, OBJ65X and the new BASIC 65 programs
  on the D81.
- `tests/smoke.sh` ends with `tests/farcheck.sh`: the OBJFAR build (B65
  with OBJ65's far-pointer integrator) from a clean checkout, checked
  against the model.

## Reproducible build

From a clean checkout (`git worktree add <dir> <commit>`, then in it `make
dist`; ACME 0.97, Python 3), twice, with the same result: `dist/b65.d81`
md5 `68943096b59218d32349da8104a7e153`, `build/b65.prg` (= `dist/sd/B65.PRG`)
md5 `2bb7d9a0d8ad3b830ad92c76d1a41461`; `dist/sd/B65GHZG.BBC`
`c37d54079e465f606db0c14cd56b9314`, `dist/sd/B65GHZS.BBC`
`d0fa8d89f15b4d36bdcb9e845ee6543f`, `dist/sd/GHZ.BAS`
`9c05609629d0e6ef97cc1a9971a31db1`. Built from a481b05; commits that
change only `docs/` give the same files.

## Known

- GHZ still has short static runs at the act changes (on the board 9
  frames at act 1 -> 2, 12 and 9 frames in act 3's set-up): first compiles
  and a cache flush and recompile there (see the next entry).
- B65's expression cache (overlay 4, about 2.7 KB of compiled code) is
  flushed when it is full, and the next pass recompiles every hot
  expression at once: a short stall (in Xemu up to about 14 frames). In GHZ
  on the stock-core path one flush falls on the act 1 -> 2 change (about
  20 frames of gaps there in Xemu); the K325T path shows none. One cause is
  the inline assembler: its operand expressions go through the same cache
  (GHZ assembles about 1.5 KB at the start, hundreds of one-shot operands).
  Next: evaluate assembler operands without caching them, after v0.3.
