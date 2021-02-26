;======================================================================
; Name:master2scenyearConverterSM19_latest.s
; Purpose: Cut master network to scenario year
;			
; Last Updated: 8/4/2020
; Last Updated By: Kyle Shipley
;           -added 5 class ramp metering
; Previous Version: master2scenyearConverterSM19_wtolls_wAuxid.s 8/3/2020
; SACOG
;======================================================================

;input
yr = '40_DPS' ;enter two digit sceanrio year ex: 2016 = 16--but might have to include other prefix (e.g. 'ds_40')

RUN PGM=HWYNET
 ;       FILEI linki[1]=master_link_sm15.dbf
 ;         nodei[1]=master_node_sm15.dbf
 ;         zones=1533
FILEI neti[1]="Q:\SACSIM19\2020MTP\highway\network update\Project Coding\masterSM19ProjCoding_latest.net"

fileo neto="Q:\SACSIM19\2020MTP\transit\Transit Model Inputs\2040\TranInputs2040_latest\?_base.net" include=a,b,distance,rad,name,screen,capclass,lanes,speed,spdcurv,hovlink,TOLLID,GPID,AUXID,USECLASS,delcurv,bike,sactrak,CS,FWYID,COUNTID,trav_dir,HWYSEG,c05dyd,c08dyd,c12dyd,c16dyd
;
;globally set capc, lanes,tsva,hovlink, delcurv, spdcurv
capclass=li.1.capc@yr@
hovlink=0
delcurv=0
spdcurv=3

lanes=li.1.lane@yr@
speed=li.1.spd@yr@
bike=li.1.bike@yr@
CS=0
;
;reset freeway hov lanes
    if (li.1.capc@yr@=8)
       hovlink=2
    endif

;arterial hov lanes
    if (li.1.capc@yr@=33)
       hovlink=2
    endif

;code metered ramps classes (revised from sacmet convension)
    ;am
	if (li.1.capc@yr@=31)
       capclass=6
       delcurv=1
    endif
	;pm
    if (li.1.capc@yr@=32)
       capclass=6
       delcurv=2
    endif
	;am pm
    if (li.1.capc@yr@=33)
       capclass=6
       delcurv=3
    endif
	;am midday pm
    if (li.1.capc@yr@=34)
       capclass=6
       delcurv=4
    endif
	;all day
    if (li.1.capc@yr@=35)
       capclass=6
       delcurv=5
    endif
;
;reset hov bypass ramps
    if (li.1.capc@yr@=30)
       capclass=8
       hovlink=3
    endif
;
;reset mf-hov lane connectors
    if (li.1.capc@yr@=9)
       hovlink=2
       spdcurv=1
    endif
;    
;reset walk links
    if (li.1.capc@yr@=7)
       hovlink=1
    endif
;
;code spdcurv values
    if(li.1.capc@yr@=22,24)
       spdcurv=2
    endif
    if(li.1.capc@yr@=1,8)
       spdcurv=1
    endif
;
;code separate aux lanes
    if(li.1.capc@yr@=51,56)
       spdcurv=1
    endif
ENDRUN
