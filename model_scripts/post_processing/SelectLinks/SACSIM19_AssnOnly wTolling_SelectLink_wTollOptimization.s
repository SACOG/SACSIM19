;Based on Full SacSIM19 Script
;Select Link -Kyle Shipley
;Created : 12/17/2018
;Last update: 09/23/2020 -KS
;updated TDF TC[] to match full model
/*
INSTRUCTIONS:
  1 - create a 'select link' subfolder within model run folder
  2 - copy/paste this script and the model run's base network into the select link run folder
  3 - update the link values for the links you want to run select-link analysis on. Format follows 'Node1-Node2, Node2-Node3', etc.
  
  For non-freeway links, POSSIBLY can at some point just do asterisk (*) at end of link ID. See Cube documentation for select link analysis.
*/

;======================================================================
;inputs

;Set per-mile auto operating cost here
auto_cost_per_mile = 0.17
iter.relgap = 0.0002
AllLaneToll = 0 ;1 True, 0 False

;inputs
GPLane_SL = '9267-9321' ; format (a node - b node)
;GPLane_SL_a = 9267
;GPLane_SL_b = 9321
HOTLane_SL = '9316-9318' ; format (a node - b node)
;HOTLane_SL_a = 9316
;HOTLane_SL_b = 9318

;Base Network SL
BaseNetwork = '?_base.net'

;Speed Attribute
SpeedA = 'LI.SPEED' ;LI.<Speed for unloaded or CSPD_1 for loaded>
;======================================================================

;IFCLUSTER:
 *cluster sacsimsub 1,2,3 start exit

; Option: add "exit" after "start" to automatically proceed
; Otherwise, Cluster will pause to be checked, and await being closed to proceed.

;======================================================================
; Initialize statistics log files

*echo Time log - start RUN - preliminaries>timelog.start.txt

*echo Some convergence progress statistics>convergencestats.txt
*echo Iter SSI Period VxTold VxTnew MaxDelV MaxDelT SSq>>convergencestats.txt

*echo Full Assignment Gap Statistics>gapstats.txt
*echo Iter Period VxTnet VxTskim>>gapstats.txt

*echo Auto skim convergence statistics>skimdeltas.txt
*echo Iter Period VehTrips AvgTripLen AvgAbs RMS MaxAbs>>skimdeltas.txt

*echo Person trips from Daysim>persontripslog.txt
*echo Iter Mode Pathtype Trips>>persontripslog.txt

*echo Vehicle trips from Daysim>vehtripslog.txt
*echo Iter Period Occs-Pathtype-VOTclass Trips>>vehtripslog.txt

;======================================================================

;======================================================================
;Assign period matrices to highway network
;
*echo Begin highway assignments Iter @iter.i@>timelog.beginhwyassign.iter@iter.i@.txt

;======================================================================
IF (iter.ssi <= 0) iter.ssi=1 ;
IF (iter.i   <= 0) iter.i=1 ;

; Global parameter - number of VOT classes in assignment and skimming (1 to 3)
tolls.ntc = 3

; Declare the inverse value of time to use in skimming (dollars per minute)
tolls.ivot1 = 60/ 7.25   ;33rd percentile ; 0.1205 dollars per minute
tolls.ivot2 = 60/16.85   ;66th percentile ; 0.2808 dollars per minute
tolls.ivot3 = 60/38.80   ;90th percentile ; 0.646 dollars per minute
; etc. as many as tolls.ntc

; this block of code calculates the total length of each toll segments, which will later be used to apportion tolls to each link
RUN PGM = HWYNET  MSG='step 0 Calculate toll segment length'
 
   NETI = ?_base.net
   fileo printo[1] = tollseg_length.csv
  
   array tseg_length = 100
   array nseg_length= 100
     
   PHASE = linkmerge
   
	   LOOP _segment=1,100
	   
			IF (_segment = TOLLID) 	   
			   tseg_length[_segment] = tseg_length[_segment] + li.1.distance
			ENDIF
			IF (_segment = GPID) 	   
			   nseg_length[_segment] = nseg_length[_segment] + li.1.distance
			ENDIF
			IF ((_segment = TOLLID) && (_numseg<TOLLID))
				_numseg = TOLLID
			ENDIF

		ENDLOOP
		
	
	ENDPHASE
	
    PHASE = summary
	
	 LOOP _segment=1,100
	 
		 IF (tseg_length[_segment] > 0)
	     		absDIFfLen = ABS(tseg_length[_segment] - nseg_length[_segment])
				IF(@AllLaneToll@ > 0)
				  tseg_length[_segment] = nseg_length[_segment] ;set toll segment to GP distance
				  absDIFfLen = ABS(tseg_length[_segment] - nseg_length[_segment])
				ENDIF
				IF(absDIFfLen > 0.25) exit   ;add an error message here
	
		   PRINT CSV=T LIST=_segment, tseg_length[_segment] , nseg_length[_segment] PRINTO=1
		 ENDIF
		
	 ENDLOOP
	 
	ENDPHASE
	
	LOG PREFIX=network, VAR=_numseg
   
	LOG VAR = _numseg

ENDRUN

   ;allseg = @network._numseg@


;LOOP time period; ENDLOOP at line 239
LOOP p=1,9                       
    IF (p=01) per='h07'
    IF (p=02) per='h08'
    IF (p=03) per='h09'
    IF (p=04) per='md5'
    IF (p=05) per='h15'
    IF (p=06) per='h16'
    IF (p=07) per='h17'
    IF (p=08) per='ev2'
    IF (p=09) per='n11'

  ;----------------------------------------------------------------------
  ;step 1 initialize network and some network variables
  RUN PGM=network    MSG='step 1 Initialize network'
    ; Initialize networks for RUN
    NETI=?_base.net
    NETO=vo.@per@.net
    	; the input tolls file
		; format of tolls.csv is index(tollseg*100+per),tollseg,per,0,factype,adjust,tollda,tolls2,tolls3,tollcv
		FILEI LOOKUPI[1] = tolls.csv
		FILEI LOOKUPI[2] = tollseg_length.csv


    ; Placeholder for carryover volume
    v_1  = 0
    vt_1 = 0	
	

    ; Speed-flow curve selection
    IF (capclass=1,6,8,9,16,18,26,36,40,46,51,56)  ; Freeway or freeway ramps
        spdcurv=1
    ELSEIF (capclass=2,22,24) ; express and other highways
        spdcurv=2
    ELSE
        spdcurv=3
    ENDIF

    
	IF ((capclass=0,7,99) || speed=0)   ;walk, bike only, or switched-off link
		spdcurv=0
		time_1 = 9999 	
 	ELSE 
   		time_1 = 60*distance/li.1.speed       ;set free-flow time
    ENDIF
	
	
	 ; for the off peak periods, change HOV and HOV3 lanes to General Purpose lanes
	 
	 IF ((@p@=4) | (@p@=8) | (@p@=9))
	 
		IF ((USECLASS == 2) | (USECLASS == 3))
			USECLASS  = 4
		ENDIF
		
	 ENDIF
     
	 ; END of changing hov lanes to gp lanes for off peak periods
	
	; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ; Set up the tolls here
	;segment tolls from the tolls.csv file is read here and apportioned to each link in the segments


		; load toll values
		lookup lookupi=1, name=tolls, 
		lookup[1]=1, result=3,      ; (fac_index,period)
		lookup[2]=1, result=4,      ; (fac_index,tolllfactype)
		lookup[3]=1, result=5,      ; (fac_index,adjust)
		lookup[4]=1, result=6,      ; (fac_index,toll_da)
		lookup[5]=1, result=7,      ; (fac_index,toll_s2)
		lookup[6]=1, result=8,      ; (fac_index,toll_s3)
		lookup[7]=1, result=9,      ; (fac_index,toll_cv)
		lookup[8]=1, result=10,     ; (fac_index,mintoll_da)
		lookup[9]=1, result=11,     ; (fac_index,mintoll_s2)
		lookup[10]=1, result=12,    ; (fac_index,mintoll_s3)
		lookup[11]=1, result=13,    ; (fac_index,mintoll_cv)
		lookup[12]=1, result=14,    ; (fac_index,maxtoll_da)
		lookup[13]=1, result=15,    ; (fac_index,maxtoll_s2)
		lookup[14]=1, result=16,    ; (fac_index,maxtoll_s3)
		lookup[15]=1, result=17,    ; (fac_index,maxtoll_cv)
		lookup[16]=1, result=18,    ; (fac_index,R_AM_on_off)
		lookup[17]=1, result=19,    ; (fac_index,R_PM_on_off)
		lookup[18]=1, result=20,    ; (fac_index,S_AM_on_off)
		lookup[19]=1, result=21,    ; (fac_index,S_PM_on_off)		
		lookup[20]=1, result=22,    ; (fac_index,A_AM_on_off)
		lookup[21]=1, result=23    ; (fac_index,A_PM_on_off)		
		
		;load segment length
		lookup lookupi=2,  name=tollseg_length,
		lookup[1]=1, result=1, ;(TOLLID)
		lookup[2]=1, result=2 ;(tollseg_length)


		fac_index = TOLLID*100+@p@
   
		IF (TOLLID > 0 && GPID = 0)
	  
			TOLLDA = tolls(4, fac_index)*DISTANCE/tollseg_length(2,TOLLID)
			TOLLS2 = tolls(5,fac_index)* DISTANCE/tollseg_length(2,TOLLID)
			TOLLS3 = tolls(6,fac_index)* DISTANCE/tollseg_length(2,TOLLID)
			TOLLCV = tolls(7,fac_index)* DISTANCE/tollseg_length(2,TOLLID)

			MINTOLLDA = tolls(8,fac_index)    
			MINTOLLS2 = tolls(9,fac_index)   
			MINTOLLS3 = tolls(10,fac_index)   
			MINTOLLCV = tolls(11,fac_index)      

			MAXTOLLDA = tolls(12,fac_index)   
			MAXTOLLS2 = tolls(13,fac_index)   
			MAXTOLLS3 = tolls(14,fac_index)  
			MAXTOLLCV = tolls(15,fac_index)  
			
			;Pricing Lane Options

			IF (tolls(16,fac_index) > 0) ; Add reversible lane to TOLL links
				_R_AM_on = tolls(16,fac_index)
			ELSE
				_R_AM_on = 0
			ENDIF
			
			IF (tolls(17,fac_index) > 0) ; Add reversible lane to TOLL links
				_R_PM_on = tolls(17,fac_index)
			ELSE
			    _R_PM_on = 0
			ENDIF
				
			LANES = LANES + _R_AM_on + _R_PM_on + tolls(18,fac_index) + tolls(19,fac_index) + tolls(20,fac_index)+ tolls(21,fac_index) 		
		
		ENDIF
		
		fac_index = GPID*100+@p@
		IF (GPID > 0)
			IF (tolls(16,fac_index) < 0) ; remove lane from general purpose facility
				_R_AM_off = tolls(16,fac_index)
			ELSE
				_R_AM_off = 0
			ENDIF
			IF (tolls(17,fac_index) < 0) ; remove lane from general purpose facility
				_R_PM_off = tolls(17,fac_index)
			ELSE
			    _R_PM_off = 0
			ENDIF
				
			IF (tolls(20,fac_index) > 0) ; remove lane from general purpose facility
				_A_AM_off = tolls(20,fac_index)
			ELSE
				_A_AM_off = 0
			ENDIF
			IF (tolls(21,fac_index) > 0) ; remove lane from general purpose facility
				_A_PM_off = tolls(21,fac_index)
			ELSE
			    _A_PM_off = 0
			ENDIF
				
			LANES = LANES + _R_AM_off + _R_PM_off - _A_AM_off - _A_PM_off
		ENDIF
    ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    log var=_zones

  ENDRUN
  ;----------------------------------------------------------------------
