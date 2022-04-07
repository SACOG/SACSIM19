/*
--------------------------------
 Name:sacsim19 DayNet vmt - Tolling - wRevenue v3.s
 Purpose: Summarize period network files to single daily network.
          Summarize tolling volumes, vehicle types, and revenue at tollid level. 
		  Add CVMT 2 category (<=1 n >0.9) as cvmt91
           
 Author: Kyle Shipley
 Last Updated: 01/06/2020
 Updated by: KS
 Copyright:   (c) SACOG
 Voyager Version:   6.1.7
--------------------------------
*/

run pgm=network  MSG='create daily network'
filei linki[1]=?_base.net
      linki[2]=vo.h07.net
      linki[3]=vo.h08.net
      linki[4]=vo.h09.net
      linki[5]=vo.md5.net
      linki[6]=vo.h15.net
      linki[7]=vo.h16.net
      linki[8]=vo.h17.net
      linki[9]=vo.ev2.net
      linki[10]=vo.n11.net
fileo neto=?day_ghg_wRev.net exclude=bike,tollda,tolls2,tolls3,tollcv,prevvol,prevvol,vc_1,cspd_1,
             Vdt_1,Vht_1,V1_1,V2_1,V3_1,Vt_1,V1t_1,V2t_1,V3t_1,
			 V_1,V4_1,V5_1,V6_1,V7_1,V8_1,V9_1,V10_1,V11_1,V12_1,V13_1,V14_1,V15_1,
			 V4T_1,V5T_1,V6T_1,V7T_1,V8T_1,V9T_1,V10T_1,V11T_1,V12T_1,V13T_1,V14T_1,V15T_1
      linko=?day_ghg_wRev.dbf format=dbf exclude=bike,tollda,tolls2,tolls3,tollcv,prevvol,prevvol,vc_1,cspd_1,
             vdt_1,vht_1,v1_1,v2_1,v3_1,vt_1,v1t_1,v2t_1,v3t_1,
			 v4T_1,v5T_1,v6T_1,v7T_1,v8T_1,v9T_1,v10T_1,v11T_1,v12T_1,v13T_1,v14T_1,v15T_1,
			 V_1,v4_1,v5_1,v6_1,v7_1,v8_1,v9_1,v10_1,v11_1,v12_1,v13_1,v14_1,v15_1

;if (capclass=7,99) delete
county='NA'
if (rad=1-29) county='Sacramento'
if (rad=30-36) county='Sutter'
if (rad=40-47) county='Yuba'
if (rad=50-57) county='Yolo'
if (rad=70-82) county='Placer'
if (rad=85-96) county='El Dorado'
if (rad=97) county='External'

lanemi=lanes*distance

;link volumes by user type
	;li.2.V1_1	+	; Drive Alone VOT Class 1 			- 33rd percentile: 0.1205 dollars per minute
	;li.2.V2_1	+	; Commercial Vehicles 2 axle			"
	;li.2.V3_1	+	; Commercial Vehicles 3 axle			"
	;li.2.V4_1	+	; Shared Drive 2						"
	;li.2.V5_1	+	; Shared Drive 3+						"
	;li.2.V6_1	+	; Drive Alone 						- 66th percentile: 0.2808 dollars per minute
	;li.2.V7_1	+	; Commercial Vehicles 2 axle			"
	;li.2.V8_1	+	; Commercial Vehicles 3 axle			"
	;li.2.V9_1	+	; Shared Drive 2						"
	;li.2.V10_1	+	; Shared Drive 3+						"
	;li.2.V11_1	+	; Drive Alone 						- 90th percentile: 0.646 dollars per minute
	;li.2.V12_1	+	; Commercial Vehicles 2 axle			"
	;li.2.V13_1	+	; Commercial Vehicles 3 axle			"
	;li.2.V14_1	+	; Shared Drive 2						"
	;li.2.V15_1   	; Shared Drive 3+						"

dy_Rev=0
a3_Rev=0
md_Rev=0
p3_Rev=0
ev_Rev=0

pk_Rev = 0
op_Rev = 0

dyv=0
a3v=0
mdv=0
p3v=0
evv=0
	
pkv = 0
opv = 0

; link volumes
h07v = li.2.V1_1	+	li.2.V2_1	+	li.2.V3_1	+	li.2.V4_1	+	li.2.V5_1	+	li.2.V6_1	+	li.2.V7_1	+	li.2.V8_1	+	li.2.V9_1	+	li.2.V10_1	+	li.2.V11_1	+	li.2.V12_1	+	li.2.V13_1	+	li.2.V14_1	+	li.2.V15_1
h08v = li.3.V1_1	+	li.3.V2_1	+	li.3.V3_1	+	li.3.V4_1	+	li.3.V5_1	+	li.3.V6_1	+	li.3.V7_1	+	li.3.V8_1	+	li.3.V9_1	+	li.3.V10_1	+	li.3.V11_1	+	li.3.V12_1	+	li.3.V13_1	+	li.3.V14_1	+	li.3.V15_1
h09v = li.4.V1_1	+	li.4.V2_1	+	li.4.V3_1	+	li.4.V4_1	+	li.4.V5_1	+	li.4.V6_1	+	li.4.V7_1	+	li.4.V8_1	+	li.4.V9_1	+	li.4.V10_1	+	li.4.V11_1	+	li.4.V12_1	+	li.4.V13_1	+	li.4.V14_1	+	li.4.V15_1
md5v = li.5.V1_1	+	li.5.V2_1	+	li.5.V3_1	+	li.5.V4_1	+	li.5.V5_1	+	li.5.V6_1	+	li.5.V7_1	+	li.5.V8_1	+	li.5.V9_1	+	li.5.V10_1	+	li.5.V11_1	+	li.5.V12_1	+	li.5.V13_1	+	li.5.V14_1	+	li.5.V15_1
h15v = li.6.V1_1	+	li.6.V2_1	+	li.6.V3_1	+	li.6.V4_1	+	li.6.V5_1	+	li.6.V6_1	+	li.6.V7_1	+	li.6.V8_1	+	li.6.V9_1	+	li.6.V10_1	+	li.6.V11_1	+	li.6.V12_1	+	li.6.V13_1	+	li.6.V14_1	+	li.6.V15_1
h16v = li.7.V1_1	+	li.7.V2_1	+	li.7.V3_1	+	li.7.V4_1	+	li.7.V5_1	+	li.7.V6_1	+	li.7.V7_1	+	li.7.V8_1	+	li.7.V9_1	+	li.7.V10_1	+	li.7.V11_1	+	li.7.V12_1	+	li.7.V13_1	+	li.7.V14_1	+	li.7.V15_1
h17v = li.8.V1_1	+	li.8.V2_1	+	li.8.V3_1	+	li.8.V4_1	+	li.8.V5_1	+	li.8.V6_1	+	li.8.V7_1	+	li.8.V8_1	+	li.8.V9_1	+	li.8.V10_1	+	li.8.V11_1	+	li.8.V12_1	+	li.8.V13_1	+	li.8.V14_1	+	li.8.V15_1
ev2v = li.9.V1_1	+	li.9.V2_1	+	li.9.V3_1	+	li.9.V4_1	+	li.9.V5_1	+	li.9.V6_1	+	li.9.V7_1	+	li.9.V8_1	+	li.9.V9_1	+	li.9.V10_1	+	li.9.V11_1	+	li.9.V12_1	+	li.9.V13_1	+	li.9.V14_1	+	li.9.V15_1
n11v = li.10.V1_1	+	li.10.V2_1	+	li.10.V3_1	+	li.10.V4_1	+	li.10.V5_1	+	li.10.V6_1	+	li.10.V7_1	+	li.10.V8_1	+	li.10.V9_1	+	li.10.V10_1	+	li.10.V11_1	+	li.10.V12_1	+	li.10.V13_1	+	li.10.V14_1	+	li.10.V15_1

a3v=int(h07v+h08v+h09v)
mdv=int(md5v)
p3v=int(h15v+h16v+h17v)
evv=int(ev2v+n11v)
dyv=int(a3v+mdv+p3v+evv)

pkv=a3v+p3v
opv=mdv+evv

; link v/c ratios
h07vc = li.2.vc_1
h08vc = li.3.vc_1
h09vc = li.4.vc_1
md5vc = li.5.vc_1
h15vc = li.6.vc_1
h16vc = li.7.vc_1
h17vc = li.8.vc_1
ev2vc = li.9.vc_1
n11vc = li.10.vc_1
/*
a3vht=h07vht+h08vht+h09vht
mdvht=md5vht
p3vht=h15vht+h16vht+h17vht
evvht=ev2vht+n11vht
dayvht=a3vht+p3vht+mdvht+evvht

; link v/c ratios
h07vht = li.2.Vht_1
h08vht = li.3.Vht_1
h09vht = li.4.Vht_1
md5vht = li.5.Vht_1
h15vht = li.6.Vht_1
h16vht = li.7.Vht_1
h17vht = li.8.Vht_1
ev2vht = li.9.Vht_1
n11vht = li.10.Vht_1
*/
maxvc_dy = max(h07vc,h08vc,h09vc,md5vc,h15vc,h16vc,h17vc,ev2vc,n11vc)
minvc_dy = min(h07vc,h08vc,h09vc,md5vc,h15vc,h16vc,h17vc,ev2vc,n11vc)
maxvc_pk = max(h07vc,h08vc,h09vc,h15vc,h16vc,h17vc)
minvc_pk = min(h07vc,h08vc,h09vc,h15vc,h16vc,h17vc)
maxvc_op = max(md5vc,ev2vc,n11vc)
minvc_op = min(md5vc,ev2vc,n11vc)
maxvc_a3 = max(h07vc,h08vc,h09vc)
maxvc_p3 = max(h15vc,h16vc,h17vc)

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

pkvmt=a3vmt+p3vmt
opvmt=mdvmt+evvmt
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

pkcvmt=a3cvmt+p3cvmt
opcvmt=mdcvmt+evcvmt

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

pkcvmt=a3cvmt+p3cvmt
pkycv=a3cv+p3cv

opycvmt=mdcvmt+evcvmt
opycv=mdcv+evcv

; link volume by user type
h07v_da = li.2.V1_1 + li.2.V6_1 + li.2.V11_1
h07v_sd2 = li.2.V4_1 + li.2.V9_1 + li.2.V14_1
h07v_sd3 = li.2.V5_1 + li.2.V10_1 + li.2.V15_1
h07v_cv = li.2.V2_1 + li.2.V3_1 + li.2.V7_1 + li.2.V8_1 + li.2.V12_1 + li.2.V13_1
if (h07v>0)
	h07v_daPT = h07v_da/h07v
	h07v_sd2PT = h07v_sd2/h07v
	h07v_sd3PT = h07v_sd3/h07v
	h07v_cvPT = h07v_cv/h07v
endif
;
h08v_da = li.3.V1_1 + li.3.V6_1 + li.3.V11_1
h08v_sd2 = li.3.V4_1 + li.3.V9_1 + li.3.V14_1
h08v_sd3 = li.3.V5_1 + li.3.V10_1 + li.3.V15_1
h08v_cv = li.3.V2_1 + li.3.V3_1 + li.3.V7_1 + li.3.V8_1 + li.3.V12_1 + li.3.V13_1
if (h08v>0)
	h08v_daPT = h08v_da/h08v
	h08v_sd2PT = h08v_sd2/h08v
	h08v_sd3PT = h08v_sd3/h08v
	h08v_cvPT = h08v_cv/h08v
endif
;
h09v_da = li.4.V1_1 + li.4.V6_1 + li.4.V11_1
h09v_sd2 = li.4.V4_1 + li.4.V9_1 + li.4.V14_1
h09v_sd3 = li.4.V5_1 + li.4.V10_1 + li.4.V15_1
h09v_cv = li.4.V2_1 + li.4.V3_1 + li.4.V7_1 + li.4.V8_1 + li.4.V12_1 + li.4.V13_1
if (h09v>0)
	h09v_daPT = h09v_da/h09v
	h09v_sd2PT = h09v_sd2/h09v
	h09v_sd3PT = h09v_sd3/h09v
	h09v_cvPT = h09v_cv/h09v
