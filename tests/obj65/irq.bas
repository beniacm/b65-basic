5 rem obj65 in basic 65 (xemu, tests/obj65check.py --irq): the frame interrupt, event, remove
10 bload "obj65":bload "obj65x",p($52000):bank 5:sys $2000:bank 128
20 edma 3,64,0,$58000
30 wpoke $58000,100,50:poke $58004,255,1:poke $58010,4:wpoke $58012,256,0
35 poke $58024,255,1:poke $58030,1,$10:wpoke $5803a,3
40 sys $1600,5,$80,2,0:t0=ti
50 sys $1609,1:t=peek($d7fa):x0=peek($58000)+256*(peek($58001) and 3)
60 do:loop until ((peek($d7fa)-t) and 255)>=50
70 sys $1609,0:f=(peek($d7fa)-t) and 255:x=peek($58000)+256*(peek($58001) and 3)
80 print "moved";x-x0;"in";f;"frames, ti";ti-t0
90 bank 5:sys $2003,0,1,0:bank 128:rreg a,x,y
100 print "event of 1:";a:bank 5:sys $2003,0,1,0:bank 128:rreg a:print "again:";a
110 bank 5:sys $2003,0,255,255:bank 128:rreg a,x,y:print "first:";a;x+256*y
120 sys $1603:print "removed, irq";peek($0314)+256*peek($0315)
