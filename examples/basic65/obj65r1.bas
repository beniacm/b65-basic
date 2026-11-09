1 rem core: any mega65 core (reports what the core has)
10 rem obj65 recipe 1: which core? the k325t ($d629 = $62, xctl bit 0
20 rem reads back), its feature level and the object registers.
30 rem k325t: xctl bit 0 (1 mb chip ram) must be set before basic 65
40 rem touches chip ram above $5ffff; this recipe leaves it set.
100 k=0:if peek($d629)=98 then x=peek($ffd71f0):poke $ffd71f0,x or 1:k=(peek($ffd71f0) and 1)=1
110 if k=0 then print "no k325t core: no list-mode objects (model";peek($d629);")":end
120 lv=peek($ffd71fd):print "k325t core, feature level";lv
130 if lv<3 then print "the 32-byte object table needs feature level 3 (the step-6 core)":end
140 print "xctl $ffd71f0 =";peek($ffd71f0)
150 print "table $ffd71f8-fa =";peek($ffd71f8)+256*peek($ffd71f9)+65536*peek($ffd71fa)
160 print "count $ffd728a-b =";peek($ffd728a)+256*peek($ffd728b);", hold $ffd71fc =";peek($ffd71fc)
170 print "collision status $ffd7280 =";peek($ffd7280)