endif
;
md5v_da = li.5.V1_1 + li.5.V6_1 + li.5.V11_1
md5v_sd2 = li.5.V4_1 + li.5.V9_1 + li.5.V14_1
md5v_sd3 = li.5.V5_1 + li.5.V10_1 + li.5.V15_1
md5v_cv = li.5.V2_1 + li.5.V3_1 + li.5.V7_1 + li.5.V8_1 + li.5.V12_1 + li.5.V13_1
if (md5v>0)
	md5v_daPT = md5v_da/md5v
	md5v_sd2PT = md5v_sd2/md5v
	md5v_sd3PT = md5v_sd3/md5v
	md5v_cvPT = md5v_cv/md5v
endif
;
h15v_da = li.6.V1_1 + li.6.V6_1 + li.6.V11_1
h15v_sd2 = li.6.V4_1 + li.6.V9_1 + li.6.V14_1
h15v_sd3 = li.6.V5_1 + li.6.V10_1 + li.6.V15_1
h15v_cv = li.6.V2_1 + li.6.V3_1 + li.6.V7_1 + li.6.V8_1 + li.6.V12_1 + li.6.V13_1
if (h15v>0)
	h15v_daPT = h15v_da/h15v
	h15v_sd2PT = h15v_sd2/h15v
	h15v_sd3PT = h15v_sd3/h15v
	h15v_cvPT = h15v_cv/h15v
endif
;
h16v_da = li.7.V1_1 + li.7.V6_1 + li.7.V11_1
h16v_sd2 = li.7.V4_1 + li.7.V9_1 + li.7.V14_1
h16v_sd3 = li.7.V5_1 + li.7.V10_1 + li.7.V15_1
h16v_cv = li.7.V2_1 + li.7.V3_1 + li.7.V7_1 + li.7.V8_1 + li.7.V12_1 + li.7.V13_1
if (h16v>0)
	h16v_daPT = h16v_da/h16v
	h16v_sd2PT = h16v_sd2/h16v
	h16v_sd3PT = h16v_sd3/h16v
	h16v_cvPT = h16v_cv/h16v
endif
;
h17v_da = li.8.V1_1 + li.8.V6_1 + li.8.V11_1
h17v_sd2 = li.8.V4_1 + li.8.V9_1 + li.8.V14_1
h17v_sd3 = li.8.V5_1 + li.8.V10_1 + li.8.V15_1
h17v_cv = li.8.V2_1 + li.8.V3_1 + li.8.V7_1 + li.8.V8_1 + li.8.V12_1 + li.8.V13_1
if (h17v>0)
	h17v_daPT = h17v_da/h17v
	h17v_sd2PT = h17v_sd2/h17v
	h17v_sd3PT = h17v_sd3/h17v
	h17v_cvPT = h17v_cv/h17v
endif
;
ev2v_da = li.9.V1_1 + li.9.V6_1 + li.9.V11_1
ev2v_sd2 = li.9.V4_1 + li.9.V9_1 + li.9.V14_1
ev2v_sd3 = li.9.V5_1 + li.9.V10_1 + li.9.V15_1
ev2v_cv = li.9.V2_1 + li.9.V3_1 + li.9.V7_1 + li.9.V8_1 + li.9.V12_1 + li.9.V13_1
if (ev2v>0)
	ev2v_daPT = ev2v_da/ev2v
	ev2v_sd2PT = ev2v_sd2/ev2v
	ev2v_sd3PT = ev2v_sd3/ev2v
	ev2v_cvPT = ev2v_cv/ev2v
endif
;
n11v_da = li.10.V1_1 + li.10.V6_1 + li.10.V11_1
n11v_sd2 = li.10.V4_1 + li.10.V9_1 + li.10.V14_1
n11v_sd3 = li.10.V5_1 + li.10.V10_1 + li.10.V15_1
n11v_cv = li.10.V2_1 + li.10.V3_1 + li.10.V7_1 + li.10.V8_1 + li.10.V12_1 + li.10.V13_1
if (n11v>0)
	n11v_daPT = n11v_da/n11v
	n11v_sd2PT = n11v_sd2/n11v
	n11v_sd3PT = n11v_sd3/n11v
	n11v_cvPT = n11v_cv/n11v
endif

dyv_da = h07v_da + h08v_da + h09v_da + md5v_da + h15v_da + h16v_da + h17v_da + ev2v_da + n11v_da
dyv_sd2 = h07v_sd2 + h08v_sd2 + h09v_sd2 + md5v_sd2 + h15v_sd2 + h16v_sd2 + h17v_sd2 + ev2v_sd2 + n11v_sd2
dyv_sd3 = h07v_sd3 + h08v_sd3 + h09v_sd3 + md5v_sd3 + h15v_sd3 + h16v_sd3 + h17v_sd3 + ev2v_sd3 + n11v_sd3
dyv_cv = h07v_cv + h08v_cv + h09v_cv + md5v_cv + h15v_cv + h16v_cv + h17v_cv + ev2v_cv + n11v_cv
if (dyv>0)
	dyv_daPT = dyv_da/dyv
	dyv_sd2PT = dyv_sd2/dyv
	dyv_sd3PT = dyv_sd3/dyv
	dyv_cvPT = dyv_cv/dyv
endif	


pkv_da = h07v_da + h08v_da + h09v_da + h15v_da + h16v_da + h17v_da
pkv_sd2 = h07v_sd2 + h08v_sd2 + h09v_sd2 + h15v_sd2 + h16v_sd2 + h17v_sd2
pkv_sd3 = h07v_sd3 + h08v_sd3 + h09v_sd3 + h15v_sd3 + h16v_sd3 + h17v_sd3
pkv_cv = h07v_cv + h08v_cv + h09v_cv + h15v_cv + h16v_cv + h17v_cv
if (pkv>0)
	pkv_daPT = pkv_da/pkv
	pkv_sd2PT = pkv_sd2/pkv
	pkv_sd3PT = pkv_sd3/pkv
	pkv_cvPT = pkv_cv/pkv
endif

opv_da = md5v_da + ev2v_da + n11v_da
opv_sd2 = md5v_sd2 + ev2v_sd2 + n11v_sd2
opv_sd3 = md5v_sd3 + ev2v_sd3 + n11v_sd3
opv_cv = md5v_cv + ev2v_cv + n11v_cv
if (opv>0)
	opv_daPT = opv_da/opv
	opv_sd2PT = opv_sd2/opv
	opv_sd3PT = opv_sd3/opv
	opv_cvPT = opv_cv/opv
endif	

;Calculate Revenue
;total rev per period

h07_Rev = 0
h08_Rev = 0
h09_Rev = 0

md5_Rev = 0

h15_Rev = 0
h16_Rev = 0
h17_Rev = 0

ev2_Rev = 0
n11_Rev = 0

dy_Rev = 0

; Final Tolls by type
h07_Tollda = li.2.TOLLDA
h08_Tollda = li.3.TOLLDA
h09_Tollda = li.4.TOLLDA

md5_Tollda = li.5.TOLLDA

h15_Tollda = li.6.TOLLDA
h16_Tollda = li.7.TOLLDA
h17_Tollda = li.8.TOLLDA

ev2_Tollda = li.9.TOLLDA
n11_Tollda = li.10.TOLLDA

h07_Tolls2 = li.2.TOLLS2
h08_Tolls2 = li.3.TOLLS2
h09_Tolls2 = li.4.TOLLS2

md5_Tolls2 = li.5.TOLLS2

h15_Tolls2 = li.6.TOLLS2
h16_Tolls2 = li.7.TOLLS2
h17_Tolls2 = li.8.TOLLS2

ev2_Tolls2 = li.9.TOLLS2
n11_Tolls2 = li.10.TOLLS2

h07_Tolls3 = li.2.TOLLS3
h08_Tolls3 = li.3.TOLLS3
h09_Tolls3 = li.4.TOLLS3

md5_Tolls3 = li.5.TOLLS3

h15_Tolls3 = li.6.TOLLS3
h16_Tolls3 = li.7.TOLLS3
h17_Tolls3 = li.8.TOLLS3

ev2_Tolls3 = li.9.TOLLS3
n11_Tolls3 = li.10.TOLLS3

h07_Tollcv = li.2.TOLLCV
h08_Tollcv = li.3.TOLLCV
h09_Tollcv = li.4.TOLLCV

md5_Tollcv = li.5.TOLLCV

h15_Tollcv = li.6.TOLLCV
h16_Tollcv = li.7.TOLLCV
h17_Tollcv = li.8.TOLLCV

ev2_Tollcv = li.9.TOLLCV
n11_Tollcv = li.10.TOLLCV

h07speed=li.2.cspd_1
h08speed=li.3.cspd_1
h09speed=li.4.cspd_1
md5speed=li.5.cspd_1
h15speed=li.6.cspd_1
h16speed=li.7.cspd_1
h17speed=li.8.cspd_1
ev2speed=li.9.cspd_1
n11speed=li.10.cspd_1

a3speed=(h07speed+h08speed+h09speed)/3
p3speed=(h15speed+h16speed+h17speed)/3
mdspeed=md5speed
evspeed=(ev2speed+n11speed)/2
dayspeed=(h07speed+h08speed+h09speed+h15speed+h16speed+h17speed+md5speed+ev2speed+n11speed)/9
dayspeedmx = max(h07speed,h08speed,h09speed,h15speed,h16speed,h17speed,md5speed,ev2speed,n11speed)
dayspeedmn = min(h07speed,h08speed,h09speed,h15speed,h16speed,h17speed,md5speed,ev2speed,n11speed)

;SOV Rev by Capclass - used to determine corridor toll per vehicle
;General Purpose Lanes
IF (Capclass=1)
	h07_daTolGP = li.2.TOLLDA
	h08_daTolGP = li.3.TOLLDA
	h09_daTolGP = li.4.TOLLDA

	md5_daTolGP = li.5.TOLLDA

	h15_daTolGP = li.6.TOLLDA
	h16_daTolGP = li.7.TOLLDA
	h17_daTolGP = li.8.TOLLDA

	ev2_daTolGP = li.9.TOLLDA
	n11_daTolGP = li.10.TOLLDA
	
	h07_daRevGP = (h07v_da * li.2.TOLLDA)
	h08_daRevGP = (h08v_da * li.3.TOLLDA)
	h09_daRevGP = (h09v_da * li.4.TOLLDA)

	md5_daRevGP = (md5v_da * li.5.TOLLDA)

	h15_daRevGP = (h15v_da * li.6.TOLLDA)
	h16_daRevGP = (h16v_da * li.7.TOLLDA)
	h17_daRevGP = (h17v_da * li.8.TOLLDA)

	ev2_daRevGP = (ev2v_da * li.9.TOLLDA)
	n11_daRevGP = (n11v_da * li.10.TOLLDA)
	
	h07ttimeGP=li.2.TIME_1
	h08ttimeGP=li.3.TIME_1
	h09ttimeGP=li.4.TIME_1
	md5ttimeGP=li.5.TIME_1
	h15ttimeGP=li.6.TIME_1
	h16ttimeGP=li.7.TIME_1
	h17ttimeGP=li.8.TIME_1
	ev2ttimeGP=li.9.TIME_1
	n11ttimeGP=li.10.TIME_1

	a3ttimeGP=(h07ttimeGP+h08ttimeGP+h09ttimeGP)/3
	p3ttimeGP=(h15ttimeGP+h16ttimeGP+h17ttimeGP)/3
	mdttimeGP=md5ttimeGP
	evttimeGP=(ev2ttimeGP+n11ttimeGP)/2
	dayttimeGP=(h07ttimeGP+h08ttimeGP+h09ttimeGP+h15ttimeGP+h16ttimeGP+h17ttimeGP+md5ttimeGP+ev2ttimeGP+n11ttimeGP)/9

	h07speedGP=li.2.cspd_1
	h08speedGP=li.3.cspd_1
	h09speedGP=li.4.cspd_1
	md5speedGP=li.5.cspd_1
	h15speedGP=li.6.cspd_1
	h16speedGP=li.7.cspd_1
	h17speedGP=li.8.cspd_1
	ev2speedGP=li.9.cspd_1
	n11speedGP=li.10.cspd_1

	a3speedGP=(h07speedGP+h08speedGP+h09speedGP)/3
	p3speedGP=(h15speedGP+h16speedGP+h17speedGP)/3
	mdspeedGP=md5speedGP
	evspeedGP=(ev2speedGP+n11speedGP)/2
	dayspeedGP=(h07speedGP+h08speedGP+h09speedGP+h15speedGP+h16speedGP+h17speedGP+md5speedGP+ev2speedGP+n11speedGP)/9
	dayspeedGPmx = max(h07speedGP,h08speedGP,h09speedGP,h15speedGP,h16speedGP,h17speedGP,md5speedGP,ev2speedGP,n11speedGP)
	dayspeedGPmn = min(h07speedGP,h08speedGP,h09speedGP,h15speedGP,h16speedGP,h17speedGP,md5speedGP,ev2speedGP,n11speedGP)
	
