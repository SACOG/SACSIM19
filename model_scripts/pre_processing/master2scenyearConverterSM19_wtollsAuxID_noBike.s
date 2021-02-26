yr = '26' ;enter two digit sceanrio year ex: 2016 = 16--but might have to include other prefix (e.g. 'ds_40')
RUN PGM=HWYNET
 ;       FILEI linki[1]=master_link_sm15.dbf
 ;         nodei[1]=master_node_sm15.dbf
 ;         zones=1533
FILEI neti[1]="Q:\SACSIM19\2020MTP\highway\network update\Project Coding\masterSM19ProjCoding_latest.net"

fileo neto="\\win10-sgao\F\MTIP2021\2026\?_base.net" include=a,b,distance,rad,name,screen,capclass,lanes,speed,spdcurv,hovlink,TOLLID,GPID,AUXID,USECLASS,delcurv,bike,sactrak,CS,FWYID,COUNTID,trav_dir,HWYSEG,c05dyd,c08dyd,c12dyd,c16dyd
;
;globally set capc, lanes,tsva,hovlink, delcurv, spdcurv
capclass=li.1.capc@yr@
hovlink=0
delcurv=0
spdcurv=3

lanes=li.1.lane@yr@
speed=li.1.spd@yr@
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

;code metered ramps classes to sacmet conventions
    if (li.1.capc@yr@=36)
       capclass=6
       delcurv=1
    endif
    if (li.1.capc@yr@=46)
       capclass=6
       delcurv=2
    endif
;
;reset hov bypass ramps
    if (li.1.capc@yr@=18)
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
