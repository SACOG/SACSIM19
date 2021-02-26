;to test zone connectivity for zones w/ hh or empl
;
; Activate or comment-out mato 100x for auto skims special for DaySim.

; read .sup and .lin file names

;======================================================================
RUN PGM=HWYNET
        FILEI neti=?_base.net      ; input networks
        neto=temp.net
    if (capclass<99)time_1=li.1.distance/(li.1.speed)*60.0
    if (li.1.capclass=99) delete
ENDRUN
RUN PGM=HWYLOAD  msg='taz connectivity check'
; AM peak period highway skim: interzonal

NETI=temp.net                      ; input network
MATO=TEMP.mat MO=1-2 FORMAT=tpp,          ; output skim matrix
    name=datime,dadist

PHASE=LINKREAD                               ; define link groups
  IF (LI.HOVLINK=0) ADDTOGROUP=1        ;no restriction
  IF (LI.HOVLINK=1) ADDTOGROUP=2        ;walk
  IF (LI.HOVLINK=2) ADDTOGROUP=3        ;HOV lanes
  IF (LI.HOVLINK=3) ADDTOGROUP=4        ;HOV bypassses
  IF (LI.CAPCLASS==99) ADDTOGROUP=5        ;HOV bypassses  
endphase

PHASE=ILOOP                                  ; skim path building
    PATHLOAD PATH=li.TIME_1,EXCLUDEGRP=2-5,         ; pathload without HOV links
       MW[1]=pathcost, noaccess=0,
       MW[2]=PATHTRACE(LI.DISTANCE), noaccess=0
endphase
ENDRUN
run pgm=hwynet
filei neti=?_base.net
log var=_zones
endrun
;
run pgm=network
filei neti=?_base.net
log var=_zones
endrun
;
run pgm=matrix msg='get taz agg from parcel file'
; compile from parcel file for nw testing
zones=@network._zones@
;
;parcel file source
zdati[1] = ?_PARC.dbf, z=taz,
sum=HOUSESP,
    STUDK12P,
    STUDUNIP,
    EMPTOT_P
;
    jloop j=1
;
; households
mw[1] = zi.1.housesp/100
;
; Enrollment
mw[2]  = zi.1.studk12p/100  ;all in parcel data are scaled
mw[3]  = zi.1.studunip/100
;
; Employment
mw[4] = zi.1.emptot_p/100
;
endjloop
;
report marginrec=y, file=?_taz4test.txt, print=n, form=12.2, 
    list=j(5),r1,r2,r3,r4
; Fields are:
; 1  zone
; 2  households
; 3  k-12 students
; 4  univ students
endrun
;
run pgm=matrix
filei mati[1]=temp.mat
;zdati[1]=?_parc.dbf
zdati[1] = ?_taz4test.txt, z=#1, housesp=2, studk12p=3, studunip=4, emptot_p=5
;
fileo reco[1]=?_taz_conn_check.dbf,fields=i,datime,dadist,hhempl
mw[1]=mi.1.1
mw[2]=mi.1.2
datime=rowsum(1)
dadist=rowsum(2)
hhempl=(zi.1.housesp+zi.1.emptot_p+zi.1.studk12p+zi.1.studunip+1)
if (hhempl>0&&datime<20)
write reco=1
endif
endrun