ENDIF
;HOV Lanes
IF (Capclass=8)
	h07_daTolHL = li.2.TOLLDA
	h08_daTolHL = li.3.TOLLDA
	h09_daTolHL = li.4.TOLLDA

	md5_daTolHL = li.5.TOLLDA

	h15_daTolHL = li.6.TOLLDA
	h16_daTolHL = li.7.TOLLDA
	h17_daTolHL = li.8.TOLLDA

	ev2_daTolHL = li.9.TOLLDA
	n11_daTolHL = li.10.TOLLDA

	h07_daRevHL = (h07v_da * li.2.TOLLDA)
	h08_daRevHL = (h08v_da * li.3.TOLLDA)
	h09_daRevHL = (h09v_da * li.4.TOLLDA)

	md5_daRevHL = (md5v_da * li.5.TOLLDA)

	h15_daRevHL = (h15v_da * li.6.TOLLDA)
	h16_daRevHL = (h16v_da * li.7.TOLLDA)
	h17_daRevHL = (h17v_da * li.8.TOLLDA)

	ev2_daRevHL = (ev2v_da * li.9.TOLLDA)
	n11_daRevHL = (n11v_da * li.10.TOLLDA)
	
	h07ttimeHL=li.2.TIME_1
	h08ttimeHL=li.3.TIME_1
	h09ttimeHL=li.4.TIME_1
	md5ttimeHL=li.5.TIME_1
	h15ttimeHL=li.6.TIME_1
	h16ttimeHL=li.7.TIME_1
	h17ttimeHL=li.8.TIME_1
	ev2ttimeHL=li.9.TIME_1
	n11ttimeHL=li.10.TIME_1
	
	;average travel times
	a3ttimeHL=(h07ttimeHL+h08ttimeHL+h09ttimeHL)/3
	p3ttimeHL=(h15ttimeHL+h16ttimeHL+h17ttimeHL)/3
	mdttimeHL=md5ttimeHL
	evttimeHL=(ev2ttimeHL+n11ttimeHL)/2
	dayttimeHL=(h07ttimeHL+h08ttimeHL+h09ttimeHL+h15ttimeHL+h16ttimeHL+h17ttimeHL+md5ttimeHL+ev2ttimeHL+n11ttimeHL)/9
	
	pkttimeHL=(h07ttimeHL+h08ttimeHL+h09ttimeHL+h15ttimeHL+h16ttimeHL+h17ttimeHL)/6
	opttimeHL=(md5ttimeHL+ev2ttimeHL+n11ttimeHL)/3
	
	h07speedHL=li.2.cspd_1
	h08speedHL=li.3.cspd_1
	h09speedHL=li.4.cspd_1
	md5speedHL=li.5.cspd_1
	h15speedHL=li.6.cspd_1
	h16speedHL=li.7.cspd_1
	h17speedHL=li.8.cspd_1
	ev2speedHL=li.9.cspd_1
	n11speedHL=li.10.cspd_1

	a3speedHL=(h07speedHL+h08speedHL+h09speedHL)/3
	p3speedHL=(h15speedHL+h16speedHL+h17speedHL)/3
	mdspeedHL=md5speedHL
	evspeedHL=(ev2speedHL+n11speedHL)/2
	
	pkspeedHL=(h07speedHL+h08speedHL+h09speedHL+h15speedHL+h16speedHL+h17speedHL)/6
	opspeedHL=(md5speedHL+ev2speedHL+n11speedHL)/3
	
	dayspeedHL=(h07speedHL+h08speedHL+h09speedHL+h15speedHL+h16speedHL+h17speedHL+md5speedHL+ev2speedHL+n11speedHL)/9
	dayspeedHLmx=max(h07speedHL,h08speedHL,h09speedHL,h15speedHL,h16speedHL,h17speedHL,md5speedHL,ev2speedHL,n11speedHL)
	dayspeedHLmn=min(h07speedHL,h08speedHL,h09speedHL,h15speedHL,h16speedHL,h17speedHL,md5speedHL,ev2speedHL,n11speedHL)
	
ENDIF
;Aux Lanes
IF (Capclass=51 | Capclass=56)
	h07_daTolAL = li.2.TOLLDA
	h08_daTolAL = li.3.TOLLDA
	h09_daTolAL = li.4.TOLLDA

	md5_daTolAL = li.5.TOLLDA

	h15_daTolAL = li.6.TOLLDA
	h16_daTolAL = li.7.TOLLDA
	h17_daTolAL = li.8.TOLLDA

	ev2_daTolAL = li.9.TOLLDA
	n11_daTolAL = li.10.TOLLDA

	h07_daRevAL = (h07v_da * li.2.TOLLDA)
	h08_daRevAL = (h08v_da * li.3.TOLLDA)
	h09_daRevAL = (h09v_da * li.4.TOLLDA)

	md5_daRevAL = (md5v_da * li.5.TOLLDA)

	h15_daRevAL = (h15v_da * li.6.TOLLDA)
	h16_daRevAL = (h16v_da * li.7.TOLLDA)
	h17_daRevAL = (h17v_da * li.8.TOLLDA)

	ev2_daRevAL = (ev2v_da * li.9.TOLLDA)
	n11_daRevAL = (n11v_da * li.10.TOLLDA)
ENDIF

;SOV---------------------
h07_daRev = (h07v_da * li.2.TOLLDA)
h08_daRev = (h08v_da * li.3.TOLLDA)
h09_daRev = (h09v_da * li.4.TOLLDA)

md5_daRev = (md5v_da * li.5.TOLLDA)

h15_daRev = (h15v_da * li.6.TOLLDA)
h16_daRev = (h16v_da * li.7.TOLLDA)
h17_daRev = (h17v_da * li.8.TOLLDA)

ev2_daRev = (ev2v_da * li.9.TOLLDA)
n11_daRev = (n11v_da * li.10.TOLLDA)

dy_daRev = h07_daRev + h08_daRev + h09_daRev + md5_daRev + h15_daRev + h16_daRev + h17_daRev + ev2_daRev + n11_daRev
pk_daRev = h07_daRev + h08_daRev + h09_daRev + h15_daRev + h16_daRev + h17_daRev
op_daRev = md5_daRev + ev2_daRev + n11_daRev
;HOV2---------------------
h07_sd2Rev = (h07v_sd2 * li.2.TOLLS2)
h08_sd2Rev = (h08v_sd2 * li.3.TOLLS2)
h09_sd2Rev = (h09v_sd2 * li.4.TOLLS2)

md5_sd2Rev = (md5v_sd2 * li.5.TOLLS2)

h15_sd2Rev = (h15v_sd2 * li.6.TOLLS2)
h16_sd2Rev = (h16v_sd2 * li.7.TOLLS2)
h17_sd2Rev = (h17v_sd2 * li.8.TOLLS2)

ev2_sd2Rev = (ev2v_sd2 * li.9.TOLLS2)
n11_sd2Rev = (n11v_sd2 * li.10.TOLLS2)

dy_sd2Rev = h07_sd2Rev + h08_sd2Rev + h09_sd2Rev + md5_sd2Rev + h15_sd2Rev + h16_sd2Rev + h17_sd2Rev + ev2_sd2Rev + n11_sd2Rev
pk_sd2Rev = h07_sd2Rev + h08_sd2Rev + h09_sd2Rev + h15_sd2Rev + h16_sd2Rev + h17_sd2Rev
op_sd2Rev = md5_sd2Rev + ev2_sd2Rev + n11_sd2Rev
;HOV3---------------------
h07_sd3Rev = (h07v_sd3 * li.2.TOLLS3)
h08_sd3Rev = (h08v_sd3 * li.3.TOLLS3)
h09_sd3Rev = (h09v_sd3 * li.4.TOLLS3)

md5_sd3Rev = (md5v_sd3 * li.5.TOLLS3)

h15_sd3Rev = (h15v_sd3 * li.6.TOLLS3)
h16_sd3Rev = (h16v_sd3 * li.7.TOLLS3)
h17_sd3Rev = (h17v_sd3 * li.8.TOLLS3)

ev2_sd3Rev = (ev2v_sd3 * li.9.TOLLS3)
n11_sd3Rev = (n11v_sd3 * li.10.TOLLS3)

dy_sd3Rev = h07_sd3Rev + h08_sd3Rev + h09_sd3Rev + md5_sd3Rev + h15_sd3Rev + h16_sd3Rev + h17_sd3Rev + ev2_sd3Rev + n11_sd3Rev
pk_sd3Rev = h07_sd3Rev + h08_sd3Rev + h09_sd3Rev + h15_sd3Rev + h16_sd3Rev + h17_sd3Rev
op_sd3Rev = md5_sd3Rev + ev2_sd3Rev + n11_sd3Rev
;Commercial Vehicle 3---------------------
h07_cvRev = (h07v_cv * li.2.TOLLCV)
h08_cvRev = (h08v_cv * li.3.TOLLCV)
h09_cvRev = (h09v_cv * li.4.TOLLCV)

md5_cvRev = (md5v_cv * li.5.TOLLCV)

h15_cvRev = (h15v_cv * li.6.TOLLCV)
h16_cvRev = (h16v_cv * li.7.TOLLCV)
h17_cvRev = (h17v_cv * li.8.TOLLCV)

ev2_cvRev = (ev2v_cv * li.9.TOLLCV)
n11_cvRev = (n11v_cv * li.10.TOLLCV)

dy_cvRev = h07_cvRev + h08_cvRev + h09_cvRev + md5_cvRev + h15_cvRev + h16_cvRev + h17_cvRev + ev2_cvRev + n11_cvRev
pk_cvRev = h07_cvRev + h08_cvRev + h09_cvRev + h15_cvRev + h16_cvRev + h17_cvRev
op_cvRev = md5_cvRev + ev2_cvRev + n11_cvRev

h07_Rev = h07_daRev + h07_sd2Rev + h07_sd3Rev + h07_cvRev
h08_Rev = h08_daRev + h08_sd2Rev + h08_sd3Rev + h08_cvRev
h09_Rev = h09_daRev + h09_sd2Rev + h09_sd3Rev + h09_cvRev
md5_Rev = md5_daRev + md5_sd2Rev + md5_sd3Rev + md5_cvRev
h15_Rev = h15_daRev + h15_sd2Rev + h15_sd3Rev + h15_cvRev
h16_Rev = h16_daRev + h16_sd2Rev + h16_sd3Rev + h16_cvRev
h17_Rev = h17_daRev + h17_sd2Rev + h17_sd3Rev + h17_cvRev
ev2_Rev = ev2_daRev + ev2_sd2Rev + ev2_sd3Rev + ev2_cvRev
n11_Rev = n11_daRev + n11_sd2Rev + n11_sd3Rev + n11_cvRev

a3_Rev = h07_Rev+h08_Rev+h09_Rev
md_Rev = md5_Rev
p3_Rev = h15_Rev+h16_Rev+h17_Rev
ev_Rev = ev2_Rev+n11_Rev
dy_Rev = a3_Rev+md_Rev+p3_Rev+ev_Rev

pk_Rev = a3_Rev + p3_Rev
op_Rev = md_Rev + ev_Rev