ENDLOOP
;======================================================================
;Assign period matrices to highway network
;
*echo Begin highway assignments Iter @iter.i@>timelog.beginhwyassign.iter@iter.i@.txt

;======================================================================
IF (iter.ssi <= 0) iter.ssi=1 ;
IF (iter.i   <= 0) iter.i=1 ;

;======================================================================
; LOOP through all periods
LOOP p=1,9
		
		IF (p=01) per='h07'   ;better order for assignment in Cluster:
		IF (p=02) per='h08'   ;group in threes taking similar RUN-times
		IF (p=03) per='h09'
		IF (p=04) per='md5'
		IF (p=05) per='h15'
		IF (p=06) per='h16'
		IF (p=07) per='h17'
		IF (p=08) per='ev2'
		IF (p=09) per='n11'


		capfac = 1.0
		IF (per='md5') capfac = 5.00
		IF (per='ev2') capfac = 2.00
		IF (per='n11') capfac = 5.30
		
		rampmeter = 999  ;IF no metering, set to a value not in link data
		IF (per='h07') rampmeter=1
		IF (per='h08') rampmeter=1
		IF (per='h09') rampmeter=1
		IF (per='h15') rampmeter=2
		IF (per='h16') rampmeter=2
		IF (per='h17') rampmeter=2

	; Cluster    
		IF (p=01) pid=1
		IF (p=02) pid=2
		IF (p=03) pid=3
		IF (p=04) pid=1
		IF (p=05) pid=2 
		IF (p=06) pid=3 
		IF (p=07) pid=1 
		IF (p=08) pid=2 
		IF (p=09) pid=3 

		*copy tollseg_length.csv tollseg_length.@per@.csv
	;----------------------------------------------------------------------
		
      ;step 48

      ;IFCLUSTER:

      DistributeMultiStep ProcessID='sacsimsub', ProcessNum=@pid@

	      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	  ; creating the toll optimization LOOP

	_maxTollChange = 0
	change_thresh = 0.05 ; IF toll doesnt change by more than this amount stop iterating

	LOOP toop = 1,5    ;toll_LOOP = toop
	
		IF (toop=01) toll_LOOP='LOOP1'
		IF (toop=02) toll_LOOP='LOOP2'
		IF (toop=03) toll_LOOP='LOOP3'
		IF (toop=04) toll_LOOP='LOOP4'
		IF (toop=05) toll_LOOP='LOOP5'

	  
      RUN PGM=NETWORK  MSG='step 48 set prevvol and prevtime'
          ; Set up assignments input network with information from previous assignment
          NETI=vo.@per@.net

          ; Previous volume and time
          prevvol  = v_1
          prevtime = time_1

          ;drop previous loading variables (need to add as many excludes as there are)
          NETO=vi.@per@.net, exclude=v_1,time_1,vc_1,cspd_1,vdt_1,vht_1,vt_1,
              v1_1,v2_1,v3_1,v4_1,v5_1,v6_1,v7_1,v8_1,v9_1,v10_1,
              v11_1,v12_1,v13_1,v14_1,v15_1,v16_1,v17_1,v18_1,v19_1,v20_1,
              v21_1,v22_1,v23_1,v24_1,v25_1,v26_1,v27_1,v28_1,v29_1,v30_1,
              v31_1,v32_1,v33_1,v34_1,v35_1,v36_1,v37_1,v38_1,v39_1,v40_1,
              v41_1,v42_1,v43_1,v44_1,v45_1,v46_1,v47_1,v48_1,v49_1,v50_1,
              v1t_1,v2t_1,v3t_1,v4t_1,v5t_1,v6t_1,v7t_1,v8t_1,v9t_1,v10t_1,
              v11t_1,v12t_1,v13t_1,v14t_1,v15t_1,v16t_1,v17t_1,v18t_1,v19t_1,v20t_1,
              v21t_1,v22t_1,v23t_1,v24t_1,v25t_1,v26t_1,v27t_1,v28t_1,v29t_1,v30t_1,
              v31t_1,v32t_1,v33t_1,v34t_1,v35t_1,v36t_1,v37t_1,v38t_1,v39t_1,v40t_1,
              v41t_1,v42t_1,v43t_1,v44t_1,v45t_1,v46t_1,v47t_1,v48t_1,v49t_1,v50t_1

      ENDRUN
		  
		; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		;step 49
		RUN PGM=HIGHWAY  MSG='step 49 Vehicle trip assignment'
		; Vehicle trip assignnment

		NETI=vi.@per@.net               ; previous (in) increments loaded network
		MATI=..\veh.avg.@per@.mat         ; 'veh.avg' for successively-averaged matrices
		FILEO NETO=vo.@per@.net         ; output (new) loaded network

		CAPFAC = @capfac@
		METERCLASS=@rampmeter@
		COMBINE=EQUI,MAXITERS=1,RELATIVEGAP=@iter.relgap@,gap=0,raad=0,aad=0;rmse=0.01

        ;------ Note:  basic classes are 1-9, special classes are two-digit classes
          SPDCAP CAPACITY[1]=2000,1000,850,800,700,1500,0,2000,1500                ;basic capacity classes 1-9
          SPDCAP CAPACITY[11]=0,1500,0,0,0,2000,0,0,0                              ;special classes:  12=hi-cap river crossing;16=hi-cap ramp
          SPDCAP CAPACITY[21]=0,1000,0,750,0,500,0,0,0                               ;special classes:  22=rural state hwy; 24=rural min art; 26=lo-cap ramp
          SPDCAP CAPACITY[51]=2000,0,0,0,0,1500,0,0,0                               ;Auxiliary lane classes: 51 = Aux links >1 mile; 56 = Aux links <1 mile    
          SPDCAP CAPACITY[62]=0,0                                                  ;special classes:  62=pnr dummy link; 63=centroid conn
          SPDCAP CAPACITY[99]=0

		; Scalar factors
		  C2PCE = 1.5
		  C3PCE = 2.0
		  HOV2Divisor = 1.00   ;cost divisors no longer needed since shared-ride trips put into higher VOT bins
		  HOV3Divisor = 1.00
		  CostPerMile = @auto_cost_per_mile@   ;from configuration file

		PHASE=LINKREAD                        ;define link groups
		  SPEED = li.speed
		  t0 = li.distance * 60 / CmpNumRetNum(li.speed,'=',0,1,li.speed)
		  t1 = li.prevtime
		  
		IF (li.USECLASS == 0) ADDTOGROUP=1        ;GENERAL PURPOSE 
		IF (li.USECLASS == 2) ADDTOGROUP=2        ;HOV2+
		IF (li.USECLASS == 3) ADDTOGROUP=3        ;HOV3+
		IF (li.USECLASS == 4) ADDTOGROUP=4        ;HOV3+
				
		  IF (li.speed = 0) 
			  ADDTOGROUP=1
			  ADDTOGROUP=2
			  ADDTOGROUP=3
			  ADDTOGROUP=4
		  ENDIF
		  IF (li.capclass = 99)
			  ADDTOGROUP=1
			  ADDTOGROUP=2
			  ADDTOGROUP=3
			  ADDTOGROUP=4			  
		  ENDIF

        ;------ ramp meter flag
        IF (METERCLASS=1 & li.DELCURV=1)
			lw.RAMP=1
        ELSEIF (METERCLASS=2 & li.DELCURV=2)
			lw.RAMP=1
        ELSE
            lw.RAMP=0
        ENDIF

		  lw.AOCost = li.distance * CostPerMile

		IF (iteration=0)
		  lw.imped1_da = li.prevtime + (li.tollda + lw.AOcost)*@tolls.ivot1@
		  lw.imped1_c3 = li.prevtime + (li.tollcv + lw.AOcost)*@tolls.ivot1@
		  lw.imped1_s2 = li.prevtime + (li.tolls2 + lw.AOcost)*@tolls.ivot1@ / HOV2Divisor
		  lw.imped1_s3 = li.prevtime + (li.tolls3 + lw.AOcost)*@tolls.ivot1@ / HOV3Divisor
		 
          lw.imped2_da = li.prevtime + (li.tollda + lw.AOcost)*@tolls.ivot2@
		  lw.imped2_c3 = li.prevtime + (li.tollcv + lw.AOcost)*@tolls.ivot2@
		  lw.imped2_s2 = li.prevtime + (li.tolls2 + lw.AOcost)*@tolls.ivot2@ / HOV2Divisor
		  lw.imped2_s3 = li.prevtime + (li.tolls3 + lw.AOcost)*@tolls.ivot2@ / HOV3Divisor
		  
		  lw.imped3_da = li.prevtime + (li.tollda + lw.AOcost)*@tolls.ivot3@
		  lw.imped3_c3 = li.prevtime + (li.tollcv + lw.AOcost)*@tolls.ivot3@
		  lw.imped3_s2 = li.prevtime + (li.tolls2 + lw.AOcost)*@tolls.ivot3@ / HOV2Divisor
		  lw.imped3_s3 = li.prevtime + (li.tolls3 + lw.AOcost)*@tolls.ivot3@ / HOV3Divisor

		ENDIF

		ENDPHASE

		;------ path load
		PHASE=ILOOP

		  PATHLOAD PATH=lw.imped1_da EXCLUDEGRP=2,3 VOL[01]=mi.1.da1,VOL[02]=mi.1.c21,		;VOT 1  Drive Alone VOT Class 1,Commercial Vehicles 2 axle
				mw[1] = mi.1.da1, SELECTLINK = (L=@GPLane_SL@),VOL[16]=mw[1],
				mw[2] = mi.1.c21, SELECTLINK = (L=@GPLane_SL@),VOL[17]=mw[2],
				mw[3] = mi.1.da1, SELECTLINK = (L=@HOTLane_SL@),VOL[31]=mw[3],
				mw[4] = mi.1.c21, SELECTLINK = (L=@HOTLane_SL@),VOL[32]=mw[4]
			PATH=lw.imped1_c3 EXCLUDEGRP=2,3,4      VOL[03]=mi.1.c31,						;VOT 1  Commercial Vehicles 3 axle
				mw[5] = mi.1.c31, SELECTLINK = (L=@GPLane_SL@),VOL[18]=mw[5],
				mw[6] = mi.1.c31, SELECTLINK = (L=@HOTLane_SL@),VOL[33]=mw[6]
			PATH=lw.imped1_s2 EXCLUDEGRP=3   		VOL[04]=mi.1.s21, 						;VOT 1  Shared Drive 2
				mw[7] = mi.1.s21 , SELECTLINK = (L=@GPLane_SL@),VOL[19]=mw[7],
				mw[8] = mi.1.s21 , SELECTLINK = (L=@HOTLane_SL@),VOL[34]=mw[8]			
			PATH=lw.imped1_s3   					VOL[05]=mi.1.s31, 						;VOT 1  Shared Drive 3+
				mw[9] = mi.1.s31, SELECTLINK = (L=@GPLane_SL@),VOL[20]=mw[9],
				mw[10] = mi.1.s31, SELECTLINK = (L=@HOTLane_SL@),VOL[35]=mw[10]			
			PATH=lw.imped2_da EXCLUDEGRP=2,3   		VOL[06]=mi.1.da2, VOL[07]=mi.1.c22,   	;VOT 2  Drive Alone, Commercial Vehicles 2 axle	
				mw[11] = mi.1.da2, SELECTLINK = (L=@GPLane_SL@),VOL[21]=mw[11],
				mw[12] = mi.1.c22, SELECTLINK = (L=@GPLane_SL@),VOL[22]=mw[12],
				mw[13] = mi.1.da2, SELECTLINK = (L=@HOTLane_SL@),VOL[36]=mw[13],				
				mw[14] = mi.1.c22, SELECTLINK = (L=@HOTLane_SL@),VOL[37]=mw[14]			
			PATH=lw.imped2_c3 EXCLUDEGRP=2,3,4      VOL[08]=mi.1.c32,						;VOT 2  Commercial Vehicles 3 axle
				mw[15] = mi.1.c32, SELECTLINK = (L=@GPLane_SL@),VOL[23]=mw[15],
				mw[16] = mi.1.c32, SELECTLINK = (L=@HOTLane_SL@),VOL[38]=mw[16]			
			PATH=lw.imped2_s2 EXCLUDEGRP=3   		VOL[09]=mi.1.s22,  						;VOT 2  Shared Drive 2
				mw[17] = mi.1.s22, SELECTLINK = (L=@GPLane_SL@),VOL[24]=mw[17],
				mw[18] = mi.1.s22, SELECTLINK = (L=@HOTLane_SL@),VOL[39]=mw[18]			
			PATH=lw.imped2_s3 						VOL[10]=mi.1.s32,						;VOT 2  Shared Drive 3+
				mw[19] = mi.1.s32, SELECTLINK = (L=@GPLane_SL@),VOL[25]=mw[19],
				mw[20] = mi.1.s32, SELECTLINK = (L=@HOTLane_SL@),VOL[40]=mw[20]			
			PATH=lw.imped3_da EXCLUDEGRP=2,3   		VOL[11]=mi.1.da3, VOL[12]=mi.1.c23,   	;VOT 3  Drive Alone, Commercial Vehicles 2 axle
				mw[21] = mi.1.da3, SELECTLINK = (L=@GPLane_SL@),VOL[26]=mw[21],
				mw[22] = mi.1.c23, SELECTLINK = (L=@GPLane_SL@),VOL[27]=mw[22],				
				mw[23] = mi.1.da3, SELECTLINK = (L=@HOTLane_SL@),VOL[41]=mw[23],
				mw[24] = mi.1.c23, SELECTLINK = (L=@HOTLane_SL@),VOL[42]=mw[24]					
			PATH=lw.imped3_c3 EXCLUDEGRP=2,3,4      VOL[13]=mi.1.c33,   						;VOT 3 Commercial Vehicles 3 axle
				mw[25] = mi.1.c33, SELECTLINK = (L=@GPLane_SL@),VOL[28]=mw[25],
				mw[26] = mi.1.c33, SELECTLINK = (L=@HOTLane_SL@),VOL[43]=mw[26]			
			PATH=lw.imped3_s2 EXCLUDEGRP=3   		VOL[14]=mi.1.s23,     					;VOT 3 Shared Drive 2
				mw[27] = mi.1.s23, SELECTLINK = (L=@GPLane_SL@),VOL[29]=mw[27],
				mw[28] = mi.1.s23, SELECTLINK = (L=@HOTLane_SL@),VOL[44]=mw[28]			
			PATH=lw.imped3_s3 						VOL[15]=mi.1.s33,   						;VOT 3 Shared Drive 3+
				mw[29] = mi.1.s33, SELECTLINK = (L=@GPLane_SL@),VOL[30]=mw[29],
				mw[30] = mi.1.s33, SELECTLINK = (L=@HOTLane_SL@),VOL[45]=mw[30]		  
		ENDPHASE

		PHASE=ADJUST  
		FUNCTION,
		;   Conical (2 - beta) - alpha(1-x) + 
		;           sqrt(alpha^2*(1-x)^2 + beta^2)
		;   where x = factor*v/c, 
		;         beta=(2*alpha-1)/(2*alpha-2)
		;   Revised (suggested DKS 3/7/2019 for gradual arterial delay, non-negative delay, softer ceilings for v/c>2)

		
		  TC[1]=T0*min((9/10-6.0*(1-0.88*(V/C))+sqrt(36.0*(1-0.88*(V/C))*(1-0.88*(V/C))+121/100)),9.1+0.5*(V/C))+lw.ramp*min((-0.029+sqrt(324.0*(1-1.8*(v/c))*(1-1.8*(v/c))+1.06)-18.0*(1-1.8*(v/c))),12+(v/c))
		          ;highways change alpha to 5

		  TC[2]=T0*min((7/8-5.0*(1-0.86*(V/C))+sqrt(25.0*(1-0.86*(V/C))*(1-0.86*(V/C))+81/64)),7.2+0.5*(V/C))+lw.ramp*min((-0.029+sqrt(324.0*(1-1.8*(v/c))*(1-1.8*(v/c))+1.06)-18.0*(1-1.8*(v/c))),12+(v/c))
		          ;arterials change alpha to 4

		  TC[3]=T0*min((5/6-4.0*(1-0.83*(V/C))+sqrt(16.0*(1-0.83*(V/C))*(1-0.83*(V/C))+49/36)),5.3+0.5*(V/C))+lw.ramp*min((-0.029+sqrt(324.0*(1-1.8*(v/c))*(1-1.8*(v/c))+1.06)-18.0*(1-1.8*(v/c))),12+(v/c))

		  V=  VOL[01]+VOL[02]*C2PCE+VOL[03]*C3PCE+VOL[04]+VOL[05] +
				VOL[06]+VOL[07]*C2PCE+VOL[08]*C3PCE+VOL[09]+VOL[10] +
				VOL[11]+VOL[12]*C2PCE+VOL[13]*C3PCE+VOL[14]+VOL[15] 

		  lw.imped1_da = time + (li.tollda + lw.AOcost)*@tolls.ivot1@
		  lw.imped1_c3 = time + (li.tollcv + lw.AOcost)*@tolls.ivot1@
		  
		  lw.imped1_s2 = time + (li.tolls2 + lw.AOcost)*@tolls.ivot1@ / HOV2Divisor
		  lw.imped1_s3 = time + (li.tolls3 + lw.AOcost)*@tolls.ivot1@ / HOV3Divisor

		  lw.imped2_da = time + (li.tollda + lw.AOcost)*@tolls.ivot2@
		  lw.imped2_c3 = time + (li.tollcv + lw.AOcost)*@tolls.ivot2@
		  
		  lw.imped2_s2 = time + (li.tolls2 + lw.AOcost)*@tolls.ivot2@ / HOV2Divisor
		  lw.imped2_s3 = time + (li.tolls3 + lw.AOcost)*@tolls.ivot2@ / HOV3Divisor
          
		  lw.imped3_da = time + (li.tollda + lw.AOcost)*@tolls.ivot3@
		  lw.imped3_c3 = time + (li.tollcv + lw.AOcost)*@tolls.ivot3@
		  
		  lw.imped3_s2 = time + (li.tolls2 + lw.AOcost)*@tolls.ivot3@ / HOV2Divisor
		  lw.imped3_s3 = time + (li.tolls3 + lw.AOcost)*@tolls.ivot3@ / HOV3Divisor


		; "Cost" function used in adjust and converge PHASEs
		FUNCTION COST = ((time + (li.tollda + lw.AOcost)*@tolls.ivot1@			 ) * (v1 + v2*C2PCE) +
		         (time + (li.tollcv + lw.AOcost)*@tolls.ivot1@			 ) * (v3*C3PCE) +
						 (time + (li.tolls2 + lw.AOcost)*@tolls.ivot1@ / HOV2Divisor	 ) * v4 +
						 (time + (li.tolls3 + lw.AOcost)*@tolls.ivot1@ / HOV3Divisor	 ) * v5 +

		  (time + (li.tollda + lw.AOcost)*@tolls.ivot2@			 ) * (v6 + v7*C2PCE) +
		  (time + (li.tollcv + lw.AOcost)*@tolls.ivot2@			 ) * (v8*c3PCE) +
		  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot2@ / HOV2Divisor	 ) * v9 +
		  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot2@ / HOV3Divisor	 ) * v10 +

		  (time + (li.tollda + lw.AOcost)*@tolls.ivot3@			 ) * (v11 + v12*C2PCE) +
		  (time + (li.tollcv + lw.AOcost)*@tolls.ivot3@			 ) * (v13*c3PCE) +
		  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot3@ / HOV2Divisor	 ) * v14 +
		  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot3@ / HOV3Divisor	 ) * v15 +


		  0) / CmpNumRetNum(V,'=',0,1,V)

		ENDPHASE

		ENDRUN
		;======================================================================
		;======================================================================
			toll_incr = 2.0  ; a multiplicative factor on initial toll in case the toll is already higher than the VOT toll
			avg_vot = 17.80
			maxvoc_allowed = 0.8
			da_to_cv3_fac = 1.5 ; a multiplicative factor to calculate cv3+ tolls based on DA toll

	   RUN PGM=network    MSG='step xx optimize tolls'
		 NETI=vo.@per@.net 
		
			; the input tolls file
			; format of tolls.csv is index(tollseg*100+per),tollseg,per,0,factype,adjust,tollda,tolls2,tolls3,tollcv
			
			FILEI LOOKUPI[1] = tolls.csv
			
			fileo printo[1] = nextToll.@per@.@toll_LOOP@.csv
			
			
		  array tseg_toll_time = 100
		  array tseg_gp_time = 100
		  array tseg_time_saved = 100
		  array tseg_vottoll = 100
		  array tseg_maxvoc = 100
		  array tseg_lastda = 100
		  array tseg_lasts2 = 100
		  array tseg_lasts3 = 100
		  array tseg_lastcv = 100  
		  array da_low = 100  
		  array cv2_low = 100 
		  array cv3_low = 100
		  array s2_low = 100  
		  array s3_low = 100  
		  array da_med = 100  
		  array cv2_med = 100 
		  array cv3_med = 100
		  array s2_med = 100  
		  array s3_med = 100  
		  array da_hi = 100   
		  array cv2_hi = 100  
		  array cv3_hi = 100 
		  array s2_hi = 100   
		  array s3_hi = 100   
		  array total_vol = 100
		  		
		PHASE = linkmerge
		
				; load toll values
			lookup lookupi=1, name=tolls, 
			lookup[1]=1, result=3,      ; (fac_index,period)
			lookup[2]=1, result=4,      ; (fac_index,tolllfactype)
			lookup[3]=1, result=5,      ; (fac_index,adjust)
			lookup[4]=1, result=6,      ; (fac_index,toll_da)
			lookup[5]=1, result=7,      ; (fac_index,toll_s2)
			lookup[6]=1, result=8,      ; (fac_index,toll_s3)
			lookup[7]=1, result=9,      ; (fac_index,toll_cv)
			lookup[8]=1, result=10,     ; (fac_index,mintoll_da)
			lookup[9]=1, result=11,     ; (fac_index,mintoll_s2)
			lookup[10]=1, result=12,    ; (fac_index,mintoll_s3)
			lookup[11]=1, result=13,    ; (fac_index,mintoll_cv)
			lookup[12]=1, result=14,    ; (fac_index,maxtoll_da)
			lookup[13]=1, result=15,    ; (fac_index,maxtoll_s2)
			lookup[14]=1, result=16,    ; (fac_index,maxtoll_s3)
			lookup[15]=1, result=17    ; (fac_index,maxtoll_cv)
			
					fac_index = TOLLID*100+@p@
  
	   
			IF (TOLLID > 0)
				tseg_toll_time[TOLLID] = tseg_toll_time[TOLLID] + TIME_1
				
	            tseg_lastda[TOLLID] = tseg_lastda[TOLLID] + TOLLDA
                tseg_lasts2[TOLLID] =  tseg_lasts2[TOLLID] + TOLLS2
		        tseg_lasts3[TOLLID] = tseg_lasts3[TOLLID] + TOLLS3
		        tseg_lastcv[TOLLID] = tseg_lastcv[TOLLID] + TOLLCV
				
				IF(VC_1 > tseg_maxvoc[TOLLID])
					tseg_maxvoc[TOLLID] = VC_1
					da_low[TOLLID]   = V1_1
					cv2_low[TOLLID]  = V2_1
					cv3_low[TOLLID] = V3_1
					s2_low[TOLLID]   = V4_1  
					s3_low[TOLLID]   = V5_1
					da_med[TOLLID]   = V6_1
					cv2_med[TOLLID]  = V7_1
					cv3_med[TOLLID] = V8_1
					s2_med[TOLLID]   = V9_1  
					s3_med[TOLLID]   = V10_1
					da_hi[TOLLID]    = V11_1
					cv2_hi[TOLLID]   = V12_1
					cv3_hi[TOLLID]  = V13_1
					s2_hi[TOLLID]    = V14_1  
					s3_hi[TOLLID]    = V15_1
					total_vol[TOLLID]= VT_1
				ENDIF
			ENDIF
	 
			IF (GPID > 0 )
				 tseg_gp_time[GPID] = tseg_gp_time[GPID] + TIME_1
			ENDIF

		ENDPHASE
		
		
		PHASE = summary
		

			LOOP _segment=1,@network._numseg@

				fac_index = _segment*100+@p@
				
				adjust = tolls(3,fac_index)
				
				IF(adjust==1)

					tseg_time_saved[_segment] = tseg_gp_time[_segment]  - tseg_toll_time[_segment] 
					tseg_vottoll[_segment] = tseg_time_saved[_segment]/60 * @avg_vot@ ; in dollars
			
					;***DA***
					
					minDA = tolls(8, fac_index)
					maxDA = tolls(12,fac_index)
					iniDA = tseg_lastda[_segment]
										
					IF(maxDA>0)
					
					   IF((iniDA > tseg_vottoll[_segment]) && (tseg_maxvoc[_segment] > @maxvoc_allowed@ ) )
						  nextTollDA = min((iniDA * @toll_incr@), maxDA)
					   ELSE
						  nextTollDA = max(min(tseg_vottoll[_segment],maxDA),minDA)
					   ENDIF
					ELSE
					   nextTollDA = 0
					 ENDIF
					 
					 avgTollDA = (tseg_lastda[_segment]+nextTollDA)/2
					 
					_maxTollChange = max(_maxTollChange,abs(iniDA - avgTollDA))
					
					;***S2***

					minS2 = tolls(9, fac_index)
					maxS2 = tolls(13,fac_index)
					iniS2 = tseg_lasts2[_segment]
					
					nextTollS2 = 0
					
					IF(maxS2>0)
					
					   IF((iniS2 > tseg_vottoll[_segment]) && (tseg_maxvoc[_segment] > @maxvoc_allowed@ ))
						  nextTollS2 = min((iniS2 * @toll_incr@), maxS2)
					   ELSE
						  nextTollS2 = max(min(tseg_vottoll[_segment],maxS2),minS2)
						ENDIF
					ELSE
					  nextTollS2 = 0
					ENDIF
					
					avgTollS2 = (tseg_lastS2[_segment]+nextTollS2)/2
					
					
					_maxTollChange = max(_maxTollChange,abs(iniS2 - avgTollS2))

					;***S3+***

					minS3 = tolls(10, fac_index)
					maxS3 = tolls(14,fac_index)
					iniS3 = tseg_lasts3[_segment]
					
					nextTollS3 = 0
					
					IF(maxS3>0)
					
					   IF((iniS3 > tseg_vottoll[_segment]) && (tseg_maxvoc[_segment] > @maxvoc_allowed@ ))
						  nextTollS3 = min((iniS3 * @toll_incr@), maxS3)
					   ELSE
						  nextTollS3 = max(min(tseg_vottoll[_segment],maxS3),minS3)
						ENDIF
					ELSE
					  nextTollS3 = 0
					ENDIF
					
					avgTollS3 = (tseg_lastS3[_segment]+nextTollS3)/2
					
					_maxTollChange = max(_maxTollChange,abs(iniS3 - avgTollS3))

					;***CV***
					; set tolls for cv is to twice the tolls for da

					minCV = tolls(11, fac_index)
					maxCV = tolls(15,fac_index)
					iniCV = tseg_lastcv[_segment]
					
					nextTollCV = min(nextTollDA * @da_to_cv3_fac@, maxCV)
					avgTollCV = min(avgTollDA * @da_to_cv3_fac@, maxCV)

					; tolls for cv can be set on its own by activating the commented portion of the script below and changing the input tolls file
					;IF((tseg_maxvoc[_segment] > @maxvoc_allowed@ ) && (maxCV>0)) 
					;
					;   IF(iniCV > tseg_vottoll[_segment])
					;      nextTollCV = iniCV * @toll_incr@
					;   ELSE
					;	  nextTollCV = max(min(tseg_vottoll[_segment],maxS3),minS3)
					;	ENDIF
					;ELSE
					;  nextTollCV = max(min(tseg_vottoll[_segment],maxCV),minCV)
					;ENDIF
					_maxTollChange = max(_maxTollChange,abs(iniCV - avgTollCV))
				
				ENDIF
			   
							
				 PRINT CSV=T LIST=_segment, tseg_toll_time[_segment], tseg_gp_time[_segment],tseg_time_saved[_segment] , tseg_vottoll[_segment], tseg_maxvoc[_segment],avgTollDA,avgTollS2,avgTollS3,avgTollCV,_maxTollChange,
												da_low[_segment], cv2_low[_segment], cv3_low[_segment], s2_low[_segment], s3_low[_segment], da_med[_segment], cv2_med[_segment], 
												cv3_med[_segment], s2_med[_segment], s3_med[_segment], da_hi[_segment], cv2_hi[_segment], cv3_hi[_segment], s2_hi[_segment], s3_hi[_segment],total_vol[_segment]   PRINTO=1
						
			ENDLOOP
		 
		LOG VAR=_maxTollChange
	 
		ENDPHASE
		
    
		ENDRUN
		
		
		; IF the maximum toll change across any segment in this time period is less than the tollchange_threshold, stop RUNning
		; assignments in this period and move to the next period
		
	    *echo @toll_LOOP@ @network._maxTollChange@ @change_thresh@ >> tollOptimizeConvergence.@per@.csv
		
	    IF(network._maxTollChange <  change_thresh) 
		  break
		ENDIF
		
		*copy nextToll.@per@.@toll_LOOP@.csv prev_toll.csv
		;=====================================================

		; reading new toll values into the network

		; format of nextToll.@per@.@toll_LOOP@.csv is   _segment, tseg_toll_time[_segment], tseg_gp_time[_segment],tseg_time_saved[_segment] , tseg_vottoll[_segment], tseg_maxvoc[_segment],avgTollDA,avgTollS2,avgTollS3,avgTollCV,_maxTollChange
		
		RUN PGM=network    MSG='step xx apportion new tolls to the links'
			 NETI=vo.@per@.net 
			 NETO=vo.@per@.out.net
			 
			FILEI LOOKUPI[1] = nextToll.@per@.@toll_LOOP@.csv
			FILEI LOOKUPI[2] = tollseg_length.@per@.csv
			
			LOOP _segment=1,@network._numseg@
			
			
			; load new toll values
			lookup lookupi=1, name=nextToll, 
			lookup[1]=1, result=1,       ;(segment)
			lookup[2]=1, result=7,      ; (tollda)
			lookup[3]=1, result=8,      ; (tolls2)
			lookup[4]=1, result=9,      ; (tolls3)
			lookup[5]=1, result=10,    ; (tollcv)
			lookup[6]=1, result=11		;(maxTollChange)
			
			;load segment length
			lookup lookupi=2,  name=tollseg_length,
			lookup[1]=1, result=1, ;(TOLLID)
			lookup[2]=1, result=2, ;(tollseg_length)
			lookup[3]=1, result=3 ;(nontollseg_length)
			
			;fac_index = TOLLID*100+@seg@
			

			
			IF (TOLLID>0)
			
			TOLLDA = nextToll(2,TOLLID)*DISTANCE/tollseg_length(2,TOLLID)
			TOLLS2 = nextToll(3,TOLLID)* DISTANCE/tollseg_length(2,TOLLID)
			TOLLS3 = nextToll(4,TOLLID)* DISTANCE/tollseg_length(2,TOLLID)
			TOLLCV = nextToll(5,TOLLID)* DISTANCE/tollseg_length(2,TOLLID)		

			ENDIF
			
			ENDLOOP
		ENDRUN
		
	*copy vo.@per@.out.net vo.@per@.net

	ENDLOOP

	;======================================================================
	;======================================================================
	; Cluster
     ENDDistributeMultiStep

     IF (pid=3)
         Wait4Files Files=sacsimsub1.script.END, 
                          sacsimsub2.script.END,
                          sacsimsub3.script.END, 
         CheckReturnCode=T,
         PrintFiles=Merge, 
         DelDistribFiles=T
     ENDIF
    ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ; END of highway periods LOOP
