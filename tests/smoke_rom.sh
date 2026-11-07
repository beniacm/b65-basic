#!/bin/sh
# Optional tests that boot the real MEGA65 ROM from an onboarded SD card image
# (not in git: copyrighted ROM). CARD=/path/to/card.img (default
# ~/src/xemu-work/card.img). The tests write files to that card image.
cd "$(dirname "$0")/.." || exit 1
make -s || exit 1
for t in tests/rom/*.txt; do
    echo "=== $t"
    python3 tests/run.py --rom --timeout 60 "$t" | sed -n '5,$p'
done