;add CVMT & CV with CV >.9 <1
if(h07vc>0.9 && h07vc<=1.0)
   h07cvmt91=h07vmt
   h07cv91=h07v
endif
if(h08vc>0.9 && h08vc<=1.0)
   h08cvmt91=h08vmt
   h08cv91=h08v
endif
if(h09vc>0.9 && h09vc<=1.0)
   h09cvmt91=h09vmt
   h09cv91=h09v
endif
if(md5vc>0.9 && md5vc<=1.0)
   md5cvmt91=md5vmt
   md5cv91=md5v
endif
if(h15vc>0.9 && h15vc<=1.0)
   h15cvmt91=h15vmt
   h15cv91=h15v
endif
if(h16vc>0.9 && h16vc<=1.0)
   h16cvmt91=h16vmt
   h16cv91=h16v
endif
if(h17vc>0.9 && h17vc<=1.0)
   h17cvmt91=h17vmt
   h17cv91=h17v
endif
if(ev2vc>0.9 && ev2vc<=1.0)
   ev2cvmt91=ev2vmt
   ev2cv91=ev2v
endif
if(n11vc>0.9 && n11vc<=1.0)
   n11cvmt91=n11vmt
   n11cv91=n11v
endif

a3cvmt91=h07cvmt91+h08cvmt91+h09cvmt91
mdcvmt91=md5cvmt91
p3cvmt91=h15cvmt91+h16cvmt91+h17cvmt91
evcvmt91=ev2cvmt91+n11cvmt91

a3cv91=h07cv91+h08cv91+h09cv91
p3cv91=h15cv91+h16cv91+h17cv91
mdcv91=md5cv91
evcv91=ev2cv91+n11cv91

daycvmt91=a3cvmt91+p3cvmt91+mdcvmt91+evcvmt91
daycv91=a3cv91+p3cv91+mdcv91+evcv91



	
merge record=false
endrun


RUN PGM=NETWORK MSG='summarize tolling revenue'
LINKI = ?day_ghg_wRev.net
FILEI LOOKUPI[1] = tolls.csv
;output files, multiple outputs for legibility, for complete list use Tolling_All_pd.csv
PRINTO[1] = "RevenueSummary_da.csv" 
PRINTO[2] = "RevenueSummary_pk_op.csv"
PRINTO[3] = "RevenueSummary_da_pk_op_hrs.csv"
PRINTO[4] = "RevenueSummary_AllToll_Check.csv"
PRINTO[5] = "Tolling_Stats.csv"
PRINTO[6] = "Tolling_All_pd.csv" ;ordered "Tolling_Stats.csv", "RevenueSummary_da_pk_op_hrs.csv", "RevenueSummary_AllToll_Check.csv"

array toll_rev_dy = 100

array toll_rev_dyda = 100
array toll_rev_dysd2 = 100
array toll_rev_dysd3 = 100
array toll_rev_dycv = 100

array total_vol_dy = 100

array total_vol_dyda = 100
array total_vol_dysd2 = 100
array total_vol_dysd3 = 100
array total_vol_dycv = 100

array total_vmt_dy = 100
array total_cvmt_dy = 100
array ttime_dy = 100
;array avg_speed_dy = 100
array max_speed_dy = 100
array min_speed_dy = 100
array max_vc_dy = 100
array min_vc_dy = 100


array ttime_dyGP = 100
;array avg_speed_dyGP = 100
array max_speed_dyGP = 100
array min_speed_dyGP = 100
array max_vc_dyGP = 100
array min_vc_dyGP = 100

array tseg_length = 100
array tseg_count= 100
	;peak periods
array toll_rev_pk = 100
	
array toll_rev_pkda = 100
array toll_rev_pksd2 = 100
array toll_rev_pksd3 = 100
array toll_rev_pkcv = 100

array total_vol_pk = 100

array total_vol_pkda = 100
array total_vol_pksd2 = 100
array total_vol_pksd3 = 100
array total_vol_pkcv = 100

array total_vmt_pk = 100
array total_cvmt_pk = 100
array total_time_pk = 100
;array avg_speed_pk = 100
array max_vc_pk = 100
array min_vc_pk = 100
array ttime_pk = 100

;off peaks
array toll_rev_op = 100

array toll_rev_opda = 100
array toll_rev_opsd2 = 100
array toll_rev_opsd3 = 100
array toll_rev_opcv = 100

array total_vol_op = 100

array total_vol_opda = 100
array total_vol_opsd2 = 100
array total_vol_opsd3 = 100
array total_vol_opcv = 100

array total_vmt_op = 100
array total_cvmt_op = 100
array total_time_op = 100
;array avg_speed_op = 100
array max_vc_op = 100
array min_vc_op = 100
array ttime_op = 100

;final tolls per facility segment
array toll_price_07da = 100
array toll_price_08da = 100
array toll_price_09da = 100
array toll_price_mdda = 100
array toll_price_15da = 100
array toll_price_16da = 100
array toll_price_17da = 100
array toll_price_evda = 100
array toll_price_nida = 100

array toll_price_07s2 = 100
array toll_price_08s2 = 100
array toll_price_09s2 = 100
array toll_price_mds2 = 100
array toll_price_15s2 = 100
array toll_price_16s2 = 100
array toll_price_17s2 = 100
array toll_price_evs2 = 100
array toll_price_nis2 = 100

array toll_price_07s3 = 100
array toll_price_08s3 = 100
array toll_price_09s3 = 100
array toll_price_mds3 = 100
array toll_price_15s3 = 100
array toll_price_16s3 = 100
array toll_price_17s3 = 100
array toll_price_evs3 = 100
array toll_price_nis3 = 100

array toll_price_07cv = 100
array toll_price_08cv = 100
array toll_price_09cv = 100
array toll_price_mdcv = 100
array toll_price_15cv = 100
array toll_price_16cv = 100
array toll_price_17cv = 100
array toll_price_evcv = 100
array toll_price_nicv = 100

;travel times
array ttime_h07HL = 100
array ttime_h08HL = 100
array ttime_h09HL = 100
array ttime_md5HL = 100
array ttime_h15HL = 100
array ttime_h16HL = 100
array ttime_h17HL = 100
array ttime_ev2HL = 100
array ttime_n11HL = 100

;VMT
array VMT_h07HL = 100
array VMT_h08HL = 100
array VMT_h09HL = 100
array VMT_md5HL = 100
array VMT_h15HL = 100
array VMT_h16HL = 100
array VMT_h17HL = 100
array VMT_ev2HL = 100
array VMT_n11HL = 100

;CVMT
array CVMT_h07HL = 100
array CVMT_h08HL = 100
array CVMT_h09HL = 100
array CVMT_md5HL = 100
array CVMT_h15HL = 100
array CVMT_h16HL = 100
array CVMT_h17HL = 100
array CVMT_ev2HL = 100
array CVMT_n11HL = 100

;SOV Rev by Capclass - used to determine corridor toll per vehicle
;General Purpose Lanes Toll
array tl_h07_daTolGP = 100
array tl_h08_daTolGP = 100
array tl_h09_daTolGP = 100
array tl_md5_daTolGP = 100
array tl_h15_daTolGP = 100
array tl_h16_daTolGP = 100
array tl_h17_daTolGP = 100
array tl_ev2_daTolGP = 100
array tl_n11_daTolGP = 100

;HOV Lanes Toll
array tl_h07_daTolHL = 100
array tl_h08_daTolHL = 100
array tl_h09_daTolHL = 100
array tl_md5_daTolHL = 100
array tl_h15_daTolHL = 100
array tl_h16_daTolHL = 100
array tl_h17_daTolHL = 100
array tl_ev2_daTolHL = 100
array tl_n11_daTolHL = 100

;Aux Lanes Toll
array tl_h07_daTolAL = 100
array tl_h08_daTolAL = 100
array tl_h09_daTolAL = 100
array tl_md5_daTolAL = 100
array tl_h15_daTolAL = 100
array tl_h16_daTolAL = 100
array tl_h17_daTolAL = 100
array tl_ev2_daTolAL = 100
array tl_n11_daTolAL = 100

;General Purpose Lanes Revenue
array tl_h07_daRevGP = 100
array tl_h08_daRevGP = 100
array tl_h09_daRevGP = 100
array tl_md5_daRevGP = 100
array tl_h15_daRevGP = 100
array tl_h16_daRevGP = 100
array tl_h17_daRevGP = 100
array tl_ev2_daRevGP = 100
array tl_n11_daRevGP = 100

;HOV Lanes Revenue
array tl_h07_daRevHL = 100
array tl_h08_daRevHL = 100
array tl_h09_daRevHL = 100
array tl_md5_daRevHL = 100
array tl_h15_daRevHL = 100
array tl_h16_daRevHL = 100
array tl_h17_daRevHL = 100
array tl_ev2_daRevHL = 100
array tl_n11_daRevHL = 100

;Aux Lanes Revenue
array tl_h07_daRevAL = 100
array tl_h08_daRevAL = 100
array tl_h09_daRevAL = 100
array tl_md5_daRevAL = 100
array tl_h15_daRevAL = 100
array tl_h16_daRevAL = 100
array tl_h17_daRevAL = 100
array tl_ev2_daRevAL = 100
array tl_n11_daRevAL = 100

;GP Lane Stats
;Daily
array total_rev_dyGP = 100
array total_vol_dyGP = 100
array total_vmt_dyGP = 100
array total_cvmt_dyGP = 100
array ttime_dyGP = 100
;array avg_speed_dyGP = 100
array max_speed_dyGP = 100
array min_speed_dyGP = 100
array max_vc_dyGP = 100
array min_vc_dyGP = 100
  
;Travel Time GP Lanes
array ttime_h07GP = 100
array ttime_h08GP = 100
array ttime_h09GP = 100
array ttime_md5GP = 100
array ttime_h15GP = 100
array ttime_h16GP = 100
array ttime_h17GP = 100
array ttime_ev2GP = 100
array ttime_n11GP = 100

;VMT GP Lanes
array VMT_h07GP = 100
array VMT_h08GP = 100
array VMT_h09GP = 100
array VMT_md5GP = 100
array VMT_h15GP = 100
array VMT_h16GP = 100
array VMT_h17GP = 100
array VMT_ev2GP = 100
array VMT_n11GP = 100

;CVMT GP Lanes
array CVMT_h07GP = 100
array CVMT_h08GP = 100
array CVMT_h09GP = 100
array CVMT_md5GP = 100
array CVMT_h15GP = 100
array CVMT_h16GP = 100
array CVMT_h17GP = 100
array CVMT_ev2GP = 100
array CVMT_n11GP = 100

