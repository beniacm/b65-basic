1 rem core: k325t feature level 3 (step 6); elsewhere it says so and stops.
10 rem obj65 recipe 2: one list-mode object, moved by basic 65.
20 rem screen: v400, 50 rows of one 16-bit token at s: a transparent gotox
30 rem (no $ffff: a row that starts with it advances only 2 bytes).
40 rem glyph $1800 (8x8 full colour) at ga, its token list at oa ($1800,
50 rem $ffff), the table at tb (32 bytes an entry; the vic-iv reads 0..15).
100 k=0:if peek($d629)=98 then x=peek($ffd71f0):poke $ffd71f0,x or 1:k=(peek($ffd71f0) and 1)=1
110 if k then lv=peek($ffd71fd)
120 if k=0 or lv<3 then print "needs the k325t core, feature level 3":end
130 s=$80000:cr=$ff84000:ga=$60000:oa=$89000:oc=$7800:tb=$8c000:l=2
140 gosub 900
200 rem the glyph: a filled circle in colour 7 (index 0 is transparent)
210 for y=0 to 7:for x=0 to 7:v=0:if (2*x-7)*(2*x-7)+(2*y-7)*(2*y-7)<=60 then v=7
220 poke ga+8*y+x,v:next x,y
230 rem its token list ($ffff ends it) and the colour word of the token
240 wpoke oa,$1800,$ffff:wpoke cr-$4000+oc,0
250 rem entry 0: x, y; draw mask 255, height 1, address bits 19-16 (8),
260 rem collision group 0; token list (low 16 bits), colour offset; stride,
270 rem box width (0 = 8), collides-with; bytes 16..31: 0
280 for i=0 to 31:poke tb+i,0:next i
290 wpoke tb,100,100:poke tb+4,255,1,8,0:wpoke tb+8,$9000,oc
300 rem the table address and the count (8-bit and 10-bit), then list mode:
310 rem xctl bits 0 (1 mb), 3 (background), 4 (list mode), 6 (object table), 7 (fast tokens)
320 poke $ffd71f8,0,$c0,8,1:poke $ffd728a,1,0:poke $ffd71f0,peek($ffd71f0) or $d9
330 rem move it: x and y with one wpoke a frame
340 for f=0 to 299:vsync 251:wpoke tb,100+f*2,100+int(50*sin(f/20)):next f
350 gosub 950:print "recipe 2 done: 300 frames"
360 end
900 rem ---- screen: save, then v400, 50 rows of one gotox, chr16, fcm above 255
910 vj=peek($d05d):vh=peek($d020):vi=peek($d021):v1=peek($d031):v5=peek($d05b):v7=peek($d07b):v0=peek($d054):v8=peek($d058):v9=peek($d059):va=peek($d05e)
915 vb=peek($d060):vc=peek($d061):vd=peek($d062):ve=peek($d063):vf=peek($d064):vg=peek($d065)
920 for i=0 to 49:wpoke s+i*l,0:wpoke cr+i*l,$90:next i:rem gotox 0, transparent ($90)
925 poke $d05d,peek($d05d) and 127:poke $d031,peek($d031) or 8:poke $d07b,49:poke $d05b,0:poke $d054,peek($d054) or 5
930 wpoke $d058,l:poke $d05e,l/2:poke $d063,peek($d063) and 192:poke $d020,0:poke $d021,0
935 poke $d060,0,mod(int(s/256),256),int(s/65536):wpoke $d064,$4000:return
950 rem ---- back to text: list mode off (xctl bits 3, 4, 6, 7), the vic as it was
960 poke $ffd71f0,peek($ffd71f0) and $27
970 poke $d031,v1:poke $d05b,v5:poke $d07b,v7:poke $d054,v0:poke $d058,v8,v9:poke $d05e,va
980 poke $d060,vb,vc,vd,ve,vf,vg:poke $d020,vh:poke $d021,vi:poke $d05d,vj:scnclr:return
