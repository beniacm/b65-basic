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

- Step-7 core: XCTL2 bit 0 set by the demos when the feature level is 4
  or more (with XCTL bits 4 and 7); level checks stay `>= 3`.