;can change this to loop through toll csv
phase=LINKMERGE
	
   LOOP _segment=1,200
   
		IF (_segment = TOLLID) 	   
		   tseg_length[_segment] = tseg_length[_segment] + li.1.distance
		   tseg_count[_segment] = tseg_count[_segment] + 1
		ENDIF

		IF ((_segment = TOLLID) && (_numseg<TOLLID))
			_numseg = TOLLID
		ENDIF

	ENDLOOP
		
  ;IF (TOLLID > 0)
    ;daily
	toll_rev_dy[TOLLID] = toll_rev_dy[TOLLID] + dy_Rev
	
	toll_rev_dyda[TOLLID] = toll_rev_dyda[TOLLID] + dy_daRev
	toll_rev_dysd2[TOLLID] = toll_rev_dysd2[TOLLID] + dy_sd2Rev
	toll_rev_dysd3[TOLLID] = toll_rev_dysd3[TOLLID] + dy_sd3Rev
	toll_rev_dycv[TOLLID] = toll_rev_dycv[TOLLID] + dy_cvRev
	
	total_vol_dy[TOLLID] = total_vol_dy[TOLLID] + dyv
	
	total_vol_dyda[TOLLID] = total_vol_dyda[TOLLID] + dyv_da
	total_vol_dysd2[TOLLID] = total_vol_dysd2[TOLLID] + dyv_sd2
	total_vol_dysd3[TOLLID] = total_vol_dysd3[TOLLID] + dyv_sd3
	total_vol_dycv[TOLLID] = total_vol_dycv[TOLLID] + dyv_cv
	
	total_vmt_dy[TOLLID] = total_vmt_dy[TOLLID] + dayvmt
	total_cvmt_dy[TOLLID] = total_cvmt_dy[TOLLID] + daycvmt
	ttime_dy[TOLLID] = ttime_dy[TOLLID] + dayttimeHL ; tollid travel time averaged at link level by time period
	;avg_speed_dy[TOLLID] = ave(avg_speed_dy[TOLLID],dayspeedHL) ;average daily link speed
	max_speed_dy[TOLLID] = max(max_speed_dy[TOLLID],dayspeedHLmx) ;link speed maximum
	IF (dayspeedHL > 0)
	  min_speed_dy[TOLLID] = min(min_speed_dy[TOLLID],dayspeedHLmn) ;link speed minimum
	ENDIF
	max_vc_dy[TOLLID] = max(max_vc_dy[TOLLID],maxvc_dy)
	IF (minvc_dy>0)
	  min_vc_dy[TOLLID] = min(min_vc_dy[TOLLID],minvc_dy)
	ENDIF
	
	;peak periods
	toll_rev_pk[TOLLID] = toll_rev_pk[TOLLID] + pk_Rev
	
	toll_rev_pkda[TOLLID] = toll_rev_pkda[TOLLID] + pk_daRev
	toll_rev_pksd2[TOLLID] = toll_rev_pksd2[TOLLID] + pk_sd2Rev
	toll_rev_pksd3[TOLLID] = toll_rev_pksd3[TOLLID] + pk_sd3Rev
	toll_rev_pkcv[TOLLID] = toll_rev_pkcv[TOLLID] + pk_cvRev
	
	total_vol_pk[TOLLID] = total_vol_pk[TOLLID] + pkv
	
	total_vol_pkda[TOLLID] = total_vol_pkda[TOLLID] + pkv_da
	total_vol_pksd2[TOLLID] = total_vol_pksd2[TOLLID] + pkv_sd2
	total_vol_pksd3[TOLLID] = total_vol_pksd3[TOLLID] + pkv_sd3
	total_vol_pkcv[TOLLID] = total_vol_pkcv[TOLLID] + pkv_cv
	
	total_vmt_pk[TOLLID] = total_vmt_pk[TOLLID] + pkvmt
	total_cvmt_pk[TOLLID] = total_cvmt_pk[TOLLID] + pkcvmt
	ttime_pk[TOLLID] = ttime_pk[TOLLID] + pkttimeHL ; tollid travel time averaged at link level by time period
	;avg_speed_pk[TOLLID] = ave(avg_speed_pk[TOLLID],pkspeedHL) ;average daily link speed
	max_vc_pk[TOLLID] = max(max_vc_pk[TOLLID],maxvc_pk)
	IF (minvc_pk>0)
	  min_vc_pk[TOLLID] = min(min_vc_pk[TOLLID],minvc_pk)
	ENDIF
	
	;off peaks
	toll_rev_op[TOLLID] = toll_rev_op[TOLLID] + op_Rev
	
	toll_rev_opda[TOLLID] = toll_rev_opda[TOLLID] + op_daRev
	toll_rev_opsd2[TOLLID] = toll_rev_opsd2[TOLLID] + op_sd2Rev
	toll_rev_opsd3[TOLLID] = toll_rev_opsd3[TOLLID] + op_sd3Rev
	toll_rev_opcv[TOLLID] = toll_rev_opcv[TOLLID] + op_cvRev
	
	total_vol_op[TOLLID] = total_vol_op[TOLLID] + opv
	
	total_vol_opda[TOLLID] = total_vol_opda[TOLLID] + opv_da
	total_vol_opsd2[TOLLID] = total_vol_opsd2[TOLLID] + opv_sd2
	total_vol_opsd3[TOLLID] = total_vol_opsd3[TOLLID] + opv_sd3
	total_vol_opcv[TOLLID] = total_vol_opcv[TOLLID] + opv_cv
	
	total_vmt_op[TOLLID] = total_vmt_op[TOLLID] + opvmt
	total_cvmt_op[TOLLID] = total_cvmt_op[TOLLID] + opcvmt
	ttime_op[TOLLID] = ttime_op[TOLLID] + opttimeHL ; tollid travel time averaged at link level by time period
	;avg_speed_op[TOLLID] = ave(avg_speed_op[TOLLID],opspeedHL) ;average daily link speed
	max_vc_op[TOLLID] = max(max_vc_op[TOLLID],maxvc_op)
	IF (minvc_op>0)
	  min_vc_op[TOLLID] = min(min_vc_op[TOLLID],minvc_op)
	ENDIF
	
	;for long summary	
	toll_price_07da[TOLLID] = toll_price_07da[TOLLID] + h07_Tollda
	toll_price_08da[TOLLID] = toll_price_08da[TOLLID] + h08_Tollda
	toll_price_09da[TOLLID] = toll_price_09da[TOLLID] + h09_Tollda
	toll_price_mdda[TOLLID] = toll_price_mdda[TOLLID] + md5_Tollda
	toll_price_15da[TOLLID] = toll_price_15da[TOLLID] + h15_Tollda
	toll_price_16da[TOLLID] = toll_price_16da[TOLLID] + h16_Tollda
	toll_price_17da[TOLLID] = toll_price_17da[TOLLID] + h17_Tollda
	toll_price_evda[TOLLID] = toll_price_evda[TOLLID] + ev2_Tollda
	toll_price_nida[TOLLID] = toll_price_nida[TOLLID] + n11_Tollda
	
	toll_price_07s2[TOLLID] = toll_price_07s2[TOLLID] + h07_Tolls2
	toll_price_08s2[TOLLID] = toll_price_08s2[TOLLID] + h08_Tolls2
	toll_price_09s2[TOLLID] = toll_price_09s2[TOLLID] + h09_Tolls2
	toll_price_mds2[TOLLID] = toll_price_mds2[TOLLID] + md5_Tolls2
	toll_price_15s2[TOLLID] = toll_price_15s2[TOLLID] + h15_Tolls2
	toll_price_16s2[TOLLID] = toll_price_16s2[TOLLID] + h16_Tolls2
	toll_price_17s2[TOLLID] = toll_price_17s2[TOLLID] + h17_Tolls2
	toll_price_evs2[TOLLID] = toll_price_evs2[TOLLID] + ev2_Tolls2
	toll_price_nis2[TOLLID] = toll_price_nis2[TOLLID] + n11_Tolls2
	
	toll_price_07s3[TOLLID] = toll_price_07s3[TOLLID] + h07_Tolls3
	toll_price_08s3[TOLLID] = toll_price_08s3[TOLLID] + h08_Tolls3
	toll_price_09s3[TOLLID] = toll_price_09s3[TOLLID] + h09_Tolls3
	toll_price_mds3[TOLLID] = toll_price_mds3[TOLLID] + md5_Tolls3
	toll_price_15s3[TOLLID] = toll_price_15s3[TOLLID] + h15_Tolls3
	toll_price_16s3[TOLLID] = toll_price_16s3[TOLLID] + h16_Tolls3
	toll_price_17s3[TOLLID] = toll_price_17s3[TOLLID] + h17_Tolls3
	toll_price_evs3[TOLLID] = toll_price_evs3[TOLLID] + ev2_Tolls3
	toll_price_nis3[TOLLID] = toll_price_nis3[TOLLID] + n11_Tolls3
	
	toll_price_07cv[TOLLID] = toll_price_07cv[TOLLID] + h07_Tollcv
	toll_price_08cv[TOLLID] = toll_price_08cv[TOLLID] + h08_Tollcv
	toll_price_09cv[TOLLID] = toll_price_09cv[TOLLID] + h09_Tollcv
	toll_price_mdcv[TOLLID] = toll_price_mdcv[TOLLID] + md5_Tollcv
	toll_price_15cv[TOLLID] = toll_price_15cv[TOLLID] + h15_Tollcv
	toll_price_16cv[TOLLID] = toll_price_16cv[TOLLID] + h16_Tollcv
	toll_price_17cv[TOLLID] = toll_price_17cv[TOLLID] + h17_Tollcv
	toll_price_evcv[TOLLID] = toll_price_evcv[TOLLID] + ev2_Tollcv
	toll_price_nicv[TOLLID] = toll_price_nicv[TOLLID] + n11_Tollcv
	
	;Travel Time Hot Lane
	ttime_h07HL[TOLLID] = ttime_h07HL[TOLLID] + h07ttimeHL
	ttime_h08HL[TOLLID] = ttime_h08HL[TOLLID] + h08ttimeHL
	ttime_h09HL[TOLLID] = ttime_h09HL[TOLLID] + h09ttimeHL
	ttime_md5HL[TOLLID] = ttime_md5HL[TOLLID] + md5ttimeHL
	ttime_h15HL[TOLLID] = ttime_h15HL[TOLLID] + h15ttimeHL
	ttime_h16HL[TOLLID] = ttime_h16HL[TOLLID] + h16ttimeHL
	ttime_h17HL[TOLLID] = ttime_h17HL[TOLLID] + h17ttimeHL
	ttime_ev2HL[TOLLID] = ttime_ev2HL[TOLLID] + ev2ttimeHL
	ttime_n11HL[TOLLID] = ttime_n11HL[TOLLID] + n11ttimeHL
	
	;VMT HL Lanes
	VMT_h07HL[TOLLID] = VMT_h07HL[TOLLID] + h07VMT
	VMT_h08HL[TOLLID] = VMT_h08HL[TOLLID] + h08VMT
	VMT_h09HL[TOLLID] = VMT_h09HL[TOLLID] + h09VMT
	VMT_md5HL[TOLLID] = VMT_md5HL[TOLLID] + md5VMT
	VMT_h15HL[TOLLID] = VMT_h15HL[TOLLID] + h15VMT
	VMT_h16HL[TOLLID] = VMT_h16HL[TOLLID] + h16VMT
	VMT_h17HL[TOLLID] = VMT_h17HL[TOLLID] + h17VMT
	VMT_ev2HL[TOLLID] = VMT_ev2HL[TOLLID] + ev2VMT
	VMT_n11HL[TOLLID] = VMT_n11HL[TOLLID] + n11VMT
	;CVMT HL Lanes 
	CVMT_h07HL[TOLLID] = CVMT_h07HL[TOLLID] + h07CVMT
	CVMT_h08HL[TOLLID] = CVMT_h08HL[TOLLID] + h08CVMT
	CVMT_h09HL[TOLLID] = CVMT_h09HL[TOLLID] + h09CVMT
	CVMT_md5HL[TOLLID] = CVMT_md5HL[TOLLID] + md5CVMT
	CVMT_h15HL[TOLLID] = CVMT_h15HL[TOLLID] + h15CVMT
	CVMT_h16HL[TOLLID] = CVMT_h16HL[TOLLID] + h16CVMT
	CVMT_h17HL[TOLLID] = CVMT_h17HL[TOLLID] + h17CVMT
	CVMT_ev2HL[TOLLID] = CVMT_ev2HL[TOLLID] + ev2CVMT
	CVMT_n11HL[TOLLID] = CVMT_n11HL[TOLLID] + n11CVMT
	
	;GP Lanes Toll
	tl_h07_daTolGP[TOLLID] = tl_h07_daTolGP[TOLLID] + h07_daTolGP
	tl_h08_daTolGP[TOLLID] = tl_h08_daTolGP[TOLLID] + h08_daTolGP
	tl_h09_daTolGP[TOLLID] = tl_h09_daTolGP[TOLLID] + h09_daTolGP
	tl_md5_daTolGP[TOLLID] = tl_md5_daTolGP[TOLLID] + md5_daTolGP
	tl_h15_daTolGP[TOLLID] = tl_h15_daTolGP[TOLLID] + h15_daTolGP
	tl_h16_daTolGP[TOLLID] = tl_h16_daTolGP[TOLLID] + h16_daTolGP
	tl_h17_daTolGP[TOLLID] = tl_h17_daTolGP[TOLLID] + h17_daTolGP
	tl_ev2_daTolGP[TOLLID] = tl_ev2_daTolGP[TOLLID] + ev2_daTolGP
	tl_n11_daTolGP[TOLLID] = tl_n11_daTolGP[TOLLID] + n11_daTolGP

	;HOV Lanes Toll
	tl_h07_daTolHL[TOLLID] = tl_h07_daTolHL[TOLLID] + h07_daTolHL
	tl_h08_daTolHL[TOLLID] = tl_h08_daTolHL[TOLLID] + h08_daTolHL
	tl_h09_daTolHL[TOLLID] = tl_h09_daTolHL[TOLLID] + h09_daTolHL
	tl_md5_daTolHL[TOLLID] = tl_md5_daTolHL[TOLLID] + md5_daTolHL
	tl_h15_daTolHL[TOLLID] = tl_h15_daTolHL[TOLLID] + h15_daTolHL
	tl_h16_daTolHL[TOLLID] = tl_h16_daTolHL[TOLLID] + h16_daTolHL
	tl_h17_daTolHL[TOLLID] = tl_h17_daTolHL[TOLLID] + h17_daTolHL
	tl_ev2_daTolHL[TOLLID] = tl_ev2_daTolHL[TOLLID] + ev2_daTolHL
	tl_n11_daTolHL[TOLLID] = tl_n11_daTolHL[TOLLID] + n11_daTolHL

	;Aux Lanes Toll
	tl_h07_daTolAL[TOLLID] = tl_h07_daTolAL[TOLLID] + h07_daTolAL
	tl_h08_daTolAL[TOLLID] = tl_h08_daTolAL[TOLLID] + h08_daTolAL
	tl_h09_daTolAL[TOLLID] = tl_h09_daTolAL[TOLLID] + h09_daTolAL
	tl_md5_daTolAL[TOLLID] = tl_md5_daTolAL[TOLLID] + md5_daTolAL
	tl_h15_daTolAL[TOLLID] = tl_h15_daTolAL[TOLLID] + h15_daTolAL
	tl_h16_daTolAL[TOLLID] = tl_h16_daTolAL[TOLLID] + h16_daTolAL
	tl_h17_daTolAL[TOLLID] = tl_h17_daTolAL[TOLLID] + h17_daTolAL
	tl_ev2_daTolAL[TOLLID] = tl_ev2_daTolAL[TOLLID] + ev2_daTolAL
	tl_n11_daTolAL[TOLLID] = tl_n11_daTolAL[TOLLID] + n11_daTolAL
	
	;GP Lanes Revenue
	tl_h07_daRevGP[TOLLID] = tl_h07_daRevGP[TOLLID] + h07_daRevGP
	tl_h08_daRevGP[TOLLID] = tl_h08_daRevGP[TOLLID] + h08_daRevGP
	tl_h09_daRevGP[TOLLID] = tl_h09_daRevGP[TOLLID] + h09_daRevGP
	tl_md5_daRevGP[TOLLID] = tl_md5_daRevGP[TOLLID] + md5_daRevGP
	tl_h15_daRevGP[TOLLID] = tl_h15_daRevGP[TOLLID] + h15_daRevGP
	tl_h16_daRevGP[TOLLID] = tl_h16_daRevGP[TOLLID] + h16_daRevGP
	tl_h17_daRevGP[TOLLID] = tl_h17_daRevGP[TOLLID] + h17_daRevGP
	tl_ev2_daRevGP[TOLLID] = tl_ev2_daRevGP[TOLLID] + ev2_daRevGP
	tl_n11_daRevGP[TOLLID] = tl_n11_daRevGP[TOLLID] + n11_daRevGP

	;HOV Lanes Revenue
	tl_h07_daRevHL[TOLLID] = tl_h07_daRevHL[TOLLID] + h07_daRevHL
	tl_h08_daRevHL[TOLLID] = tl_h08_daRevHL[TOLLID] + h08_daRevHL
	tl_h09_daRevHL[TOLLID] = tl_h09_daRevHL[TOLLID] + h09_daRevHL
	tl_md5_daRevHL[TOLLID] = tl_md5_daRevHL[TOLLID] + md5_daRevHL
	tl_h15_daRevHL[TOLLID] = tl_h15_daRevHL[TOLLID] + h15_daRevHL
	tl_h16_daRevHL[TOLLID] = tl_h16_daRevHL[TOLLID] + h16_daRevHL
	tl_h17_daRevHL[TOLLID] = tl_h17_daRevHL[TOLLID] + h17_daRevHL
	tl_ev2_daRevHL[TOLLID] = tl_ev2_daRevHL[TOLLID] + ev2_daRevHL
	tl_n11_daRevHL[TOLLID] = tl_n11_daRevHL[TOLLID] + n11_daRevHL

	;Aux Lanes Revenue
	tl_h07_daRevAL[TOLLID] = tl_h07_daRevAL[TOLLID] + h07_daRevAL
	tl_h08_daRevAL[TOLLID] = tl_h08_daRevAL[TOLLID] + h08_daRevAL
	tl_h09_daRevAL[TOLLID] = tl_h09_daRevAL[TOLLID] + h09_daRevAL
	tl_md5_daRevAL[TOLLID] = tl_md5_daRevAL[TOLLID] + md5_daRevAL
	tl_h15_daRevAL[TOLLID] = tl_h15_daRevAL[TOLLID] + h15_daRevAL
	tl_h16_daRevAL[TOLLID] = tl_h16_daRevAL[TOLLID] + h16_daRevAL
	tl_h17_daRevAL[TOLLID] = tl_h17_daRevAL[TOLLID] + h17_daRevAL
	tl_ev2_daRevAL[TOLLID] = tl_ev2_daRevAL[TOLLID] + ev2_daRevAL
	tl_n11_daRevAL[TOLLID] = tl_n11_daRevAL[TOLLID] + n11_daRevAL
	
  ;ENDIF
  ;IF (GPID > 0)
	;Daily
	total_rev_dyGP[GPID] = total_rev_dyGP[GPID] + dy_Rev
	total_vol_dyGP[GPID] = total_vol_dyGP[GPID] + dyv
  	total_vmt_dyGP[GPID] = total_vmt_dyGP[GPID] + dayvmt
	total_cvmt_dyGP[GPID] = total_cvmt_dyGP[GPID] + daycvmt
	ttime_dyGP[GPID] = ttime_dyGP[GPID] + dayttimeGP
	;avg_speed_dyGP[GPID] = ave(avg_speed_dyGP[GPID],dayspeedGP)
	max_speed_dyGP[GPID] = max(max_speed_dyGP[GPID],dayspeedGPmx)
	IF (dayspeedGP > 0)
	  min_speed_dyGP[GPID] = min(min_speed_dyGP[GPID],dayspeedGPmn)
	ENDIF
	max_vc_dyGP[GPID] = max(max_vc_dyGP[GPID],maxvc_dy)
	IF (minvc_dy > 0) 
	  min_vc_dyGP[GPID] = min(min_vc_dyGP[GPID],minvc_dy)
	ENDIF
  
  	;Travel Time GP Lanes
	ttime_h07GP[GPID] = ttime_h07GP[GPID] + h07ttimeGP
	ttime_h08GP[GPID] = ttime_h08GP[GPID] + h08ttimeGP
	ttime_h09GP[GPID] = ttime_h09GP[GPID] + h09ttimeGP
	ttime_md5GP[GPID] = ttime_md5GP[GPID] + md5ttimeGP
	ttime_h15GP[GPID] = ttime_h15GP[GPID] + h15ttimeGP
	ttime_h16GP[GPID] = ttime_h16GP[GPID] + h16ttimeGP
	ttime_h17GP[GPID] = ttime_h17GP[GPID] + h17ttimeGP
	ttime_ev2GP[GPID] = ttime_ev2GP[GPID] + ev2ttimeGP
	ttime_n11GP[GPID] = ttime_n11GP[GPID] + n11ttimeGP

	;VMT GP Lanes
	VMT_h07GP[GPID] = VMT_h07GP[GPID] + h07VMT
	VMT_h08GP[GPID] = VMT_h08GP[GPID] + h08VMT
	VMT_h09GP[GPID] = VMT_h09GP[GPID] + h09VMT
	VMT_md5GP[GPID] = VMT_md5GP[GPID] + md5VMT
	VMT_h15GP[GPID] = VMT_h15GP[GPID] + h15VMT
	VMT_h16GP[GPID] = VMT_h16GP[GPID] + h16VMT
	VMT_h17GP[GPID] = VMT_h17GP[GPID] + h17VMT
	VMT_ev2GP[GPID] = VMT_ev2GP[GPID] + ev2VMT
	VMT_n11GP[GPID] = VMT_n11GP[GPID] + n11VMT	

	;CVMT GP Lanes
	CVMT_h07GP[GPID] = CVMT_h07GP[GPID] + h07CVMT
	CVMT_h08GP[GPID] = CVMT_h08GP[GPID] + h08CVMT
	CVMT_h09GP[GPID] = CVMT_h09GP[GPID] + h09CVMT
	CVMT_md5GP[GPID] = CVMT_md5GP[GPID] + md5CVMT
	CVMT_h15GP[GPID] = CVMT_h15GP[GPID] + h15CVMT
	CVMT_h16GP[GPID] = CVMT_h16GP[GPID] + h16CVMT
	CVMT_h17GP[GPID] = CVMT_h17GP[GPID] + h17CVMT
	CVMT_ev2GP[GPID] = CVMT_ev2GP[GPID] + ev2CVMT
	CVMT_n11GP[GPID] = CVMT_n11GP[GPID] + n11CVMT

	
  ;ENDIF
  