ENDLOOP
	;======================================================================
	LOOP p=1,9
		IF (p=01) per='h07'
		IF (p=02) per='h08'
		IF (p=03) per='h09'
		IF (p=04) per='md5'
		IF (p=05) per='h15'
		IF (p=06) per='h16'
		IF (p=07) per='h17'
		IF (p=08) per='ev2'
		IF (p=09) per='n11'
	
	
		;step 50
		RUN PGM=NETWORK  MSG='step 50 summary convergence monitoring'
			; Summarize vehicle-minutes statistics for convergence monitoring
	
			filei NETI[1]=vo.@per@.net
	
			_VXTold = _VXTold + li.1.v_1 * li.1.prevtime
			_VXTnew = _VXTnew + li.1.v_1 * li.1.time_1
			_period = '@per@'
	
			; Maximum delta-vol and delta-time
			_delv = abs(li.1.v_1 - li.1.prevvol)
			_maxdelv = max(_maxdelv, _delv)
			IF (li.1.v_1 + li.1.prevvol >= 1)
				_maxdelt = max(_maxdelt, abs(li.1.time_1 - li.1.prevtime))
			ENDIF
	
			; RMS delta-vol (weighted)
			_SSq = _SSq + _delv*_delv
			; Calculate RMS by dividing by respective VXTnew
	
			PHASE=summary
				print file=convergencestats.txt, appEND=T, 
				list='@iter.i@'(4), '@iter.ssi@'(4), _period,
				_VXTold(12), _VXTnew(12),
				_maxdelv(12), _maxdelt(8.2), _SSq(12)
			ENDPHASE
		ENDRUN
		; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; END of highway periods LOOP
	ENDLOOP
	
	;======================================================================
	; END of iteration LOOP of demand and assignment models at line 456
	
	*echo END Iter @iter.i@>timelog.ENDLOOP.iter@iter.i@.txt
	;ENDLOOP
