# GHZ: Maxice's SCROLLTEST in B65 (examples/ghz.bas)

The v0.3 showpiece, in three acts: "YOU HAVE SEEN THIS ON MEGA65" (SCROLLTEST
from INTRO2.D81, the Green Hill scroller by Maxice, frame for frame), "...BUT IN
BASIC?" (its source scrolls over the running picture) and "...AND WITH THE
VIC-IV EXTENSIONS" (the K325T's list-mode objects). Acts 1 (S1) and 2 (S2) are done.

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

Per frame BASIC moves the seven band counters and the front layer and starts
one chained DMA list of 86 jobs: 52 row copies (21 tokens from token maps in
chip RAM made at start, the source moved when a column advances), 8 fills of
the GOTOX fine X bytes (destination step 208), 26 fills that park the ring
slots (step 4). Then an inline-assembler routine (`RING`, 64 rings: the
motion and the slot placement, 192 slot writes) runs with `CALL`, and BASIC
cycles the waterfall. Glyph $n of SCROLLTEST is char $n + $1400 here (the
glyphs at $55800: bank 5, free under B65); screen $50000, colour RAM
$FF80800, token maps $52000, DMA list $5C000.

Budget (Xemu, tests/ghzcheck.py, without the frame wait): 5.2 ms a frame
before the rings start, about 6 ms with the 64 rings: 50 frames per second
with two thirds of the frame free.

## Act 2: the source over the picture

After act 1 (A1% = 3000 frames, 60 s) the program's own source scrolls up
over the running scene, white on transparent: `B65GHZS.BBC` (made by
`tools/mkghz.py --text` from examples/ghz.bas, in dist/sd) holds the 8x8
font as 96 full-colour glyphs (colour 250) and the listing as 40-column
token lines ("...BUT IN BASIC?" first). Each screen row gets two more token
sets after SCROLLTEST's 104 tokens: a GOTOX and 40 characters of line L
moved up by S pixels, a GOTOX and 40 characters of line L+1 moved down by
8 - S (the GOTOX Y offset: bits 15-13 up, bit 12 down), so the text moves
one pixel a frame; the rows grow to 186 tokens (line step 372). The text
tokens come from attic RAM ($8580000) with the same DMA list (52 more
row copies, their source moved every 8 frames); the inline-assembler
routine writes the GOTOX bytes of all rows (fine X and the text sets' Y
offsets) each frame, since a DMA fill cannot step 372 bytes. Xemu does not
draw GOTOX Y offsets, so `SM%=0` scrolls in 8-pixel steps (the tests);
the smooth scroll needs the board.

## Tests

- `tests/ghzcheck.py [frames] [--local]`: B65 runs N frames in Xemu (MEGA65
  ROM boot, a private card copy); the screen in the memory dump must equal the
  model's (all tokens' low bytes, GOTOX fine X, ring slots), and the art line
  must say which art was used. `--local`: INTRO2.D81 on the card copy, the art
  read from it (300 and 965 frames OK); default: the generated pack, with a
  D81 whose SCROLLTEST has one checked byte changed, so the program must fall
  back (600 frames OK). `--shot file.png` keeps the picture for a screenshot;
  `--act2 N` starts act 2 at frame N (with the overlay file, in 8-pixel
  steps).
- Board: `tests/board.py run tests/board_ghz.txt`: 1500 frames of act 1 in
  real time, then "frames 1500 ... in N cs" (3000 at 50 fps);
  `tests/board_ghz2.txt`: act 2 from frame 200 to the end of the source
  (2700 frames, 5400 cs at 50 fps; the smooth scroll).
