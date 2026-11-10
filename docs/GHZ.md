# GHZ: Maxice's SCROLLTEST in B65 (examples/ghz.bas)

The v0.3 showpiece, in three acts: "YOU HAVE SEEN THIS ON MEGA65" (SCROLLTEST
from INTRO2.D81, the Green Hill scroller by Maxice, frame for frame), "BUT
HAVE YOU SEEN IT IN BASIC?" (its source scrolls over the running picture) and
"NOW WITH THE K325T VIC-IV" (1000 rings, clouds and bushes as list-mode
objects), then a closing card ("B65 BASIC FOR MEGA65 AND K325T",
github.com/beniacm/b65-basic) and the late frames per act. Each act about
30 s, about 90 s in all.

## The art (none of it in the repository or the shipped files)

`ghz.bas` takes the art from your own copy of SCROLLTEST at run time:
`INTRO2.D81` in the SD card root (every MEGA65 card from the filehost has
it; the name is `DN$` in line 115 if yours differs). It opens the D81 as a
plain file (OPENIN reads it into attic RAM, about 0.5 s), finds SCROLLTEST
in the directory (track 40 sector 3 on), follows its sector chain with
`PTR#` and block `BGET#` (254 bytes a sector) into bank 5 as if loaded at
$2001 ($52001: glyph n then sits at its tile address, GA% = $55800), checks
the length (34241) and the sum of every 16th byte, and copies the tables to
TA% with four DMA jobs: palette $2FF4 (R/G/B, 768), waterfall $2D00 (24),
sines $2DEB (512), band tables and front map $3300 (2492). The intro
prints "ORIGINAL ART FROM INTRO2.D81" (about 0.8 s in Xemu).

On any failure (no D81, no SCROLLTEST, another build) it loads
`B65GHZG.BBC`, an original generated tileset with the same layout ("GENERATED
ART"; `make dist` puts it in `dist/sd`): palette R/G/B (768, VIC-IV nibble
order), waterfall R/G/B 8 each (entries 25-28), sine1, sine2 (256 each), band
1 (5 x 50), band 2 (3 x 49), bands 3-7 (5 x 42), front map (13 x 145), glyphs
$160-$296 (NCM, 64 bytes each).

## What SCROLLTEST does each frame (decoded from its 45GS02 code)

The screen: 26 rows of 104 16-bit tokens (V400, line step 208, CHR16 +
FCLRHI): GOTOX (opaque, colour $10) + 21 band tiles ($02xx, NCM colour $08,
palette bank 0 for rows 0-9, bank 1 below) + GOTOX ($90 transparent) + 21
front tiles ($01xx, bank 2) + 30 ring slots (GOTOX $90 with a Y offset in
bits 13-15 + a ring glyph, bank 3). A tile is two glyph rows: top b, bottom
b+1.

- Bands ($238E): seven, each with a counter, a step and a coarse column;
  when the counter underflows it is reloaded (bands 1, 2: 31, 15) or 31/16
  is added (bands 3-7), the column advances (wrap 29, 28, 21) and the band's
  21 tiles per row are copied from its table. The GOTOX fine X is the
  counter (bands 2, 4, 6, 7) or half of it (1, 3, 5): rows 0-9 0.5 px a
  frame, 10-15 1, 16-17 1.5, 18-19 2, 20-21 2.5, 22-23 3, 24-25 4.
- The front layer ($2140): fine X -= speed (start 4); on underflow +16 and
  the next of 124 map columns; after column 123 the speed rises by 1 (up to
  15). The 21 visible map columns are copied to all 13 row pairs each frame.
- The waterfall ($2106): every 8 frames palette entries 25-28 take the next
  of 4 phases of the R/G/B tables.
- Rings ($2B1F, $2A41, $2B69): all 780 slots parked (GOTOX X bit 9 set by a
  DMA fill, step 4); 64 rings: X = sine1[p + 16 j] + sine1[c + 32 g + 16
  j] (9 bits), Y = sine2[...] + sine2[...] (8 bits), p advancing 1 a frame,
  glyph frame base +3 every 10 frames ($84..$93, 6 frames, 3 glyphs each);
  once the speed has left 4, each ring takes the next free slot in 3
  consecutive rows from row Y/8 - 2 (Y offset (Y AND 7) EOR 7), at most 29
  slots a row.