*echo END RUN>timelog.ENDRUN.txt
*dir timelog*.txt /od >alltimelogs.txt

;===========================================================================
;Rollup Network with Select LINK LINK
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
	  
fileo neto=?daynet_SL_temp.net

; link volumes
_h07v = li.2.V1_1	+	li.2.V2_1	+	li.2.V3_1	+	li.2.V4_1	+	li.2.V5_1	+	li.2.V6_1	+	li.2.V7_1	+	li.2.V8_1	+	li.2.V9_1	+	li.2.V10_1	+	li.2.V11_1	+	li.2.V12_1	+	li.2.V13_1	+	li.2.V14_1	+	li.2.V15_1
_h08v = li.3.V1_1	+	li.3.V2_1	+	li.3.V3_1	+	li.3.V4_1	+	li.3.V5_1	+	li.3.V6_1	+	li.3.V7_1	+	li.3.V8_1	+	li.3.V9_1	+	li.3.V10_1	+	li.3.V11_1	+	li.3.V12_1	+	li.3.V13_1	+	li.3.V14_1	+	li.3.V15_1
_h09v = li.4.V1_1	+	li.4.V2_1	+	li.4.V3_1	+	li.4.V4_1	+	li.4.V5_1	+	li.4.V6_1	+	li.4.V7_1	+	li.4.V8_1	+	li.4.V9_1	+	li.4.V10_1	+	li.4.V11_1	+	li.4.V12_1	+	li.4.V13_1	+	li.4.V14_1	+	li.4.V15_1
_md5v = li.5.V1_1	+	li.5.V2_1	+	li.5.V3_1	+	li.5.V4_1	+	li.5.V5_1	+	li.5.V6_1	+	li.5.V7_1	+	li.5.V8_1	+	li.5.V9_1	+	li.5.V10_1	+	li.5.V11_1	+	li.5.V12_1	+	li.5.V13_1	+	li.5.V14_1	+	li.5.V15_1
_h15v = li.6.V1_1	+	li.6.V2_1	+	li.6.V3_1	+	li.6.V4_1	+	li.6.V5_1	+	li.6.V6_1	+	li.6.V7_1	+	li.6.V8_1	+	li.6.V9_1	+	li.6.V10_1	+	li.6.V11_1	+	li.6.V12_1	+	li.6.V13_1	+	li.6.V14_1	+	li.6.V15_1
_h16v = li.7.V1_1	+	li.7.V2_1	+	li.7.V3_1	+	li.7.V4_1	+	li.7.V5_1	+	li.7.V6_1	+	li.7.V7_1	+	li.7.V8_1	+	li.7.V9_1	+	li.7.V10_1	+	li.7.V11_1	+	li.7.V12_1	+	li.7.V13_1	+	li.7.V14_1	+	li.7.V15_1
_h17v = li.8.V1_1	+	li.8.V2_1	+	li.8.V3_1	+	li.8.V4_1	+	li.8.V5_1	+	li.8.V6_1	+	li.8.V7_1	+	li.8.V8_1	+	li.8.V9_1	+	li.8.V10_1	+	li.8.V11_1	+	li.8.V12_1	+	li.8.V13_1	+	li.8.V14_1	+	li.8.V15_1
_ev2v = li.9.V1_1	+	li.9.V2_1	+	li.9.V3_1	+	li.9.V4_1	+	li.9.V5_1	+	li.9.V6_1	+	li.9.V7_1	+	li.9.V8_1	+	li.9.V9_1	+	li.9.V10_1	+	li.9.V11_1	+	li.9.V12_1	+	li.9.V13_1	+	li.9.V14_1	+	li.9.V15_1
_n11v = li.10.V1_1	+	li.10.V2_1	+	li.10.V3_1	+	li.10.V4_1	+	li.10.V5_1	+	li.10.V6_1	+	li.10.V7_1	+	li.10.V8_1	+	li.10.V9_1	+	li.10.V10_1	+	li.10.V11_1	+	li.10.V12_1	+	li.10.V13_1	+	li.10.V14_1	+	li.10.V15_1

