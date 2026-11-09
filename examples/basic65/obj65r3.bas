1 rem core: k325t feature level 3 (step 6); elsewhere it says so and stops.
10 rem obj65 recipe 3: n objects bouncing, written as one batch a frame
20 rem with hold ($ffd71fc = 1: the vic-iv keeps its last snapshot of the
30 rem table, so the batch appears at once). hold must be 0 at a frame start
40 rem for the next snapshot: release it, then wait for the frame (vsync).
50 rem the table is cleared with one dma fill (edma 3, length, value, address).
100 k=0:if peek($d629)=98 then x=peek($ffd71f0):poke $ffd71f0,x or 1:k=(peek($ffd71f0) and 1)=1
110 if k then lv=peek($ffd71fd)
120 if k=0 or lv<3 then print "needs the k325t core, feature level 3":end
130 s=$80000:cr=$ff84000:ga=$60000:oa=$89000:oc=$7800:tb=$8c000:l=2
140 gosub 900
200 rem the glyph: a filled circle in colour 7 (index 0 is transparent)
210 for y=0 to 7:for x=0 to 7:v=0:if (2*x-7)*(2*x-7)+(2*y-7)*(2*y-7)<=60 then v=7
220 poke ga+8*y+x,v:next x,y
240 wpoke oa,$1800,$ffff:wpoke cr-$4000+oc,0
250 n=32:dim x(n),y(n),dx(n),dy(n)
260 edma 3,32*n,0,tb
270 for i=0 to n-1:a=tb+32*i:x(i)=20+mod(i,8)*70:y(i)=40+int(i/8)*80:dx(i)=1+mod(i,3):dy(i)=1+mod(i,2)
280 wpoke a,x(i),y(i):poke a+4,255,1,8,0:wpoke a+8,$9000,oc:next i
290 poke $ffd71f8,0,$c0,8,n:poke $ffd728a,n,0:poke $ffd71f0,peek($ffd71f0) or $d9:xb=1:gosub 9000
300 for f=0 to 199
310 for i=0 to n-1:x=x(i)+dx(i):y=y(i)+dy(i)
320 if x<0 or x>632 then dx(i)=-dx(i):x=x(i)
330 if y<0 or y>392 then dy(i)=-dy(i):y=y(i)
340 x(i)=x:y(i)=y:next i
350 poke $ffd71fc,1:for i=0 to n-1:wpoke tb+32*i,x(i),y(i):next i:poke $ffd71fc,0
360 vsync 251:next f
370 gosub 950:print "recipe 3 done: 200 frames,";n;"objects"
380 end
900 rem ---- screen: save, then v400, 50 rows of one gotox, chr16, fcm above 255
910 vj=peek($d05d):vh=peek($d020):vi=peek($d021):v1=peek($d031):v5=peek($d05b):v7=peek($d07b):v0=peek($d054):v8=peek($d058):v9=peek($d059):va=peek($d05e)
915 vb=peek($d060):vc=peek($d061):vd=peek($d062):ve=peek($d063):vf=peek($d064):vg=peek($d065)
920 for i=0 to 49:wpoke s+i*l,0:wpoke cr+i*l,$90:next i:rem gotox 0, transparent ($90)
925 poke $d05d,peek($d05d) and 127:poke $d031,peek($d031) or 8:poke $d07b,49:poke $d05b,0:poke $d054,peek($d054) or 5
930 wpoke $d058,l:poke $d05e,l/2:poke $d063,peek($d063) and 192:poke $d020,0:poke $d021,0
935 poke $d060,0,mod(int(s/256),256),int(s/65536):wpoke $d064,$4000:return
950 rem ---- back to text: list mode off (xctl bits 3, 4, 6, 7), the vic as it was
960 xb=0:gosub 9000:poke $ffd71f0,peek($ffd71f0) and $27
970 poke $d031,v1:poke $d05b,v5:poke $d07b,v7:poke $d054,v0:poke $d058,v8,v9:poke $d05e,va
980 poke $d060,vb,vc,vd,ve,vf,vg:poke $d020,vh:poke $d021,vi:poke $d05d,vj:scnclr:return
9000 rem xctl2 bit 0 (4-pixel painting, with xctl bits 4 and 7) from feature level 4: xb = 1 / 0
9010 if peek($ffd71fd)>=4 then poke $ffd71f1,(peek($ffd71f1) and 254) or xb
9020 return
