run pgm=network  
filei linki[1]=vo.h07.net
      linki[2]=vo.h08.net
      linki[3]=vo.h09.net
      linki[4]=vo.md5.net
      linki[5]=vo.h15.net
      linki[6]=vo.h16.net
      linki[7]=vo.h17.net
      linki[8]=vo.ev2.net
      linki[9]=vo.n11.net
fileo neto=?day_4byfy_wTks.net exclude=prevvol,prevvol,vc_1,cspd_1,vdt_1,vht_1,v_1,v1_1,v2_1,v3_1,v4_1,v5_1,v6_1,v7_1,vt_1,v1t_1,v2t_1,v3t_1,v4t_1,v5t_1,v6t_1,v7t_1
;set up

;link volumes
lanemi=distance*lanes
;
h07v = li.1.V1_1	+	li.1.V2_1	+	li.1.V3_1	+	li.1.V4_1	+	li.1.V5_1	+	li.1.V6_1	+	li.1.V7_1	+	li.1.V8_1	+	li.1.V9_1	+	li.1.V10_1	+	li.1.V11_1	+	li.1.V12_1	+	li.1.V13_1	+	li.1.V14_1	+	li.1.V15_1
h08v = li.2.V1_1	+	li.2.V2_1	+	li.2.V3_1	+	li.2.V4_1	+	li.2.V5_1	+	li.2.V6_1	+	li.2.V7_1	+	li.2.V8_1	+	li.2.V9_1	+	li.2.V10_1	+	li.2.V11_1	+	li.2.V12_1	+	li.2.V13_1	+	li.2.V14_1	+	li.2.V15_1
h09v = li.3.V1_1	+	li.3.V2_1	+	li.3.V3_1	+	li.3.V4_1	+	li.3.V5_1	+	li.3.V6_1	+	li.3.V7_1	+	li.3.V8_1	+	li.3.V9_1	+	li.3.V10_1	+	li.3.V11_1	+	li.3.V12_1	+	li.3.V13_1	+	li.3.V14_1	+	li.3.V15_1
md5v = li.4.V1_1	+	li.4.V2_1	+	li.4.V3_1	+	li.4.V4_1	+	li.4.V5_1	+	li.4.V6_1	+	li.4.V7_1	+	li.4.V8_1	+	li.4.V9_1	+	li.4.V10_1	+	li.4.V11_1	+	li.4.V12_1	+	li.4.V13_1	+	li.4.V14_1	+	li.4.V15_1
h15v = li.5.V1_1	+	li.5.V2_1	+	li.5.V3_1	+	li.5.V4_1	+	li.5.V5_1	+	li.5.V6_1	+	li.5.V7_1	+	li.5.V8_1	+	li.5.V9_1	+	li.5.V10_1	+	li.5.V11_1	+	li.5.V12_1	+	li.5.V13_1	+	li.5.V14_1	+	li.5.V15_1
h16v = li.6.V1_1	+	li.6.V2_1	+	li.6.V3_1	+	li.6.V4_1	+	li.6.V5_1	+	li.6.V6_1	+	li.6.V7_1	+	li.6.V8_1	+	li.6.V9_1	+	li.6.V10_1	+	li.6.V11_1	+	li.6.V12_1	+	li.6.V13_1	+	li.6.V14_1	+	li.6.V15_1
h17v = li.7.V1_1	+	li.7.V2_1	+	li.7.V3_1	+	li.7.V4_1	+	li.7.V5_1	+	li.7.V6_1	+	li.7.V7_1	+	li.7.V8_1	+	li.7.V9_1	+	li.7.V10_1	+	li.7.V11_1	+	li.7.V12_1	+	li.7.V13_1	+	li.7.V14_1	+	li.7.V15_1
ev2v = li.8.V1_1	+	li.8.V2_1	+	li.8.V3_1	+	li.8.V4_1	+	li.8.V5_1	+	li.8.V6_1	+	li.8.V7_1	+	li.8.V8_1	+	li.8.V9_1	+	li.8.V10_1	+	li.8.V11_1	+	li.8.V12_1	+	li.8.V13_1	+	li.8.V14_1	+	li.8.V15_1
n11v = li.9.V1_1	+	li.9.V2_1	+	li.9.V3_1	+	li.9.V4_1	+	li.9.V5_1	+	li.9.V6_1	+	li.9.V7_1	+	li.9.V8_1	+	li.9.V9_1	+	li.9.V10_1	+	li.9.V11_1	+	li.9.V12_1	+	li.9.V13_1	+	li.9.V14_1	+	li.9.V15_1