/*
;get Select Link Values
;GPLane_SL_a = 9267
;GPLane_SL_b = 9321
                     
if (li.2.a == 9267 & li.2.b == 9321) h07v_TGPSL = _h07v
if (li.3.a == 9267 & li.3.b == 9321) h08v_TGPSL = _h08v
if (li.4.a == 9267 & li.4.b == 9321) h09v_TGPSL = _h09v
if (li.5.a == 9267 & li.5.b == 9321) md5v_TGPSL = _md5v
if (li.6.a == 9267 & li.6.b == 9321) h15v_TGPSL = _h15v
if (li.7.a == 9267 & li.7.b == 9321) h16v_TGPSL = _h16v
if (li.8.a == 9267 & li.8.b == 9321) h17v_TGPSL = _h17v
if (li.9.a == 9267 & li.9.b == 9321) ev2v_TGPSL = _ev2v
if (li.10.a == 9267 & li.10.b == 9321) n11v_TGPSL = _n11v

if (li.2.a == 9316 & li.2.b == 9318) h07v_THSL = _h07v
if (li.3.a == 9316 & li.3.b == 9318) h08v_THSL = _h08v
if (li.4.a == 9316 & li.4.b == 9318) h09v_THSL = _h09v
if (li.5.a == 9316 & li.5.b == 9318) md5v_THSL = _md5v
if (li.6.a == 9316 & li.6.b == 9318) h15v_THSL = _h15v
if (li.7.a == 9316 & li.7.b == 9318) h16v_THSL = _h16v
if (li.8.a == 9316 & li.8.b == 9318) h17v_THSL = _h17v
if (li.9.a == 9316 & li.9.b == 9318) ev2v_THSL = _ev2v
if (li.10.a == 9316 & li.10.b == 9318) n11v_THSL = _n11v
*/
merge record=false
endrun

