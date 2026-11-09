1 rem core: k325t feature level 3 (step 6) to see it; any mega65 core: runs (logic only). needs obj65 and obj65x on the disk.
5 rem jumper65: the basic 65 twin of examples/jumper.bas with the obj65 library: the frame interrupt moves the player (gravity, bounce with half the speed), basic reads the stick
10 rem obj65 (sys $1600..) is the motion of b65 in a bload library, obj65x (bank 5: sys
20 rem $2000..) the sine table, events and hitpix (docs/obj65.md). object 0 is the
30 rem player: cartesian with an acceleration (+24 = 89: 0.35 px per frame^2),
40 rem limit set 0 (x 0..632, y down to 384: bounce, half restitution). left/right
50 rem write vx (+18), fire vy = -7 (a second jump in the air is allowed). objects
60 rem 1..np are platforms. a landing needs hitpix after the box collision (k325t:
70 rem the engine's event, polled; else hitpix against every platform each frame:
80 rem sl=1); it stands while a platform pixel is under one of its own (hitpix one
90 rem pixel lower), else it falls. joystick in port 2.
100 rem bn>0: bn frames with scripted input and manual steps (tests).
120 bn=0:rs=1:np=6:sl=0
130 k=0:if peek($d629)=98 then x=peek($ffd71f0):poke $ffd71f0,x or 1:k=(peek($ffd71f0) and 1)=1
135 lv=0:if k then lv=peek($ffd71fd)
140 if k and lv<3 then print "needs feature level 3 (the step-6 core)":end
145 ga=$60000:oa=$89000:oc=$7800:s=$80000:cr=$ff84000:tb=$8c000:l=2
150 if k=0 then ga=$54000:oa=$56000:tb=$58000:sl=1:rem (no k325t: logic only)
155 if bn then sl=1:rem (tests: the same on every machine)
160 trap 2900:bload "obj65":bload "obj65x",p($52000):bank 5:sys $2000:bank 128
170 scnclr:print "jumper65":v0=peek($d054):gosub 1200:if k then gosub 1400
180 edma 3,32*(np+1),0,tb
190 x=300:y=100:if bn then x=347:y=200
195 ol=oa-int(oa/65536)*65536
200 a=tb:wpoke a,x,y:poke a+4,255,1,int(oa/65536),2:wpoke a+8,ol,oc:poke a+15,1
210 poke a+16,1,$6a:wpoke a+24,89
220 restore 900:for i=1 to np:read x,y:a=tb+32*i:wpoke a,x,y:poke a+4,255,1,int(oa/65536),1
230 wpoke a+8,ol+16,oc+16:poke a+15,2:next i
240 poke $1618,0,0,0,$fe,$78,2,$80,1,$2a:rem limit set 0: 0,-512 .. 632,384, bounce x/y, half
250 sys $1600,int(tb/65536),int(tb/256)-256*int(tb/65536),np+1,0
260 if bn=0 then sys $1609,1
270 jc=0:f=0:sp=0:fr=0:t=ti:lf=-1:ff=-1
300 if bn=0 or sl=0 then vsync 251:rem (the engine path: one step a frame, also in tests)
310 z=peek($dc00) and 31:if bn then gosub 1100
320 vx=0:if (z and 4)=0 then vx=-768
330 if (z and 8)=0 then vx=768
340 if vx<0 then vx=vx+65536
345 wpoke tb+18,vx
350 if (z and 16)=0 then if fr=0 then fr=1:if jc<2 then jc=jc+1:gosub 600
360 if z and 16 then fr=0
370 if sp then ha=0:hb=sp:hx=0:hy=1:gosub 800:if r=0 then gosub 650
380 if sp=0 then gosub 700
390 gosub 850:if y>=384 then jc=0
400 if bn then sys $1606
410 f=f+1:if f<>bn then 300
420 sys $1603:poke $d054,v0:if k then gosub 950
430 if rs then print bn;"frames in";ti-t;"seconds"
440 if bn then gosub 850:print "landed at frame";lf;", fell off at frame";ff;", now x";x;"y";y;"standing on";sp
450 end
600 rem ---- jump: vy = -7, gravity on
610 sys $1609,0:wpoke tb+20,65536-1792:wpoke tb+24,89:poke tb+17,$6a:if bn=0 then sys $1609,1
620 sp=0:return
650 rem ---- nothing under its pixels: it falls
660 sys $1609,0:wpoke tb+20,0:wpoke tb+24,89:poke tb+17,$6a:if bn=0 then sys $1609,1
670 sp=0:ff=f:return
700 rem ---- landing: the engine's partner (k325t) or every platform
710 if sl then for q=1 to np:ha=0:hb=q:hx=0:hy=0:gosub 800:if r=1 then gosub 750:if sp then q=np
720 if sl then next q:return
730 if (peek($ffd7280) and 1)=0 then return
740 poke $ffd7282,0,0:q=peek($ffd7284)+256*(peek($ffd7285) and 3):poke $ffd7280,1:if q<1 or q>np then return
750 rem ---- land on q: the topmost pixel contact over the last two frames' fall
755 vy=peek(tb+20)+256*peek(tb+21):if vy>32767 then vy=vy-65536
760 if vy<=0 then return
765 v=int(2*vy/256+2):ha=0:hb=q:hx=0:hy=-v:gosub 800:if r then return:rem side contact
770 d=v
775 d=d-1:if d>=0 then hy=-d:gosub 800:if r=0 then 775
780 if d<0 then return
785 gosub 850:y=y-d-1:sys $1609,0
790 wpoke tb+2,y-1024*int(y/1024):poke tb+31,0:wpoke tb+20,0,0:poke tb+17,$2a:if bn=0 then sys $1609,1
795 jc=0:sp=q:if lf<0 then lf=f
797 return
800 rem ---- hitpix(ha,hb,hx,hy) -> r (obj65x, bank 5)
805 if hx<0 then hx=hx+65536
810 if hy<0 then hy=hy+65536
815 wpoke $52009,ha,hb,hx,hy:bank 5:sys $2006:bank 128:rreg r:return
850 rem ---- x, y of the player
855 x=peek(tb)+256*(peek(tb+1) and 3):y=peek(tb+2)+256*(peek(tb+3) and 3):if y>511 then y=y-1024
860 return
900 data 60,330, 200,280, 340,230, 480,180, 120,150, 400,110
1100 rem ---- test input: nothing until frame 20, then right
1110 z=31:if f>=20 then z=31-8
1120 return
1200 rem ---- glyphs (the player, a platform; full colour above 255) and token lists
1210 restore 1300:for c=0 to 1:read i:for a=0 to 63:read d:poke ga+64*c+a,i*d:next a,c
1220 for c=0 to 1:wpoke oa+16*c,int(ga/64)+c,$ffff:wpoke cr-$4000+oc+16*c,0:next c
1230 poke $d054,peek($d054) or 4:return
1300 data 7,0,0,1,1,1,1,0,0,0,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,0,0,1,1,0,0,0,1,1,1,1,0,0,0,1,1,0,0,1,1,0
1310 data 5,1,1,1,1,1,1,1,1,1,0,1,0,1,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
1400 rem ---- screen: v400, 50 rows of one transparent gotox (the objects follow it), chr16, fcm above 255
1410 vj=peek($d05d):vh=peek($d020):vi=peek($d021):v1=peek($d031):v5=peek($d05b):v7=peek($d07b):v0=peek($d054):v8=peek($d058):v9=peek($d059):va=peek($d05e)
1415 vb=peek($d060):vc=peek($d061):vd=peek($d062):ve=peek($d063):vf=peek($d064):vg=peek($d065)
1420 for i=0 to 49:wpoke s+i*l,0:wpoke cr+i*l,$90:next i:rem gotox 0, transparent ($90)
1425 poke $d05d,peek($d05d) and 127:poke $d031,peek($d031) or 8:poke $d07b,49:poke $d05b,0:poke $d054,peek($d054) or 5
1430 wpoke $d058,l:poke $d05e,l/2:poke $d063,peek($d063) and 192:poke $d020,0:poke $d021,0
1435 poke $d060,0,mod(int(s/256),256),int(s/65536):wpoke $d064,$4000
1440 poke $ffd71f0,peek($ffd71f0) or $d9:return
950 rem ---- back to text
960 poke $ffd71f0,peek($ffd71f0) and $27
970 poke $d031,v1:poke $d05b,v5:poke $d07b,v7:poke $d054,v0:poke $d058,v8,v9:poke $d05e,va
980 poke $d060,vb,vc,vd,ve,vf,vg:poke $d020,vh:poke $d021,vi:poke $d05d,vj:scnclr:return
2900 sys $1603:poke $d054,v0:if k then gosub 950
2910 print err$(er);" in";el:end
