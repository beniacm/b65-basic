#!/usr/bin/env python3
"""Generate the 45GS02 opcode tables for the B65 BASIC inline assembler.

Table format (ACME source):
  asm_mnem: for each mnemonic: 4 chars (space padded), then one byte per
            addressing mode index pointing into ... (compact form below)
We emit a list of entries: mnemonic(4 bytes), mode(1), opcode(1), flags(1)
flags: bit0 = 45GS02 Q-prefix ($42 $42), bit1 = NEG-less (reserved)
sorted by mnemonic; terminated by $ff.
"""
# addressing mode numbers (must match src/asm.a)
IMP, ACC, IMM, ZP, ZPX, ZPY, ABS, ABSX, ABSY, IND, INDX, IZX, IZY, IZZ, ISY, REL, REL16, ZPREL, IMM16, FLAT = range(20)

rows = """
00 BRK IMP|01 ORA IZX|02 CLE IMP|03 SEE IMP|04 TSB ZP|05 ORA ZP|06 ASL ZP|07 RMB0 ZP|08 PHP IMP|09 ORA IMM|0A ASL ACC|0B TSY IMP|0C TSB ABS|0D ORA ABS|0E ASL ABS|0F BBR0 ZPREL
10 BPL REL|11 ORA IZY|12 ORA IZZ|13 BPL REL16|14 TRB ZP|15 ORA ZPX|16 ASL ZPX|17 RMB1 ZP|18 CLC IMP|19 ORA ABSY|1A INC ACC|1B INZ IMP|1C TRB ABS|1D ORA ABSX|1E ASL ABSX|1F BBR1 ZPREL
20 JSR ABS|21 AND IZX|22 JSR IND|23 JSR INDX|24 BIT ZP|25 AND ZP|26 ROL ZP|27 RMB2 ZP|28 PLP IMP|29 AND IMM|2A ROL ACC|2B TYS IMP|2C BIT ABS|2D AND ABS|2E ROL ABS|2F BBR2 ZPREL
30 BMI REL|31 AND IZY|32 AND IZZ|33 BMI REL16|34 BIT ZPX|35 AND ZPX|36 ROL ZPX|37 RMB3 ZP|38 SEC IMP|39 AND ABSY|3A DEC ACC|3B DEZ IMP|3C BIT ABSX|3D AND ABSX|3E ROL ABSX|3F BBR3 ZPREL
40 RTI IMP|41 EOR IZX|42 NEG IMP|43 ASR ACC|44 ASR ZP|45 EOR ZP|46 LSR ZP|47 RMB4 ZP|48 PHA IMP|49 EOR IMM|4A LSR ACC|4B TAZ IMP|4C JMP ABS|4D EOR ABS|4E LSR ABS|4F BBR4 ZPREL
50 BVC REL|51 EOR IZY|52 EOR IZZ|53 BVC REL16|54 ASR ZPX|55 EOR ZPX|56 LSR ZPX|57 RMB5 ZP|58 CLI IMP|59 EOR ABSY|5A PHY IMP|5B TAB IMP|5C MAP IMP|5D EOR ABSX|5E LSR ABSX|5F BBR5 ZPREL
60 RTS IMP|61 ADC IZX|62 RTN IMM|63 BSR REL16|64 STZ ZP|65 ADC ZP|66 ROR ZP|67 RMB6 ZP|68 PLA IMP|69 ADC IMM|6A ROR ACC|6B TZA IMP|6C JMP IND|6D ADC ABS|6E ROR ABS|6F BBR6 ZPREL
70 BVS REL|71 ADC IZY|72 ADC IZZ|73 BVS REL16|74 STZ ZPX|75 ADC ZPX|76 ROR ZPX|77 RMB7 ZP|78 SEI IMP|79 ADC ABSY|7A PLY IMP|7B TBA IMP|7C JMP INDX|7D ADC ABSX|7E ROR ABSX|7F BBR7 ZPREL
80 BRA REL|81 STA IZX|82 STA ISY|83 BRA REL16|84 STY ZP|85 STA ZP|86 STX ZP|87 SMB0 ZP|88 DEY IMP|89 BIT IMM|8A TXA IMP|8B STY ABSX|8C STY ABS|8D STA ABS|8E STX ABS|8F BBS0 ZPREL
90 BCC REL|91 STA IZY|92 STA IZZ|93 BCC REL16|94 STY ZPX|95 STA ZPX|96 STX ZPY|97 SMB1 ZP|98 TYA IMP|99 STA ABSY|9A TXS IMP|9B STX ABSY|9C STZ ABS|9D STA ABSX|9E STZ ABSX|9F BBS1 ZPREL
A0 LDY IMM|A1 LDA IZX|A2 LDX IMM|A3 LDZ IMM|A4 LDY ZP|A5 LDA ZP|A6 LDX ZP|A7 SMB2 ZP|A8 TAY IMP|A9 LDA IMM|AA TAX IMP|AB LDZ ABS|AC LDY ABS|AD LDA ABS|AE LDX ABS|AF BBS2 ZPREL
B0 BCS REL|B1 LDA IZY|B2 LDA IZZ|B3 BCS REL16|B4 LDY ZPX|B5 LDA ZPX|B6 LDX ZPY|B7 SMB3 ZP|B8 CLV IMP|B9 LDA ABSY|BA TSX IMP|BB LDZ ABSX|BC LDY ABSX|BD LDA ABSX|BE LDX ABSY|BF BBS3 ZPREL
C0 CPY IMM|C1 CMP IZX|C2 CPZ IMM|C3 DEW ZP|C4 CPY ZP|C5 CMP ZP|C6 DEC ZP|C7 SMB4 ZP|C8 INY IMP|C9 CMP IMM|CA DEX IMP|CB ASW ABS|CC CPY ABS|CD CMP ABS|CE DEC ABS|CF BBS4 ZPREL
D0 BNE REL|D1 CMP IZY|D2 CMP IZZ|D3 BNE REL16|D4 CPZ ZP|D5 CMP ZPX|D6 DEC ZPX|D7 SMB5 ZP|D8 CLD IMP|D9 CMP ABSY|DA PHX IMP|DB PHZ IMP|DC CPZ ABS|DD CMP ABSX|DE DEC ABSX|DF BBS5 ZPREL
E0 CPX IMM|E1 SBC IZX|E2 LDA ISY|E3 INW ZP|E4 CPX ZP|E5 SBC ZP|E6 INC ZP|E7 SMB6 ZP|E8 INX IMP|E9 SBC IMM|EA EOM IMP|EB ROW ABS|EC CPX ABS|ED SBC ABS|EE INC ABS|EF BBS6 ZPREL
F0 BEQ REL|F1 SBC IZY|F2 SBC IZZ|F3 BEQ REL16|F4 PHW IMM16|F5 SBC ZPX|F6 INC ZPX|F7 SMB7 ZP|F8 SED IMP|F9 SBC ABSY|FA PLX IMP|FB PLZ IMP|FC PHW ABS|FD SBC ABSX|FE INC ABSX|FF BBS7 ZPREL
"""
modes = dict(IMP=IMP, ACC=ACC, IMM=IMM, ZP=ZP, ZPX=ZPX, ZPY=ZPY, ABS=ABS, ABSX=ABSX, ABSY=ABSY,
             IND=IND, INDX=INDX, IZX=IZX, IZY=IZY, IZZ=IZZ, ISY=ISY, REL=REL, REL16=REL16,
             ZPREL=ZPREL, IMM16=IMM16, FLAT=FLAT)