a3v=int(h07v+h08v+h09v)
mdv=int(md5v)
p3v=int(h15v+h16v+h17v)
evv=int(ev2v+n11v)
dyv=int(a3v+mdv+p3v+evv)
;link speeds

h07s = li.1.cspd_1
h08s = li.2.cspd_1
h09s = li.3.cspd_1
md5s = li.4.cspd_1
h15s = li.5.cspd_1
h16s = li.6.cspd_1
h17s = li.7.cspd_1
ev2s = li.8.cspd_1
n11s = li.9.cspd_1

; link v/c ratios
h07vc = li.1.vc_1
h08vc = li.2.vc_1
h09vc = li.3.vc_1
md5vc = li.4.vc_1
h15vc = li.5.vc_1
h16vc = li.6.vc_1
h17vc = li.7.vc_1
ev2vc = li.8.vc_1
n11vc = li.9.vc_1
;combine speeds & vc's
;
a3vc=0
if(a3v>0) ;3-hour am peak average vc is volume-weighted
   a3vc=(h07vc*h07v+h08vc*h08v+h09vc*h09v)/a3v
endif
p3vc=0
if(p3v>0)
   p3vc=(h15vc*h15v+h16vc*h16v+h17vc*h17v)/p3v
endif
evvc=0
if(evv>0)
   evvc=(ev2vc*ev2v+n11vc*n11v)/evv
endif
;
a3s=0
if(a3v>0)
   a3s=(h07s*h07v+h08s*h08v+h09s*h09v)/a3v
endif
p3s=0
if(p3v>0)
   p3s=(h15s*h15v+h16s*h16v+h17s*h17v)/p3v
endif
evs=0
if(evv>0)
   evs=(ev2s*ev2v+n11s*n11v)/evv
endif
;
; link vmt
h07vmt = h07v*distance
h08vmt = h08v*distance
h09vmt = h09v*distance
md5vmt = md5v*distance
h15vmt = h15v*distance
h16vmt = h16v*distance
h17vmt = h17v*distance
ev2vmt = ev2v*distance
n11vmt = n11v*distance

a3vmt=h07vmt+h08vmt+h09vmt
mdvmt=md5vmt
p3vmt=h15vmt+h16vmt+h17vmt
evvmt=ev2vmt+n11vmt
dayvmt=a3vmt+p3vmt+mdvmt+evvmt
;
; link vht
h07vht = h07v*(time_1/60)
h08vht = h08v*(time_1/60)
h09vht = h09v*(time_1/60)
md5vht = md5v*(time_1/60)
h15vht = h15v*(time_1/60)
h16vht = h16v*(time_1/60)
h17vht = h17v*(time_1/60)
ev2vht = ev2v*(time_1/60)
n11vht = n11v*(time_1/60)

a3vht=h07vht+h08vht+h09vht
mdvht=md5vht
p3vht=h15vht+h16vht+h17vht
evvht=ev2vht+n11vht
dayvht=a3vht+p3vht+mdvht+evvht
;
; link volume & vmt for high v/c > 1.0
h07cvmt=0
h08cvmt=0
h09cvmt=0
md5cvmt=0
h15cvmt=0
h16cvmt=0
h17cvmt=0
ev2cvmt=0
n11cvmt=0

a3cvmt=0
p3cvmt=0
mdcvmt=0
evcvmt=0
daycvmt=0

h07cv=0
h08cv=0
h09cv=0
md5cv=0
h15cv=0
h16cv=0
h17cv=0
ev2cv=0
n11cv=0

