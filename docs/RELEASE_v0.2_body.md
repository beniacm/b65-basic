B65 BASIC is a BBC BASIC (Z80 v5 derived) interpreter for the MEGA65, rewritten for the 45GS02.

**What's new since v0.1-dev.1**

- **Speed:** 5-6 times faster than BASIC 65 on the board. Per statement:

  | statement | BASIC 65 | B65 v0.2 |
  |---|---|---|
  | POKE | 135 µs | 24 µs |
  | integer add and IF | 142 µs | about 24 µs |
  | 4-byte `!` write | 162 µs | 40 µs |
  | MOD/AND expression | 328 µs | 62 µs |

  How:
  - a compiler for numeric expressions, assignments and single-line IFs, with a cache of the compiled code;
  - integer constants encoded when the line is entered, integer FOR...NEXT, and the 45GS02 math unit for `*`, DIV and MOD;
  - cached GOTO/GOSUB targets and PROC/FN definitions.
- **Moving objects** (list mode v3, K325T step-6 core): B65 keeps the table for up to 1024 objects and moves them in its frame interrupt; BASIC only starts and steers them. The statements:
  - OBJECT, OBJVEL, OBJMOVE (straight, turning, exact polar), OBJORBIT, OBJSPRING;
  - OBJLIFE, OBJLIMITS / OBJBOUNDS (wrap, bounce, kill), OBJKILL, OBJUPDATE;
  - ON OBJEVENT, OBJX/OBJY/OBJVX/OBJVY/OBJEVENT( );
  - HITPIX(a,b[,dx,dy]), a pixel-exact overlap test.
- **The K325T collision engine:** ON COLLISION PROCname and COLLIDE(n) for objects 0..1023.
- **Diagnostics:** `*INFO` (version, machine, ROM, RAM, K325T feature level) and SELFTEST (one PASS/FAIL line per subsystem).
- **Other changes:**
  - whole-array AND, plus a tight integer loop for whole-array + and -;
  - WAIT on the VIC-IV frame counter;
  - *DELETE keeps both FAT copies and the free count right;
  - the packed PRG starts in 0.78 s.
- **New examples:** bounce (64 balls), swarm (255 objects), swarm2 (1000 bullets), jumper (pixel-accurate platforms) and selftest. The first line of every example says which core it needs.

On the K325T rig with the step-6 core, jumper, bounce and parallax run at 50 frames per second, and swarm2 at 49 with 1000 bullets.

**Flag day:** the step-6 core (mega65-core 0209a1c57) uses 32-byte object table entries. The object examples in this release need it, so do not run them on older K325T bitstreams (feature levels 1-2). Programs that build a 16-byte table by hand move entry n from base+16*n to base+32*n. Tokenised programs SAVEd by v0.2 do not run in v0.1-dev.1; keep text copies.

**Downloads:**
- `b65.d81`: the interpreter as B65 plus the examples as text files. Mount it, then `DLOAD "B65"`, `RUN`; in B65, `LOAD "JUMPER"`, `RUN`.
- `b65.prg`: the interpreter alone, load address $2001.

**Verified:**
- K325T rig with the step-6 core: smoke 33/33, the v3 object board test 20/20, SELFTEST 14/14, and the demo timings above.
- Xemu: smoke, check scripts, the object and HITPIX models, and the card tests (fsck clean).

**A standard MEGA65 has not been tested yet.** B65 is written to run on one: everything works there except drawing the list-mode objects, which still move logically. Nobody has tried it on a stock machine yet. If you have one, please type `*INFO`, run SELFTEST (`LOAD "SELFTEST"`, `RUN`) and paste both into an issue at https://github.com/beniacm/b65-basic/issues. Reports of any kind are welcome.
