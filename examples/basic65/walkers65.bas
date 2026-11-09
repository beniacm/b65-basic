1 rem core: any mega65 core (gotox slots); k325t feature level 3 (step 6) for the object path. not on k325t levels 1-2. work in progress.
5 rem per frame: (measured below)
10 rem walkers: an original crowd demo for basic 65 (vic-iv, 256 colours)
20 rem twin of examples/walkers.bas (b65 basic): same picture, same motion.
30 rem little walkers drop from a hatch, walk, turn at walls, step up single
40 rem tiles, fall off ledges and leave through the door on the right. a script
50 rem gives three of them a job: one digs through the upper ledge, one blocks
60 rem the way back, one builds a stair over the hill. the level is an 80x25
70 rem chr16 map of full-colour tiles (v200) over a 200-line sky gradient;
75 rem digging and building change it. own 256-colour palette (0-15 kept).
80 rem walkers are shaded full-colour glyphs: list-mode v2 objects on a k325t
90 rem ($d629=$62; one glyph byte + one x/y write per update, hold around the
100 rem batch); elsewhere (xemu, standard mega65) the same glyphs as gotox
105 rem tokens in 8 slots at the end of each row.
110 rem bn>0: stop after bn frames (tests); rs=1: back to text, print timing
120 bn=0:rs=1:m=2
130 sc=$50000:ls=196:cb=$ff80800:ch=$54000:fg=$5e000:tl=$53800:n=8:k=(peek($d629)=98):sk=1
140 dim x(7),y(7),d(7),s(7),t(7),pr(7),jf(3),jt(3),jc(3),jr(3),jd(3),kc(9)
145 v0=peek($d054):v1=peek($d058):v2=peek($d059):v5=peek($d05e)
146 v6=peek($d060):v7=peek($d061):v8=peek($d062):v9=peek($d063):va=peek($d064):vb=peek($d065)
147 vc=peek($d068):vd=peek($d069):ve=peek($d06a):v4=peek($d05d):vf=peek($d021)
150 trap 1900
155 gosub 3630
160 print "building the level...":gosub 3500
170 cm=3:s=0:nb=25*ls:d=sc:gosub 3800:d=cb:gosub 3800:nb=2048:d=ch:gosub 3800:nb=40*64:d=fg:gosub 3800
180 restore 210
185 read g:if g>=0 then for y=0 to 7:read b:poke ch+8*g+y,b:next y
190 if g>=0 then 185
200 rem font for the counter (normal glyphs): a e k l o r s t u w / 0-9
210 data 65,24,36,66,126,66,66,66,0, 69,126,64,64,124,64,64,126,0
220 data 75,66,68,72,112,72,68,66,0, 76,64,64,64,64,64,64,126,0
230 data 79,60,66,66,66,66,66,60,0, 82,124,66,66,124,72,68,66,0
240 data 83,60,66,64,60,2,66,60,0, 84,126,24,24,24,24,24,24,0
250 data 85,66,66,66,66,66,66,60,0, 87,66,66,66,90,90,102,66,0
260 data 47,2,4,8,16,32,64,0,0, 48,60,70,74,82,98,66,60,0
270 data 49,24,56,24,24,24,24,126,0, 50,60,66,2,12,48,64,126,0
280 data 51,60,66,2,28,2,66,60,0, 52,12,20,36,68,126,4,4,0
290 data 53,126,64,124,2,2,66,60,0, 54,28,32,64,124,66,66,60,0
300 data 55,126,2,4,8,16,16,16,0, 56,60,66,66,60,66,66,60,0
310 data 57,60,66,66,62,2,4,56,0, -1
320 rem full-colour tiles $1780+n: 0-24 sky (one per row), 25 hatch, 26 door
330 rem post, 27 doorway, 28 lintel, 31 empty; solid from 32: 32 grass,
340 rem 33 earth, 34 brick, 35 step, 36 stone
350 gosub 3040
360 rem rows: 80 tiles (sky), 8 walker slots (gotox, glyph), gotox 632 and
370 rem the last tile again (a raster line ends where its last glyph is painted)
380 for r=0 to 24:a=sc+r*ls:c=cb+r*ls:cm=3
390 sk=2:nb=80:s=$80+r:d=a:gosub 3800:s=$17:d=a+1:gosub 3800:sk=4:nb=8:s=$9f:d=a+162:gosub 3800:s=$17:d=a+163:gosub 3800
400 s=$90:d=c+160:gosub 3800:sk=1:poke a+192,120,2,$80+r,$17:poke c+192,$10
410 next r
420 rem level: ledge a, ledge b with a stone pillar, floor with walls, a hill
430 rem too high to step up, the exit door; then the hatch and the counter
440 c1=4:r1=8:c2=38:r2=8:g=32:gosub 3000:r1=9:r2=9:g=33:gosub 3000
450 c1=30:r1=15:c2=64:r2=15:g=32:gosub 3000:r1=16:r2=16:g=33:gosub 3000:c1=52:r1=10:c2=53:r2=14:g=36:gosub 3000
460 c1=0:r1=23:c2=79:r2=23:g=32:gosub 3000:r1=24:r2=24:g=33:gosub 3000
470 c1=0:r1=17:c2=1:r2=22:g=34:gosub 3000:c1=78:c2=79:gosub 3000
480 c1=44:r1=19:c2=48:r2=19:g=32:gosub 3000:r1=20:r2=22:g=33:gosub 3000
490 c1=73:r1=20:c2=75:r2=20:g=28:gosub 3000:c2=73:r1=21:r2=22:g=26:gosub 3000:c1=75:c2=75:gosub 3000:c1=74:c2=74:g=27:gosub 3000
500 c1=9:r1=2:c2=11:r2=2:g=25:gosub 3000:c1=2:r1=0:a$="walkers":c=140:gosub 3020:c1=62:a$="out 0/8":gosub 3020
510 for r=0 to 24:a=sc+r*ls:poke a+194,peek(a+158):next r:rem the last tile again
520 gosub 3300
530 rem job script: from frame jf, the first walker at column jc / row jr
540 rem (direction jd, 0 = any) gets job jt: 3 dig, 5 block, 4 build
550 restore 560:for j=0 to 2:read jf(j),jt(j),jc(j),jr(j),jd(j):next j:jf(3)=1e6
560 data 150,3,20,7,0, 300,5,12,22,0, 450,4,39,22,1
570 rem vic-iv: hotreg off, chr16 + full colour above glyph 255, 196-byte rows
580 rem of 98 tokens, screen/colour/charset pointers, sky colour behind the text
590 poke $d05d,peek($d05d) and 127:poke $d054,peek($d054) or 5:poke $d058,196,0:poke $d05e,98
595 vg=peek($d031):poke $d031,vg and 223:rem attributes off (colour bytes above 15 are colours)
600 poke $d063,peek($d063) and 192:poke $d060,0,0,5:poke $d064,0,8
610 poke $d068,0,$40,5:poke $d020,0:poke $d021,16
620 if k then gosub 3700
630 rem main loop: a new walker every 75 frames, m walker updates per frame
640 for i=0 to 7:s(i)=0:pr(i)=-1:next i
650 f=0:o=0:ns=0:j=0:i=-1:br=-1:bx=0:bk=-1:w2=0:sp=1:t0=ti
660 f=f+1:sp=sp-1:if sp=0 then sp=75:if ns<n then gosub 2000
670 if k then poke $ffd71fc,1:rem hold: the vic-iv keeps its snapshot while we write
680 for q=1 to m:gosub 1000:next q:if k then poke $ffd71fc,0
690 vsync 251:if o>=n-1 then w2=w2+1:if w2>150 then 160
700 if f<>bn then 660
710 t0=ti-t0
720 if rs then gosub 3900:print bn;"frames in";t0;"seconds"
730 end
1000 rem update the next walker (round robin); v2 x/y are written and 1023 (10-bit)
1010 i=i+1:if i=n then i=0
1015 s=s(i):if s=0 or s=6 then return
1020 x=x(i):y=y(i):d=d(i):r=int(y/8):c=int((x+2)/4):a=sc+r*ls+2*c
1030 on s gosub 1100,1200,1300,1400,1500
1040 x(i)=x:y(i)=y:d(i)=d:s(i)=s:if s=6 then return
1050 if k then poke $5f880+4*i,$c0+fm:e=$5f800+16*i:wpoke e,(2*x) and 1023:wpoke e+2,y and 1023:return
1060 r=int(y/8):if r<>pr(i) then if pr(i)>=0 then poke sc+pr(i)*ls+162+4*i,$9f
1070 pr(i)=r:e=sc+r*ls+160+4*i:wpoke e,2*x:wpoke e+2,$17c0+fm:return
1100 rem walk: fall if nothing below; at a wall step up one tile or turn
1110 if peek(a+ls)<$a0 then s=2:fm=4:return
1120 e=x+d:g=int((e+int((d+1)*3/2))/4):w=sc+r*ls+2*g
1130 if peek(w)>=$a0 then 1170
1140 if r=br and abs(e-bx)<4 and i<>bk then d=-d:else x=e
1150 if r=22 and c>72 and c<76 then s=6:gosub 1600:return
1160 if f>=jf(j) and r=jr(j) and c=jc(j) and (jd(j)=0 or d=jd(j)) then gosub 1700:return
1165 fm=1-d+(int(x/2) and 1):return
1170 if peek(w-ls)<$a0 then y=y-8:x=4*g:else d=-d
1180 fm=1-d+(int(x/2) and 1):return
1200 rem fall: 8 pixels per update, land on a solid tile
1210 y=y+8:fm=4:if peek(a+2*ls)>=$a0 then s=1
1220 return
1300 rem dig: every 4th update clear the tile below (sky shows) and sink 8
1310 t=t(i)+1:t(i)=t:fm=5+(int(t/2) and 1):if t and 3 then return
1320 if peek(a+ls)<$a0 or r>=21 then s=2:fm=4:return
1330 poke a+ls,$81+r:y=y+8:return
1400 rem build: every 8th update a step next to the walker, then up onto it
1410 t=t(i)+1:t(i)=t:fm=7:if t and 7 then return
1420 if t>32 then s=1:return
1430 w=a+2*d:if peek(w)>=$a0 or peek(w-ls)>=$a0 then s=1:return
1440 poke w,$a3:x=x+4*d:y=y-8:return
1500 fm=8:return
1600 rem out of the door: hide, count
1610 o=o+1:poke sc+2*66,48+o
1620 if k then poke $5f804+16*i,0:else poke sc+pr(i)*ls+162+4*i,$9f
1630 return
1700 rem give this walker the scripted job (snapped to its tile)
1710 s=jt(j):t(i)=0:x=4*c:if s=5 then bx=x:br=r:bk=i
1720 fm=4+s:if s=4 then fm=7
1725 if s=5 then fm=8
1730 j=j+1:return
1900 gosub 3900:print err$(er);" in";el:end
2000 rem a new walker drops from the hatch
2010 s(ns)=2:x(ns)=40:y(ns)=24:d(ns)=1:t(ns)=0:pr(ns)=-1
2020 if k then poke $5f804+16*ns,255
2030 ns=ns+1:return
3000 for rr=r1 to r2:for cc=c1 to c2:poke sc+rr*ls+2*cc,$80+g:next cc,rr:return
3020 for ii=1 to len(a$):aa=r1*ls+2*(c1+ii-1):poke sc+aa,asc(mid$(a$,ii,1)),0:poke cb+aa+1,c:next ii:return
3040 rem sky: one tile per row, a 32-step gradient over the 200 lines
3050 cm=3:nb=8:sk=1:for n=0 to 24:for y=0 to 7:s=16+int((n*8+y)*31/199):d=fg+64*n+8*y:gosub 3800:next y,n:n=8
3060 for nn=25 to 36:if nn<29 or nn>31 then for y=0 to 7:for x=0 to 7:gosub 3080:poke fg+64*nn+8*y+x,v:next x,y
3070 next nn:return
3080 if nn=25 then v=180-2*int(y/2):if x=1 or x=6 then v=v-3
3085 if nn=25 then return
3090 if nn=26 then v=131:if x<2 then v=135
3095 if nn=26 then if x>5 then v=129
3100 if nn=26 then return
3110 if nn=27 then v=143-y:if x=0 or x=7 then v=146
3115 if nn=27 then return
3120 if nn=28 then v=140+mod(x+y,2):if y>5 then v=134
3125 if nn=28 then return
3130 if nn=32 and y<3 then v=94-3*y+mod(x*3+y,3):return
3140 if nn=32 or nn=33 then v=53+mod(x*5+y*7,5):if mod(x*7+y*3,11)=0 then v=49
3145 if nn=32 or nn=33 then return
3150 if nn=34 then v=72+mod(x+y,3):if y=0 or y=4 then v=76
3155 if nn=34 then if y=3 or y=7 or (y<3 and x=7) or (y>4 and x=3) then v=147
3160 if nn=34 then return
3170 if nn=35 then v=137+(x and 1):if y=0 then v=142
3175 if nn=35 then if y=7 then v=146
3180 if nn=35 then return
3190 v=73:if x<2 then v=78
3200 if x>5 then v=68
3210 if y=0 or y=7 then v=147
3220 return
3300 rem walker frames (8x8, full colour): walk right 0-1, left 2-3 (mirrored),
3310 rem fall 4, dig 5-6, build 7, block 8; letters = palette entries below
3330 restore 3340:k$=".hHsSbBlyw":for ii=0 to 9:read kc(ii):next ii
3340 data 0,94,84,166,158,198,188,146,141,134
3350 for ff=0 to 8:if ff=2 or ff=3 then 3390
3360 for y=0 to 7:read a$:for x=0 to 7:p=kc(instr(k$,mid$(a$,x+1,1))-1)
3370 poke $5f000+64*ff+8*y+x,p:if ff<2 then poke $5f000+64*(ff+2)+8*y+7-x,p
3380 next x,y
3390 next ff:return
3400 data "..hhH...", ".hsSs...", "..sS....", ".bbBl...", "s.bB.s..", "..bB....", "..l.l...", ".ll..l.."
3410 data "..hhH...", ".hsSs...", "..sS....", "..bBb...", "..bBs...", "..bB....", "..lH....", "..ll...."
3420 data "s.hhH.s.", "s.sSs.s.", ".bsSb...", "..bBb...", "..bB....", "..bB....", ".l..l...", ".l..l..."
3430 data "........", "..hhH...", ".hsSs...", ".bbBb...", "s.bBb.yy", "..bB..y.", ".l.l..y.", "l...l.y."
3440 data "........", "........", "..hhH...", ".hsSsy..", ".bbBby..", "s.bB.y..", ".l.l.y..", "l...lyy."
3450 data "..hhH...", ".hsSs...", "..sS....", ".bbBl...", "..bBsww.", "..bB.ww.", "..l.l...", ".ll.ll.."
3460 data "..hhH...", ".hsSs...", "s.sS.s..", "sbbBbbs.", "..bB....", "..bB....", ".l..l...", "ll..ll.."
3500 rem own palette: ramps from 16 on (0-15 stay the standard colours)
3515 restore 3560
3520 read ps:if ps<0 then return
3530 read pc,r0,g0,b0,r1,g1,b1:for ii=0 to pc-1:qi=ps+ii
3540 qr=r0+int((r1-r0)*ii/(pc-1)):qg=g0+int((g1-g0)*ii/(pc-1)):qb=b0+int((b1-b0)*ii/(pc-1)):gosub 3610:next ii
3550 goto 3520
3560 data 16,32,18,16,60,250,190,130, 48,16,35,20,10,215,165,105, 64,16,25,25,35,215,215,225
3570 data 80,16,8,40,12,140,230,90, 96,16,10,45,45,170,235,130, 112,16,5,20,70,130,210,255
3580 data 128,16,80,25,0,255,245,160, 144,8,0,0,0,50,40,60, 152,16,70,35,25,255,215,180
3590 data 168,16,40,45,55,235,240,250, 184,16,10,20,90,120,170,255, 200,16,60,0,5,255,130,110
3600 data 216,16,50,0,60,255,160,255, 232,24,0,0,0,255,255,255, -1
3610 rem the vic-iv stores palette bytes nibble-swapped
3620 poke $d100+qi,mod(qr,16)*16+int(qr/16):poke $d200+qi,mod(qg,16)*16+int(qg/16):poke $d300+qi,mod(qb,16)*16+int(qb/16):return
3630 for ii=16 to 255:poke $5f400+ii,peek($d100+ii):poke $5f500+ii,peek($d200+ii):poke $5f600+ii,peek($d300+ii):next ii:return
3650 for ii=16 to 255:poke $d100+ii,peek($5f400+ii):poke $d200+ii,peek($5f500+ii):poke $d300+ii,peek($5f600+ii):next ii:return
3700 rem full-colour walker glyphs $17c0+frame at $5f000; one token list per walker
3720 for ii=0 to 7:poke $5f880+4*ii,$c0,$17,255,255
3730 ee=$5f800+16*ii:poke ee,0,0,0,0,0,1,$45,0:wpoke ee+8,$f880+4*ii:wpoke ee+10,$3c00+4*ii:poke ee+12,0,0,0,0
3750 poke $ff83c00+4*ii,0,0:next ii
3760 poke $ffd71f8,0,$f8,5,8:poke $ffd71f0,peek($ffd71f0) or $d0:xb=1:gosub 9000:return
3800 rem dma job at tl: options mb, skip sk, $0b; cmd cm, count nb, source s, target d
3810 s2=s-int(s/1048576)*1048576:d2=d-int(d/1048576)*1048576
3820 poke tl,$80,int(s/1048576),$81,int(d/1048576),$85,sk,$0b,0,cm,mod(nb,256),int(nb/256)
3830 poke tl+11,mod(s2,256),mod(int(s2/256),256),int(s2/65536),mod(d2,256),mod(int(d2/256),256),int(d2/65536),0,0,0
3840 poke $d701,$38,5,0,0,0:return
3900 if k then xb=0:gosub 9000:poke $ffd71f0,peek($ffd71f0) and $2f
3910 gosub 3650:poke $d054,v0:poke $d058,v1,v2:poke $d05e,v5:poke $d060,v6,v7,v8,v9,va,vb
3920 poke $d068,vc,vd,ve:poke $d021,vf:poke $d031,vg:poke $d05d,v4:scnclr:return
9000 rem xctl2 bit 0 (4-pixel painting, with xctl bits 4 and 7) from feature level 4: xb = 1 / 0
9010 if peek($ffd71fd)>=4 then poke $ffd71f1,(peek($ffd71f1) and 254) or xb
9020 return