;===========================================================================
;Rollup Network with Select LINK LINK
run pgm=network  MSG='create daily network'
filei linki[1]=?daynet_SL_temp.net
      linki[2]=vo.h07.net
      linki[3]=vo.h08.net
      linki[4]=vo.h09.net
      linki[5]=vo.md5.net
      linki[6]=vo.h15.net
      linki[7]=vo.h16.net
      linki[8]=vo.h17.net
      linki[9]=vo.ev2.net
      linki[10]=vo.n11.net
	  
fileo neto=?daynet_SL.net exclude=bike,MINTOLLDA,MINTOLLS2,MINTOLLS3,MINTOLLCV,MAXTOLLCV,MAXTOLLDA,MAXTOLLS2,MAXTOLLS3,
			 prevvol,prevvol,vc_1,cspd_1,tollda,tolls2,tolls3,tollcv,
             Vdt_1,Vht_1,V1_1,V2_1,V3_1,Vt_1,V1t_1,V2t_1,V3t_1,
			 V_1,V4_1,V5_1,V6_1,V7_1,V8_1,V9_1,V10_1,V11_1,V12_1,V13_1,V14_1,V15_1,
			 V4T_1,V5T_1,V6T_1,V7T_1,V8T_1,V9T_1,V10T_1,V11T_1,V12T_1,V13T_1,V14T_1,V15T_1,
			 V16_1,V17_1,V18_1,V19_1,V20_1,V21_1,V22_1,V23_1,V24_1,V25_1,V26_1,V27_1,V28_1,V29_1,V30_1,
			 V31_1,V32_1,V33_1,V34_1,V35_1,V36_1,V37_1,V38_1,V39_1,V40_1,V41_1,V42_1,V43_1,V44_1,V45_1,
			 V16T_1,V17T_1,V18T_1,V19T_1,V20T_1,V21T_1,V22T_1,V23T_1,V24T_1,V25T_1,V26T_1,V27T_1,V28T_1,V29T_1,V30T_1,
			 V31T_1,V32T_1,V33T_1,V34T_1,V35T_1,V36T_1,V37T_1,V38T_1,V39T_1,V40T_1,V41T_1,V42T_1,V43T_1,V44T_1,V45T_1
      linko=?daynet_SL.dbf format=dbf exclude=bike,MINTOLLDA,MINTOLLS2,MINTOLLS3,MINTOLLCV,MAXTOLLCV,MAXTOLLDA,MAXTOLLS2,MAXTOLLS3,
			 prevvol,prevvol,vc_1,cspd_1,
             vdt_1,vht_1,v1_1,v2_1,v3_1,vt_1,v1t_1,v2t_1,v3t_1,
			 v4T_1,v5T_1,v6T_1,v7T_1,v8T_1,v9T_1,v10T_1,v11T_1,v12T_1,v13T_1,v14T_1,v15T_1,
			 V_1,v4_1,v5_1,v6_1,v7_1,v8_1,v9_1,v10_1,v11_1,v12_1,v13_1,v14_1,v15_1,
			 V16_1,V17_1,V18_1,V19_1,V20_1,V21_1,V22_1,V23_1,V24_1,V25_1,V26_1,V27_1,V28_1,V29_1,V30_1,
			 V31_1,V32_1,V33_1,V34_1,V35_1,V36_1,V37_1,V38_1,V39_1,V40_1,V41_1,V42_1,V43_1,V44_1,V45_1,
			 V16T_1,V17T_1,V18T_1,V19T_1,V20T_1,V21T_1,V22T_1,V23T_1,V24T_1,V25T_1,V26T_1,V27T_1,V28T_1,V29T_1,V30T_1,
			 V31T_1,V32T_1,V33T_1,V34T_1,V35T_1,V36T_1,V37T_1,V38T_1,V39T_1,V40T_1,V41T_1,V42T_1,V43T_1,V44T_1,V45T_1

			 
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

