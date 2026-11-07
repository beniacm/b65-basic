# B65 BASIC for MEGA65
ACME ?= acme
SRC := $(wildcard src/*.a)
all: build/b65.prg build/boot.bin
build/b65.prg: $(SRC)
	@mkdir -p build
	python3 tools/fixbranches.py
build/boot.bin: tests/boot.a
	@mkdir -p build
	$(ACME) tests/boot.a
# regenerate the keyword/error tables from upstream (UPSTREAM=path to BBCZ80 checkout)
tables:
	python3 tools/gen_tables.py $(UPSTREAM)/src/MAIN.Z80 > src/tables.a
test: all
	tests/smoke.sh
clean:
	rm -rf build
.PHONY: all test clean tables