ents = []
for line in rows.strip().split('\n'):
    for cell in line.split('|'):
        op, mn, md = cell.split()
        ents.append((mn, modes[md], int(op, 16), 0))
ents.append(('NOP', IMP, 0xEA, 0))
# long branch aliases (LBxx / LBRA) map to the 16-bit relative forms
for mn, md, op, fl in list(ents):
    if md == REL16:
        ents.append(('L' + mn, REL16, op, 0))
# 45GS02 32-bit flat addressing: [zp],Z = $EA prefix + (zp),Z opcode
for mn, md, op, fl in list(ents):
    if md == IZZ and mn in ('ORA', 'AND', 'EOR', 'ADC', 'STA', 'LDA', 'CMP', 'SBC'):
        ents.append((mn, FLAT, op, 2))
# 45GS02 Q instructions: $42 $42 prefix on the accumulator instruction
qmap = {'ORA': 'ORQ', 'AND': 'ANDQ', 'EOR': 'EORQ', 'ADC': 'ADCQ', 'SBC': 'SBCQ', 'CMP': 'CPQ',
        'LDA': 'LDQ', 'STA': 'STQ', 'BIT': 'BITQ', 'ASL': 'ASLQ', 'LSR': 'LSRQ', 'ROL': 'ROLQ',
        'ROR': 'RORQ', 'ASR': 'ASRQ', 'INC': 'INQ', 'DEC': 'DEQ'}
for mn, md, op, fl in list(ents):
    if mn in qmap and md in (ACC, ZP, ZPX, ABS, ABSX, IZZ, FLAT) and fl in (0, 2):
        if md == IZZ:
            ents.append((qmap[mn], IZZ, op, 1))       # LDQ (zp)  (Z not used)
        else:
            ents.append((qmap[mn], md, op, 1 | fl))
# CPQ is also known as CMPQ
for mn, md, op, fl in list(ents):
    if mn == 'CPQ':
        ents.append(('CMPQ', md, op, fl))
ents.sort(key=lambda e: (e[0], e[1]))
out = ['; *** GENERATED by tools/gen_opcodes.py - 45GS02 instruction table',
       '; entries: mnemonic (4 chars), mode, opcode, flags (bit0 $42 $42 prefix, bit1 $EA prefix)',
       'asm_tab:']
for mn, md, op, fl in ents:
    out.append('\t!text "%-4s" : !byte %d, $%02x, %d' % (mn, md, op, fl))
out.append('\t!byte $ff')
print('\n'.join(out))
print('; %d entries' % len(ents))