pkv=0
opv=0

dyv_TSL=0
a3v_TSL=0
mdv_TSL=0
p3v_TSL=0
evv_TSL=0
	
pkv_TSL = 0
opv_TSL = 0

;pkv_TSL_pt = 0
;opv_TSL_pt = 0

;dyv_TSL_pt=0
;a3v_TSL_pt=0
;mdv_TSL_pt=0
;p3v_TSL_pt=0
;evv_TSL_pt=0
	
;pkv_TSL_pt = 0
;opv_TSL_pt = 0
	
pkv_GPSL = 0
opv_GPSL = 0

dyv_GPSL=0
a3v_GPSL=0
mdv_GPSL=0
p3v_GPSL=0
evv_GPSL=0
	
pkv_GPSL = 0
opv_GPSL = 0

;dyv_GPSL_pt=0
;a3v_GPSL_pt=0
;mdv_GPSL_pt=0
;p3v_GPSL_pt=0
;evv_GPSL_pt=0
	
;pkv_GPSL_pt = 0
;opv_GPSL_pt = 0

pkv_GPSL = 0
opv_GPSL = 0

dyv_HSL=0
a3v_HSL=0
mdv_HSL=0
p3v_HSL=0
evv_HSL=0
	
pkv_HSL = 0
opv_HSL = 0

;dyv_HSL_pt=0
;a3v_HSL_pt=0
;mdv_HSL_pt=0
;p3v_HSL_pt=0
;evv_HSL_pt=0
	
;pkv_HSL_pt = 0
;opv_HSL_pt = 0


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

; SL General Purpose Lane
; SL volumes
h07v_GPSL = li.2.V16_1	+	li.2.V17_1	+	li.2.V18_1	+	li.2.V19_1	+	li.2.V20_1	+	li.2.V21_1	+	li.2.V22_1	+	li.2.V23_1	+	li.2.V24_1	+	li.2.V25_1	+	li.2.V26_1	+	li.2.V27_1	+	li.2.V28_1	+	li.2.V29_1	+	li.2.V30_1
h08v_GPSL = li.3.V16_1	+	li.3.V17_1	+	li.3.V18_1	+	li.3.V19_1	+	li.3.V20_1	+	li.3.V21_1	+	li.3.V22_1	+	li.3.V23_1	+	li.3.V24_1	+	li.3.V25_1	+	li.3.V26_1	+	li.3.V27_1	+	li.3.V28_1	+	li.3.V29_1	+	li.3.V30_1
h09v_GPSL = li.4.V16_1	+	li.4.V17_1	+	li.4.V18_1	+	li.4.V19_1	+	li.4.V20_1	+	li.4.V21_1	+	li.4.V22_1	+	li.4.V23_1	+	li.4.V24_1	+	li.4.V25_1	+	li.4.V26_1	+	li.4.V27_1	+	li.4.V28_1	+	li.4.V29_1	+	li.4.V30_1
md5v_GPSL = li.5.V16_1	+	li.5.V17_1	+	li.5.V18_1	+	li.5.V19_1	+	li.5.V20_1	+	li.5.V21_1	+	li.5.V22_1	+	li.5.V23_1	+	li.5.V24_1	+	li.5.V25_1	+	li.5.V26_1	+	li.5.V27_1	+	li.5.V28_1	+	li.5.V29_1	+	li.5.V30_1
h15v_GPSL = li.6.V16_1	+	li.6.V17_1	+	li.6.V18_1	+	li.6.V19_1	+	li.6.V20_1	+	li.6.V21_1	+	li.6.V22_1	+	li.6.V23_1	+	li.6.V24_1	+	li.6.V25_1	+	li.6.V26_1	+	li.6.V27_1	+	li.6.V28_1	+	li.6.V29_1	+	li.6.V30_1
h16v_GPSL = li.7.V16_1	+	li.7.V17_1	+	li.7.V18_1	+	li.7.V19_1	+	li.7.V20_1	+	li.7.V21_1	+	li.7.V22_1	+	li.7.V23_1	+	li.7.V24_1	+	li.7.V25_1	+	li.7.V26_1	+	li.7.V27_1	+	li.7.V28_1	+	li.7.V29_1	+	li.7.V30_1
h17v_GPSL = li.8.V16_1	+	li.8.V17_1	+	li.8.V18_1	+	li.8.V19_1	+	li.8.V20_1	+	li.8.V21_1	+	li.8.V22_1	+	li.8.V23_1	+	li.8.V24_1	+	li.8.V25_1	+	li.8.V26_1	+	li.8.V27_1	+	li.8.V28_1	+	li.8.V29_1	+	li.8.V30_1
ev2v_GPSL = li.9.V16_1	+	li.9.V17_1	+	li.9.V18_1	+	li.9.V19_1	+	li.9.V20_1	+	li.9.V21_1	+	li.9.V22_1	+	li.9.V23_1	+	li.9.V24_1	+	li.9.V25_1	+	li.9.V26_1	+	li.9.V27_1	+	li.9.V28_1	+	li.9.V29_1	+	li.9.V30_1
n11v_GPSL = li.10.V16_1	+	li.10.V17_1	+	li.10.V18_1	+	li.10.V19_1	+	li.10.V20_1	+	li.10.V21_1	+	li.10.V22_1	+	li.10.V23_1	+	li.10.V24_1	+	li.10.V25_1	+	li.10.V26_1	+	li.10.V27_1	+	li.10.V28_1	+	li.10.V29_1	+	li.10.V30_1

