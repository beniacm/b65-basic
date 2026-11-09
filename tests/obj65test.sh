#!/bin/sh
# OBJ65 (the BASIC 65 object library) in Xemu with the MEGA65 ROM: the motion
# against tests/objmodel.py, HITPIX against tests/hitmodel.py, the frame
# interrupt and EVENT, and the jumper65 twin's landing script.
cd "$(dirname "$0")/.." || exit 1
make -s || exit 1
fail=0
for a in "1 24 60" "5 40 60" "16 60 40" "7 300 30"; do python3 tests/obj65check.py $a | tail -1 | grep -q OK || { echo "FAIL obj65check $a"; fail=1; }; done
for a in "1 12" "3 14" "5 14"; do python3 tests/hit65check.py $a | tail -1 | grep -q OK || { echo "FAIL hit65check $a"; fail=1; }; done
python3 tests/obj65check.py --irq | tail -1 | grep -q OK || { echo "FAIL irq"; fail=1; }
python3 tests/obj65check.py --jumper | tail -1 | grep -q OK || { echo "FAIL jumper65"; fail=1; }
[ $fail = 0 ] && echo "obj65test: all OK"
exit $fail
