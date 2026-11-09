5 REM Jumper: gravity, double jump and bounce with list mode v3 objects (step-6 core). The frame interrupt moves the player; BASIC only reads the stick
10 REM Object 0 is the player: OBJVEL 0,vx,vy,0,0.35 gives it gravity, the
20 REM limit set 0 (x 0..632, y down to 384) makes it bounce off the walls
30 REM and the floor with half the speed. Left/right: OBJVEL 0,vx (vy
40 REM kept); fire: OBJVEL 0,,-7 -- a second jump in mid-air is allowed
50 REM (the double jump), then only after landing. Objects 1..NP% are
60 REM platforms (static); the collision engine reports player/platform
70 REM boxes (groups: player 2 with 1, platforms 1 with 2) and PROChit puts
80 REM the player on top when it falls onto one and HITPIX finds their
85 REM pixels touching (without the K325T core: HITPIX against every
90 REM platform each frame). Joystick in port 2.
100 REM BN%>0: stop after BN% frames with scripted input (tests).
120 BN%=0:RS%=1:NP%=6
130 K%=(?&6E1=&FF):GA%=&60000:OA%=&89000:OC%=&7800:S%=&80000:CR%=&FF84000
135 IF K%=0 THEN GA%=&54000:S%=&50000:OA%=&56000:REM (Xemu: logic only)
140 V1%=?&D031:V5%=?&D05B:V7%=?&D07B:ON ERROR PROCtext:REPORT:PRINT " at line ";ERL:END
150 CLS:PRINT "Jumper":PROCscreen
160 OBJECT 0,300,100,OA%,OC%,0,1,255,2,1:OBJVEL 0,0,0,0,0.35
170 OBJLIMITS 0,0,-512,632,384,2+8+32:OBJBOUNDS 0,0
180 RESTORE 900:FOR I%=1 TO NP%:READ X%,Y%:OBJECT I%,X%,Y%,OA%+16,OC%+16,0,1,255,1,2:NEXT
190 IF K% THEN ON COLLISION PROChit
200 JC%=0:F%=0:T%=TIME
210 REPEAT
220 WAIT:EI:IF BN% THEN Z%=FNscript(F%) ELSE Z%=?&DC00 AND 31
230 IF (Z% AND 4)=0 THEN OBJVEL 0,-3 ELSE IF (Z% AND 8)=0 THEN OBJVEL 0,3 ELSE OBJVEL 0,0
240 IF (Z% AND 16)=0 THEN IF FR%=0 THEN FR%=1:IF JC%<2 THEN JC%=JC%+1:OBJVEL 0,,-7
250 IF Z% AND 16 THEN FR%=0
255 IF K%=0 THEN PROCsoft
260 IF OBJY(0)>=384 THEN JC%=0
270 DI:F%=F%+1:UNTIL F%=BN%
280 T%=TIME-T%:IF RS% THEN PROCtext:PRINT BN%;" frames in ";T%;" cs"
290 END
900 DATA 60,330, 200,280, 340,230, 480,180, 120,150, 400,110
1000 DEF PROChit:LOCAL Q%
1010 Q%=COLLIDE(0):IF Q%>0 THEN PROCland(Q%)
1020 ENDPROC
1030 DEF PROCland(Q%):IF OBJVY(0)<=0 THEN ENDPROC
1040 IF HITPIX(0,Q%)=0 THEN ENDPROC:REM the boxes overlap, the pixels do not (yet)
1050 OBJECT 0,OBJX(0),OBJY(Q%)-8,OA%,OC%,0,1,255,2,1:OBJVEL 0,0,0,0,0.35:OBJBOUNDS 0,0:JC%=0
1060 ENDPROC
1070 DEF PROCsoft:LOCAL Q%:FOR Q%=1 TO NP%:PROCland(Q%):NEXT:ENDPROC
1100 DEF FNscript(F%):REM test input: right, a jump, a double jump, left
1110 IF F%<20 THEN =31-8
1120 IF F%=20 OR F%=32 THEN =31-16
1130 IF F%<60 THEN =31
1140 =31-4
1200 DEF PROCscreen:LOCAL I%,A%,C%,D%,L%,ZB%
1210 REM glyphs GA%/64+n (8x8 full colour): 0 the player, 1 a platform
1220 RESTORE 1300:FOR C%=0 TO 1:READ I%:FOR A%=0 TO 63:READ D%:?(GA%+64*C%+A%)=I%*D%:NEXT:NEXT
1230 FOR C%=0 TO 1:PROCw(OA%+16*C%,GA% DIV 64+C%):PROCw(OA%+16*C%+2,&FFFF):PROCw(CR%-&4000+OC%+16*C%,0)
1240 NEXT
1250 GOTO 1400
1300 DATA 7,0,0,1,1,1,1,0,0,0,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,0,0,1,1,0,0,0,1,1,1,1,0,0,0,1,1,0,0,1,1,0
1310 DATA 5,1,1,1,1,1,1,1,1,1,0,1,0,1,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
1400 ZB%=TRUE:IF K% THEN ?&FFD71F0=?&FFD71F0 OR 8:ZB%=(?&FFD71F0 AND 8)=0
1410 L%=40-120*ZB%:FOR I%=0 TO 49*L%+L%-2 STEP 2:PROCw(S%+I%,32):PROCw(CR%+I%,256):NEXT
1420 ?&D05D=?&D05D AND 127:?&D031=?&D031 OR 8:?&D07B=49:?&D05B=0:?&D054=?&D054 OR 5
1430 PROCw(&D058,L%):?&D05E=L% DIV 2:?&D063=?&D063 AND 192:?&D020=0:?&D021=0
1440 ?&D060=0:?&D061=(S% DIV 256) AND 255:?&D062=S% DIV 65536:PROCw(&D064,&4000)
1450 IF K% THEN ?&FFD71F0=?&FFD71F0 OR &D0
1460 ENDPROC
1700 DEF PROCtext:IF K% THEN ON COLLISION OFF:?&FFD71F0=?&FFD71F0 AND &27
1710 ?&D031=V1%:?&D05B=V5%:?&D07B=V7%:MODE 0:ENDPROC
1720 DEF PROCw(A%,V%):?A%=V% AND 255:?(A%+1)=(V% DIV 256) AND 255:ENDPROC