; SL Hot Lane
; SL volumes
h07v_HSL = li.2.V31_1	+	li.2.V32_1	+	li.2.V33_1	+	li.2.V34_1	+	li.2.V35_1	+	li.2.V36_1	+	li.2.V37_1	+	li.2.V38_1	+	li.2.V39_1	+	li.2.V40_1	+	li.2.V41_1	+	li.2.V42_1	+	li.2.V43_1	+	li.2.V44_1	+	li.2.V45_1
h08v_HSL = li.3.V31_1	+	li.3.V32_1	+	li.3.V33_1	+	li.3.V34_1	+	li.3.V35_1	+	li.3.V36_1	+	li.3.V37_1	+	li.3.V38_1	+	li.3.V39_1	+	li.3.V40_1	+	li.3.V41_1	+	li.3.V42_1	+	li.3.V43_1	+	li.3.V44_1	+	li.3.V45_1
h09v_HSL = li.4.V31_1	+	li.4.V32_1	+	li.4.V33_1	+	li.4.V34_1	+	li.4.V35_1	+	li.4.V36_1	+	li.4.V37_1	+	li.4.V38_1	+	li.4.V39_1	+	li.4.V40_1	+	li.4.V41_1	+	li.4.V42_1	+	li.4.V43_1	+	li.4.V44_1	+	li.4.V45_1
md5v_HSL = li.5.V31_1	+	li.5.V32_1	+	li.5.V33_1	+	li.5.V34_1	+	li.5.V35_1	+	li.5.V36_1	+	li.5.V37_1	+	li.5.V38_1	+	li.5.V39_1	+	li.5.V40_1	+	li.5.V41_1	+	li.5.V42_1	+	li.5.V43_1	+	li.5.V44_1	+	li.5.V45_1
h15v_HSL = li.6.V31_1	+	li.6.V32_1	+	li.6.V33_1	+	li.6.V34_1	+	li.6.V35_1	+	li.6.V36_1	+	li.6.V37_1	+	li.6.V38_1	+	li.6.V39_1	+	li.6.V40_1	+	li.6.V41_1	+	li.6.V42_1	+	li.6.V43_1	+	li.6.V44_1	+	li.6.V45_1
h16v_HSL = li.7.V31_1	+	li.7.V32_1	+	li.7.V33_1	+	li.7.V34_1	+	li.7.V35_1	+	li.7.V36_1	+	li.7.V37_1	+	li.7.V38_1	+	li.7.V39_1	+	li.7.V40_1	+	li.7.V41_1	+	li.7.V42_1	+	li.7.V43_1	+	li.7.V44_1	+	li.7.V45_1
h17v_HSL = li.8.V31_1	+	li.8.V32_1	+	li.8.V33_1	+	li.8.V34_1	+	li.8.V35_1	+	li.8.V36_1	+	li.8.V37_1	+	li.8.V38_1	+	li.8.V39_1	+	li.8.V40_1	+	li.8.V41_1	+	li.8.V42_1	+	li.8.V43_1	+	li.8.V44_1	+	li.8.V45_1
ev2v_HSL = li.9.V31_1	+	li.9.V32_1	+	li.9.V33_1	+	li.9.V34_1	+	li.9.V35_1	+	li.9.V36_1	+	li.9.V37_1	+	li.9.V38_1	+	li.9.V39_1	+	li.9.V40_1	+	li.9.V41_1	+	li.9.V42_1	+	li.9.V43_1	+	li.9.V44_1	+	li.9.V45_1
n11v_HSL = li.10.V31_1	+	li.10.V32_1	+	li.10.V33_1	+	li.10.V34_1	+	li.10.V35_1	+	li.10.V36_1	+	li.10.V37_1	+	li.10.V38_1	+	li.10.V39_1	+	li.10.V40_1	+	li.10.V41_1	+	li.10.V42_1	+	li.10.V43_1	+	li.10.V44_1	+	li.10.V45_1

; SL Total (All Lanes)
; SL volumes
h07v_TSL = h07v_GPSL + h07v_HSL
h08v_TSL = h08v_GPSL + h08v_HSL
h09v_TSL = h09v_GPSL + h09v_HSL
md5v_TSL = md5v_GPSL + md5v_HSL
h15v_TSL = h15v_GPSL + h15v_HSL
h16v_TSL = h16v_GPSL + h16v_HSL
h17v_TSL = h17v_GPSL + h17v_HSL
ev2v_TSL = ev2v_GPSL + ev2v_HSL
n11v_TSL = n11v_GPSL + n11v_HSL
/*
;Total Select Link Volume (All Lanes)
_h07v_TTSL = li.1.h07v_TGPSL + li.1.h07v_THSL
_h08v_TTSL = li.1.h08v_TGPSL + li.1.h08v_THSL
_h09v_TTSL = li.1.h09v_TGPSL + li.1.h09v_THSL
_md5v_TTSL = li.1.md5v_TGPSL + li.1.md5v_THSL
_h15v_TTSL = li.1.h15v_TGPSL + li.1.h15v_THSL
_h16v_TTSL = li.1.h16v_TGPSL + li.1.h16v_THSL
_h17v_TTSL = li.1.h17v_TGPSL + li.1.h17v_THSL
_ev2v_TTSL = li.1.ev2v_TGPSL + li.1.ev2v_THSL
_n11v_TTSL = li.1.n11v_TGPSL + li.1.n11v_THSL

a3v_TTSL=int(_h07v_TTSL+_h08v_TTSL+_h09v_TTSL)
mdv_TTSL=int(_md5v_TTSL)
p3v_TTSL=int(_h15v_TTSL+_h16v_TTSL+_h17v_TTSL)
evv_TTSL=int(_ev2v_TTSL+_n11v_TTSL)
dyv_TTSL=int(a3v_TTSL+mdv_TTSL+p3v_TTSL+evv_TTSL)

pkv_TTSL=int(a3v_TTSL+p3v_TTSL)
opv_TTSL=int(mdv_TTSL+evv_TTSL)
*/
a3v=int(h07v+h08v+h09v)
mdv=int(md5v)
p3v=int(h15v+h16v+h17v)
evv=int(ev2v+n11v)
dyv=int(a3v+mdv+p3v+evv)

pkv=a3v+p3v
opv=mdv+evv

a3v_TSL=int(h07v_TSL+h08v_TSL+h09v_TSL)
mdv_TSL=int(md5v_TSL)
p3v_TSL=int(h15v_TSL+h16v_TSL+h17v_TSL)
evv_TSL=int(ev2v_TSL+n11v_TSL)
dyv_TSL=int(a3v_TSL+mdv_TSL+p3v_TSL+evv_TSL)

pkv_TSL=a3v_TSL+p3v_TSL
opv_TSL=mdv_TSL+evv_TSL

a3v_GPSL=int(h07v_GPSL+h08v_GPSL+h09v_GPSL)
mdv_GPSL=int(md5v_GPSL)
p3v_GPSL=int(h15v_GPSL+h16v_GPSL+h17v_GPSL)
evv_GPSL=int(ev2v_GPSL+n11v_GPSL)
dyv_GPSL=int(a3v_GPSL+mdv_GPSL+p3v_GPSL+evv_GPSL)

pkv_GPSL=int(a3v_GPSL+p3v_GPSL)
opv_GPSL=int(mdv_GPSL+evv_GPSL)

a3v_HSL=int(h07v_HSL+h08v_HSL+h09v_HSL)
mdv_HSL=int(md5v_HSL)
p3v_HSL=int(h15v_HSL+h16v_HSL+h17v_HSL)
evv_HSL=int(ev2v_HSL+n11v_HSL)
dyv_HSL=int(a3v_HSL+mdv_HSL+p3v_HSL+evv_HSL)

pkv_HSL=int(a3v_HSL+p3v_HSL)
opv_HSL=int(mdv_HSL+evv_HSL)

/*
if (dyv_GPSL>0 && dyv_TTSL>0)
	dyv_GPSL_pt= dyv_GPSL/dyv_TTSL
	a3v_GPSL_pt= a3v_GPSL/a3v_TTSL
	mdv_GPSL_pt= mdv_GPSL/mdv_TTSL
	p3v_GPSL_pt= p3v_GPSL/p3v_TTSL
	evv_GPSL_pt= evv_GPSL/evv_TTSL

	pkv_GPSL_pt = pkv_GPSL/pkv_TTSL
	opv_GPSL_pt = opv_GPSL/opv_TTSL
ENDIF
if (dyv_HSL>0 && dyv_TTSL>0)
	dyv_HSL_pt= dyv_HSL/dyv_TTSL
	a3v_HSL_pt= a3v_HSL/a3v_TTSL
	mdv_HSL_pt= mdv_HSL/mdv_TTSL
	p3v_HSL_pt= p3v_HSL/p3v_TTSL
	evv_HSL_pt= evv_HSL/evv_TTSL

	pkv_HSL_pt = pkv_HSL/pkv_TTSL
	opv_HSL_pt = opv_HSL/opv_TTSL	
ENDIF	
if (dyv_TSL>0 && dyv_TTSL>0)
	dyv_TSL_pt= dyv_TSL/dyv_TTSL
	a3v_TSL_pt= a3v_TSL/a3v_TTSL
	mdv_TSL_pt= mdv_TSL/mdv_TTSL
	p3v_TSL_pt= p3v_TSL/p3v_TTSL
	evv_TSL_pt= evv_TSL/evv_TTSL

	pkv_TSL_pt = pkv_TSL/pkv_TTSL
	opv_TSL_pt = opv_TSL/opv_TTSL
ENDIF
*/
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

pkvmt=a3vmt+p3vmt
opvmt=mdvmt+evvmt

;
; link volume by user type to Calcuate Revenues
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

;tolls
Toll_h07v_da = li.2.TOLLDA
Toll_h07v_sd2 = li.2.TOLLS2
Toll_h07v_sd3 = li.2.TOLLS3
Toll_h07v_cv = li.2.TOLLCV

;Calculate Revenue
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


merge record=false
endrun


