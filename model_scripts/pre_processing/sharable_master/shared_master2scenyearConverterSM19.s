;======================================================================
; Name:master2scenyearConverterSM19_latest.s
; Purpose: Cut master network to scenario year
;			
; Last Updated: 8/4/2020
; Last Updated By: Kyle Shipley
;           -added 5 class ramp metering
; Previous Version: master2scenyearConverterSM19_wtolls_wAuxid.s 8/3/2020
; SACOG
;INSTRUCTIONS
; 1) Enter scenario year (yr)
; 2) Choose a pricing flag 'P' or 'B' (for 'Baseline').
;	NOTE that if you choose a scenario year before the earliest pricing year,
;	then you must set the pricing flag = 'B'
; 3) Specify file path for input master network (NETI) and where you want the output scenario-specific
;	base network to go (NETO).

; The begin_toll_year and baseline_tollflag variables generally should not be changed.
;======================================================================

;input
yr = '27' ;enter two digit sceanrio year ex: 2016 = 16--but might have to include other prefix (e.g. 'ds_40')
pricing_flag = 'B' ; Used to compute correct useclass for tolled facilities. 'B' = baseline, non-pricing scenario -- 'P' = priced/tolled scenario

begin_toll_year = '35' ; year at which tolling may take effect. This should not be changed except during MTP updates
baseline_tollflag = 'B' ; always the flag that represents baseline, or non-pricing scenario useclass.


RUN PGM=HWYNET
FILEI NETI[1]="\\data-svr\Modeling\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\test_sharable_net.net"

FILEO NETO="\\data-svr\Modeling\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\?_base.net" include=
A B DISTANCE RAD NAME SCREEN CAPCLASS,
LANES SPEED SPDCURV HOVLINK,
TOLLID GPID AUXID,
USECLASS DELCURV,
BIKE SACTRAK CS FWYID COUNTID TRAV_DIR HWYSEG,
C05DYD,C08DYD,C12DYD,C16DYD
;
;globally set capc, lanes,tsva,hovlink, delcurv, spdcurv
CAPCLASS=LI.1.CAPC@yr@

; 2/4/2021: tolling flag only applies for years 2035 and 2040
IF (@yr@ >= @begin_toll_year@)
	USECLASS=LI.1.USECLASS@yr@@pricing_flag@
ELSE
	USECLASS=LI.1.USECLASS@yr@@baseline_tollflag@
ENDIF
	
HOVLINK=0
DELCURV=0
SPDCURV=3

LANES=LI.1.LANE@yr@
SPEED=LI.1.SPD@yr@
BIKE=LI.1.BIKE@yr@

;
;reset freeway hov lanes
    if (LI.1.CAPC@yr@=8)
       HOVLINK=2
    endif

;code metered ramps classes (revised from sacmet convension)
    ;am
	IF (LI.1.CAPC@yr@=31)
       CAPCLASS=6
       DELCURV=1
    ENDIF
	;pm
    IF (LI.1.CAPC@yr@=32)
       CAPCLASS=6
       DELCURV=2
    ENDIF
	;am pm
    IF (LI.1.CAPC@yr@=33)
       CAPCLASS=6
       DELCURV=3
    ENDIF
	;am midday pm
    IF (LI.1.CAPC@yr@=34)
       CAPCLASS=6
       DELCURV=4
    ENDIF
	;all day
    IF (LI.1.CAPC@yr@=35)
       CAPCLASS=6
       DELCURV=5
    ENDIF
;
;reset hov bypass ramps
    IF (LI.1.CAPC@yr@=30)
       CAPCLASS=8
       HOVLINK=3
    ENDIF
;
;reset mf-hov lane connectors
    IF (LI.1.CAPC@yr@=9)
       HOVLINK=2
       SPDCURV=1
    ENDIF
;    
;reset walk links
    IF (LI.1.CAPC@yr@=7)
       HOVLINK=1
    ENDIF
;
;code spdcurv values (default = 3, set earlier)
    IF(LI.1.CAPC@YR@=22,24)
       SPDCURV=2
    ENDIF
    IF(LI.1.CAPC@YR@=1,8)
       SPDCURV=1
    ENDIF
;
;code separate spdcurv for aux lanes
    IF(LI.1.CAPC@YR@=51,56)
       SPDCURV=1
    ENDIF
ENDRUN