`tests/ghzmodel.py` is this state machine in Python. Run on SCROLLTEST's
own data it reaches, after 965 frames, exactly the state and the screen of
a memory dump of the real demo running in Xemu (every counter, phase, band
and front token; 779 of 780 ring slots, the dump being taken while the last
ring was being placed).

## How B65 does it

Per frame BASIC moves the seven band counters and the front layer (counter,
fine X, coarse column: one byte each for the routine) and cycles the
waterfall. Then one inline-assembler routine (`RING`, run with `CALL`) sets
the sources of the DMA list's row copies (52 from token maps in chip RAM
made at start: a row's base + 2 x its band's column; 52 text rows for act
2), starts the chained list (130 jobs: those copies and 26 fills that park
the ring slots, step 4), writes every row's GOTOX bytes (fine X, the text
sets' Y offsets: a DMA fill cannot step 372 bytes) and does the 64 rings
(the motion and the slot placement, 192 slot writes). Glyph $n of SCROLLTEST is char $n + $1400 here (the
glyphs at $55800: bank 5, free under B65); screen $50000, colour RAM
$FF80800, token maps $52000, DMA list $5C000.

Budget (Xemu, tests/ghzcheck.py, without the frame wait): 3.2 ms a frame on
average with the 64 rings. With the frame wait every frame makes it in 20 ms
except two at the start (the first calls of the procedures): 1000 frames in
2010 cs. (When BASIC still set the 52 job sources itself, 8% of the frames
missed: the front layer's 26 sources every 4 frames, plus band reloads.)

## Act 2: the listing

After act 1 (A1% = 1500 frames, 30 s) the program's own listing scrolls up
pixel by pixel straight over the running, scrolling scene, white with a
black shadow on a transparent background, under the fixed top line "BUT
HAVE YOU SEEN IT IN BASIC?" (rows 0-1 never move). The listing is parts of
this program as B65's LIST shows them: ">LIST 200-290" (the frame loop),
">LIST 800-895" (the DMA list), ">LIST 971-1010" (RING), ">LIST 1212-1238"
(act 3's ring routine), wrapped at 40 columns, in rows 2..25, scrolling SV%
pixels a frame (line 115: 1). It ends with the prompt and a cursor, stays
2 s, then "B65 BASIC. n LINES." / "50 FRAMES PER SECOND." stand over the
scene for 3 s. 30 s in all.

`B65GHZS.BBC` (made by `tools/mkghz.py --text` from examples/ghz.bas, in
dist/sd) holds the 8x8 font as 96 full-colour glyphs (text colour 250,
white; a shadow 251, black, right of and below each pixel: the shadow is
part of each glyph, so it costs no painting time) and the text as
40-column token lines. Each screen row has two text sets after
SCROLLTEST's 104 tokens: a GOTOX and 40 characters of line L moved up by
S pixels, a GOTOX and 40 characters of line L+1 moved down by 8 - S (GOTOX
Y offset: bits 15-13 up, bit 12 down), both transparent, each with a row
mask (colour byte 0 bit 3, the mask in byte 1): set 1 draws pixel rows
0..7-S, set 2 rows 8-S..7 (without the masks the VIC-IV paints the
neighbouring glyphs' rows there: the board showed it as flicker every 4
frames). The rows are 186 tokens (line step 372); the text sets start at X
16, the first visible pixel. The text comes from attic RAM ($8580000)
through the frame's DMA list (52 row copies); the routine RING writes each
row's GOTOX bytes and masks every frame (a DMA fill cannot step 372
bytes), ANDed with a per-row table (PF%), and keeps the first V%+31 rows
fixed (no offset, the caption line's text: the routine FIX points their
text jobs at it). Xemu does not draw GOTOX Y offsets or row masks, so
`SM%=0` scrolls in 8-pixel steps for the tests.

**Text is always in front.** In acts 1 and 2 the text sets are the last
tokens of every row (band 0-21, front 22-43, ring slots 44-103, text
104-185), so they paint over everything. In act 3 the list-mode objects
are appended after a row's tokens and would paint over the text, so the
rings are kept out of a caption's row while it shows: A3% hides a ring
whose y lies in a band (OV%+129..130, set by BASIC: row 11 for "NOW WITH
THE K325T VIC-IV", row 12 for "1000 RINGS. 10 LAYERS. STILL BASIC."), as
row 0 is kept free for the HUD; the clouds (rows 1-4) and bushes (rows
22-25) never reach those rows. A ring in a caption's row is hidden, not
removed: the count stays 1000.

## Frame timing

With the frame wait on (BN%=0) RING waits for the picture and then for
raster line RW% (254, below it), so the DMA list, the ring slot fills and
the ring placement all happen in the vertical blank: no rows show cleared
slots (the board showed flicker in the top rows while the update ran right
after the frame start). The front layer's speed ramps in act 1 only (it
stays at about 7 for acts 2 and 3). Act 3's object routine A3% runs
mid-frame, before the next RING (the VIC-IV copies the object table at the
top of a frame).

## Painting budget

The rows are painted on the slow RRB path in acts 1 and 2 on a stock core:
every token costs time wherever its X is (NCM and FCM glyphs 16 pixel
cycles each), so a full 186-token row costs 3200-3580 cycles (GHDL, from
board dumps). That fits the 5184 cycles of DBLRR ($D051 bit 6: two lines
per painting) but not the 2592 of one line: when DBLRR was lost on the
board (any write to $D051 with bit 6 clear switches it off; $D051 also
holds the raster-X compare MSB) every row was cut where the painter stood,
a staircase. So:

- CHRCOUNT ($D05E) follows the act: 104 tokens in act 1 (SCROLLTEST's row:
  the text sets are not fetched at all), 186 in act 2 (both text sets),
  145 for the closing caption and act 3 (set 1 only). LINESTEP stays 372.
- RING writes $D051 = $40 (DBLRR) every frame in the vertical blank.
- On a K325T the fast RRB and fast token paths (XCTL bits 4 and 7) are on
  from act 1 (pixel-identical; 1209-1686 cycles for a full row), act 3 adds
  bit 6 (objects) and, at level 4, 4-pixel painting; PROCback clears them.

## Act 3: the K325T VIC-IV

"NOW WITH THE K325T VIC-IV": on a K325T core of feature level 3 or more
(recorded at level 4)
(`?&FFD71FD`), act 3 moves the rings into the list-mode object table
(B65's table address `&E0000`, 1020 objects, 32-byte v3 entries written by
the program itself, XCTL bits 4, 6, 7; level 4: 4-pixel painting, XCTL2
bit 0):

- objects 8..1007: rings, an 8x8 full-colour ring turning in four frames
  (original art in B65GHZS.BBC, palette 192..195), on SCROLLTEST's paths
  (ring i: group i DIV 16 with the phase offsets of act 1, plus 37 and 53 per
  eight groups so groups 8 apart differ; rings 0..63 are exactly act 1's).
  Their count ramps 64 -> 300 (frames 150..268) -> 1000 (700..1050), held
  with the caption until frame 1400 (28 s) (the draw mask: rings beyond the count
  and off the screen have mask 0, so they take no bucket entries). An 8x8
  ring touches at most 2 rows: 1000 rings need at most 2000 of the 2048
  bucket entries (SCROLLTEST's 16x24 rings would need 4);
- objects 0..7: clouds (64x16) drifting at 1/4 pixel a frame in the sky
  rows, behind the rings; objects 1008..1019: bushes (48x16) in front,
  1.5 times the front layer's speed. So 10 layers: 7 bands, the front, the
  clouds, the bushes. "1000 RINGS. 10 LAYERS. STILL BASIC." at 1000;
- the routine `A3%` (inline assembler, after RING each frame) writes every
  ring's X, Y, mask and token list (one of four, for the turn) and moves the
  clouds and bushes (X in 1/256 pixel, wrapping at -64 to 383); BASIC only
  ramps the count, turns the animation and updates the HUD;
- the HUD (row 0, kept free of objects: rings only from pixel row 8, clouds
  from row 10; through act 2's text sets, from a page in attic RAM):
  RINGS, FPS (from `$D7FA`), OBJECTS and LINE (the VIC-IV's counter 25,
  the longest painting of the last half second, in pixel cycles; read
  through `$FFD71E0-E3`).

Any other core (and Xemu): the caption and "THIS CORE: 64 RINGS, PLAIN RRB",
act 1's 64 rings in their RRB slots, the HUD with RINGS and FPS, 400 frames.
`XT%=1` runs the K325T path's routine on a scratch table in bank 1 (from
TOP, rounded up to a page; the run prints its address) for the tests.

Act 3's set-up (palette entries 192-223 and 250/251, the HUD page in attic
RAM and its captions, the object token lists, the template, the 1000 ring
entries, the clouds and bushes) runs at the start, while the intro is
shown (PROCprep, line 160): none of it is visible before act 3, and
PROCact3 only switches the text page, CHRCOUNT, the caption band and the
object registers, so the scene never stops between the acts.

Budget (Xemu, the routine on the scratch table): 1000 rings about 8 ms a
frame; in real time act 3 misses only its caption frames (3 in 1000). The
whole demo as shipped (Xemu): act 1 3000 frames 4 late (start-up), act 2
0 late, act 3 0 late. Finding on the way: B65's expression cache (4 ways)
thrashed in some program layouts (up to 226 late frames in 400); it has 16
ways now (see RELEASE_v0.3.md).

## Board results

Recorded on 2026-11-10 on the QMTECH K325T board (core batch 3,
0b3eadd7b, feature level 4), art from INTRO2.D81, commit ad52e78: acts of
30 s, 30 s and 28 s plus the closing card, 50 fps throughout.

| act | frames | late frames | longest painting | late pixels |
|---|---|---|---|---|
| 1 | 1500 | 3 | 1076 | 0 |
| 2 | 1492 | 17 | 1602 | 0 |
| 3 | 1401 | 15 | 1689 | 0 |

Registers in act 1: `$D051` $40 (+ the X position bits), `$D031` $48,
`$D05E` $68 (104), XCTL $91, XCTL2 $00. The HUD reached RINGS 1000. Video
frame analysis: no one-frame glitch apart from the act-2 panel of that build
leaving, no repeated frame in act 2. video: (link follows)

The S7 build (79a66ee: act 2 transparent over the scene, text always in
front) was recorded the same day: act 1 registers `$D051` $41, `$D031` $48,
`$D05E` $68, `$D054` $45, XCTL $91 (three reads); 0 one-frame brightness
glitches in the whole 105 s take; act 2's listing white with the black
shadow over the live scene, legible, the caption fixed; act 3's HUD and both
captions free of rings; "1000 RINGS. 10 LAYERS. STILL BASIC." reached. It
still held the picture briefly at the two act changes (the set-ups); 238201f
moved those set-ups out of the frame loop.

Acts 1 and 2 use only standard VIC-IV features and should look the same on
a standard MEGA65 (not tested: reports to
https://github.com/beniacm/b65-basic/issues); act 3 needs the K325T list
mode.

## Tests

- `tests/ghzcheck.py [frames] [--local]`: B65 runs N frames in Xemu (MEGA65
  ROM boot, a private card copy); the screen in the memory dump must equal the
  model's (all tokens' low bytes, GOTOX fine X, ring slots), and the art line
  must say which art was used. `--local`: INTRO2.D81 on the card copy, the art
  read from it (300 and 965 frames OK); default: the generated pack, with a
  D81 whose SCROLLTEST has one checked byte changed, so the program must fall
  back (600 frames OK). `--shot file.png` keeps the picture for a screenshot;
  `--act2 N` starts act 2 at frame N (with the overlay file, in 8-pixel
  steps); `--act3 N`: act 1 until frame N, no act 2, act 3 on the scratch
  table, whose ring, cloud and bush entries must equal the model's (1000
  frames: 1000 rings OK).
- Board: `tests/board.py run tests/board_ghz.txt`: 1500 frames of act 1 in
  real time, then "frames 1500 ... in N cs" (3000 at 50 fps);
  `tests/board_ghz2.txt`: act 2 from frame 200 to the end of the source
  (3000 frames, 6000 cs at 50 fps; the smooth scroll);
  `tests/board_ghz3.txt`: act 3 after 200 frames of act 1 (the objects, 4 px
  painting, the HUD; "act 3: 1001 frames, n late"); `tests/board_ghzall.txt`:
  the demo as shipped (the recording). Each run ends with "act n: frames, late"
  per act (late frames counted from each act's 11th frame, through `$D7FA`);
  on a K325T also the VIC-IV's longest painting (counter 25, pixel cycles;
  5184 is two lines, the DBLRR cut-off) and its late pixels (counter 23),
  each act measured from its 11th frame (act 3: the HUD's readings).
