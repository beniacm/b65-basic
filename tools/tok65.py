#!/usr/bin/env python3
"""Tokenise a BASIC 65 program written as text (lower case, as typed on a
MEGA65) into a PRG for BASIC 65 (load address $2001).

    tools/tok65.py prog.bas prog.prg

Keywords are crunched like the BASIC 65 editor does: outside strings, REM
text and DATA the first keyword in table order that matches wins (as in
the ROM), so variable names must not contain keywords (e.g. "score"
contains OR).
Only for testing B65's examples/basic65 programs in Xemu.
"""
import sys

# BASIC 65 keyword tables (public keyword list; token values as in the ROM)
MAIN = ("END FOR NEXT DATA INPUT# INPUT DIM READ LET GOTO RUN IF RESTORE GOSUB RETURN REM "
        "STOP ON WAIT LOAD SAVE VERIFY DEF POKE PRINT# PRINT CONT LIST CLR CMD SYS OPEN CLOSE "
        "GET NEW TAB( TO FN SPC( THEN NOT STEP + - * / ^ AND OR > = < SGN INT ABS USR FRE POS "
        "SQR RND LOG EXP COS SIN TAN ATN PEEK LEN STR$ VAL ASC CHR$ LEFT$ RIGHT$ MID$ GO "
        "RGRAPHIC RCOLOR - JOY RPEN DEC HEX$ ERR$ INSTR ELSE RESUME TRAP TRON TROFF SOUND VOL "
        "AUTO IMPORT GRAPHIC PAINT CHAR BOX CIRCLE PASTE CUT LINE MERGE COLOR SCNCLR XOR HELP "
        "DO LOOP EXIT DIR DSAVE DLOAD HEADER SCRATCH COLLECT COPY RENAME BACKUP DELETE "
        "RENUMBER KEY MONITOR USING UNTIL WHILE").split()
ESC_FE = ("BANK FILTER PLAY TEMPO MOVSPR SPRITE SPRCOLOR RREG ENVELOPE SLEEP CATALOG DOPEN "
          "APPEND DCLOSE BSAVE BLOAD RECORD CONCAT DVERIFY DCLEAR SPRSAV COLLISION BEGIN BEND "
          "WINDOW BOOT FREAD# WPOKE FWRITE# DMA - EDMA - MEM OFF FAST SPEED TYPE BVERIFY - "
          "ERASE FIND CHANGE SET SCREEN POLYGON ELLIPSE VIEWPORT GCOPY PEN PALETTE DMODE DPAT "
          "FORMAT TURBO FOREGROUND - BACKGROUND BORDER HIGHLIGHT MOUSE RMOUSE DISK CURSOR "
          "RCURSOR LOADIFF SAVEIFF EDIT FONT FGOTO FGOSUB MOUNT FREEZER CHDIR DOT INFO BIT "
          "UNLOCK LOCK MKDIR << >> VSYNC").split()
ESC_CE = ("POT BUMP LPEN RSPPOS RSPRITE RSPCOLOR LOG10 RWINDOW POINTER MOD PIXEL RPALETTE "
          "RSPEED RPLAY WPEEK DECBIN STRBIN$").split()

TABLE = []
for i, w in enumerate(MAIN):
    if w == '-' and i != 0x2b:            # placeholder ($CE is the escape byte); $AB is "-"
        continue
    TABLE.append((w, bytes([0x80 + i])))
for i, w in enumerate(ESC_FE):
    if w != '-':
        TABLE.append((w, bytes([0xfe, 0x02 + i])))
for i, w in enumerate(ESC_CE):
    TABLE.append((w, bytes([0xce, 0x02 + i])))


def petscii(c, in_string):
    o = ord(c)
    if 'a' <= c <= 'z':
        return o - 32                      # unshifted letter
    if 'A' <= c <= 'Z':
        return o + 0x80 if in_string else o
    return o


def tokenise_line(text):
    out = bytearray()
    up = ''.join(chr(petscii(c, False)) if 'a' <= c <= 'z' else c for c in text)
    i, quote, rest, data = 0, False, False, False
    while i < len(text):
        c = text[i]
        if rest:
            out.append(petscii(c, True))
            i += 1
            continue
        if c == '"':
            quote = not quote
            out.append(0x22)
            i += 1
            continue
        if quote:
            out.append(petscii(c, True))
            i += 1
            continue
        if data:
            if c == ':':
                data = False
            out.append(petscii(c, True))
            i += 1
            continue
        if c == '?':
            out.append(0x99)
            i += 1
            continue
        for w, t in TABLE:
            if up.startswith(w, i):
                out += t
                i += len(w)
                if w == 'REM':
                    rest = True
                if w == 'DATA':
                    data = True
                break
        else:
            out.append(petscii(c, False))
            i += 1
    return bytes(out)


def tokenise(src, load=0x2001):
    lines = []
    for raw in src.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        n = 0
        while n < len(raw) and raw[n].isdigit():
            n += 1
        lines.append((int(raw[:n]), tokenise_line(raw[n:].lstrip())))
    prg = bytearray([load & 255, load >> 8])
    addr = load
    for num, body in sorted(lines):
        rec = bytes([num & 255, num >> 8]) + body + b'\0'
        addr += 2 + len(rec)
        prg += bytes([addr & 255, addr >> 8]) + rec
    prg += b'\0\0'
    return bytes(prg)


if __name__ == '__main__':
    src = open(sys.argv[1]).read()
    open(sys.argv[2], 'wb').write(tokenise(src))
