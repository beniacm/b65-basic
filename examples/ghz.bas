1 REM Core: any MEGA65 core. The art: SCROLLTEST from your own INTRO2.D81 in the SD card root (read at run time), else B65GHZG.BBC (generated tiles, in dist/sd). B65GHZS.BBC: acts 2 and 3.
5 REM GHZ, act 1: Maxice's SCROLLTEST scroller (INTRO2.D81) frame for frame in B65: seven parallax bands, a front layer whose speed ramps, 64 rings, a waterfall. Act 2: this listing. Act 3 (K325T): 1000 rings, clouds, bushes as objects
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
110 BN%=0:RN%=0:VS%=0:A1%=1500:SM%=1:A2%=1:XT%=0:REM A1%: the frames of act 1; SM%=0: the text in 8-pixel steps (Xemu draws no GOTOX Y offsets); A2%=0: no act 2; XT%=1: act 3's objects in a scratch table (tests)
115 DN$="INTRO2.D81":PN$="SCROLLTEST":SV%=1:RW%=254:RB%=0:REM the D81 in the SD card root and the program on it that has the art; SV%: act 2's scroll (pixels a frame); RW%: RING's raster line; RB%=1: rings 'behind'
120 SC%=&50000:LS%=372:CO%=&800:CR%=&FF80000+CO%:TM%=&52600:GA%=&55800:TA%=&5A600:DL%=&5C000:FT%=&5D000:TT%=&8580000:PS%=&5F000:OG%=&5E800:OP%=&5F400:OL%=&5F500:JS%=&5F600:EL%=&5F700:C3%=&3000:HU%=&85A0000
130 DIM DB% 255,C%(6),ST%(6),AD%(6),RL%(6),W%(6),SH%(6),K%(6),R0%(6),R1%(6),BL%(25),FL%(25),JB%(25),JF%(25),JA%(25),JC%(25),FR%(3),LA%(3),LM%(3),LP%(3)
140 ON ERROR E$=REPORT$:E%=ERL:PROCback:PRINT E$;" at line ";E%:END
150 T%=TIME:IF BN%=0 THEN CLS:PRINT TAB(26,11);"YOU HAVE SEEN THIS ON MEGA65":PRINT TAB(23,13);"SCROLLTEST BY MAXICE, INTRO DISK 2"
155 PROCload:IF BN%=0 THEN PRINT TAB((80-LEN AR$) DIV 2,16);AR$:REPEAT UNTIL TIME-T%>=300 ELSE PRINT AR$;" in ";TIME-T%;" cs"
160 P3%=1:PROCtables:PROCscreen:PROCdma:PROCasm:WHILE P3%<=25:PROCprep:ENDWHILE:PROCvic:P3%=0:PROCprep:P3%=26:REM act 3's set-up now: none of it shows before act 3
163 PROCwarm
165 IF BN%=0 THEN REPEAT UNTIL INKEY(0)<0:REM keys pending from before do not end the demo
170 F%=0:FX%=0:FC%=0:SP%=4:W1%=0:W2%=0:EX%=0:AC%=1:AN%=1:AS%=0:TL%=0:TS%=0:LQ%=?&D7FA:Q%=LQ%:T0%=TIME
200 REPEAT
210 FOR B%=0 TO 6:C%(B%)=C%(B%)-ST%(B%):IF C%(B%)<0 THEN PROCband(B%)
220 ?(V%+10+B%)=C%(B%)>>SH%(B%):NEXT
230 W1%=W1%+1:IF W1%=8 THEN W1%=0:W2%=(W2%+1) AND 3:PROCwf
240 FX%=FX%-SP%:IF FX%<0 THEN FX%=FX%+16:PROCfront
250 ?(V%+7)=FX%:?(V%+6)=SP%:IF AC%>1 OR F%=A1% THEN PROCstep
255 IF AC%=4 THEN IF K3%+XT% THEN CALL A3%:REM act 3: 1000 rings, clouds and bushes in the object table (mid-frame: the VIC-IV copies the table at the top of the frame)
260 REM (BN%=0: RING waits for the picture, then for raster line RW% below it: one pass a frame, all screen and slot writes in the vertical blank)
270 CALL RING%:REM the job sources, the DMA list, the GOTOX bytes, the rings
280 F%=F%+1:FR%(AN%)=FR%(AN%)+1:IF BN%=0 THEN Q%=?&D7FA:IF F%-AS%>10 THEN LA%(AN%)=LA%(AN%)+((Q%-LQ%-1) AND 255)
282 LQ%=Q%:IF KH% THEN IF F%-AS%=11 THEN ?&FFD71E3=0:REM (K325T: the VIC-IV's counters from each act's 11th frame)
283 IF F%=12 THEN ?&D011=&10:REM the display on: the first frames (first compiles) are not shown
285 IF BN%=0 THEN IF F%=RN% OR INKEY(0)>=0 THEN EX%=1
290 UNTIL F%=BN% OR EX%
300 T0%=TIME-T0%:PROCctr(AN%):PROCback:IF BN%+RN%=0 THEN PROCcard
305 IF BN%+RN% THEN PRINT "frames ";F%;" speed ";SP%;" front ";FC%;",";FX%;" in ";T0%;" cs"
307 IF BN% THEN PRINT "ring ";RZ%;" a3 ";AZ%;" rt ";~RT%
308 FOR I%=1 TO 3:IF FR%(I%) THEN PRINT "act ";I%;": ";FR%(I%);" frames, ";LA%(I%);" late";:IF KH% THEN PRINT ", longest painting ";LM%(I%);", late pixels ";LP%(I%) ELSE PRINT
309 NEXT
310 END
320 DEF PROCcard:CLS:PRINT TAB(25,11);"B65 BASIC FOR MEGA65 AND K325T":PRINT TAB(26,13);"github.com/beniacm/b65-basic":T%=TIME:REPEAT UNTIL TIME-T%>=400:PRINT:ENDPROC
330 REM ---- the acts: 1 (until frame A1%), 2 (the listing; AC% 2 scrolling, 3 the closing caption), 3 (AC% 4)
332 DEF PROCstep
334 IF AC%=1 THEN PROCa1:ENDPROC
338 IF AC%=2 THEN PROClist:ENDPROC
340 IF AC%=3 THEN H2%=H2%+1:IF H2%>=150 THEN PROCact3:ENDPROC
342 IF AC%=4 THEN PROCa3
344 ENDPROC
346 DEF PROCa1:PROCctr(1):IF NL%=0 THEN EX%=1:ENDPROC:REM (no B65GHZS.BBC: act 1 only)
347 AN%=2:AS%=F%:AC%=3:H2%=150:IF A2% THEN PROCact2
348 ENDPROC
400 DEF PROCband(B%)
410 IF RL%(B%) THEN C%(B%)=RL%(B%) ELSE C%(B%)=C%(B%)+AD%(B%)
420 K%(B%)=K%(B%)+1:IF K%(B%)>=W%(B%) THEN K%(B%)=0
430 ?(V%+17+B%)=2*K%(B%):ENDPROC:REM (RING moves the rows' job sources)
440 REM ---- act 2: the fixed top line "BUT HAVE YOU SEEN IT IN BASIC?", below it a LIST of this program's main parts scrolling SV% pixels a frame over the running scene (rows 2..25), then "B65 BASIC. n LINES."
441 DEF PROCact2:?&D05E=186:AC%=2:P2%=0:H2%=0:TL%=0:TS%=0:?(V%+31)=2:?(OV%+124)=0:?(OV%+125)=0:?(OV%+126)=8:PROCtext:?(V%+8)=0:?(V%+9)=2:?(V%+28)=&FF:ENDPROC
442 DEF PROClist:H2%=H2%+1:IF P2%=1 THEN PROCscroll:ENDPROC
443 IF P2%=0 THEN IF H2%>=50 THEN P2%=1:ENDPROC
444 IF P2%=2 THEN IF H2%>=100 THEN ?&D05E=145:?(V%+31)=0:TL%=LE%+1:PROCtext:AC%=3:H2%=0
445 ENDPROC
446 DEF PROCscroll:TS%=TS%+SV%:IF TS%>=8 THEN TS%=0:TL%=TL%+1:PROCtext:IF TL%>=LE%-25 THEN P2%=2:H2%=0
447 IF SM%=0 OR TS%=0 THEN ?(V%+8)=0:?(V%+9)=2:?(V%+28)=&FF:ENDPROC
448 ?(V%+8)=TS%<<5:?(V%+9)=((8-TS%)<<5) OR &10:?(V%+28)=&FF>>TS%:?(V%+29)=(&FF<<(8-TS%)) AND &FF:ENDPROC:REM (set 1: line L up S pixels, rows 0..7-S; set 2: line L+1 down 8-S, rows 8-S..7)
449 DEF PROCtext:PROCtb(&80000+80*TL%):ENDPROC
450 DEF PROCfront
460 FC%=FC%+1:IF FC%=&7C THEN FC%=0:IF AC%=1 THEN S%=(SP%+1) AND 15:IF S% THEN SP%=S%:REM (the speed ramps in act 1 only)
470 ?(V%+24)=2*FC%:ENDPROC
480 DEF PROCsrc(J%,S%):?(J%+13)=S% AND 255:?(J%+14)=(S%>>8) AND 255:?(J%+15)=S%>>16:ENDPROC
490 DEF PROCwf:LOCAL I%:FOR I%=0 TO 3:?(&D119+I%)=?(TA%+768+W2%+I%):?(&D219+I%)=?(TA%+776+W2%+I%):?(&D319+I%)=?(TA%+784+W2%+I%):NEXT:ENDPROC
500 REM ---- the art: tables 3796 bytes to TA%, glyphs $160.. to GA% (from SCROLLTEST on the D81, else the generated pack)
510 DEF PROCload:LOCAL F%
520 OK%=0:AR$="GENERATED ART":F%=OPENIN DN$:IF F% THEN PROCd81(F%):CLOSE#F%
530 IF OK% THEN AR$="ORIGINAL ART FROM "+DN$ ELSE F%=OPENIN "B65GHZG":IF F%=0 THEN ERROR 214,"B65GHZG.BBC not on the SD card (see docs/GHZ.md)"
540 IF OK%=0 THEN BGET#F%,TA%,3796:BGET#F%,GA%,19904:CLOSE#F%
560 NL%=0:F%=OPENIN "B65GHZS":IF F%=0 THEN ENDPROC:REM (no overlay: no acts 2 and 3)
570 NL%=BGET#F%:NL%=NL%+256*BGET#F%:LE%=BGET#F%:LE%=LE%+256*BGET#F%:BGET#F%,FT%,6144:BGET#F%,TT%,80*NL%:BGET#F%,OP%,96:BGET#F%,OG%,2048:CLOSE#F%:ENDPROC
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
775 FOR I%=208 TO 290 STEP 82:?(A%+I%)=16:?(A%+I%+1)=2:?(C%+I%)=&98:?(C%+I%+1)=&FF:NEXT:REM text sets at X 16 (the first visible pixel), GOTOX + transparent + row mask
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
958 FOR I%=17 TO 24:?(V%+I%)=0:NEXT:?(V%+25)=0:?(V%+26)=0:?(V%+27)=8:?(V%+30)=0:?(V%+31)=0
959 K3%=0:KH%=(?&6E1=&FF):IF KH% THEN IF ?&FFD71FD>=3 THEN K3%=1
960 NO%=1020:RT%=(TOP+&FF) AND &FFFF00:IF K3% THEN RT%=&E0000:REM the object table (K325T: B65's own table address; tests: scratch in bank 1 above the program)
961 IF K3%=0 AND XT% AND RT%+32*NO%>&1F800 THEN ERROR 215,"Program too long for the test table"
962 DIM OV% 140:?(OV%+127)=(BN%=0) AND 1:?(OV%+128)=RW%:FOR I%=0 TO 3:?(OV%+70+I%)=((RT%+256)>>(8*I%)) AND 255:?(OV%+74+I%)=((RT%+32*1008)>>(8*I%)) AND 255:?(OV%+78+I%)=(RT%>>(8*I%)) AND 255:NEXT
963 ?OV%=64:?(OV%+1)=0:?(OV%+2)=0:CL%=FB%+78:CH%=CL%+26:FOR I%=0 TO 25:O%=CO%+LS%*I%:?(CL%+I%)=O% AND 255:?(CH%+I%)=O%>>8:NEXT:?(V%+28)=&FF:?(V%+29)=&FF:PF%=CH%+26:FOR I%=0 TO 25:?(PF%+I%)=&FF:NEXT:PROCfill(EL%,300,&40,&17)
964 ?(OV%+129)=255:?(OV%+130)=255:REM no caption band (A3%: rings with band lo <= y < hi are hidden)
965 DIM RING% 900,A3% 900:FOR I%=0 TO 2 STEP 2:P%=RING%
970 [OPT I%
971 .ring LDA OV%+127:BEQ rs:LDA OV%+128:STA &C1
972 .rv LDA &D011:BMI rv:LDA &D012:CMP &C1:BCS rv:.rw LDA &D011:BMI rs:LDA &D012:CMP &C1:BCC rw
973 .rs LDA #&40:STA &D051:LDA #(DL%>>16):STA &C2:LDA #0:STA &C3:LDA #((DL%+13) AND 255):STA &C0:LDA #(((DL%+13)>>8) AND 255):STA &C1:LDY #0
974 .s1 LDX RM%,Y:LDA BB%,Y:CLC:ADC V%+17,X:LDZ #0:STA [&C0],Z:LDA BB%+26,Y:ADC #0:INZ:STA [&C0],Z:LDA BB%+52,Y:ADC #0:INZ:STA [&C0],Z:JSR nx:INY:CPY #26:BNE s1:LDY #0
975 .s2 LDA FB%,Y:CLC:ADC V%+24:LDZ #0:STA [&C0],Z:LDA FB%+26,Y:ADC #0:INZ:STA [&C0],Z:LDA FB%+52,Y:ADC #0:INZ:STA [&C0],Z:JSR nx:INY:CPY #26:BNE s2
976 LDA V%+25:STA &B0:LDA V%+26:STA &B1:LDA V%+27:STA &B2:JSR tx:LDA V%+25:CLC:ADC #80:STA &B0:LDA V%+26:ADC #0:STA &B1:LDA V%+27:ADC #0:STA &B2:JSR tx
977 JSR fix:LDA #(DL%>>16):STA &D702:LDA #0:STA &D704:LDA #((DL%>>8) AND 255):STA &D701:LDA #(DL% AND 255):STA &D705
978 LDA #(SC%>>16):STA &C2:LDA #0:STA &C3:LDA #&F8:STA &C6:LDA #&0F:STA &C7:LDY #25
979 .f1 LDA PL%+2,Y:SEC:SBC #88:STA &C0:LDA PH%+2,Y:SBC #0:STA &C1:LDX RM%,Y:LDA V%+10,X:LDZ #0:STA [&C0],Z:LDA V%+7:LDZ #44:STA [&C0],Z
980 LDA CL%,Y:STA &C4:LDA CH%,Y:STA &C5:LDZ #209:CPY V%+31:BCC f2:LDA V%+8:STA [&C0],Z:LDA V%+28:AND PF%,Y:STA [&C4],Z:LDA V%+9:LDZ #35:INC &C1:STA [&C0],Z:LDA V%+29:AND PF%,Y:INC &C5:STA [&C4],Z:BRA f3
981 .f2 LDA #0:STA [&C0],Z:LDA #&FF:STA [&C4],Z:LDA #2:LDZ #35:INC &C1:STA [&C0],Z
982 .f3 LDZ #0:DEY:LBPL f1:INC V%:INC V%+1:INC V%+5:LDA V%+5:CMP #10:BNE r1:LDA #0:STA V%+5:LDA V%+4:CLC:ADC #3:CMP #&96:BNE r0:LDA #&84
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
1100 LDA V%+30:LBNE pd:LDA V%+6:CMP #4:LBEQ pd:LDX #27:LDA #0
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
1208 ]:RZ%=P%-RING%:P%=A3%
1210 [OPT I%
1212 .a3 LDA OV%+70:STA &B0:LDA OV%+71:STA &B1:LDA OV%+72:STA &B2:LDA OV%+73:STA &B3:LDA OV%:STA &BB:LDA OV%+1:STA &BC:ORA &BB:LBEQ a3e
1214 LDA #0:STA &B5:STA &B7:STA &B8:LDA V%+2:STA &B9:LDA V%+3:STA &BA
1216 .a3g LDA V%:CLC:ADC &B7:STA &BD:LDA V%+1:CLC:ADC &B8:STA &BE:LDA &B9:STA &BF:LDA &BA:STA &C0
1218 LDA &B5:CLC:ADC OV%+2:AND #3:ASL A:ASL A:STA &C1:LDX #16
1220 .a3k LDY &BD:LDA S1%,Y:LDY &BF:CLC:ADC S1%,Y:STA &C2:LDA #0:ROL A:STA &C3:LDA &C2:CLC:ADC #4:LDZ #0:STA [&B0],Z:LDA &C3:ADC #0:INZ:STA [&B0],Z
1222 LDY &BE:LDA S2%,Y:LDY &C0:CLC:ADC S2%,Y:CMP #23:BCC a3h:CMP #223:BCS a3h:CMP OV%+129:BCC a3w:CMP OV%+130:BCC a3h
1223 .a3w SEC:SBC #15:LDZ #2:STA [&B0],Z:LDA #0:SBC #0:AND #3:INZ:STA [&B0],Z:LDA #&FF:BRA a3v
1224 .a3h LDA #0
1226 .a3v LDZ #4:STA [&B0],Z:LDA &C1:LDZ #8:STA [&B0],Z:LDZ #0
1228 LDA &BD:CLC:ADC #16:STA &BD:LDA &BE:CLC:ADC #16:STA &BE:LDA &BF:CLC:ADC #16:STA &BF:LDA &C0:CLC:ADC #16:STA &C0
1230 LDA &B0:CLC:ADC #32:STA &B0:BCC a3n:INC &B1:BNE a3n:INC &B2
1232 .a3n LDA &BB:BNE a3d:DEC &BC
1234 .a3d DEC &BB:LDA &BB:ORA &BC:BEQ a3e:DEX:LBNE a3k
1236 LDA &B9:CLC:ADC #32:STA &B9:LDA &BA:CLC:ADC #32:STA &BA:INC &B5:LDA &B5:AND #7:BNE a3x:LDA &B7:CLC:ADC #37:STA &B7:LDA &B8:CLC:ADC #53:STA &B8
1238 .a3x JMP a3g
1240 .a3e LDA OV%+78:STA &B0:LDA OV%+79:STA &B1:LDA OV%+80:STA &B2:LDA OV%+81:STA &B3:LDA OV%+5:STA &C4:LDA OV%+6:STA &C5:LDX #8:LDY #0:JSR mv
1242 LDA OV%+74:STA &B0:LDA OV%+75:STA &B1:LDA OV%+76:STA &B2:LDA OV%+77:STA &B3:LDA OV%+3:STA &C4:LDA OV%+4:STA &C5:LDX #12:LDY #24:JSR mv:RTS
1244 .mv LDA OV%+8,Y:SEC:SBC &C4:STA OV%+8,Y:LDA OV%+9,Y:SBC &C5:STA OV%+9,Y:LDA OV%+10,Y:SBC #0:STA OV%+10,Y:BPL mv2
1246 LDA OV%+9,Y:CMP #&C0:BCS mv2:CLC:ADC #&C0:STA OV%+9,Y:LDA OV%+10,Y:ADC #1:STA OV%+10,Y
1248 .mv2 LDZ #0:LDA OV%+9,Y:STA [&B0],Z:INZ:LDA OV%+10,Y:AND #3:STA [&B0],Z:LDZ #0
1250 LDA &B0:CLC:ADC #32:STA &B0:BCC mv3:INC &B1:BNE mv3:INC &B2
1252 .mv3 INY:INY:INY:DEX:BNE mv:RTS
1254 .ai LDA OV%+70:STA &B0:LDA OV%+71:STA &B1:LDA OV%+72:STA &B2:LDA OV%+73:STA &B3:LDA #&E8:STA &BB:LDA #3:STA &BC
1256 .ai1 LDY #0:LDZ #0
1258 .ai2 LDA OV%+86,Y:STA [&B0],Z:INY:INZ:CPY #32:BNE ai2:LDZ #0:LDA &B0:CLC:ADC #32:STA &B0:BCC ai3:INC &B1:BNE ai3:INC &B2
1260 .ai3 LDA &BB:BNE ai4:DEC &BC
1262 .ai4 DEC &BB:LDA &BB:ORA &BC:BNE ai1:RTS
1263 .pu LDA OV%+120:STA &B0:LDA OV%+121:STA &B1:LDA OV%+122:STA &B2:LDA OV%+123:STA &B3:LDY #0:LDZ #0
1264 .pu1 LDA DB%,Y:CLC:ADC #&20:STA [&B0],Z:INZ:INZ:INY:CPY #40:BNE pu1:LDZ #0:RTS
1265 .fix LDX V%+31:BEQ fz:LDA #((DL%+1157) AND 255):STA &C0:LDA #(((DL%+1157)>>8) AND 255):STA &C1:LDA OV%+124:STA &B0:LDA OV%+125:STA &B1:LDA OV%+126:STA &B2
1266 .fx LDZ #0:LDA &B0:STA [&C0],Z:INZ:LDA &B1:STA [&C0],Z:INZ:LDA &B2:STA [&C0],Z:JSR nx:LDA &B0:CLC:ADC #80:STA &B0:BCC fy:INC &B1
1267 .fy DEX:BNE fx
1268 .fz RTS
1269 ]:NEXT:AI%=ai:PU%=pu:AZ%=P%-A3%:ENDPROC
1300 REM ---- the VIC-IV as SCROLLTEST sets it (V400, 26 rows of 104 tokens, CHR16 + FCLRHI), our palette
1310 DEF PROCvic:LOCAL I%:VS%=1
1320 RESTORE 1390:FOR I%=0 TO 20:READ VR%:?(PS%+768+I%)=?VR%:NEXT
1330 FOR I%=0 TO 255:?(PS%+I%)=?(&D100+I%):?(PS%+256+I%)=?(&D200+I%):?(PS%+512+I%)=?(&D300+I%):NEXT
1340 FOR I%=0 TO 255:?(&D100+I%)=?(TA%+I%):?(&D200+I%)=?(TA%+256+I%):?(&D300+I%)=?(TA%+512+I%):NEXT
1350 ?&D05D=?&D05D AND &7F:?&D031=(?&D031 OR 8) AND &5F:?&D051=&40:?&D05B=0:?&D054=(?&D054 AND &C0) OR 5:?&D058=LS% AND 255:?&D059=LS%>>8:?&D05E=104:?&D07B=&1A:IF KH% THEN ?&FFD71F0=?&FFD71F0 OR &90
1360 ?&D060=SC% AND 255:?&D061=(SC%>>8) AND 255:?&D062=SC%>>16:?&D063=0:?&D064=CO% AND 255:?&D065=CO%>>8
1370 ?&D016=0:?&D011=0:?&D04C=&30:?&D020=0:?&D021=0:W2%=0:PROCwf:ENDPROC:REM display off ($D011 DEN) until frame 12; the waterfall entries 25-28 set now
1390 DATA &D031,&D051,&D054,&D058,&D059,&D05B,&D05D,&D05E,&D060,&D061,&D062,&D063,&D064,&D065,&D07B,&D016,&D011,&D04C,&D020,&D021,&D070
1400 DEF PROCback:LOCAL I%:IF VS%=0 THEN ENDPROC
1405 IF KH% THEN ?&FFD71F0=?&FFD71F0 AND &27:PROCxctl2(0):?&FFD71FB=0:?&FFD728A=0:?&FFD728B=0
1410 RESTORE 1390:FOR I%=0 TO 20:READ VR%:?VR%=?(PS%+768+I%):NEXT
1420 FOR I%=0 TO 255:?(&D100+I%)=?(PS%+I%):?(&D200+I%)=?(PS%+256+I%):?(&D300+I%)=?(PS%+512+I%):NEXT
1430 MODE 0:ENDPROC
1490 DEF PROCtb(T%):?(V%+25)=T% AND 255:?(V%+26)=(T%>>8) AND 255:?(V%+27)=T%>>16:ENDPROC
1500 REM ---- act 3: "NOW WITH THE K325T VIC-IV": rings 64 -> 300 -> 1000 as list-mode objects (8x8 full-colour rings on SCROLLTEST's sine paths,
1502 REM written each frame by the routine A3%), 8 clouds behind and 12 bushes in front (objects too), 4-pixel painting; a HUD row; any other core: 64 rings (plain RRB)
1510 DEF PROCact3:LOCAL I%:REM the set-up (PROCprep: palette, HUD page, object table) ran at the start; here only the switch
1512 IF A2% THEN PROCctr(2)
1513 ?&D05E=145:AC%=4:AN%=3:AS%=F%:F3%=0:N3%=64:H3%=0:QH%=?&D7FA:WHILE P3%<=25:PROCprep:ENDWHILE
1514 PROCtb(HU% AND &FFFFF):?(V%+8)=0:?(V%+9)=2:?(V%+28)=&FF:REM the text sets show the HUD page (attic HU%): row 0 counters, captions
1519 ?(OV%+129)=96:?(OV%+130)=111:REM text is always in front: rings stay out of a caption's row while it shows (objects are painted after the row's text)
1520 IF K3%+XT%=0 THEN ENDPROC
1522 ?(V%+30)=1:IF K3%=0 THEN ENDPROC
1524 ?&FFD71F8=RT% AND 255:?&FFD71F9=(RT%>>8) AND 255:?&FFD71FA=(RT%>>16) AND 15:?&FFD71FB=NO% AND 255:?&FFD728A=NO% AND 255:?&FFD728B=NO%>>8
1526 ?&FFD71F0=?&FFD71F0 OR &D0:PROCxctl2(1):ENDPROC
1530 DEF PROCa3:F3%=F3%+1
1532 IF K3%+XT% THEN IF F3%>150 AND F3%<=268 OR F3%>700 AND N3%<1000 THEN N3%=N3%+2:?OV%=N3% AND 255:?(OV%+1)=N3%>>8
1534 IF F3%=150 THEN PROCput(11,""):PROCput(13,""):?(OV%+129)=255:?(OV%+130)=255
1536 IF K3% AND N3%=1000 AND H3%=0 THEN H3%=F3%:PROCput(12,"1000 RINGS. 10 LAYERS. STILL BASIC."):?(OV%+129)=104:?(OV%+130)=119
1538 IF F3% MOD 10=0 THEN ?(OV%+2)=(?(OV%+2)+1) AND 3
1540 S%=SP%*384:?(OV%+3)=S% AND 255:?(OV%+4)=S%>>8
1542 IF F3% MOD 25=0 THEN PROChud
1544 IF F3%>=1400+1000*(K3%+XT%=0) THEN EX%=1
1546 ENDPROC
1550 DEF PROChud:LOCAL E%,L%,M%,S$
1552 E%=(?&D7FA-QH%) AND 255:QH%=?&D7FA:IF E%=0 THEN E%=25
1554 S$="RINGS "+STR$(N3%)+" FPS "+STR$((1250+E% DIV 2) DIV E%):IF BN% THEN S$="RINGS "+STR$(N3%)
1556 IF K3% THEN L%=FNctr(25):PROCctr(3):S$=S$+" OBJECTS "+STR$(N3%+20)+" LINE "+STR$(L%)
1558 $DB%=LEFT$(S$+"                                        ",40):!(OV%+120)=HU%:CALL PU%:ENDPROC
1560 DEF PROCput(R%,S$):LOCAL A%:A%=HU%+80*R%:S$=STRING$((40-LEN(S$)) DIV 2," ")+S$:$DB%=LEFT$(S$+STRING$(40," "),40)
1562 !(OV%+120)=A%:CALL PU%:ENDPROC:REM (PU%: the 40 characters at DB% as text tokens to the HUD page)
1564 DEF FNctr(N%):LOCAL L%,M%:?&FFD71E0=N%:REPEAT L%=?&FFD71E1+256*?&FFD71E2:M%=?&FFD71E1+256*?&FFD71E2:UNTIL L%=M%:=L%
1566 DEF PROCctr(A%):LOCAL L%:IF KH%=0 THEN ENDPROC
1568 L%=FNctr(25):IF L%>LM%(A%) THEN LM%(A%)=L%
1569 LP%(A%)=LP%(A%)+FNctr(23):?&FFD71E3=0:ENDPROC:REM (counter 25: the longest painting in pixel cycles, 23: late pixels; then cleared)
1570 DEF PROCfill(A%,N%,B%,C%):PROCjob(JS%,3,N% DIV 2,B%,A% AND &FFFFF,2):?(JS%+3)=A%>>20:?(JS%+10)=3
1572 PROCjob(JS%+22,3,N% DIV 2,C%,(A%+1) AND &FFFFF,2):?(JS%+25)=A%>>20:?(JS%+32)=3:?(JS%+10)=7:PROCrun(JS%):ENDPROC
1574 DEF PROCrun(J%):?&D702=J% DIV 65536:?&D704=0:?&D701=(J% DIV 256) AND 255:?&D705=J% AND 255:ENDPROC
1580 REM objects: 0..7 clouds (64x16, rows 0..5), 8..1007 rings (8x8; X, Y, mask and token list from A3% each frame), 1008..1019 bushes (48x16, rows 22..25); PROCobjs(slice 3..25)
1582 DEF PROCobjs(Q%):LOCAL I%,A%,X%,Y%,S%,W%,O%,X3%:IF Q%>5 THEN PROCobj1(Q%-6):ENDPROC
1584 IF Q%=3 THEN FOR I%=0 TO 3:!(OL%+4*I%)=&FFFF0000+&17A0+I%:NEXT:A%=OL%+16:FOR I%=0 TO 1:FOR X%=0 TO 7:PROCw(A%+20*I%+2*X%,&17A4+8*I%+X%):NEXT:PROCw(A%+20*I%+16,&FFFF):NEXT
1586 IF Q%=3 THEN A%=OL%+56:FOR I%=0 TO 1:FOR X%=0 TO 5:PROCw(A%+16*I%+2*X%,&17B4+6*I%+X%):NEXT:PROCw(A%+16*I%+12,&FFFF):NEXT
1588 IF Q%=4 THEN FOR I%=0 TO 63 STEP 4:!(&FF80000+C3%+I%)=0:NEXT
1590 IF Q%=4 THEN FOR I%=0 TO 31:?(OV%+86+I%)=0:NEXT:?(OV%+86+5)=1:?(OV%+86+6)=&40+(OL%>>16)+&80*RB%:?(OV%+86+9)=(OL%>>8) AND 255:?(OV%+86+10)=C3% AND 255:?(OV%+86+11)=C3%>>8
1592 IF Q%=5 THEN CALL AI%:REM rings: the template written to 1000 entries
1593 ENDPROC
1594 DEF PROCobj1(I%):LOCAL A%,X%,Y%,S%,W%,O%,X3%:IF I%<8 THEN A%=RT%+32*I%:X%=56*I%+20*(I% MOD 3):Y%=10+(I%*13) MOD 26:S%=OL%+16:W%=20 ELSE A%=RT%+32*(1000+I%):X%=40*(I%-8):Y%=176+8*(I% MOD 3):S%=OL%+56:W%=16
1596 FOR X3%=0 TO 31 STEP 4:!(A%+X3%)=0:NEXT:PROCw(A%,X% AND &3FF):PROCw(A%+2,Y%):?(A%+4)=&FF:?(A%+5)=2:?(A%+6)=&40+(S%>>16):PROCw(A%+8,S% AND &FFFF):PROCw(A%+10,C3%):PROCw(A%+12,W%)
1598 O%=OV%+8+3*I%:?O%=0:PROCw(O%+1,X%):IF I%=19 THEN ?(OV%+5)=64:?(OV%+6)=0:?(OV%+3)=0:?(OV%+4)=0
1599 ENDPROC
1600 DEF PROCw(A%,V%):?A%=V% AND 255:?(A%+1)=(V%>>8) AND 255:ENDPROC
1700 REM ---- act 3's set-up in 26 steps, run at the start (line 160; step 0, the palette, after PROCvic): HUD page and captions, then (objects) the token lists, the template, the 1000 ring entries, the 20 clouds and bushes
1702 DEF PROCprep:LOCAL I%:IF P3%>25 THEN ENDPROC
1704 IF P3%=0 THEN ?&D1FA=&FF:?&D2FA=&FF:?&D3FA=&FF:?&D1FB=0:?&D2FB=0:?&D3FB=0:FOR I%=0 TO 31:?(&D1C0+I%)=?(OP%+I%):?(&D2C0+I%)=?(OP%+32+I%):?(&D3C0+I%)=?(OP%+64+I%):NEXT
1706 IF P3%=1 THEN PROCfill(HU%,26*80,&40,&17)
1708 IF P3%=2 THEN PROCput(11,"NOW WITH THE K325T VIC-IV"):IF K3%=0 THEN PROCput(13,"THIS CORE: 64 RINGS, PLAIN RRB")
1710 IF P3%>2 THEN IF K3%+XT% THEN PROCobjs(P3%)
1712 P3%=P3%+1:ENDPROC
1720 REM ---- warm-up: the code of the act changes and of act 3's first frames runs once now, with the display off, so its first compiles do not stall the picture later; then everything back
1722 DEF PROCwarm:LOCAL I%:IF NL%=0 THEN ENDPROC
1724 F%=0:SP%=4:P2%=0:TL%=0:TS%=0:H2%=0:PROCa1:PROClist:PROCscroll:TL%=0:TS%=0:PROCtext:?&D05E=104:?(V%+31)=0:?(V%+8)=2:?(V%+9)=2:?(V%+28)=&FF:?(V%+29)=&FF
1726 IF K3% THEN N3%=64:H3%=0:QH%=?&D7FA:F3%=199:PROCa3:F3%=0:N3%=64:?OV%=64:?(OV%+1)=0:?(OV%+2)=0:?(OV%+3)=0:?(OV%+4)=0
1728 FOR I%=1 TO 3:LM%(I%)=0:LP%(I%)=0:NEXT:ENDPROC
9000 DEF PROCxctl2(B%):REM XCTL2 bit 0 (4-pixel painting, with XCTL bits 4 and 7) from feature level 4
9010 IF ?&FFD71FD>=4 THEN ?&FFD71F1=(?&FFD71F1 AND &FE) OR B%
9020 ENDPROC