a3cv=0
p3cv=0
mdcv=0
evcv=0
daycv=0
if(h07vc>1.0)
   h07cvmt=h07vmt
   h07cv=h07v
endif
if(h08vc>1.0)
   h08cvmt=h08vmt
   h08cv=h08v
endif
if(h09vc>1.0)
   h09cvmt=h09vmt
   h09cv=h09v
endif
if(md5vc>1.0)
   md5cvmt=md5vmt
   md5cv=md5v
endif
if(h15vc>1.0)
   h15cvmt=h15vmt
   h15cv=h15v
endif
if(h16vc>1.0)
   h16cvmt=h16vmt
   h16cv=h16v
endif
if(h17vc>1.0)
   h17cvmt=h17vmt
   h17cv=h17v
endif
if(ev2vc>1.0)
   ev2cvmt=ev2vmt
   ev2cv=ev2v
endif
if(n11vc>1.0)
   n11cvmt=n11vmt
   n11cv=n11v
endif

a3cvmt=h07cvmt+h08cvmt+h09cvmt
mdcvmt=md5cvmt
p3cvmt=h15cvmt+h16cvmt+h17cvmt
evcvmt=ev2cvmt+n11cvmt

a3cv=h07cv+h08cv+h09cv
p3cv=h15cv+h16cv+h17cv
mdcv=md5cv
evcv=ev2cv+n11cv

daycvmt=a3cvmt+p3cvmt+mdcvmt+evcvmt
daycv=a3cv+p3cv+mdcv+evcv

;commercial vehicles (3+ axle)
_h07v_cv2 = li.1.V2_1 + li.1.V7_1 + li.1.V12_1
_h07v_cv3 = li.1.V3_1 + li.1.V8_1 + li.1.V13_1

_h08v_cv2 = li.2.V2_1 + li.2.V7_1 + li.2.V12_1
_h08v_cv3 = li.2.V3_1 + li.2.V8_1 + li.2.V13_1

_h09v_cv2 = li.3.V2_1 + li.3.V7_1 + li.3.V12_1
_h09v_cv3 = li.3.V3_1 + li.3.V8_1 + li.3.V13_1

_md5v_cv2 = li.4.V2_1 + li.4.V7_1 + li.4.V12_1
_md5v_cv3 = li.4.V3_1 + li.4.V8_1 + li.4.V13_1

_h15v_cv2 = li.5.V2_1 + li.5.V7_1 + li.5.V12_1
_h15v_cv3 = li.5.V3_1 + li.5.V8_1 + li.5.V13_1

_h16v_cv2 = li.6.V2_1 + li.6.V7_1 + li.6.V12_1
_h16v_cv3 = li.6.V3_1 + li.6.V8_1 + li.6.V13_1

_h17v_cv2 = li.7.V2_1 + li.7.V7_1 + li.7.V12_1
_h17v_cv3 = li.7.V3_1 + li.7.V8_1 + li.7.V13_1

_ev2v_cv2 = li.8.V2_1 + li.8.V7_1 + li.8.V12_1
_ev2v_cv3 = li.8.V3_1 + li.8.V8_1 + li.8.V13_1

_n11v_cv2 = li.9.V2_1 + li.9.V7_1 + li.9.V12_1
_n11v_cv3 = li.9.V3_1 + li.9.V8_1 + li.9.V13_1

a3v_cv2=_h07v_cv2+_h08v_cv2+_h09v_cv2
p3v_cv2=_h15v_cv2+_h16v_cv2+_h17v_cv2
mdv_cv2=_md5v_cv2
evv_cv2=_ev2v_cv2+_n11v_cv2
dav_cv2=a3v_cv2+p3v_cv2+mdv_cv2+evv_cv2

a3v_cv3=_h07v_cv3+_h08v_cv3+_h09v_cv3
p3v_cv3=_h15v_cv3+_h16v_cv3+_h17v_cv3
mdv_cv3=_md5v_cv3
evv_cv3=_ev2v_cv3+_n11v_cv3
dav_cv3=a3v_cv3+p3v_cv3+mdv_cv3+evv_cv3

merge record=false
endrun





