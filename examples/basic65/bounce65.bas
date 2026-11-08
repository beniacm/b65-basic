5 rem per frame (32 balls): 42 ms in xemu with the vsync wait, so 24 fps (move, walls, table about 1.2 ms a ball; the four star planes: 8 wpokes and one 8-job dma, about 1.5 ms). rrb per row: 6 x 4 x (gotox + star) = 48 tokens (no xctl bit 3: + gotox + 80 black)
10 rem bounce: n balls that bounce off the walls and off each other (basic 65),
12 rem in front of four parallax star planes (1/4, 1/2, 1, 2 pixels a frame)
20 rem twin of examples/bounce.bas (b65 basic), 32 balls instead of 64.
30 rem k325t core ($d629=$62): the balls are rrb list mode v2 objects (shaded
40 rem full-colour glyphs from an own 256-colour palette, 640x400) and the
50 rem core's collision engine compares all of them once per frame; this
60 rem program polls it: status $ffd71c0 bit 0, table $ffd71a0 (a bit per
70 rem object), partner of object i: poke $ffd71c1,i : peek($ffd71c2), then
80 rem poke $ffd71c0,1 clears it. the engine tests boxes, inclusive edges
85 rem (here 6x8: table +14 = 6 for an 8-pixel ball), so it fires a little
86 rem early at the diagonals: every pair is confirmed with the centre
87 rem distance (dx*dx+dy*dy <= 64, two radius-4 balls) before the two
90 rem velocities are swapped and both balls moved one step apart. basic 65's
95 rem and is 16-bit, so x, y, dx, dy are separate arrays here (b65 packs
96 rem x+65536*y into one integer).
100 rem elsewhere (xemu, standard mega65): the first 8 balls are sprites, the
105 rem pairs are found in basic only with sw=1 (tests; slow with many balls).
110 rem bn>0: stop after bn frames (tests); rs=1: back to text, timing;
115 rem g=1: gravity.
120 bn=0:rs=1:n=32:g=0:sw=0:bw=6
130 tb=$8c000:ga=$60000:oa=$89000:oc=$7800:s=$80000:cr=$ff84000:zl=$90000:zh=$a8000:zs=$bc000:sg=6:k=(peek($d629)=98)
135 if k=0 then s=$50000:ga=$58000:zl=$8400000:zh=$8420000:zs=$54000:rem (no chip ram at $60000-$fffff: attic)
136 rem k325t: xctl bit 0 (1 mb chip ram) before any access above $5ffff; basic 65
137 rem does not set it (without it writes there are dropped)
138 if k then poke $ffd71f0,peek($ffd71f0) or 1
140 dim x(n),y(n),dx(n),dy(n),zd(3),za(3)
150 trap 2900
155 v1=peek($d031):v5=peek($d05b):v7=peek($d07b):v0=peek($d054):v8=peek($d058):v9=peek($d059):va=peek($d05e)
156 vb=peek($d060):vc=peek($d061):vd=peek($d062):ve=peek($d063):vf=peek($d064):vg=peek($d065):vh=peek($d021)
160 gosub 2840:scnclr:print "bounce:";n;"balls":gosub 2700:gosub 1200
170 rem start on a grid (no overlaps), random velocities -3..3 (not 0)
180 r=rnd(-42):for i=0 to n-1:x(i)=12+mod(i,16)*39:y(i)=20+int(i/16)*90
190 dx(i)=int(rnd(1)*6)-3:if dx(i)>=0 then dx(i)=dx(i)+1
195 dy(i)=int(rnd(1)*6)-3:if dy(i)>=0 then dy(i)=dy(i)+1
197 next i
200 gosub 1400:if k=0 then gosub 1600
210 rem main loop: wait for the frame, resolve the pairs of the last pass,
220 rem move every ball (walls: 1135), write x/y (v2 x/y and 1023). no hold:
225 rem the loop takes about two frames, and the vic-iv copies the table only
226 rem at a frame start with hold = 0 (a held batch would never be copied); a
227 rem wpoke writes x and y at once, a ball torn for one frame is harmless
230 f=0:np=0:t=ti
250 vsync 251:x=mod(q0-int(f/4),632):wpoke j0,x+zb:wpoke j1,x+hb:x=mod(q1-int(f/2),632):wpoke j2,x+zb:wpoke j3,x+hb
252 x=mod(q2-f,632):wpoke j4,x+zb:wpoke j5,x+hb:x=mod(q3-2*f,632):wpoke j6,x+zb:wpoke j7,x+hb
254 poke $d702,int(dl/65536):poke $d704,0:poke $d701,mod(int(dl/256),256):poke $d705,mod(dl,256):if sw then gosub 1140
255 if k then if peek($ffd71c0) and 1 then gosub 1010:poke $ffd71c0,1
260 if g then if (f and 3)=0 then for i=0 to n-1:dy(i)=dy(i)+1:next i
280 for i=0 to n-1:x=x(i)+dx(i):y=y(i)+dy(i):if x<0 or x>632 or y<0 or y>392 then gosub 1135
300 x(i)=x:y(i)=y:if k then wpoke tb+16*i,x and 1023,y and 1023
310 next i
320 if k=0 then gosub 1660
330 f=f+1:if f<>bn then 250
340 t=ti-t:if rs then gosub 1700:print bn;"frames in";t;"seconds,";np;"pairs"
350 end
1000 rem ---- pairs ----
1010 for b=0 to int((n-1)/8):m=peek($ffd71a0+b):if m then gosub 1030
1020 next b:return
1030 for j=0 to 7:if (m and 2^j)=0 then 1045
1035 i=b*8+j:poke $ffd71c1,i:q=peek($ffd71c2):if q<>255 and q>i then a=i:c=q:gosub 1060
1045 next j:return
1060 u=x(c)-x(a):v=y(c)-y(a):if u*u+v*v>64 then return
1070 np=np+1:u=dx(a):dx(a)=dx(c):dx(c)=u:u=dy(a):dy(a)=dy(c):dy(c)=u
1080 h=a:gosub 1100:h=c:gosub 1100:return
1100 xx=x(h)+dx(h):yy=y(h)+dy(h):if xx>=0 and xx<=632 and yy>=0 and yy<=392 then x(h)=xx:y(h)=yy
1110 return
1135 if x<0 or x>632 then dx(i)=-dx(i):x=x(i)+dx(i)
1136 if y<0 or y>392 then dy(i)=-dy(i):y=y(i)+dy(i)
1137 return
1140 for a=0 to n-2:for c=a+1 to n-1:if abs(x(c)-x(a))<8 and abs(y(c)-y(a))<8 then aa=a:cc=c:gosub 1150:a=aa:c=cc
1145 next c,a:return
1150 gosub 1060:return
1200 rem ---- set-up: six shaded balls (8x8 full colour, lit from the top
1210 rem left) at ga = glyphs $1800-$1805: palette ramps (first entry, length)
1240 restore 1300:for c=0 to 5:read r,m:for y=0 to 7:for x=0 to 7:v=0
1250 if (2*x-7)*(2*x-7)+(2*y-7)*(2*y-7)<=60 then d=(2*x-4)*(2*x-4)+(2*y-4)*(2*y-4):v=r+m-1-int(d*(m-1)/110):if v<r then v=r
1260 poke ga+64*c+8*y+x,v:next x,y,c:return
1300 data 97,11, 184,16, 152,16, 128,16, 168,16, 64,16
1400 rem k325t: token lists (one per ball colour) and their colour words;
1410 rem object table: x/y, mask, height, bits 19-16, collision group 1, list,
1420 rem colour offset, stride, box width bw
1430 if k=0 then 1470
1440 for c=0 to 5:wpoke oa+16*c,$1800+c,$ffff:wpoke cr-$4000+oc+16*c,0:next c
1450 for i=0 to n-1:a=tb+16*i:c=mod(i,6):wpoke a,x(i),y(i):poke a+4,255,1,8,1
1460 wpoke a+8,$9000+16*c,oc+16*c:poke a+12,0,0,bw,0:next i
1465 rem xctl bit 3 (newer k325t bitstreams): unpainted pixels show the
1466 rem background, so sparse rows need no opaque base (bf=0)
1468 bf=-1:if k then poke $ffd71f0,peek($ffd71f0) or 8:bf=(peek($ffd71f0) and 8)=0
1470 gosub 1800
1500 rem vic-iv (hotreg off): v400, 50 rows, one line per glyph row, chr16 +
1510 rem full colour above 255, rows of l/2 tokens, pointers; list mode v2 with
1515 rem the fast token path (xctl bit 7)
1520 poke $d05d,peek($d05d) and 127:poke $d031,peek($d031) or 8:poke $d07b,49:poke $d05b,0:poke $d054,peek($d054) or 5
1530 wpoke $d058,l:poke $d05e,l/2:poke $d063,peek($d063) and 192:poke $d020,0:poke $d021,0
1540 poke $d060,0,mod(int(s/256),256),int(s/65536):wpoke $d064,$4000
1550 if k then poke $ffd71f8,0,$c0,8,n:poke $ffd71f0,peek($ffd71f0) or $d1
1560 return
1600 rem no list mode: balls 0-7 as sprites (8x8 circle, scaled to 320x200)
1620 for y=0 to 20:poke $5fc00+3*y,0,0,0:next y
1630 restore 1650:for y=0 to 7:read v:poke $5fc00+3*y,v:next y
1640 poke $d06c,0,$fa,$85:for i=0 to 7:wpoke $5fa00+2*i,$17f0:poke $d027+i,2+i:next i:poke $d015,255:return
1650 data 60,126,255,255,255,255,126,60
1800 rem ---- background: four parallax star planes (sparse rrb), as in
1802 rem examples/bounce.bas: each row (l bytes) = sg groups of 4 x (gotox,
1803 rem star glyph ga/64+6+plane). without xctl bit 3 (bf) the vic-iv keeps
1804 rem old pixels in its raster buffer where a row paints nothing: then each
1805 rem row starts with gotox 0 (opaque) + 80 black full-colour glyphs. in the
1806 rem star parts (16*sg bytes a row: in the rows, or with the base in a
1807 rem staging area zs) plane p's gotox words are every 16 bytes: per frame one
1808 rem dma job per plane and byte (x lo, x hi) rewrites them, copying with
1810 rem source step zd(p) from ramp tables zl/zh (lo/hi byte of n mod 632;
1811 rem k325t: chip ram, else attic); with the base 50 row jobs then copy the
1812 rem star parts into the rows. star k of plane p is at x = (za(p) - offset +
1813 rem k*zd(p)) mod 632. offsets f/4, f/2, f, 2*f. star gotox colour $90.
1820 zn=50*sg:dl=$5c000:zt=$5ca00:sk=1:dk=1:c=0:zb=zl-int(zl/65536)*65536:hb=zh-int(zh/65536)*65536
1821 so=-162*bf:l=so+16*sg:zw=s:if bf then zw=zs
1824 for i=0 to 631:poke zl+i,mod(i,256):poke zh+i,int(i/256):next i
1826 i=632
1827 nn=i:sr=zl:de=zl+i:gosub 1880:sr=zh:de=zh+i:gosub 1880:i=i*2:if i<72000 then 1827
1828 c=3:sr=0:nn=50*l:de=s:gosub 1880:de=cr:gosub 1880:if bf=0 then 1830
1829 i=ga/64+10:nn=80:dk=2:sr=mod(i,256):de=s+2:gosub 1880:sr=int(i/256):de=s+3:gosub 1880:c=0:dk=1:nn=162:sr=s:for i=1 to 49:de=s+i*l:gosub 1880:next i
1830 c=3:dk=4:nn=4*sg:sr=$90:for i=0 to 49:if bf then poke cr+i*l,$10
1831 de=cr+i*l+so:gosub 1880:next i:dk=16:nn=zn
1832 for q=0 to 3:i=ga/64+6+q:sr=mod(i,256):de=zw+4*q+2:gosub 1880:sr=int(i/256):de=zw+4*q+3:gosub 1880:next q
1834 restore 1850:for i=0 to 319:poke ga+384+i,0:next i
1836 for q=0 to 3:read zd(q),za(q),j:for i=1 to j:read a,d:poke ga+64*(6+q)+a,d:next i,q
1838 for j=0 to 7:q=int(j/2):a=dl+22*j:poke a,$80,int(zl/2^20),$81,0,$83,zd(q),$85,16
1840 c=-4*((j<7) or bf):nn=zn:sr=zl:if j and 1 then sr=zh
1841 de=zw+4*q+(j and 1):ja=a+8:gosub 1890:next j:if bf=0 then 1845
1843 for j=0 to 49:a=dl+176+22*j:poke a,$80,0,$81,0,$83,1,$85,1:c=-4*(j<49):nn=16*sg
1844 sr=zs+16*sg*j:de=s+l*j+162:ja=a+8:gosub 1890:next j
1845 j0=dl+13:j1=j0+22:j2=j1+22:j3=j2+22:j4=j3+22:j5=j4+22:j6=j5+22:j7=j6+22
1846 q0=za(0)+632*2^21:q1=za(1)+632*2^21:q2=za(2)+632*2^21:q3=za(3)+632*2^21:return
1848 rem per plane: source step, start, pixels (offset in the glyph, colour)
1850 data 251,0,1, 27,170
1852 data 145,301,1, 27,175
1854 data 171,612,4, 27,179,28,179,35,179,36,179
1856 data 147,845,10, 19,178,20,178,26,178,27,183,28,183,29,178,34,178,35,183,36,183,37,178
1880 rem dma job c: nn bytes from sr (fill: value) to de, steps sk/dk
1882 poke zt,$80,int(sr/2^20),$81,int(de/2^20),$83,sk,$85,dk:ja=zt+8:gosub 1890
1884 poke $d702,int(zt/65536):poke $d704,0:poke $d701,mod(int(zt/256),256):poke $d705,mod(zt,256):return
1890 v=sr-int(sr/2^20)*2^20:w=de-int(de/2^20)*2^20
1892 poke ja,$0b,0,c,mod(nn,256),int(nn/256),mod(v,256),mod(int(v/256),256),int(v/65536)
1894 poke ja+8,mod(w,256),mod(int(w/256),256),int(w/65536),0,0,0:return
1660 poke $d010,0:for i=0 to 7:xx=24+int(x(i)/2):poke $d000+2*i,xx and 255,50+int(y(i)/2)
1670 if xx>255 then poke $d010,peek($d010) or 2^i
1680 next i:return
1700 poke $d015,0:if k then poke $ffd71c0,1:poke $ffd71f0,peek($ffd71f0) and $26
1710 poke $d031,v1:poke $d05b,v5:poke $d07b,v7:poke $d054,v0:poke $d058,v8,v9:poke $d05e,va
1720 poke $d060,vb,vc,vd,ve,vf,vg:poke $d021,vh:gosub 2860:scnclr:return
2700 rem own palette: ramps from 16 on (0-15 stay the standard colours)
2710 restore 2760
2720 read ps:if ps<0 then return
2730 read pc,r0,g0,b0,r1,g1,b1:dd=pc-1:if dd<1 then dd=1
2740 for ii=0 to pc-1:qi=ps+ii:qr=r0+int((r1-r0)*ii/dd):qg=g0+int((g1-g0)*ii/dd):qb=b0+int((b1-b0)*ii/dd):gosub 2820:next ii
2750 goto 2720
2760 data 16,32,14,18,70,255,190,140, 48,16,40,22,10,190,140,80, 64,16,30,35,60,175,185,215
2770 data 80,16,5,35,10,110,200,70, 97,11,90,0,0,255,140,120, 108,2,60,40,20,120,90,50
2780 data 110,2,110,60,20,170,110,50, 113,8,50,55,70,235,240,250, 121,4,200,150,0,255,230,90
2790 data 125,1,90,170,255,90,170,255, 126,2,30,30,40,220,30,30, 128,16,90,30,0,255,240,150
2800 data 144,8,0,0,0,40,35,55, 152,16,20,60,15,200,235,110, 168,16,130,150,190,255,255,255
2810 data 184,16,20,25,70,140,170,240, 200,16,45,25,10,190,130,70, 216,40,0,0,0,255,255,255, -1
2820 rem the vic-iv stores palette bytes nibble-swapped
2830 poke $d100+qi,mod(qr,16)*16+int(qr/16):poke $d200+qi,mod(qg,16)*16+int(qg/16):poke $d300+qi,mod(qb,16)*16+int(qb/16):return
2840 for ii=16 to 255:poke $5f400+ii,peek($d100+ii):poke $5f500+ii,peek($d200+ii):poke $5f600+ii,peek($d300+ii):next ii:return
2860 for ii=16 to 255:poke $d100+ii,peek($5f400+ii):poke $d200+ii,peek($5f500+ii):poke $d300+ii,peek($5f600+ii):next ii:return
2900 gosub 1700:print err$(er);" in";el:end
