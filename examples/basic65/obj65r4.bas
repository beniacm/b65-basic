1 rem core: k325t feature level 3 (step 6); elsewhere it says so and stops.
10 rem obj65 recipe 4: the collision engine, polled once a frame. groups:
20 rem the player (object 0) is group 1 and collides with group 2 (+7 = 1,
30 rem +15 = 2); the bullets are group 2 with group 1, so they never
40 rem collide with each other. results of the last pass, page $ffd7280:
50 rem status bit 0 (write 1 to clear), index $ffd7282-3, first partner
60 rem $ffd7284-5 ($3ff: none), count $ffd7286-7, a bit per object at
70 rem $ffd7200 (object n: byte n/8, bit n and 7). object 300 shows the
80 rem 10-bit index (entries 4..299 stay empty: draw mask 0).
100 k=0:if peek($d629)=98 then x=peek($ffd71f0):poke $ffd71f0,x or 1:k=(peek($ffd71f0) and 1)=1
110 if k then lv=peek($ffd71fd)
120 if k=0 or lv<3 then print "needs the k325t core, feature level 3":end
130 s=$80000:cr=$ff84000:ga=$60000:oa=$89000:oc=$7800:tb=$8c000:l=80
140 gosub 900
200 rem the glyph: a filled circle in colour 7 (index 0 is transparent)
210 for y=0 to 7:for x=0 to 7:v=0:if (2*x-7)*(2*x-7)+(2*y-7)*(2*y-7)<=60 then v=7
220 poke ga+8*y+x,v:next x,y
240 wpoke oa,$1800,$ffff:wpoke cr-$4000+oc,0
250 n=301:edma 3,32*n,0,tb
260 for i=0 to 3:o=i:if i=3 then o=300
270 a=tb+32*o:wpoke a,100+60*i,200:poke a+4,255,1,8,2:wpoke a+8,$9000,oc:poke a+15,1:next i
280 poke tb+7,1:poke tb+15,2:wpoke tb,40,200
290 poke $ffd71f8,0,$c0,8,mod(n,256):poke $ffd728a,mod(n,256),int(n/256):poke $ffd71f0,peek($ffd71f0) or $d9
300 poke $ffd7280,1:hf=-1
310 for f=0 to 299:vsync 251:wpoke tb,40+f,200
320 if (peek($ffd7280) and 1)=0 then 360
330 if hf<0 then hf=f:c=peek($ffd7286)+256*peek($ffd7287):o=0:gosub 800:p0=p:o=300:gosub 800:p3=p
340 poke $ffd7280,1
360 next f
370 gosub 950:print "first contact at frame";hf;",";c;"objects collided"
380 print "partner of 0:";p0;", of 300:";p3;"(1023: none)"
390 print "bit of object 300:";(peek($ffd7200+37) and 16)/16
400 end
800 poke $ffd7282,mod(o,256),int(o/256):p=peek($ffd7284)+256*(peek($ffd7285) and 3):return
900 rem ---- screen: save, then v400, 50 rows, chr16, fcm above 255, rows
910 vj=peek($d05d):vh=peek($d020):vi=peek($d021):v1=peek($d031):v5=peek($d05b):v7=peek($d07b):v0=peek($d054):v8=peek($d058):v9=peek($d059):va=peek($d05e)
915 vb=peek($d060):vc=peek($d061):vd=peek($d062):ve=peek($d063):vf=peek($d064):vg=peek($d065)
920 for i=0 to 49:wpoke s+i*l,$ffff:next i
925 poke $d05d,peek($d05d) and 127:poke $d031,peek($d031) or 8:poke $d07b,49:poke $d05b,0:poke $d054,peek($d054) or 5
930 wpoke $d058,l:poke $d05e,l/2:poke $d063,peek($d063) and 192:poke $d020,0:poke $d021,0
935 poke $d060,0,mod(int(s/256),256),int(s/65536):wpoke $d064,$4000:return
950 rem ---- back to text: list mode off (xctl bits 3, 4, 6, 7), the vic as it was
960 poke $ffd71f0,peek($ffd71f0) and $27
970 poke $d031,v1:poke $d05b,v5:poke $d07b,v7:poke $d054,v0:poke $d058,v8,v9:poke $d05e,va
980 poke $d060,vb,vc,vd,ve,vf,vg:poke $d020,vh:poke $d021,vi:poke $d05d,vj:scnclr:return