endphase	
	LOG PREFIX=network, VAR=_numseg
	LOG VAR = _numseg
	

phase = SUMMARY
	;headers
	 PRINT CSV=T LIST='tollid, toll_rev_dy, toll_rev_dyda,toll_rev_dysd2,toll_rev_dysd3, toll_rev_dycv,total_vol_dy, total_vol_dyda, total_vol_dysd2,total_vol_dysd3, total_vol_dycv,tseg_length, tseg_count' PRINTO=1
	 
	 PRINT CSV=T LIST='tollid, toll_rev_pk, toll_rev_pkda,toll_rev_pksd2,toll_rev_pksd3, toll_rev_pkcv,toll_rev_op, toll_rev_opda,toll_rev_opsd2,toll_rev_opsd3, toll_rev_opcv,total_vol_pk, total_vol_pkda, total_vol_pksd2,total_vol_pksd3, total_vol_pkcv,total_vol_op, total_vol_opda, total_vol_opsd2,total_vol_opsd3, total_vol_opcv,tseg_length,tseg_count' PRINTO=2
	 
	 PRINT CSV=T LIST='tollid, toll_rev_dy, toll_rev_dyda,toll_rev_dysd2,toll_rev_dysd3, toll_rev_dycv, ,total_vol_dy, total_vol_dyda, total_vol_dysd2,total_vol_dysd3, total_vol_dycv, , toll_rev_pk,toll_rev_pkda,toll_rev_pksd2,toll_rev_pksd3,toll_rev_pkcv, ,total_vol_pk,total_vol_pkda,total_vol_pksd2,total_vol_pksd3,total_vol_pkcv, ,toll_rev_op,toll_rev_opda,toll_rev_opsd2,toll_rev_opsd3,toll_rev_opcv, ,total_vol_op,total_vol_opda,total_vol_opsd2,total_vol_opsd3,total_vol_opcv, ,tseg_length, tseg_count, , tp_07da,tp_08da,tp_09da,tp_mdda,tp_15da,tp_16da,tp_17da,tp_evda,tp_nida, ,tp_07sd2,tp_08sd2,tp_09sd2,tp_mdsd2,tp_15sd2,tp_16sd2,tp_17sd2,tp_evsd2,tp_nisd2, ,tp_07sd3,tp_08sd3,tp_09sd3,tp_mdsd3,tp_15sd3,tp_16sd3,tp_17sd3,tp_evsd3,tp_nisd3, ,tp_07cv,tp_08cv,tp_09cv,tp_mdcv,tp_15cv,tp_16cv,tp_17cv,tp_evcv,tp_nicv' PRINTO=3
	 
	 PRINT CSV=T LIST='tollid,h07_daTolGP,h08_daTolGP,h09_daTolGP,md5_daTolGP,h15_daTolGP,h16_daTolGP,h17_daTolGP,ev2_daTolGP,n11_daTolGP, ,h07_daTolHL,h08_daTolHL,h09_daTolHL,md5_daTolHL,h15_daTolHL,h16_daTolHL,h17_daTolHL,ev2_daTolHL,n11_daTolHL, ,h07_daTolAL,h08_daTolAL,h09_daTolAL,md5_daTolAL,h15_daTolAL,h16_daTolAL,h17_daTolAL,ev2_daTolAL,n11_daTolAL, ,h07_daRevGP,h08_daRevGP,h09_daRevGP,md5_daRevGP,h15_daRevGP,h16_daRevGP,h17_daRevGP,ev2_daRevGP,n11_daRevGP, ,h07_daRevHL,h08_daRevHL,h09_daRevHL,md5_daRevHL,h15_daRevHL,h16_daRevHL,h17_daRevHL,ev2_daRevHL,n11_daRevHL, ,h07_daRevAL,h08_daRevAL,h09_daRevAL,md5_daRevAL,h15_daRevAL,h16_daRevAL,h17_daRevAL,ev2_daRevAL,n11_daRevAL' PRINTO=4
	 
	 PRINT CSV=T LIST='tollid,toll_rev_dy,total_vol_dy,total_vmt_dy,total_cvmt_dy,ttime_dy,max_speed_dy,min_speed_dy,max_vc_dy,min_vc_dy, ,toll_rev_pk,total_vol_pk,total_vmt_pk,total_cvmt_pk,total_time_pk,max_vc_pk,min_vc_pk,,toll_rev_op,total_vol_op,total_vmt_op,total_cvmt_op,total_time_op,max_vc_op,min_vc_op,,ttime_h07HL,ttime_h08HL,ttime_h09HL,ttime_md5HL,ttime_h15HL,ttime_h16HL,ttime_h17HL,ttime_ev2HL,ttime_n11HL,,				  VMT_h07HL,VMT_h08HL,VMT_h09HL,VMT_md5HL,VMT_h15HL,VMT_h16HL,VMT_h17HL,VMT_ev2HL,VMT_n11HL,,				  CVMT_h07HL,CVMT_h08HL,CVMT_h09HL,CVMT_md5HL,CVMT_h15HL,CVMT_h16HL,CVMT_h17HL,CVMT_ev2HL,CVMT_n11HL,,				  toll_rev_dyGP,total_vol_dyGP,total_vmt_dyGP,total_cvmt_dyGP,ttime_dyGP,max_speed_dyGP,min_speed_dyGP,max_vc_dyGP,min_vc_dyGP,,				  ttime_h07GP,ttime_h08GP,ttime_h09GP,ttime_md5GP,ttime_h15GP,ttime_h16GP,ttime_h17GP,ttime_ev2GP,ttime_n11GP,,				  VMT_h07GP,VMT_h08GP,VMT_h09GP,VMT_md5GP,VMT_h15GP,VMT_h16GP,VMT_h17GP,VMT_ev2GP,VMT_n11GP,,				  CVMT_h07GP,CVMT_h08GP,CVMT_h09GP,CVMT_md5GP,CVMT_h15GP,CVMT_h16GP,CVMT_h17GP,CVMT_ev2GP,CVMT_n11GP' PRINTO=5
				  
	 PRINT CSV=T LIST='tollid,toll_rev_dy,total_vol_dy,total_vmt_dy,total_cvmt_dy,ttime_dy,max_speed_dy,min_speed_dy,max_vc_dy,min_vc_dy,toll_rev_pk,total_vol_pk,total_vmt_pk,total_cvmt_pk,total_time_pk,max_vc_pk,min_vc_pk,toll_rev_op,total_vol_op,total_vmt_op,total_cvmt_op,total_time_op,max_vc_op,min_vc_op,ttime_h07HL,ttime_h08HL,ttime_h09HL,ttime_md5HL,ttime_h15HL,ttime_h16HL,ttime_h17HL,ttime_ev2HL,ttime_n11HL,VMT_h07HL,VMT_h08HL,VMT_h09HL,VMT_md5HL,VMT_h15HL,VMT_h16HL,VMT_h17HL,VMT_ev2HL,VMT_n11HL,CVMT_h07HL,CVMT_h08HL,CVMT_h09HL,CVMT_md5HL,CVMT_h15HL,CVMT_h16HL,CVMT_h17HL,CVMT_ev2HL,CVMT_n11HL,toll_rev_dyGP,total_vol_dyGP,total_vmt_dyGP,total_cvmt_dyGP,ttime_dyGP,max_speed_dyGP,min_speed_dyGP,max_vc_dyGP,min_vc_dyGP,ttime_h07GP,ttime_h08GP,ttime_h09GP,ttime_md5GP,ttime_h15GP,ttime_h16GP,ttime_h17GP,ttime_ev2GP,ttime_n11GP,VMT_h07GP,VMT_h08GP,VMT_h09GP,VMT_md5GP,VMT_h15GP,VMT_h16GP,VMT_h17GP,VMT_ev2GP,VMT_n11GP,CVMT_h07GP,CVMT_h08GP,CVMT_h09GP,CVMT_md5GP,CVMT_h15GP,CVMT_h16GP,CVMT_h17GP,CVMT_ev2GP,CVMT_n11GP,toll_rev_dyda,toll_rev_dysd2,toll_rev_dysd3,toll_rev_dycv,total_vol_dyda,total_vol_dysd2,total_vol_dysd3,total_vol_dycv,toll_rev_pkda,toll_rev_pksd2,toll_rev_pksd3,toll_rev_pkcv,total_vol_pkda,total_vol_pksd2,total_vol_pksd3,total_vol_pkcv,toll_rev_opda,toll_rev_opsd2,toll_rev_opsd3,toll_rev_opcv,total_vol_opda,total_vol_opsd2,total_vol_opsd3,total_vol_opcv,tseg_length,tseg_count,tp_07da,tp_08da,tp_09da,tp_mdda,tp_15da,tp_16da,tp_17da,tp_evda,tp_nida,tp_07sd2,tp_08sd2,tp_09sd2,tp_mdsd2,tp_15sd2,tp_16sd2,tp_17sd2,tp_evsd2,tp_nisd2,tp_07sd3,tp_08sd3,tp_09sd3,tp_mdsd3,tp_15sd3,tp_16sd3,tp_17sd3,tp_evsd3,tp_nisd3,tp_07cv,tp_08cv,tp_09cv,tp_mdcv,tp_15cv,tp_16cv,tp_17cv,tp_evcv,tp_nicv,h07_daTolGP,h08_daTolGP,h09_daTolGP,md5_daTolGP,h15_daTolGP,h16_daTolGP,h17_daTolGP,ev2_daTolGP,n11_daTolGP,h07_daTolHL,h08_daTolHL,h09_daTolHL,md5_daTolHL,h15_daTolHL,h16_daTolHL,h17_daTolHL,ev2_daTolHL,n11_daTolHL,h07_daTolAL,h08_daTolAL,h09_daTolAL,md5_daTolAL,h15_daTolAL,h16_daTolAL,h17_daTolAL,ev2_daTolAL,n11_daTolAL,h07_daRevGP,h08_daRevGP,h09_daRevGP,md5_daRevGP,h15_daRevGP,h16_daRevGP,h17_daRevGP,ev2_daRevGP,n11_daRevGP,h07_daRevHL,h08_daRevHL,h09_daRevHL,md5_daRevHL,h15_daRevHL,h16_daRevHL,h17_daRevHL,ev2_daRevHL,n11_daRevHL,h07_daRevAL,h08_daRevAL,h09_daRevAL,md5_daRevAL,h15_daRevAL,h16_daRevAL,h17_daRevAL,ev2_daRevAL,n11_daRevAL' PRINTO=6
				
  LOOP _segment=0,_numseg;@network._numseg@	
	IF (_segment > 0)	;toll segments only
	PRINT CSV=T LIST=_segment, toll_rev_dy[_segment], toll_rev_dyda[_segment],toll_rev_dysd2[_segment] ,
								toll_rev_dysd3[_segment], toll_rev_dycv[_segment],
								total_vol_dy[_segment], total_vol_dyda[_segment], total_vol_dysd2[_segment],
								total_vol_dysd3[_segment], total_vol_dycv[_segment],
								tseg_length[_segment], tseg_count[_segment]	PRINTO=1
								
	PRINT CSV=T LIST=_segment, toll_rev_pk[_segment], toll_rev_pkda[_segment],toll_rev_pksd2[_segment] ,
								toll_rev_pksd3[_segment], toll_rev_pkcv[_segment],
								toll_rev_op[_segment], toll_rev_opda[_segment],toll_rev_opsd2[_segment] ,
								toll_rev_opsd3[_segment], toll_rev_opcv[_segment],
								total_vol_pk[_segment], total_vol_pkda[_segment], total_vol_pksd2[_segment],
								total_vol_pksd3[_segment], total_vol_pkcv[_segment],
								total_vol_op[_segment], total_vol_opda[_segment], total_vol_opsd2[_segment],
								total_vol_opsd3[_segment], total_vol_opcv[_segment],
								tseg_length[_segment], tseg_count[_segment]	PRINTO=2
								
	PRINT CSV=T LIST=_segment, toll_rev_dy[_segment], toll_rev_dyda[_segment],toll_rev_dysd2[_segment],toll_rev_dysd3[_segment], toll_rev_dycv[_segment],'',
								total_vol_dy[_segment], total_vol_dyda[_segment], total_vol_dysd2[_segment],total_vol_dysd3[_segment], total_vol_dycv[_segment],'',
								toll_rev_pk[_segment], toll_rev_pkda[_segment],toll_rev_pksd2[_segment],toll_rev_pksd3[_segment], toll_rev_pkcv[_segment],'',
								total_vol_pk[_segment], total_vol_pkda[_segment], total_vol_pksd2[_segment],total_vol_pksd3[_segment], total_vol_pkcv[_segment],'',
								toll_rev_op[_segment], toll_rev_opda[_segment],toll_rev_opsd2[_segment],toll_rev_opsd3[_segment], toll_rev_opcv[_segment],'',
								total_vol_op[_segment], total_vol_opda[_segment], total_vol_opsd2[_segment],total_vol_opsd3[_segment], total_vol_opcv[_segment],'',
								tseg_length[_segment], tseg_count[_segment],'',
								toll_price_07da[_segment],toll_price_08da[_segment],toll_price_09da[_segment],
								toll_price_mdda[_segment],toll_price_15da[_segment],toll_price_16da[_segment],
								toll_price_17da[_segment],toll_price_evda[_segment],toll_price_nida[_segment],'',
								toll_price_07s2[_segment],toll_price_08s2[_segment],toll_price_09s2[_segment],
								toll_price_mds2[_segment],toll_price_15s2[_segment],toll_price_16s2[_segment],
								toll_price_17s2[_segment],toll_price_evs2[_segment],toll_price_nis2[_segment],'',
								toll_price_07s3[_segment],toll_price_08s3[_segment],toll_price_09s3[_segment],
								toll_price_mds3[_segment],toll_price_15s3[_segment],toll_price_16s3[_segment],
								toll_price_17s3[_segment],toll_price_evs3[_segment],toll_price_nis3[_segment],'',
								toll_price_07cv[_segment],toll_price_08cv[_segment],toll_price_09cv[_segment],
								toll_price_mdcv[_segment],toll_price_15cv[_segment],toll_price_16cv[_segment],
								toll_price_17cv[_segment],toll_price_evcv[_segment],toll_price_nicv[_segment] 	PRINTO=3

	PRINT CSV=T LIST=_segment, tl_h07_daTolGP[_segment],tl_h08_daTolGP[_segment],tl_h09_daTolGP[_segment],
								tl_md5_daTolGP[_segment],tl_h15_daTolGP[_segment],tl_h16_daTolGP[_segment],
								tl_h17_daTolGP[_segment],tl_ev2_daTolGP[_segment],tl_n11_daTolGP[_segment],'',
								tl_h07_daTolHL[_segment],tl_h08_daTolHL[_segment],tl_h09_daTolHL[_segment],
								tl_md5_daTolHL[_segment],tl_h15_daTolHL[_segment],tl_h16_daTolHL[_segment],
								tl_h17_daTolHL[_segment],tl_ev2_daTolHL[_segment],tl_n11_daTolHL[_segment],'',
								tl_h07_daTolAL[_segment],tl_h08_daTolAL[_segment],tl_h09_daTolAL[_segment],
								tl_md5_daTolAL[_segment],tl_h15_daTolAL[_segment],tl_h16_daTolAL[_segment],
								tl_h17_daTolAL[_segment],tl_ev2_daTolAL[_segment],tl_n11_daTolAL[_segment],'',			
								tl_h07_daRevGP[_segment],tl_h08_daRevGP[_segment],tl_h09_daRevGP[_segment],
								tl_md5_daRevGP[_segment],tl_h15_daRevGP[_segment],tl_h16_daRevGP[_segment],
								tl_h17_daRevGP[_segment],tl_ev2_daRevGP[_segment],tl_n11_daRevGP[_segment],'',
								tl_h07_daRevHL[_segment],tl_h08_daRevHL[_segment],tl_h09_daRevHL[_segment],
								tl_md5_daRevHL[_segment],tl_h15_daRevHL[_segment],tl_h16_daRevHL[_segment],
								tl_h17_daRevHL[_segment],tl_ev2_daRevHL[_segment],tl_n11_daRevHL[_segment],'',
								tl_h07_daRevAL[_segment],tl_h08_daRevAL[_segment],tl_h09_daRevAL[_segment],
								tl_md5_daRevAL[_segment],tl_h15_daRevAL[_segment],tl_h16_daRevAL[_segment],
								tl_h17_daRevAL[_segment],tl_ev2_daRevAL[_segment],tl_n11_daRevAL[_segment]	 	PRINTO=4
	
	PRINT CSV=T LIST=_segment, 		toll_rev_dy[_segment],total_vol_dy[_segment],total_vmt_dy[_segment],total_cvmt_dy[_segment],ttime_dy[_segment],max_speed_dy[_segment],min_speed_dy[_segment],max_vc_dy[_segment],min_vc_dy[_segment],'',
				  toll_rev_pk[_segment],total_vol_pk[_segment],total_vmt_pk[_segment],total_cvmt_pk[_segment],total_time_pk[_segment],max_vc_pk[_segment],min_vc_pk[_segment],'',
				  toll_rev_op[_segment],total_vol_op[_segment],total_vmt_op[_segment],total_cvmt_op[_segment],total_time_op[_segment],max_vc_op[_segment],min_vc_op[_segment],'',
				  ttime_h07HL[_segment],ttime_h08HL[_segment],ttime_h09HL[_segment],ttime_md5HL[_segment],ttime_h15HL[_segment],ttime_h16HL[_segment],ttime_h17HL[_segment],ttime_ev2HL[_segment],ttime_n11HL[_segment],'',
				  VMT_h07HL[_segment],VMT_h08HL[_segment],VMT_h09HL[_segment],VMT_md5HL[_segment],VMT_h15HL[_segment],VMT_h16HL[_segment],VMT_h17HL[_segment],VMT_ev2HL[_segment],VMT_n11HL[_segment],'',
				  CVMT_h07HL[_segment],CVMT_h08HL[_segment],CVMT_h09HL[_segment],CVMT_md5HL[_segment],CVMT_h15HL[_segment],CVMT_h16HL[_segment],CVMT_h17HL[_segment],CVMT_ev2HL[_segment],CVMT_n11HL,'',
				  toll_rev_dyGP[_segment],total_vol_dyGP[_segment],total_vmt_dyGP[_segment],total_cvmt_dyGP[_segment],ttime_dyGP[_segment],max_speed_dyGP[_segment],min_speed_dyGP[_segment],max_vc_dyGP[_segment],min_vc_dyGP[_segment],'',
				  ttime_h07GP[_segment],ttime_h08GP[_segment],ttime_h09GP[_segment],ttime_md5GP[_segment],ttime_h15GP[_segment],ttime_h16GP[_segment],ttime_h17GP[_segment],ttime_ev2GP[_segment],ttime_n11GP[_segment],'',
				  VMT_h07GP[_segment],VMT_h08GP[_segment],VMT_h09GP[_segment],VMT_md5GP[_segment],VMT_h15GP[_segment],VMT_h16GP[_segment],VMT_h17GP[_segment],VMT_ev2GP[_segment],VMT_n11GP[_segment],'',
				  CVMT_h07GP[_segment],CVMT_h08GP[_segment],CVMT_h09GP[_segment],CVMT_md5GP[_segment],CVMT_h15GP[_segment],CVMT_h16GP[_segment],CVMT_h17GP[_segment],CVMT_ev2GP[_segment],CVMT_n11GP[_segment] PRINTO=5
	ENDIF
	PRINT CSV=T LIST=_segment, 		toll_rev_dy[_segment],total_vol_dy[_segment],total_vmt_dy[_segment],total_cvmt_dy[_segment],ttime_dy[_segment],max_speed_dy[_segment],min_speed_dy[_segment],max_vc_dy[_segment],min_vc_dy[_segment],
				  toll_rev_pk[_segment],total_vol_pk[_segment],total_vmt_pk[_segment],total_cvmt_pk[_segment],total_time_pk[_segment],max_vc_pk[_segment],min_vc_pk[_segment],
				  toll_rev_op[_segment],total_vol_op[_segment],total_vmt_op[_segment],total_cvmt_op[_segment],total_time_op[_segment],max_vc_op[_segment],min_vc_op[_segment],
				  ttime_h07HL[_segment],ttime_h08HL[_segment],ttime_h09HL[_segment],ttime_md5HL[_segment],ttime_h15HL[_segment],ttime_h16HL[_segment],ttime_h17HL[_segment],ttime_ev2HL[_segment],ttime_n11HL[_segment],
				  VMT_h07HL[_segment],VMT_h08HL[_segment],VMT_h09HL[_segment],VMT_md5HL[_segment],VMT_h15HL[_segment],VMT_h16HL[_segment],VMT_h17HL[_segment],VMT_ev2HL[_segment],VMT_n11HL[_segment],
				  CVMT_h07HL[_segment],CVMT_h08HL[_segment],CVMT_h09HL[_segment],CVMT_md5HL[_segment],CVMT_h15HL[_segment],CVMT_h16HL[_segment],CVMT_h17HL[_segment],CVMT_ev2HL[_segment],CVMT_n11HL,
				  toll_rev_dyGP[_segment],total_vol_dyGP[_segment],total_vmt_dyGP[_segment],total_cvmt_dyGP[_segment],ttime_dyGP[_segment],max_speed_dyGP[_segment],min_speed_dyGP[_segment],max_vc_dyGP[_segment],min_vc_dyGP[_segment],
				  ttime_h07GP[_segment],ttime_h08GP[_segment],ttime_h09GP[_segment],ttime_md5GP[_segment],ttime_h15GP[_segment],ttime_h16GP[_segment],ttime_h17GP[_segment],ttime_ev2GP[_segment],ttime_n11GP[_segment],
				  VMT_h07GP[_segment],VMT_h08GP[_segment],VMT_h09GP[_segment],VMT_md5GP[_segment],VMT_h15GP[_segment],VMT_h16GP[_segment],VMT_h17GP[_segment],VMT_ev2GP[_segment],VMT_n11GP[_segment],
				  CVMT_h07GP[_segment],CVMT_h08GP[_segment],CVMT_h09GP[_segment],CVMT_md5GP[_segment],CVMT_h15GP[_segment],CVMT_h16GP[_segment],CVMT_h17GP[_segment],CVMT_ev2GP[_segment],CVMT_n11GP[_segment], 
				  
				  toll_rev_dyda[_segment],toll_rev_dysd2[_segment],toll_rev_dysd3[_segment], toll_rev_dycv[_segment],
					total_vol_dyda[_segment], total_vol_dysd2[_segment],total_vol_dysd3[_segment], total_vol_dycv[_segment],
					toll_rev_pkda[_segment],toll_rev_pksd2[_segment],toll_rev_pksd3[_segment], toll_rev_pkcv[_segment],
					total_vol_pkda[_segment], total_vol_pksd2[_segment],total_vol_pksd3[_segment], total_vol_pkcv[_segment],
					toll_rev_opda[_segment],toll_rev_opsd2[_segment],toll_rev_opsd3[_segment], toll_rev_opcv[_segment],
					total_vol_opda[_segment], total_vol_opsd2[_segment],total_vol_opsd3[_segment], total_vol_opcv[_segment],
					tseg_length[_segment], tseg_count[_segment],
					toll_price_07da[_segment],toll_price_08da[_segment],toll_price_09da[_segment],
					toll_price_mdda[_segment],toll_price_15da[_segment],toll_price_16da[_segment],
					toll_price_17da[_segment],toll_price_evda[_segment],toll_price_nida[_segment],
					toll_price_07s2[_segment],toll_price_08s2[_segment],toll_price_09s2[_segment],
					toll_price_mds2[_segment],toll_price_15s2[_segment],toll_price_16s2[_segment],
					toll_price_17s2[_segment],toll_price_evs2[_segment],toll_price_nis2[_segment],
					toll_price_07s3[_segment],toll_price_08s3[_segment],toll_price_09s3[_segment],
					toll_price_mds3[_segment],toll_price_15s3[_segment],toll_price_16s3[_segment],
					toll_price_17s3[_segment],toll_price_evs3[_segment],toll_price_nis3[_segment],
					toll_price_07cv[_segment],toll_price_08cv[_segment],toll_price_09cv[_segment],
					toll_price_mdcv[_segment],toll_price_15cv[_segment],toll_price_16cv[_segment],
					toll_price_17cv[_segment],toll_price_evcv[_segment],toll_price_nicv[_segment],
				    tl_h07_daTolGP[_segment],tl_h08_daTolGP[_segment],tl_h09_daTolGP[_segment],
					tl_md5_daTolGP[_segment],tl_h15_daTolGP[_segment],tl_h16_daTolGP[_segment],
					tl_h17_daTolGP[_segment],tl_ev2_daTolGP[_segment],tl_n11_daTolGP[_segment],
					tl_h07_daTolHL[_segment],tl_h08_daTolHL[_segment],tl_h09_daTolHL[_segment],
					tl_md5_daTolHL[_segment],tl_h15_daTolHL[_segment],tl_h16_daTolHL[_segment],
					tl_h17_daTolHL[_segment],tl_ev2_daTolHL[_segment],tl_n11_daTolHL[_segment],
					tl_h07_daTolAL[_segment],tl_h08_daTolAL[_segment],tl_h09_daTolAL[_segment],
					tl_md5_daTolAL[_segment],tl_h15_daTolAL[_segment],tl_h16_daTolAL[_segment],
					tl_h17_daTolAL[_segment],tl_ev2_daTolAL[_segment],tl_n11_daTolAL[_segment],			
					tl_h07_daRevGP[_segment],tl_h08_daRevGP[_segment],tl_h09_daRevGP[_segment],
					tl_md5_daRevGP[_segment],tl_h15_daRevGP[_segment],tl_h16_daRevGP[_segment],
					tl_h17_daRevGP[_segment],tl_ev2_daRevGP[_segment],tl_n11_daRevGP[_segment],
					tl_h07_daRevHL[_segment],tl_h08_daRevHL[_segment],tl_h09_daRevHL[_segment],
					tl_md5_daRevHL[_segment],tl_h15_daRevHL[_segment],tl_h16_daRevHL[_segment],
					tl_h17_daRevHL[_segment],tl_ev2_daRevHL[_segment],tl_n11_daRevHL[_segment],
					tl_h07_daRevAL[_segment],tl_h08_daRevAL[_segment],tl_h09_daRevAL[_segment],
					tl_md5_daRevAL[_segment],tl_h15_daRevAL[_segment],tl_h16_daRevAL[_segment],
					tl_h17_daRevAL[_segment],tl_ev2_daRevAL[_segment],tl_n11_daRevAL[_segment] PRINTO=6
	
  ENDLOOP
ENDPHASE
ENDRUN