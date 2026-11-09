1 REM Core: any MEGA65 core (GOTOX slots); K325T feature level 3 (step 6) for the object path. Not on K325T levels 1-2. Work in progress.
5 REM Per frame: (measured below)
10 REM Walkers: an original crowd demo for B65 BASIC (VIC-IV, 256 colours)
20 REM Little walkers drop from a hatch, walk, turn at walls, step up single
30 REM tiles, fall off ledges and leave through the door on the right. A script
40 REM gives three of them a job: one digs through the upper ledge, one blocks
50 REM the way back, one builds a stair over the hill. The level is an 80x25
60 REM CHR16 map of full-colour tiles (V200) over a 200-line sky gradient;
70 REM digging and building change it. Own 256-colour palette (0-15 kept).
80 REM Walkers are shaded full-colour glyphs: list-mode v2 objects on a
90 REM confirmed K325T (?&6E1=&FF; one glyph byte + one X/Y write per update,
100 REM HOLD around the batch); elsewhere (Xemu, standard MEGA65) the same
105 REM glyphs as GOTOX tokens in 8 slots at the end of each row.
110 REM BASIC 65 twin: examples/basic65/walkers65.bas (same picture, motion).
115 REM BN%>0: stop after BN% frames (tests); RS%=1: back to text, print timing
120 BN%=0:RS%=1:M%=2
130 SC%=&50000:LS%=196:CB%=&FF80800:CH%=&54000:FG%=&5E000:TL%=&53800:N%=8:K%=(?&6E1=&FF):SK%=1
140 DIM X%(7),Y%(7),D%(7),S%(7),T%(7),PR%(7),JF%(3),JT%(3),JC%(3),JR%(3),JD%(3),KC%(9)
150 ON ERROR PROCtext:REPORT:PRINT " at line ";ERL:END
155 PROCpalsave
160 PRINT "Building the level...":PROCpalette
170 PROCdma(3,25*LS%,0,SC%):PROCdma(3,25*LS%,0,CB%):PROCdma(3,2048,0,CH%):PROCdma(3,40*64,0,FG%)
180 RESTORE 210:REPEAT:READ G%:IF G%>=0 THEN FOR Y%=0 TO 7:READ B%:?(CH%+8*G%+Y%)=B%:NEXT
190 UNTIL G%<0
200 REM font for the counter (normal glyphs): A E K L O R S T U W / 0-9
210 DATA 65,24,36,66,126,66,66,66,0, 69,126,64,64,124,64,64,126,0
220 DATA 75,66,68,72,112,72,68,66,0, 76,64,64,64,64,64,64,126,0
230 DATA 79,60,66,66,66,66,66,60,0, 82,124,66,66,124,72,68,66,0
240 DATA 83,60,66,64,60,2,66,60,0, 84,126,24,24,24,24,24,24,0
250 DATA 85,66,66,66,66,66,66,60,0, 87,66,66,66,90,90,102,66,0
260 DATA 47,2,4,8,16,32,64,0,0, 48,60,70,74,82,98,66,60,0
270 DATA 49,24,56,24,24,24,24,126,0, 50,60,66,2,12,48,64,126,0
280 DATA 51,60,66,2,28,2,66,60,0, 52,12,20,36,68,126,4,4,0
290 DATA 53,126,64,124,2,2,66,60,0, 54,28,32,64,124,66,66,60,0
300 DATA 55,126,2,4,8,16,16,16,0, 56,60,66,66,60,66,66,60,0
310 DATA 57,60,66,66,62,2,4,56,0, -1
320 REM full-colour tiles &1780+n: 0-24 sky (one per row), 25 hatch, 26 door
330 REM post, 27 doorway, 28 lintel, 31 empty; solid from 32: 32 grass,
340 REM 33 earth, 34 brick, 35 step, 36 stone
350 PROCtiles
360 REM rows: 80 tiles (sky), 8 walker slots (GOTOX, glyph), GOTOX 632 and
370 REM the last tile again (a raster line ends where its last glyph is painted)
380 FOR R%=0 TO 24:A%=SC%+R%*LS%:C%=CB%+R%*LS%
390 SK%=2:PROCdma(3,80,&80+R%,A%):PROCdma(3,80,&17,A%+1):SK%=4:PROCdma(3,8,&9F,A%+162):PROCdma(3,8,&17,A%+163)
400 PROCdma(3,8,&90,C%+160):SK%=1:?(A%+192)=120:?(A%+193)=2:?(C%+192)=&10:?(A%+194)=&80+R%:?(A%+195)=&17
410 NEXT
420 REM level: ledge A, ledge B with a stone pillar, floor with walls, a hill
430 REM too high to step up, the exit door; then the hatch and the counter
440 PROCbox(4,8,38,8,32):PROCbox(4,9,38,9,33)
450 PROCbox(30,15,64,15,32):PROCbox(30,16,64,16,33):PROCbox(52,10,53,14,36)
460 PROCbox(0,23,79,23,32):PROCbox(0,24,79,24,33)
470 PROCbox(0,17,1,22,34):PROCbox(78,17,79,22,34)
480 PROCbox(44,19,48,19,32):PROCbox(44,20,48,22,33)
490 PROCbox(73,20,75,20,28):PROCbox(73,21,73,22,26):PROCbox(75,21,75,22,26):PROCbox(74,21,74,22,27)
500 PROCbox(9,2,11,2,25):PROCtxt(2,0,"WALKERS",140):PROCtxt(62,0,"OUT 0/8",140)
510 FOR R%=0 TO 24:A%=SC%+R%*LS%:?(A%+194)=?(A%+158):NEXT:REM the last tile again
520 PROCframes
530 REM job script: from frame JF, the first walker at column JC / row JR
540 REM (direction JD, 0 = any) gets job JT: 3 dig, 5 block, 4 build
550 RESTORE 560:FOR J%=0 TO 2:READ JF%(J%),JT%(J%),JC%(J%),JR%(J%),JD%(J%):NEXT:JF%(3)=1E6
560 DATA 150,3,20,7,0, 300,5,12,22,0, 450,4,39,22,1
570 REM VIC-IV: CHR16 + full colour above glyph 255, 196-byte rows of 98
580 REM tokens, screen/colour/charset pointers, sky colour behind the text
590 ?&D054=?&D054 OR 5:?&D058=LS% AND 255:?&D059=LS% DIV 256:?&D05E=98
600 ?&D063=?&D063 AND &C0:?&D060=0:?&D061=0:?&D062=5:?&D064=0:?&D065=8
610 ?&D068=0:?&D069=&40:?&D06A=5:?&D020=0:?&D021=16
620 IF K% THEN PROCv2
630 REM main loop: a new walker every 75 frames, M% walker updates per frame
640 FOR I%=0 TO 7:S%(I%)=0:PR%(I%)=-1:NEXT
650 F%=0:O%=0:NS%=0:J%=0:I%=-1:BR%=-1:BX%=0:BI%=-1:W2%=0:SP%=1:T0%=TIME
660 F%=F%+1:SP%=SP%-1:IF SP%=0 THEN SP%=75:IF NS%<N% THEN GOSUB 2000
670 IF K% THEN ?&FFD71FC=1:REM HOLD: the VIC-IV keeps its snapshot while we write
680 FOR Q%=1 TO M%:GOSUB 1000:NEXT:IF K% THEN ?&FFD71FC=0
690 WAIT:IF O%>=N%-1 THEN W2%=W2%+1:IF W2%>150 THEN 160
700 IF F%<>BN% THEN 660
710 T0%=TIME-T0%
720 IF RS% THEN PROCtext:PRINT BN%;" frames in ";T0%;" cs: ";BN%*100 DIV T0%;" frames per second"
730 END
1000 REM update the next walker (round robin); v2 X/Y are written AND 1023 (10-bit)
1010 I%=I%+1:IF I%=N% THEN I%=0
1015 S%=S%(I%):IF S%=0 OR S%=6 THEN RETURN
1020 X%=X%(I%):Y%=Y%(I%):D%=D%(I%):R%=Y% DIV 8:C%=(X%+2) DIV 4:A%=SC%+R%*LS%+2*C%
1030 ON S% GOSUB 1100,1200,1300,1400,1500
1040 X%(I%)=X%:Y%(I%)=Y%:D%(I%)=D%:S%(I%)=S%:IF S%=6 THEN RETURN
1050 IF K% THEN ?(&5F900+4*I%)=&C0+FR%:!(&5F800+32*I%)=(2*X% AND 1023)+(Y% AND 1023)*65536:RETURN
1060 R%=Y% DIV 8:IF R%<>PR%(I%) THEN IF PR%(I%)>=0 THEN ?(SC%+PR%(I%)*LS%+162+4*I%)=&9F
1070 PR%(I%)=R%:!(SC%+R%*LS%+160+4*I%)=2*X%+(&17C0+FR%)*65536:RETURN
1100 REM walk: fall if nothing below; at a wall step up one tile or turn
1110 IF ?(A%+LS%)<&A0 THEN S%=2:FR%=4:RETURN
1120 E%=X%+D%:G%=(E%+(D%+1)*3 DIV 2) DIV 4:W%=SC%+R%*LS%+2*G%
1130 IF ?W%>=&A0 THEN 1170
1140 IF R%=BR% AND ABS(E%-BX%)<4 AND I%<>BI% THEN D%=-D% ELSE X%=E%
1150 IF R%=22 AND C%>72 AND C%<76 THEN S%=6:GOSUB 1600:RETURN
1160 IF F%>=JF%(J%) AND R%=JR%(J%) AND C%=JC%(J%) AND (JD%(J%)=0 OR D%=JD%(J%)) THEN GOSUB 1700:RETURN
1165 FR%=1-D%+(X% DIV 2 AND 1):RETURN
1170 IF ?(W%-LS%)<&A0 THEN Y%=Y%-8:X%=4*G% ELSE D%=-D%
1180 FR%=1-D%+(X% DIV 2 AND 1):RETURN
1200 REM fall: 8 pixels per update, land on a solid tile
1210 Y%=Y%+8:FR%=4:IF ?(A%+2*LS%)>=&A0 THEN S%=1
1220 RETURN
1300 REM dig: every 4th update clear the tile below (sky shows) and sink 8
1310 T%=T%(I%)+1:T%(I%)=T%:FR%=5+(T% DIV 2 AND 1):IF T% AND 3 THEN RETURN
1320 IF ?(A%+LS%)<&A0 OR R%>=21 THEN S%=2:FR%=4:RETURN
1330 ?(A%+LS%)=&81+R%:Y%=Y%+8:RETURN
1400 REM build: every 8th update a step next to the walker, then up onto it
1410 T%=T%(I%)+1:T%(I%)=T%:FR%=7:IF T% AND 7 THEN RETURN
1420 IF T%>32 THEN S%=1:RETURN
1430 W%=A%+2*D%:IF ?W%>=&A0 OR ?(W%-LS%)>=&A0 THEN S%=1:RETURN
1440 ?W%=&A3:X%=X%+4*D%:Y%=Y%-8:RETURN
1500 FR%=8:RETURN
1600 REM out of the door: hide, count
1610 O%=O%+1:?(SC%+2*66)=48+O%
1620 IF K% THEN ?(&5F804+32*I%)=0 ELSE ?(SC%+PR%(I%)*LS%+162+4*I%)=&9F
1630 RETURN
1700 REM give this walker the scripted job (snapped to its tile)
1710 S%=JT%(J%):T%(I%)=0:X%=4*C%:IF S%=5 THEN BX%=X%:BR%=R%:BI%=I%
1720 FR%=4+S%:IF S%=4 THEN FR%=7
1725 IF S%=5 THEN FR%=8
1730 J%=J%+1:RETURN
2000 REM a new walker drops from the hatch
2010 S%(NS%)=2:X%(NS%)=40:Y%(NS%)=24:D%(NS%)=1:T%(NS%)=0:PR%(NS%)=-1
2020 IF K% THEN ?(&5F804+32*NS%)=255
2030 NS%=NS%+1:RETURN
3000 DEF PROCbox(C1%,R1%,C2%,R2%,G%):LOCAL R%,C0%
3010 FOR R%=R1% TO R2%:FOR C0%=C1% TO C2%:?(SC%+R%*LS%+2*C0%)=&80+G%:NEXT:NEXT:ENDPROC
3020 DEF PROCtxt(C1%,R1%,T$,C%):LOCAL I%,A%
3030 FOR I%=1 TO LEN T$:A%=R1%*LS%+2*(C1%+I%-1):?(SC%+A%)=ASC(MID$(T$,I%,1)):?(SC%+A%+1)=0
3035 ?(CB%+A%+1)=C%:NEXT:ENDPROC
3040 DEF PROCtiles:LOCAL N%,X%,Y%
3050 REM sky: one tile per row, a 32-step gradient over the 200 lines
3060 FOR N%=0 TO 24:FOR Y%=0 TO 7:PROCdma(3,8,16+(N%*8+Y%)*31 DIV 199,FG%+64*N%+8*Y%):NEXT:NEXT
3070 FOR N%=25 TO 36:IF N%<29 OR N%>31 THEN FOR Y%=0 TO 7:FOR X%=0 TO 7:PROCtile:?(FG%+64*N%+8*Y%+X%)=V%:NEXT:NEXT
3075 NEXT:ENDPROC
3080 DEF PROCtile
3090 IF N%=25 THEN V%=180-2*(Y% DIV 2):IF X%=1 OR X%=6 THEN V%=V%-3
3095 IF N%=25 THEN ENDPROC
3100 IF N%=26 THEN V%=131:IF X%<2 THEN V%=135
3105 IF N%=26 THEN IF X%>5 THEN V%=129
3110 IF N%=26 THEN ENDPROC
3120 IF N%=27 THEN V%=143-Y%:IF X%=0 OR X%=7 THEN V%=146
3125 IF N%=27 THEN ENDPROC
3130 IF N%=28 THEN V%=140+(X%+Y%) MOD 2:IF Y%>5 THEN V%=134
3135 IF N%=28 THEN ENDPROC
3140 IF N%=32 AND Y%<3 THEN V%=94-3*Y%+(X%*3+Y%) MOD 3:ENDPROC
3150 IF N%=32 OR N%=33 THEN V%=53+(X%*5+Y%*7) MOD 5:IF (X%*7+Y%*3) MOD 11=0 THEN V%=49
3155 IF N%=32 OR N%=33 THEN ENDPROC
3160 IF N%=34 THEN V%=72+(X%+Y%) MOD 3:IF Y%=0 OR Y%=4 THEN V%=76
3165 IF N%=34 THEN IF Y%=3 OR Y%=7 OR (Y%<3 AND X%=7) OR (Y%>4 AND X%=3) THEN V%=147
3170 IF N%=34 THEN ENDPROC
3180 IF N%=35 THEN V%=137+(X% AND 1):IF Y%=0 THEN V%=142
3185 IF N%=35 THEN IF Y%=7 THEN V%=146
3190 IF N%=35 THEN ENDPROC
3200 V%=73:IF X%<2 THEN V%=78
3210 IF X%>5 THEN V%=68
3220 IF Y%=0 OR Y%=7 THEN V%=147
3230 ENDPROC
3300 DEF PROCframes:LOCAL F%,Y%,X%,A$,P%,K$
3310 REM walker frames (8x8, full colour): walk right 0-1, left 2-3 (mirrored),
3320 REM fall 4, dig 5-6, build 7, block 8; letters = palette entries below
3330 RESTORE 3340:K$=".hHsSbBlyw":FOR I%=0 TO 9:READ KC%(I%):NEXT
3340 DATA 0,94,84,166,158,198,188,146,141,134
3350 FOR F%=0 TO 8:IF F%=2 OR F%=3 THEN 3390
3360 FOR Y%=0 TO 7:READ A$:FOR X%=0 TO 7:P%=KC%(INSTR(K$,MID$(A$,X%+1,1))-1)
3370 ?(&5F000+64*F%+8*Y%+X%)=P%:IF F%<2 THEN ?(&5F000+64*(F%+2)+8*Y%+7-X%)=P%
3380 NEXT:NEXT
3390 NEXT:ENDPROC
3400 DATA "..hhH...", ".hsSs...", "..sS....", ".bbBl...", "s.bB.s..", "..bB....", "..l.l...", ".ll..l.."
3410 DATA "..hhH...", ".hsSs...", "..sS....", "..bBb...", "..bBs...", "..bB....", "..lH....", "..ll...."
3420 DATA "s.hhH.s.", "s.sSs.s.", ".bsSb...", "..bBb...", "..bB....", "..bB....", ".l..l...", ".l..l..."
3430 DATA "........", "..hhH...", ".hsSs...", ".bbBb...", "s.bBb.yy", "..bB..y.", ".l.l..y.", "l...l.y."
3440 DATA "........", "........", "..hhH...", ".hsSsy..", ".bbBby..", "s.bB.y..", ".l.l.y..", "l...lyy."
3450 DATA "..hhH...", ".hsSs...", "..sS....", ".bbBl...", "..bBsww.", "..bB.ww.", "..l.l...", ".ll.ll.."
3460 DATA "..hhH...", ".hsSs...", "s.sS.s..", "sbbBbbs.", "..bB....", "..bB....", ".l..l...", "ll..ll.."
3500 DEF PROCpalette:LOCAL S%,C%,I%,R0%,G0%,B0%,R1%,G1%,B1%
3510 REM own palette: ramps from 16 on (0-15 stay the standard colours)
3515 RESTORE 3560
3520 READ S%:IF S%<0 THEN ENDPROC
3530 READ C%,R0%,G0%,B0%,R1%,G1%,B1%:FOR I%=0 TO C%-1
3540 PROCpal(S%+I%,R0%+(R1%-R0%)*I% DIV (C%-1),G0%+(G1%-G0%)*I% DIV (C%-1),B0%+(B1%-B0%)*I% DIV (C%-1)):NEXT
3550 GOTO 3520
3560 DATA 16,32,18,16,60,250,190,130, 48,16,35,20,10,215,165,105, 64,16,25,25,35,215,215,225
3570 DATA 80,16,8,40,12,140,230,90, 96,16,10,45,45,170,235,130, 112,16,5,20,70,130,210,255
3580 DATA 128,16,80,25,0,255,245,160, 144,8,0,0,0,50,40,60, 152,16,70,35,25,255,215,180
3590 DATA 168,16,40,45,55,235,240,250, 184,16,10,20,90,120,170,255, 200,16,60,0,5,255,130,110
3600 DATA 216,16,50,0,60,255,160,255, 232,24,0,0,0,255,255,255, -1
3610 DEF PROCpal(I%,R%,G%,B%):REM the VIC-IV stores palette bytes nibble-swapped
3620 ?(&D100+I%)=(R% MOD 16)*16+R% DIV 16:?(&D200+I%)=(G% MOD 16)*16+G% DIV 16:?(&D300+I%)=(B% MOD 16)*16+B% DIV 16:ENDPROC
3630 DEF PROCpalsave:LOCAL I%
3640 FOR I%=16 TO 255:?(&5F400+I%)=?(&D100+I%):?(&5F500+I%)=?(&D200+I%):?(&5F600+I%)=?(&D300+I%):NEXT:ENDPROC
3650 DEF PROCpalrest:LOCAL I%
3660 FOR I%=16 TO 255:?(&D100+I%)=?(&5F400+I%):?(&D200+I%)=?(&5F500+I%):?(&D300+I%)=?(&5F600+I%):NEXT:ENDPROC
3700 DEF PROCv2
3710 REM full-colour walker glyphs &17C0+frame at &5F000; one token list per walker
3720 FOR I%=0 TO 7:A%=&5F900+4*I%:?A%=&C0:?(A%+1)=&17:?(A%+2)=255:?(A%+3)=255
3730 E%=&5F800+32*I%:!E%=0:?(E%+4)=0:?(E%+5)=1:?(E%+6)=&45:?(E%+7)=0
3740 !(E%+8)=(&F900+4*I%)+(&3C00+4*I%)*65536:!(E%+12)=0
3750 ?(&FF83C00+4*I%)=0:?(&FF83C01+4*I%)=0:NEXT
3760 ?&FFD71F8=0:?&FFD71F9=&F8:?&FFD71FA=5:?&FFD71FB=8:?&FFD71F0=?&FFD71F0 OR &50:ENDPROC
3800 DEF PROCdma(C%,N%,S%,D%):?TL%=&80:?(TL%+1)=S% DIV &100000:?(TL%+2)=&81:?(TL%+3)=D% DIV &100000
3810 ?(TL%+4)=&85:?(TL%+5)=SK%:?(TL%+6)=&0B:?(TL%+7)=0:?(TL%+8)=C%:?(TL%+9)=N% AND 255:?(TL%+10)=N% DIV 256
3820 !(TL%+11)=S% AND &FFFFF:!(TL%+14)=D% AND &FFFFF:?(TL%+18)=0:?(TL%+19)=0
3830 ?&D702=TL% DIV 65536:?&D704=0:?&D701=(TL% DIV 256) AND 255:?&D705=TL% AND 255:ENDPROC
3900 DEF PROCtext
3910 IF K% THEN ?&FFD71F0=?&FFD71F0 AND &AF
3920 PROCpalrest:MODE 0:ENDPROC
