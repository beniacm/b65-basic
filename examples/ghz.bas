1 REM Core: any MEGA65 core. The art: SCROLLTEST from your own INTRO2.D81 in the SD card root (read at run time), else B65GHZG.BBC (generated tiles, in dist/sd). B65GHZS.BBC: act 2.
5 REM GHZ, act 1: Maxice's SCROLLTEST scroller (INTRO2.D81) frame for frame in B65: seven parallax bands, a front layer whose speed ramps, 64 rings on sine paths, a cycling waterfall
10 REM The VIC-IV draws 26 rows of 104 16-bit tokens (V400, 208 bytes a row):
20 REM GOTOX + 21 band tiles + GOTOX + 21 front tiles + 30 ring slots (GOTOX
30 REM with a Y offset + a ring glyph). Tiles are NCM (16 x 8 pixels, 4 bits).
40 REM Per frame BASIC moves the bands and the front layer (counters, fine X,
50 REM coarse columns) and cycles the waterfall's palette entries 25-28; then
60 REM the inline-assembler routine RING sets the sources of the DMA list's
70 REM row copies (52 from the token maps, 52 text rows), starts the chained
80 REM list (with 26 fills that park the ring slots), writes the rows' GOTOX
90 REM bytes, moves 64 rings on two summed sine tables per axis and puts each
95 REM into the slots of 3 rows (as SCROLLTEST does). The data: docs/GHZ.md.
100 REM BN%>0: BN% frames without the intro and the frame wait (tests); RN%>0: stop after RN% frames.
110 BN%=0:RN%=0:VS%=0:A1%=3000:SM%=1:REM A1%: the frames of act 1; SM%=0: the text in 8-pixel steps (Xemu draws no GOTOX Y offsets)
115 DN$="INTRO2.D81":PN$="SCROLLTEST":REM the D81 in the SD card root and the program on it that has the art
120 SC%=&50000:LS%=372:CO%=&800:CR%=&FF80000+CO%:TM%=&52600:GA%=&55800:TA%=&5A600:DL%=&5C000:FT%=&5D000:TT%=&8580000:PS%=&5F000
130 DIM DB% 255,C%(6),ST%(6),AD%(6),RL%(6),W%(6),SH%(6),K%(6),R0%(6),R1%(6),BL%(25),FL%(25),JB%(25),JF%(25),JA%(25),JC%(25)
140 ON ERROR E$=REPORT$:E%=ERL:PROCback:PRINT E$;" at line ";E%:END
150 T%=TIME:IF BN%=0 THEN CLS:PRINT TAB(26,11);"YOU HAVE SEEN THIS ON MEGA65":PRINT TAB(23,13);"SCROLLTEST BY MAXICE, INTRO DISK 2"
155 PROCload:IF BN%=0 THEN PRINT TAB((80-LEN AR$) DIV 2,16);AR$:REPEAT UNTIL TIME-T%>=300 ELSE PRINT AR$;" in ";TIME-T%;" cs"
160 PROCtables:PROCscreen:PROCdma:PROCasm:PROCvic
165 IF BN%=0 THEN REPEAT UNTIL INKEY(0)<0:REM keys pending from before do not end the demo
170 F%=0:FX%=0:FC%=0:SP%=4:W1%=0:W2%=0:EX%=0:AC%=1:TL%=0:TS%=0:T0%=TIME
200 REPEAT
210 FOR B%=0 TO 6:C%(B%)=C%(B%)-ST%(B%):IF C%(B%)<0 THEN PROCband(B%)
220 ?(V%+10+B%)=C%(B%)>>SH%(B%):NEXT
230 W1%=W1%+1:IF W1%=8 THEN W1%=0:W2%=(W2%+1) AND 3:PROCwf
240 FX%=FX%-SP%:IF FX%<0 THEN FX%=FX%+16:PROCfront
250 ?(V%+7)=FX%:?(V%+6)=SP%:IF AC%=2 THEN PROCscroll ELSE IF F%=A1% AND NL% THEN PROCact2
270 CALL RING%:REM the job sources, the DMA list, the GOTOX bytes, the rings
280 F%=F%+1:IF BN%=0 THEN WAIT
285 IF BN%=0 THEN IF F%=RN% OR INKEY(0)>=0 THEN EX%=1
290 UNTIL F%=BN% OR EX%
300 T0%=TIME-T0%:PROCback:IF BN%+RN% THEN PRINT "frames ";F%;" speed ";SP%;" front ";FC%;",";FX%;" in ";T0%;" cs"
310 END
400 DEF PROCband(B%)
410 IF RL%(B%) THEN C%(B%)=RL%(B%) ELSE C%(B%)=C%(B%)+AD%(B%)
420 K%(B%)=K%(B%)+1:IF K%(B%)>=W%(B%) THEN K%(B%)=0
430 ?(V%+17+B%)=2*K%(B%):ENDPROC:REM (RING moves the rows' job sources)
440 REM ---- act 2: the source scrolls up over the picture (two token sets a row: line L moved up by S pixels, line L+1 down by 8-S)
442 DEF PROCact2:AC%=2:TL%=0:TS%=0:?&D1FA=&FF:?&D2FA=&FF:?&D3FA=&FF:PROCtext:ENDPROC
444 DEF PROCscroll:TS%=TS%+1:IF TS%=8 THEN TS%=0:TL%=TL%+1:PROCtext
445 IF TL%>=NL%-27 THEN AC%=3:?(V%+8)=0:?(V%+9)=2:ENDPROC:REM (the closing caption stays on rows 11 and 13)
446 IF SM%=0 THEN ?(V%+8)=0:?(V%+9)=2:ENDPROC
447 IF TS% THEN ?(V%+8)=TS%<<5:?(V%+9)=((8-TS%)<<5) OR &10 ELSE ?(V%+8)=0:?(V%+9)=2:REM (Y offset: bits 15-13 up, bit 12: down)
448 ENDPROC
449 DEF PROCtext:LOCAL T%:T%=&80000+80*TL%:?(V%+25)=T% AND 255:?(V%+26)=(T%>>8) AND 255:?(V%+27)=T%>>16:ENDPROC
450 DEF PROCfront
460 FC%=FC%+1:IF FC%=&7C THEN FC%=0:S%=(SP%+1) AND 15:IF S% THEN SP%=S%
470 ?(V%+24)=2*FC%:ENDPROC
480 DEF PROCsrc(J%,S%):?(J%+13)=S% AND 255:?(J%+14)=(S%>>8) AND 255:?(J%+15)=S%>>16:ENDPROC
490 DEF PROCwf:LOCAL I%:FOR I%=0 TO 3:?(&D119+I%)=?(TA%+768+W2%+I%):?(&D219+I%)=?(TA%+776+W2%+I%):?(&D319+I%)=?(TA%+784+W2%+I%):NEXT:ENDPROC
500 REM ---- the art: tables 3796 bytes to TA%, glyphs $160.. to GA% (from SCROLLTEST on the D81, else the generated pack)
510 DEF PROCload:LOCAL F%
520 OK%=0:AR$="GENERATED ART":F%=OPENIN DN$:IF F% THEN PROCd81(F%):CLOSE#F%
530 IF OK% THEN AR$="ORIGINAL ART FROM "+DN$ ELSE F%=OPENIN "B65GHZG":IF F%=0 THEN ERROR 214,"B65GHZG.BBC not on the SD card (see docs/GHZ.md)"
540 IF OK%=0 THEN BGET#F%,TA%,3796:BGET#F%,GA%,19904:CLOSE#F%
560 NL%=0:F%=OPENIN "B65GHZS":IF F%=0 THEN ENDPROC:REM (no overlay: no act 2)
570 NL%=BGET#F%:NL%=NL%+256*BGET#F%:BGET#F%,FT%,6144:BGET#F%,TT%,80*NL%:CLOSE#F%:ENDPROC
580 REM D81: the directory from track 40 sector 3 (8 entries of 32 bytes a sector), the file's sectors (254 bytes each) land as loaded at $2001 (bank 5: $52001, so glyph n is at GA%)
582 DEF PROCd81(F%):LOCAL T%,S%,E%,A%,N%,L%,I%,N$,P$:P$=PN$+STRING$(16-LEN PN$,CHR$&A0):T%=40:S%=3:A%=0
584 REPEAT PTR#F%=((T%-1)*40+S%)*256:BGET#F%,DB%,256:FOR E%=0 TO 224 STEP 32:N$="":FOR I%=5 TO 20:N$=N$+CHR$(DB%?(E%+I%)):NEXT
586 IF (DB%?(E%+2) AND 7)=2 AND N$=P$ THEN A%=&10000+DB%?(E%+3)+256*DB%?(E%+4)
588 NEXT:T%=?DB%:S%=DB%?1:UNTIL T%=0 OR T%>80 OR A%
590 IF A%=0 THEN ENDPROC
591 T%=A% AND 255:S%=(A%>>8) AND 255:L%=0
592 REPEAT
593 IF T%<1 OR T%>80 OR S%>39 OR L%>34241 THEN ENDPROC
594 PTR#F%=((T%-1)*40+S%)*256:T%=BGET#F%:S%=BGET#F%:IF T% THEN N%=254 ELSE N%=S%-1
595 BGET#F%,&51FFF+L%,N%:L%=L%+N%:UNTIL T%=0
596 IF L%<>34241 THEN ENDPROC
597 S%=0:FOR I%=&51FFF TO &5A5BF STEP 16:S%=S%+?I%:NEXT:IF S%<>132577 THEN ENDPROC:REM (every 16th byte; another SCROLLTEST build gets the generated art)
598 OK%=1:PROCcp(&52FF4,TA%,768):PROCcp(&52D00,TA%+768,24):PROCcp(&52DEB,TA%+792,512):PROCcp(&53300,TA%+1304,2492):ENDPROC
599 DEF PROCcp(S%,D%,N%):PROCjob(DL%,0,N%,S%,D%,1):?(DL%+10)=0:?&D702=DL% DIV 65536:?&D704=0:?&D701=(DL% DIV 256) AND 255:?&D705=DL% AND 255:ENDPROC
600 REM ---- token maps (16-bit tokens: glyph $160.. is char $1560..) and the band table
610 DEF PROCtables:LOCAL B%,T%,R%,A%,N%,X%,O%,V%
620 RESTORE 690:FOR B%=0 TO 6:READ R0%(B%),R1%(B%),ST%(B%),AD%(B%),RL%(B%),W%(B%),SH%(B%):C%(B%)=3:K%(B%)=0:NEXT:C%(0)=1:C%(1)=10
630 A%=TM%:FOR R%=0 TO 25
640 IF R%<10 THEN O%=1304+50*(R% DIV 2):N%=50 ELSE IF R%<16 THEN O%=1554+49*((R%-10) DIV 2):N%=49 ELSE O%=1701+42*((R%-16) DIV 2):N%=42
650 BL%(R%)=A%:FOR X%=0 TO N%-1:V%=(?(TA%+O%+X%)+(R% AND 1)) AND 255:?A%=V%:?(A%+1)=&16:A%=A%+2:NEXT
660 FL%(R%)=A%:O%=1911+145*(R% DIV 2):FOR X%=0 TO 144:V%=(?(TA%+O%+X%)+(R% AND 1)) AND 255:?A%=V%:?(A%+1)=&15:A%=A%+2:NEXT
670 NEXT:ENDPROC
680 REM rows, step, reload add, reload, wrap, fine shift (SCROLLTEST's seven bands)
690 DATA 0,9,1,0,31,29,1, 10,15,1,0,15,28,0, 16,17,3,31,0,21,1, 18,19,2,16,0,21,0
695 DATA 20,21,5,31,0,21,1, 22,23,3,16,0,21,0, 24,25,4,16,0,21,0
700 REM ---- screen and colour RAM: 26 rows of 186 tokens (104 as SCROLLTEST's, then 2 x (GOTOX + 40 text chars))
710 DEF PROCscreen:LOCAL R%,I%,A%,C%
720 FOR R%=0 TO 25:A%=SC%+LS%*R%:C%=CR%+LS%*R%
730 ?A%=0:?(A%+1)=0:?C%=&10:?(C%+1)=0
740 FOR I%=2 TO 42 STEP 2:?(A%+I%)=0:?(A%+I%+1)=&16:?(C%+I%)=8:?(C%+I%+1)=-&10*(R%>=10):NEXT
750 ?(A%+44)=&70:?(A%+45)=0:?(C%+44)=&90:?(C%+45)=0
760 FOR I%=46 TO 86 STEP 2:?(A%+I%)=&60:?(A%+I%+1)=&15:?(C%+I%)=8:?(C%+I%+1)=&20:NEXT
770 FOR I%=88 TO 204 STEP 4:?(A%+I%)=0:?(A%+I%+1)=1:?(A%+I%+2)=&84:?(A%+I%+3)=&16:?(C%+I%)=&90:?(C%+I%+1)=0:?(C%+I%+2)=8:?(C%+I%+3)=&30:NEXT
775 FOR I%=208 TO 290 STEP 82:?(A%+I%)=0:?(A%+I%+1)=2:?(C%+I%)=&90:?(C%+I%+1)=0:NEXT
777 FOR I%=210 TO 370 STEP 2:IF I%<>290 THEN ?(A%+I%)=&40:?(A%+I%+1)=&17:?(C%+I%)=0:?(C%+I%+1)=0
778 NEXT
780 NEXT:ENDPROC
800 REM ---- the DMA list: 26 band rows, 26 front rows, 2 x 26 text rows (attic), 26 ring slot fills
810 DEF PROCdma:LOCAL J%,R%,B%
820 J%=DL%:FOR R%=0 TO 25:JB%(R%)=J%:PROCjob(J%,0,42,BL%(R%),SC%+LS%*R%+2,1):J%=J%+22:NEXT
830 FOR R%=0 TO 25:JF%(R%)=J%:PROCjob(J%,0,42,FL%(R%),SC%+LS%*R%+46,1):J%=J%+22:NEXT
840 FOR R%=0 TO 25:JA%(R%)=J%:PROCjob(J%,0,80,&80000,SC%+LS%*R%+210,1):?(J%+1)=&85:J%=J%+22:NEXT
850 FOR R%=0 TO 25:JC%(R%)=J%:PROCjob(J%,0,80,&80000,SC%+LS%*R%+292,1):?(J%+1)=&85:J%=J%+22:NEXT
860 FOR R%=0 TO 25:PROCjob(J%,3,30,2,SC%+LS%*R%+89,4):J%=J%+22:NEXT
870 ?(J%-12)=?(J%-12) AND &FB:ENDPROC
880 DEF PROCjob(J%,C%,N%,S%,D%,DS%)
890 ?J%=&80:?(J%+1)=0:?(J%+2)=&81:?(J%+3)=0:?(J%+4)=&83:?(J%+5)=1:?(J%+6)=&85:?(J%+7)=DS%:?(J%+8)=&0B:?(J%+9)=0
895 ?(J%+10)=C%+4:?(J%+11)=N% AND 255:?(J%+12)=N%>>8:PROCsrc(J%,S%):PROCsrc(J%+3,D%):?(J%+19)=0:?(J%+20)=0:?(J%+21)=0:ENDPROC
900 REM ---- RING: 64 rings (SCROLLTEST's $2A41 motion and $2B69 placement)
910 DEF PROCasm:LOCAL P%,I%,O%
920 DIM V% 1200:S1%=V%+32:S2%=S1%+256:TX%=S2%+256:TH%=TX%+65:TY%=TH%+65:TG%=TY%+65:CN%=TG%+65:PL%=CN%+28:PH%=PL%+28
930 FOR I%=0 TO 255:?(S1%+I%)=?(TA%+792+I%):?(S2%+I%)=?(TA%+1048+I%):NEXT
940 ?V%=0:?(V%+1)=&3F:?(V%+2)=0:?(V%+3)=&3F:?(V%+4)=&84:?(V%+5)=0:?(V%+6)=4
950 FOR I%=2 TO 27:O%=SC%+LS%*(I%-2)+88:?(PL%+I%)=O% AND 255:?(PH%+I%)=(O%>>8) AND 255:NEXT
955 RM%=PH%+28:?(V%+8)=2:?(V%+9)=2:FOR I%=0 TO 25:B%=0:WHILE I%>R1%(B%):B%=B%+1:ENDWHILE:?(RM%+I%)=B%:NEXT
956 REM job sources: band row = BB(row) + 2 x column (V%+17+band), front row = FB(row) + 2 x column (V%+24), text rows from V%+25..27 (80 bytes a line)
957 BB%=RM%+26:FB%=BB%+78:FOR I%=0 TO 25:FOR O%=0 TO 2:?(BB%+26*O%+I%)=(BL%(I%)>>(8*O%)) AND 255:?(FB%+26*O%+I%)=(FL%(I%)>>(8*O%)) AND 255:NEXT:NEXT
958 FOR I%=17 TO 24:?(V%+I%)=0:NEXT:?(V%+25)=0:?(V%+26)=0:?(V%+27)=8
960 DIM RING% 700:FOR I%=0 TO 2 STEP 2:P%=RING%
970 [OPT I%
971 .ring LDA #(DL%>>16):STA &C2:LDA #0:STA &C3:LDA #((DL%+13) AND 255):STA &C0:LDA #(((DL%+13)>>8) AND 255):STA &C1:LDY #0
972 .s1 LDX RM%,Y:LDA BB%,Y:CLC:ADC V%+17,X:LDZ #0:STA [&C0],Z:LDA BB%+26,Y:ADC #0:INZ:STA [&C0],Z:LDA BB%+52,Y:ADC #0:INZ:STA [&C0],Z:JSR nx:INY:CPY #26:BNE s1:LDY #0
973 .s2 LDA FB%,Y:CLC:ADC V%+24:LDZ #0:STA [&C0],Z:LDA FB%+26,Y:ADC #0:INZ:STA [&C0],Z:LDA FB%+52,Y:ADC #0:INZ:STA [&C0],Z:JSR nx:INY:CPY #26:BNE s2
974 LDA V%+25:STA &B0:LDA V%+26:STA &B1:LDA V%+27:STA &B2:JSR tx:LDA V%+25:CLC:ADC #80:STA &B0:LDA V%+26:ADC #0:STA &B1:LDA V%+27:ADC #0:STA &B2:JSR tx
975 LDA #(DL%>>16):STA &D702:LDA #0:STA &D704:LDA #((DL%>>8) AND 255):STA &D701:LDA #(DL% AND 255):STA &D705
976 LDA #(SC%>>16):STA &C2:LDA #0:STA &C3:LDY #25
977 .f1 LDA PL%+2,Y:SEC:SBC #88:STA &C0:LDA PH%+2,Y:SBC #0:STA &C1:LDX RM%,Y:LDA V%+10,X:LDZ #0:STA [&C0],Z
978 LDA V%+7:LDZ #44:STA [&C0],Z:LDA V%+8:LDZ #209:STA [&C0],Z:LDA V%+9:LDZ #291-256:INC &C1:STA [&C0],Z:LDZ #0:DEY:BPL f1
980 INC V%:INC V%+1:INC V%+5:LDA V%+5:CMP #10:BNE r1:LDA #0:STA V%+5:LDA V%+4:CLC:ADC #3:CMP #&96:BNE r0:LDA #&84
990 .r0 STA V%+4
1000 .r1 LDA V%+4:STA &B7:LDA V%+2:STA &B2:LDA V%+3:STA &B3:LDA #0:STA &B4:LDA #4:STA &B5
1010 .g1 LDA V%:STA &B0:LDA V%+1:STA &B1:LDX #16
1020 .g2 TXA:CLC:ADC &B4:STA &B6
1030 LDY &B0:LDA S1%,Y:LDY &B2:CLC:ADC S1%,Y:LDY &B6:STA TX%,Y:LDA #0:ROL A:STA TH%,Y
1040 LDY &B1:LDA S2%,Y:LDY &B3:CLC:ADC S2%,Y:LDY &B6:STA TY%,Y:LDA &B7:STA TG%,Y
1050 LDA &B0:CLC:ADC #16:STA &B0:LDA &B1:CLC:ADC #16:STA &B1:LDA &B2:CLC:ADC #16:STA &B2:LDA &B3:CLC:ADC #16:STA &B3
1060 DEX:BNE g2
1070 LDA &B4:CLC:ADC #16:STA &B4:LDA &B2:CLC:ADC #&20:STA &B2:LDA &B3:CLC:ADC #&20:STA &B3
1080 LDA &B7:CLC:ADC #3:CMP #&96:BNE g3:LDA #&84
1090 .g3 STA &B7:DEC &B5:LBNE g1
1100 LDA V%+6:CMP #4:LBEQ pd:LDX #27:LDA #0
1110 .c0 STA CN%,X:DEX:BPL c0
1120 LDX #64
1130 .p1 LDA TY%,X:AND #7:EOR #7:ASL A:ASL A:ASL A:ASL A:ASL A:STA &B8
1140 LDA TY%,X:LSR A:LSR A:LSR A:STA &B9:LDA TG%,X:STA &BA:LDA #3:STA &BB
1150 .p2 LDY &B9:CPY #28:BCS pn:LDA CN%,Y:CMP #29:BEQ pn:INC A:STA CN%,Y:DEC A:ASL A:ASL A:STA &BC
1160 CPY #2:BCC ps:LDA PL%,Y:CLC:ADC &BC:STA &C0:LDA PH%,Y:ADC #0:STA &C1:LDZ #0
1170 LDA TX%,X:STA [&C0],Z:INZ:LDA TH%,X:ORA &B8:STA [&C0],Z:INZ:LDA &BA:STA [&C0],Z:INZ:LDA #&16:STA [&C0],Z:LDZ #0
1180 .ps INC &B9:INC &BA:DEC &BB:BNE p2
1190 .pn DEX:LBNE p1
1200 .pd RTS
1202 .nx LDA &C0:CLC:ADC #22:STA &C0:BCC nr:INC &C1
1203 .nr LDZ #0:RTS
1204 .tx LDY #26
1205 .t1 LDZ #0:LDA &B0:STA [&C0],Z:INZ:LDA &B1:STA [&C0],Z:INZ:LDA &B2:STA [&C0],Z:JSR nx:LDA &B0:CLC:ADC #80:STA &B0:BCC t2:INC &B1:BNE t2:INC &B2
1206 .t2 DEY:BNE t1:RTS
1210 ]:NEXT:ENDPROC
1300 REM ---- the VIC-IV as SCROLLTEST sets it (V400, 26 rows of 104 tokens, CHR16 + FCLRHI), our palette
1310 DEF PROCvic:LOCAL I%:VS%=1
1320 RESTORE 1390:FOR I%=0 TO 20:READ VR%:?(PS%+768+I%)=?VR%:NEXT
1330 FOR I%=0 TO 255:?(PS%+I%)=?(&D100+I%):?(PS%+256+I%)=?(&D200+I%):?(PS%+512+I%)=?(&D300+I%):NEXT
1340 FOR I%=0 TO 255:?(&D100+I%)=?(TA%+I%):?(&D200+I%)=?(TA%+256+I%):?(&D300+I%)=?(TA%+512+I%):NEXT
1350 ?&D05D=?&D05D AND &7F:?&D031=(?&D031 OR 8) AND &5F:?&D051=&40:?&D05B=0:?&D054=(?&D054 AND &C0) OR 5:?&D058=LS% AND 255:?&D059=LS%>>8:?&D05E=186:?&D07B=&1A
1360 ?&D060=SC% AND 255:?&D061=(SC%>>8) AND 255:?&D062=SC%>>16:?&D063=0:?&D064=CO% AND 255:?&D065=CO%>>8
1370 ?&D016=0:?&D011=&10:?&D04C=&30:?&D020=0:?&D021=0:ENDPROC
1390 DATA &D031,&D051,&D054,&D058,&D059,&D05B,&D05D,&D05E,&D060,&D061,&D062,&D063,&D064,&D065,&D07B,&D016,&D011,&D04C,&D020,&D021,&D070
1400 DEF PROCback:LOCAL I%:IF VS%=0 THEN ENDPROC
1410 RESTORE 1390:FOR I%=0 TO 20:READ VR%:?VR%=?(PS%+768+I%):NEXT
1420 FOR I%=0 TO 255:?(&D100+I%)=?(PS%+I%):?(&D200+I%)=?(PS%+256+I%):?(&D300+I%)=?(PS%+512+I%):NEXT
1430 MODE 0:ENDPROC
