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

## B65

- Version string v0.3-dev (`*INFO` tells it from the release).

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
