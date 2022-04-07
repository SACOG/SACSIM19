/*
--------------------------------
 Name:sacsim19 DayNet.s
 Purpose: Summarize period network files to single daily network and dbf.
          
           
 Author: 
 Last Updated: 1/15/19
 Updated by: Kyle Shipley
 Copyright:   (c) SACOG
 Voyager Version:   6.1.7
--------------------------------
*/

run pgm=network  
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
fileo neto=?day_ghg.net exclude=bike,tollda,tolls2,tolls3,prevvol,prevvol,vc_1,cspd_1,
             Vdt_1,Vht_1,V1_1,V2_1,V3_1,Vt_1,V1t_1,V2t_1,V3t_1,
			 V_1,V4_1,V5_1,V6_1,V7_1,V8_1,V9_1,V10_1,V11_1,V12_1,V13_1,V14_1,V15_1,
			 V4T_1,V5T_1,V6T_1,V7T_1,V8T_1,V9T_1,V10T_1,V11T_1,V12T_1,V13T_1,V14T_1,V15T_1
      linko=?daynet_vmt.dbf format=dbf exclude=bike,tollda,tolls2,tolls3,prevvol,prevvol,vc_1,cspd_1,
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

merge record=false
endrun





