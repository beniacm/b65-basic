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
  `INSTALL "lib"` loads a library of PROCs/FNs.
* **Not available:** `SYS`, `TINT`, `PUT`, star commands other than
  `*CAT` and `*DELETE`, and BBC OS calls (`CALL &FFEE` etc.); `CALL` and
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
`SUMLEN(A$())`, `DIM(A(),1)`.

**Hardware info:** `?&6E0` = model id (`$D629`), `?&6E1` = `&FF` on a
K325T, `?&6E2`/`?&6E3` = chip RAM in KB, `?&6E4` = attic RAM in MB.

**K325T RRB list mode** (only with the K325T core): the VIC-IV paints
"objects" from a table that is moved like sprites; see
`docs/rrb_list_mode.md` in the harness repository and the examples
`rrblist_b65.bas` (v1) and `rrblist_b65v2.bas` (v2).

## Examples

| file | what |
|---|---|
| `examples/parallax.bas` | three overlapping RRB layers of full-colour glyphs, own 256-colour palette, 16-colour sprites between the layers, DMA-list scrolling; birds on a K325T |
| `examples/basic65/parallax65.bas` | the same in BASIC 65 |
| `examples/rrblist_b65.bas` | RRB list mode v1: bouncing balls (K325T only) |
| `examples/rrblist_b65v2.bas` | RRB list mode v2: bouncing balls, V400 (K325T only) |

ESCAPE stops a demo; the parallax demo then returns to the text screen.
