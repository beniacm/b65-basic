5 REM Per frame (255 objects), Xemu, no vsync wait: 4.7 ms, 5.7 with the drifting player (P%()+V%() 1.6, AND mask 1.4, three respawns, mouse, one 4-job DMA into the table): 50 fps
10 REM Swarm: 254 bullets and a player (B65, K325T list mode v2 objects).
20 REM Three spawners circle the screen: a spiral, a stream aimed at the
30 REM player and a rotating sprinkler; three bullets are (re)spawned per
40 REM frame, round robin, so a bullet lives 85 frames. Motion without a
50 REM BASIC loop: P%()=P%()+V0%() / V1%() (two velocity arrays for half-pixel
60 REM steps), Q%()=P%() AND &3FF03FF (10-bit X/Y: a bullet that leaves the
70 REM 640x400 screen goes into the invisible part of the 1024-pixel space and
80 REM is reused before it could come back), then 4 chained DMA jobs copy
90 REM byte b of every Q%(i) to byte b of object i (source step 4, step 32).
100 REM Player = object 0, moved with the mouse or a joystick in port 2; with
102 REM no input for 2 s (and always with BN%>0) it drifts on a slow path.
104 REM Collision groups (+7) and collides-with masks (+15): bullets 1/2, player
106 REM 2/1 when the core honours +15 (?&FFD71FD >= 2), else player group 3
108 REM (shares bit 0 with the bullets: bullet-bullet pairs exist too, but
109 REM PROChit only asks COLLIDE(0)); ON COLLISION PROChit counts hits and flashes the
112 REM player. Without the K325T the program runs, but nothing is shown.
115 REM BN%>0: stop after BN% frames (tests); RS%=1: back to text, timing.
120 BN%=0:RS%=1:N%=255:K%=(?&6E1=&FF):BG%=1:PG%=2:BW%=2:PW%=1
125 IF K% THEN IF ?&FFD71FD<2 THEN PG%=3:BW%=0:PW%=0:REM (no collides-with byte yet)
130 TB%=&8C000:GA%=&60000:OA%=&89000:OC%=&7800:S%=&80000:CR%=&FF84000:DL%=&5F800
135 IF K%=0 THEN TB%=&56000:GA%=&58000:S%=&50000:REM (Xemu: logic only)
140 DIM P%(N%-1),V0%(N%-1),V1%(N%-1),Q%(N%-1),T0%(191),T1%(191),C%(63)
150 V1%=?&D031:V5%=?&D05B:V7%=?&D07B:ON ERROR PROCtext:REPORT:PRINT " at line ";ERL:END
160 CLS:PRINT "Swarm: ";N%-1;" bullets":PROCtables:PROCscreen
170 IF K% THEN ON COLLISION PROChit
180 REM all bullets start invisible (X 700), standing still
190 P%()=700+65536*100:Q%()=P%() AND &3FF03FF:J%=1:HI%=0:HT%=0:A%=0:B%=0:C%=0:D%=0:MX%=-1:MY%=-1:ID%=0
200 MOUSE TO 160,150
230 F%=0:T%=TIME
240 REPEAT
250 WAIT:?&D702=DL% DIV 65536:?&D704=0:?&D701=(DL% DIV 256) AND 255:?&D705=DL% AND 255:EI
260 MOUSE X%,Y%,Z%:Z%=?&DC00 AND 15:IF Z%<15 THEN X%=X%-3*((Z% AND 8)=0)+3*((Z% AND 4)=0):Y%=Y%-3*((Z% AND 2)=0)+3*((Z% AND 1)=0):MOUSE TO X%,Y%
265 IF X%=MX% AND Y%=MY% THEN ID%=ID%+1 ELSE ID%=0:MX%=X%:MY%=Y%
267 IF ID%>100 OR BN% THEN X%=160+120*SIN(F%/70):Y%=100+70*SIN(F%/45)
270 P%(0)=(2*X% AND 1023)+65536*(2*Y% AND 1023):IF HT% THEN HT%=HT%-1:IF HT%=0 THEN !(TB%+8)=&9000+48+(OC%+48)*65536
280 IF F% AND 1 THEN P%()=P%()+V1%() ELSE P%()=P%()+V0%()
290 A%=(A%+5) AND 63:I%=C%((F%>>2) AND 63)-&40004:P%(J%)=I%:V0%(J%)=T0%(A%):V1%(J%)=T1%(A%):!(TB%+32*J%+8)=&9000+(OC%)*65536:J%=J%+1:IF J%=N% THEN J%=1
300 IF (F% AND 7)=0 THEN I%=C%(((F%>>2)+21) AND 63):U%=(P%(0) AND &FFFF)-(I% AND &FFFF):W%=(P%(0)>>>16)-(I%>>>16):B%=64+INT(ATN(W%/(U%-(U%=0)*.5))*10.19+(U%<0)*-32.5) AND 63
310 I%=C%(((F%>>2)+21) AND 63)-&40004:P%(J%)=I%:V0%(J%)=T0%(64+B%):V1%(J%)=T1%(64+B%):!(TB%+32*J%+8)=&9010+(OC%+16)*65536:J%=J%+1:IF J%=N% THEN J%=1
320 C%=(C%+11) AND 63:I%=C%(((F%>>2)+42) AND 63)-&40004:P%(J%)=I%:V0%(J%)=T0%(C%+128):V1%(J%)=T1%(C%+128):!(TB%+32*J%+8)=&9020+(OC%+32)*65536:J%=J%+1:IF J%=N% THEN J%=1
330 Q%()=P%() AND &3FF03FF:DI:IF (F% AND 15)=0 THEN PROCstat
340 F%=F%+1:UNTIL F%=BN%
350 T%=TIME-T%:IF RS% THEN PROCtext:PRINT BN%;" frames in ";T%;" cs, ";HI%;" hits"
360 END
1000 REM ---- collision: player (object 0) and its first partner ----
1010 DEF PROChit
1020 Q=COLLIDE(0):IF Q>0 THEN HI%=HI%+1:HT%=10:!(TB%+8)=&9040+(OC%+64)*65536
1030 ENDPROC
1100 DEF PROCstat:LOCAL I%,S$
1110 S$="HITS "+STR$HI%+"  TIME "+STR$((TIME-T%) DIV 100)+"   "
1120 FOR I%=1 TO LEN(S$):?(S%+2*I%-2)=ASC(MID$(S$,I%,1)):NEXT:ENDPROC
1200 REM ---- set-up ----
1210 DEF PROCtables:LOCAL I%,D%,R,X%,Y%,A,X0%,Y0%
1220 REM T0%/T1%(64*speed+direction): packed velocity of frame 0/1 (sum =
1230 REM 2 frames of motion, rounded); speeds 3, 4 and 2.5 pixels a frame
1240 FOR I%=0 TO 2:R=2*(3+(I%=1)*-1-(I%=2)*-.5):FOR D%=0 TO 63:A=D%*PI/32
1250 X%=INT(R*COS(A)+.5):Y%=INT(R*SIN(A)+.5):X0%=X%>>1:Y0%=Y%>>1
1260 T0%(64*I%+D%)=X0%+65536*Y0%:T1%(64*I%+D%)=X%-X0%+65536*(Y%-Y0%):NEXT:NEXT
1270 REM spawner path: a slow ellipse around the centre (packed positions)
1280 FOR D%=0 TO 63:A=D%*PI/32:C%(D%)=320+INT(220*COS(A))+65536*(200+INT(130*SIN(2*A))):NEXT:ENDPROC
1300 DEF PROCscreen:LOCAL I%,A%,C%,D%,ZB%
1310 REM glyphs GA%/64+n (8x8 full colour): 0-2 bullets (yellow, cyan, green
1320 REM dots), 3 player (white diamond), 4 player hit (red)
1330 RESTORE 1400:FOR C%=0 TO 4:READ I%:FOR A%=0 TO 63:READ D%:?(GA%+64*C%+A%)=I%*D%:NEXT:NEXT
1340 REM token lists (glyph, $FFFF) and their colour words
1350 IF K% THEN FOR C%=0 TO 4:PROCw(OA%+16*C%,GA% DIV 64+C%):PROCw(OA%+16*C%+2,&FFFF):PROCw(CR%-&4000+OC%+16*C%,0):NEXT
1360 REM objects: X/Y, mask, 1 row, bits 19-16 of the token list, group, list,
1370 REM colour offset, stride, box width 6, collides-with mask
1380 IF K% THEN FOR I%=0 TO N%-1:A%=TB%+32*I%:!A%=Q%(0):?(A%+4)=255:?(A%+5)=0:?(A%+6)=8:?(A%+7)=BG%:!(A%+8)=&9000+OC%*65536:!(A%+12)=6*65536+BW%*&1000000:NEXT
1390 IF K% THEN !(TB%+8)=&9030+(OC%+48)*65536:?(TB%+7)=PG%:?(TB%+15)=PW%
1395 GOTO 1500
1400 DATA 7,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,1,1,1,1,1,1,0,0,1,1,1,1,1,1,0,0,1,1,1,1,1,1,0,0,1,1,1,1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0
1410 DATA 3,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1,1,1,1,0,0,0,1,1,1,1,1,1,0,0,1,1,1,1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0
1420 DATA 5,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1,1,1,1,0,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,0,1,1,1,1,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0
1430 DATA 1,0,0,0,1,1,0,0,0,0,0,1,1,1,1,0,0,0,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,1,1,0,0,0
1440 DATA 2,0,0,0,1,1,0,0,0,0,0,1,1,1,1,0,0,0,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,1,1,0,0,0
1500 REM rows: 20 tokens (the score text) if XCTL bit 3 clears unpainted
1510 REM pixels, else 80 (an opaque row); V400, 50 rows, CHR16, FCM > 255
1520 ZB%=TRUE:IF K% THEN ?&FFD71F0=?&FFD71F0 OR 8:ZB%=(?&FFD71F0 AND 8)=0
1530 L%=40-120*ZB%:FOR I%=0 TO 49*L%+L%-2 STEP 2:PROCw(S%+I%,32):PROCw(CR%+I%,256):NEXT
1540 ?&D05D=?&D05D AND 127:?&D031=?&D031 OR 8:?&D07B=49:?&D05B=0:?&D054=?&D054 OR 5
1550 PROCw(&D058,L%):?&D05E=L% DIV 2:?&D063=?&D063 AND 192:?&D020=0:?&D021=0
1560 ?&D060=0:?&D061=(S% DIV 256) AND 255:?&D062=S% DIV 65536:PROCw(&D064,&4000)
1570 IF K% THEN ?&FFD71F8=TB% AND 255:?&FFD71F9=(TB% DIV 256) AND 255:?&FFD71FA=TB% DIV 65536:?&FFD71FB=N%:?&FFD71F0=?&FFD71F0 OR &D0
1580 REM DMA list: byte b of Q%(i) -> byte b of object i, b = 0..3
1590 FOR I%=0 TO 3:A%=DL%+22*I%:?A%=&80:?(A%+1)=^Q%(0) DIV &100000:?(A%+2)=&81:?(A%+3)=TB% DIV &100000:?(A%+4)=&83:?(A%+5)=4:?(A%+6)=&85:?(A%+7)=32
1600 PROCjob(A%+8,4*(I%<3)*-1,N%,^Q%(0)+I%,TB%+I%):NEXT:ENDPROC
1700 DEF PROCtext:IF K% THEN ON COLLISION OFF:?&FFD71F0=?&FFD71F0 AND &27
1710 ?&D031=V1%:?&D05B=V5%:?&D07B=V7%:MODE 0:ENDPROC
1720 DEF PROCw(A%,V%):?A%=V% AND 255:?(A%+1)=(V% DIV 256) AND 255:ENDPROC
1730 DEF PROCjob(J%,C%,N%,S%,D%)
1740 ?J%=&0B:?(J%+1)=0:?(J%+2)=C%:?(J%+3)=N% AND 255:?(J%+4)=N% DIV 256
1750 !(J%+5)=S% AND &FFFFF:!(J%+8)=D% AND &FFFFF:?(J%+12)=0:?(J%+13)=0:ENDPROC
