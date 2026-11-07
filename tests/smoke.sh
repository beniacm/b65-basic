#!/bin/sh
# B65 BASIC smoke test: build, run every tests/smoke/*.txt script in headless
# Xemu and compare the transcript with tests/smoke/*.expected.
# usage: tests/smoke.sh [--update]
cd "$(dirname "$0")/.." || exit 1
make -s || exit 1
fail=0
for t in tests/smoke/*.txt; do
    exp="${t%.txt}.expected"
    out=$(python3 tests/run.py "$t" 2>&1)
    if [ "$1" = "--update" ]; then
        printf '%s\n' "$out" > "$exp"; echo "updated $exp"; continue
    fi
    if printf '%s\n' "$out" | diff -u "$exp" - > /tmp/b65_smoke_diff.$$; then
        echo "PASS $t"
    else
        echo "FAIL $t"; cat /tmp/b65_smoke_diff.$$; fail=1
    fi
    rm -f /tmp/b65_smoke_diff.$$
done
exit $fail
