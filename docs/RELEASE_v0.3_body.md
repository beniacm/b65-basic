B65 BASIC is a BBC BASIC (Z80 v5 derived) interpreter for the MEGA65, rewritten for the 45GS02.

**What's new since v0.2**

- **GHZ, a three-act demo written in B65 BASIC** (`GHZ.BAS`). It runs at 50 frames per second throughout.
  - Act 1 replays Maxice's SCROLLTEST, the Green Hill scroller from INTRO2.D81, frame for frame: seven parallax bands, the front layer, 64 rings and the waterfall.
  - Act 2 scrolls the program's own listing over the running scene.
  - Act 3 (K325T core) moves the rings into the list-mode object table: 1000 rings, plus clouds and bushes as objects, with a HUD showing the VIC-IV's own counters.

  The program reads the art at run time from your own copy of INTRO2.D81 (every MEGA65 SD card from the filehost has it). Without it, the demo uses an original generated tileset. None of the original art is in this repository or this release.

  video: (link follows)
- **OBJ65 for BASIC 65:** the v3 object table, the collision engine and B65's object motion for BASIC 65 programs.
  - The library is two PRGs, OBJ65 and OBJ65X.
  - Four POKE recipes come with it, plus jumper65, the BASIC 65 twin of jumper.
  - docs/OBJ65.md describes it all.
- **4-pixel painting** (K325T step-7 core, feature level 4): every list-mode demo sets XCTL2 bit 0 when the core has it.
- **B65:**
  - `BGET#c,addr,n` reads a block from a file into memory (34 KB in about 20 ms).
  - The compiled-expression cache has 16 ways instead of 4. Before, a loop could slow down for no visible reason when its lines moved in memory; benchmarks are unchanged.
  - INKEY at the end of a test script returns "no key" instead of ending the session.
- **Programming note, the RRB row budget:** every token of a row costs painting time, even when it is parked off the screen. On a standard VIC-IV a row of 186 tokens needs DBLRR ($D051 bit 6). Set CHRCOUNT ($D05E) to the tokens a screen really uses. docs/USER.md and docs/GHZ.md have the details.

**Files for the SD card** (all in the SD card's root directory; B65 reads data files only from there, not from a mounted D81):
- `GHZ.BAS`, `B65GHZG.BBC` (the generated tileset) and `B65GHZS.BBC` (act 2's font and listing, act 3's art).
- `INTRO2.D81`, which is already on your card: GHZ takes the original art from it.

Then `LOAD "GHZ"`, `RUN` in B65.

**Downloads:**
- `b65.d81`: the interpreter as B65, the examples as text files (GHZ.BAS among them), OBJ65 and the BASIC 65 programs. Mount it, then `DLOAD "B65"`, `RUN`.
- `b65.prg`: the interpreter alone, load address $2001.
- `B65GHZG.BBC` and `B65GHZS.BBC`: GHZ's data files, for the SD card root.

**Verified:**
- K325T rig with the step-7 core (feature level 4):
  - smoke 34 of 34, the v3 object board test 20 PASS / 0 FAIL, SELFTEST 14 PASS / 0 FAIL (batch 4 core);
  - demos at 50 fps: jumper 600 frames in 1198 cs, swarm2 1500 in 3056 cs, bounce 1500 in 3004 cs (850 pairs), parallax 600 in 1200 cs;
  - the SD card fsck-clean before and after the file tests;
  - 4-pixel painting: (4PX FIGURES);
  - GHZ (2026-11-10): 1500 / 1500 / 1401 frames in its three acts at 50 fps, no late pixels, no one-frame glitches in the video.
- Xemu: smoke, the check scripts, the GHZ, object and HITPIX models, and the card tests (fsck clean).

**A standard MEGA65 has not been tested yet.** B65 is written to run on one. Everything works there except drawing the list-mode objects, which still move logically. GHZ's acts 1 and 2 use only standard VIC-IV features; act 3 then shows a one-line note. If you have a standard MEGA65, please type `*INFO`, run SELFTEST (`LOAD "SELFTEST"`, `RUN`) and GHZ, and paste the outputs (GHZ prints frames and late frames per act at the end) into an issue at https://github.com/beniacm/b65-basic/issues. Reports of any kind are welcome.
