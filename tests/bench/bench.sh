#!/bin/sh
# B65 speed benchmark in real-time Xemu: per-iteration cost in microseconds
# (10000 iterations, TIME in centiseconds = microseconds per iteration).
# Statement cost = line value - "empty".
cd "$(dirname "$0")/../.." || exit 1
make -s >/dev/null || exit 1
python3 tests/run.py tests/bench/bench10k.txt --timeout 400 | sed -n '/^>RUN/,$p' | grep -v '^>'
