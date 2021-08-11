;Based on Full SacSIM19 Script and previous model(s) select zone scripts
;Select Zone script to calculate Project Level VMT.
; 	
;Created 9/15/2020 -Kyle Shipley
;Last update: 8/11/2021 - KS
; -adjusted speed bin code
; -updated TDF TC[] to match full model
; -adjusted min speed bin value
/*
INSTRUCTIONS:
  1 - create a 'select zone' subfolder within model run folder
  2 - copy/paste this script and the model run's base network into the select zone run folder
  3 - update the zone number for the TAZ(s) you want to run select-zone analysis on. Format follows '#-#,#,#', etc.
  4 - confirm/update auto cost based on scenario year
*/
;======================================================================
;inputs
; Insert project TAZ numbers.Separate out TAZ numbers as 'PROJECT2' or 'PROJECT3' to account for the max 255 character length for each TAZ list. Make sure to add a comma at the end for PROJECT1, so that cube reads it as a string of TAZs.
; Project Zones
PROJECT1='40,44,47-68,986,1078-1079,'
PROJECT2='1501'
PROJECT3=' '

;Set per-mile auto operating cost here
auto_cost_per_mile = 0.17

;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
maxit=300 ;
iter.relgap = 0.0002

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

	  
  RUN PGM=NETWORK  MSG='step 48 set prevvol and prevtime'
	  ; Set up assignments input network with information from previous assignment
	  NETI=..\vo.@per@.net

	  ; Previous volume and time
	  prevvol  = v_1
	  prevtime = time_1
	  precspd = cspd_1

	  ;drop previous loading variables (need to add as many excludes as there are)
	  NETO=vi.@per@.net, exclude=v_1,time_1,cspd_1,vc_1,vdt_1,vht_1,vt_1,
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

	NETI=vi.@per@.net                   ; previous (in) increments loaded network
	MATI=..\veh.avg.@per@.mat           ; 'veh.avg' for successively-averaged matrices
	FILEO NETO=vo.@per@_temp.net        ; output (new) loaded network
  MATO[1] = SZ_II.@per@_temp.mat MO=16-30
  MATO[2] = SZ_IX.@per@_temp.mat MO=31-45
  MATO[3] = SZ_XI.@per@_temp.mat MO=46-60
  MATO[4] = SZ_XX.@per@_temp.mat MO=61-75
  
  
  ;output project II,IX,XI,XX skims
	CAPFAC = @capfac@
	METERCLASS=@rampmeter@
	COMBINE=EQUI,MAXITERS=@maxit@,RELATIVEGAP=@iter.relgap@,gap=0,raad=0,aad=0;rmse=0.01

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
	  SPEED = li.precspd
	  t0 = li.distance * 60 / CmpNumRetNum(SPEED,'=',0,1,SPEED)
	  t1 = li.prevtime
	  
	IF (li.USECLASS == 0) ADDTOGROUP=1        ;GENERAL PURPOSE 
	IF (li.USECLASS == 2) ADDTOGROUP=2        ;HOV2+
	IF (li.USECLASS == 3) ADDTOGROUP=3        ;HOV3+
	IF (li.USECLASS == 4) ADDTOGROUP=4        ;not allowing Commercial Vehs to use HOVs during all hours 
			
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
  
  ;build all initial matrix by mode and VOT
  mw[1] = mi.1.da1
  mw[2] = mi.1.s21
  mw[3] = mi.1.s31
  mw[4] = mi.1.c21
  mw[5] = mi.1.c31
  mw[6] = mi.1.da2
  mw[7] = mi.1.s22
  mw[8] = mi.1.s32
  mw[9] = mi.1.c22
  mw[10] = mi.1.c32
  mw[11] = mi.1.da3
  mw[12] = mi.1.s23
  mw[13] = mi.1.s33
  mw[14] = mi.1.c23
  mw[15] = mi.1.c33
  
    ;project trips
  IF (I=@PROJECT1@@PROJECT2@@PROJECT3@)                          ;Isloate project trips                 
      
        mw[16] = mi.1.da1   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@      ; I-I
        mw[17] = mi.1.s21   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[18] = mi.1.s31   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[19] = mi.1.c21   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[20] = mi.1.c31   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[21] = mi.1.da2   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[22] = mi.1.s22   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[23] = mi.1.s32   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[24] = mi.1.c22   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[25] = mi.1.c32   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[26] = mi.1.da3   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[27] = mi.1.s23   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[28] = mi.1.s33   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[29] = mi.1.c23   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        mw[30] = mi.1.c33   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@ 
        
        
        mw[31] = mi.1.da1   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@			 ; I-X
        mw[32] = mi.1.s21   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[33] = mi.1.s31   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[34] = mi.1.c21   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[35] = mi.1.c31   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[36] = mi.1.da2   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[37] = mi.1.s22   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[38] = mi.1.s32   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[39] = mi.1.c22   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[40] = mi.1.c32   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[41] = mi.1.da3   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[42] = mi.1.s23   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[43] = mi.1.s33   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[44] = mi.1.c23   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[45] = mi.1.c33   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
      
  ELSE
       
        mw[46] = mi.1.da1   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@      ; X-I
        mw[47] = mi.1.s21   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[48] = mi.1.s31   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[49] = mi.1.c21   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[50] = mi.1.c31   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[51] = mi.1.da2   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[52] = mi.1.s22   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[53] = mi.1.s32   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[54] = mi.1.c22   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[55] = mi.1.c32   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[56] = mi.1.da3   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[57] = mi.1.s23   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[58] = mi.1.s33   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[59] = mi.1.c23   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
        mw[60] = mi.1.c33   INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
          
  ENDIF  
 
      mw[61] = mw[1]-(mw[16]+mw[31]+mw[46])                                                       ; X-X
      mw[62] = mw[2]-(mw[17]+mw[32]+mw[47])
      mw[63] = mw[3]-(mw[18]+mw[33]+mw[48])
      mw[64] = mw[4]-(mw[19]+mw[34]+mw[49])
      mw[65] = mw[5]-(mw[20]+mw[35]+mw[50])     
      mw[66] = mw[6]-(mw[21]+mw[36]+mw[51])
      mw[67] = mw[7]-(mw[22]+mw[37]+mw[52])
      mw[68] = mw[8]-(mw[23]+mw[38]+mw[53])
      mw[69] = mw[9]-(mw[24]+mw[39]+mw[54])
      mw[70] = mw[10]-(mw[25]+mw[40]+mw[55])  
      mw[71] = mw[11]-(mw[26]+mw[41]+mw[56])
      mw[72] = mw[12]-(mw[27]+mw[42]+mw[57])
      mw[73] = mw[13]-(mw[28]+mw[43]+mw[58])
      mw[74] = mw[14]-(mw[29]+mw[44]+mw[59])
      mw[75] = mw[15]-(mw[30]+mw[45]+mw[60])
      
      
    ;Assign I-I Trip Volumes
    
  PATHLOAD PATH=lw.imped1_da EXCLUDEGRP=2,3   VOL[01]=MW[16],
                                              VOL[02]=MW[19]		            ;VOT 1  Drive Alone VOT Class 1,Commercial Vehicles 2 axle
		PATH=lw.imped1_c3 EXCLUDEGRP=2,3,4        VOL[03]=mw[20]						    ;VOT 1  Commercial Vehicles 3 axle
		PATH=lw.imped1_s2 EXCLUDEGRP=3   		      VOL[04]=mw[17]     						;VOT 1  Shared Drive 2
		PATH=lw.imped1_s3   					            VOL[05]=mw[18]     						;VOT 1  Shared Drive 3+

		PATH=lw.imped2_da EXCLUDEGRP=2,3   		    VOL[06]=mw[21],
                                              VOL[07]=mw[24]             	  ;VOT 2  Drive Alone, Commercial Vehicles 2 axle	
    PATH=lw.imped2_c3 EXCLUDEGRP=2,3,4        VOL[08]=mw[25]		  				  ;VOT 2  Commercial Vehicles 3 axle
		PATH=lw.imped2_s2 EXCLUDEGRP=3   		      VOL[09]=mw[22]				      	;VOT 2  Shared Drive 2
		PATH=lw.imped2_s3 						            VOL[10]=mw[23]	    					;VOT 2  Shared Drive 3+
		PATH=lw.imped3_da EXCLUDEGRP=2,3       		VOL[11]=mw[26],
                                              VOL[12]=mw[29]   	            ;VOT 3  Drive Alone, Commercial Vehicles 2 axle

		PATH=lw.imped3_c3 EXCLUDEGRP=2,3,4        VOL[13]=mw[30]     						;VOT 3 Commercial Vehicles 3 axle
		PATH=lw.imped3_s2 EXCLUDEGRP=3   		      VOL[14]=mw[27]       					;VOT 3 Shared Drive 2
		PATH=lw.imped3_s3 						            VOL[15]=mw[28]    						;VOT 3 Shared Drive 3+
    
    ;Assign I-X Trip Volumes
    
	  PATH=lw.imped1_da EXCLUDEGRP=2,3          VOL[16]=MW[31],
                                              VOL[17]=MW[34]		            ;VOT 1  Drive Alone VOT Class 1,Commercial Vehicles 2 axle
		PATH=lw.imped1_c3 EXCLUDEGRP=2,3,4        VOL[18]=mw[35]						    ;VOT 1  Commercial Vehicles 3 axle
		PATH=lw.imped1_s2 EXCLUDEGRP=3   		      VOL[19]=mw[32]     						;VOT 1  Shared Drive 2
		PATH=lw.imped1_s3   					            VOL[20]=mw[33]     						;VOT 1  Shared Drive 3+

		PATH=lw.imped2_da EXCLUDEGRP=2,3   		    VOL[21]=mw[36],
                                              VOL[22]=mw[39]             	  ;VOT 2  Drive Alone, Commercial Vehicles 2 axle	
    PATH=lw.imped2_c3 EXCLUDEGRP=2,3,4        VOL[23]=mw[40]		  				  ;VOT 2  Commercial Vehicles 3 axle
		PATH=lw.imped2_s2 EXCLUDEGRP=3   		      VOL[24]=mw[37]				      	;VOT 2  Shared Drive 2
		PATH=lw.imped2_s3 						            VOL[25]=mw[38]	    					;VOT 2  Shared Drive 3+
		PATH=lw.imped3_da EXCLUDEGRP=2,3       		VOL[26]=mw[41],
                                              VOL[27]=mw[44]   	            ;VOT 3  Drive Alone, Commercial Vehicles 2 axle

		PATH=lw.imped3_c3 EXCLUDEGRP=2,3,4        VOL[28]=mw[45]     						;VOT 3 Commercial Vehicles 3 axle
		PATH=lw.imped3_s2 EXCLUDEGRP=3   		      VOL[29]=mw[42]       					;VOT 3 Shared Drive 2
		PATH=lw.imped3_s3 						            VOL[30]=mw[43]    						;VOT 3 Shared Drive 3+
    
    ;Assign X-I Trip Volumes
    
	  PATH=lw.imped1_da EXCLUDEGRP=2,3          VOL[31]=MW[46],
                                              VOL[32]=MW[49]		            ;VOT 1  Drive Alone VOT Class 1,Commercial Vehicles 2 axle
		PATH=lw.imped1_c3 EXCLUDEGRP=2,3,4        VOL[33]=mw[50]						    ;VOT 1  Commercial Vehicles 3 axle
		PATH=lw.imped1_s2 EXCLUDEGRP=3   		      VOL[34]=mw[47]     						;VOT 1  Shared Drive 2
		PATH=lw.imped1_s3   					            VOL[35]=mw[48]     						;VOT 1  Shared Drive 3+

		PATH=lw.imped2_da EXCLUDEGRP=2,3   		    VOL[36]=mw[51],
                                              VOL[37]=mw[54]             	  ;VOT 2  Drive Alone, Commercial Vehicles 2 axle	
    PATH=lw.imped2_c3 EXCLUDEGRP=2,3,4        VOL[38]=mw[55]		  				  ;VOT 2  Commercial Vehicles 3 axle
		PATH=lw.imped2_s2 EXCLUDEGRP=3   		      VOL[39]=mw[52]				      	;VOT 2  Shared Drive 2
		PATH=lw.imped2_s3 						            VOL[40]=mw[53]	    					;VOT 2  Shared Drive 3+
		PATH=lw.imped3_da EXCLUDEGRP=2,3       		VOL[41]=mw[56],
                                              VOL[42]=mw[59]   	            ;VOT 3  Drive Alone, Commercial Vehicles 2 axle

		PATH=lw.imped3_c3 EXCLUDEGRP=2,3,4        VOL[43]=mw[60]     						;VOT 3 Commercial Vehicles 3 axle
		PATH=lw.imped3_s2 EXCLUDEGRP=3   		      VOL[44]=mw[57]       					;VOT 3 Shared Drive 2
		PATH=lw.imped3_s3 						            VOL[45]=mw[58]    						;VOT 3 Shared Drive 3+
    
    ;Assign X-X Trip Volumes
    
	  PATH=lw.imped1_da EXCLUDEGRP=2,3          VOL[46]=MW[61],
                                              VOL[47]=MW[64]		            ;VOT 1  Drive Alone VOT Class 1,Commercial Vehicles 2 axle
		PATH=lw.imped1_c3 EXCLUDEGRP=2,3,4        VOL[48]=mw[65]						    ;VOT 1  Commercial Vehicles 3 axle
		PATH=lw.imped1_s2 EXCLUDEGRP=3   		      VOL[49]=mw[62]     						;VOT 1  Shared Drive 2
		PATH=lw.imped1_s3   					            VOL[50]=mw[63]     						;VOT 1  Shared Drive 3+

		PATH=lw.imped2_da EXCLUDEGRP=2,3   		    VOL[51]=mw[66],
                                              VOL[52]=mw[69]             	  ;VOT 2  Drive Alone, Commercial Vehicles 2 axle	
    PATH=lw.imped2_c3 EXCLUDEGRP=2,3,4        VOL[53]=mw[70]		  				  ;VOT 2  Commercial Vehicles 3 axle
		PATH=lw.imped2_s2 EXCLUDEGRP=3   		      VOL[54]=mw[67]				      	;VOT 2  Shared Drive 2
		PATH=lw.imped2_s3 						            VOL[55]=mw[68]	    					;VOT 2  Shared Drive 3+
		PATH=lw.imped3_da EXCLUDEGRP=2,3       		VOL[56]=mw[71],
                                              VOL[57]=mw[74]   	            ;VOT 3  Drive Alone, Commercial Vehicles 2 axle

		PATH=lw.imped3_c3 EXCLUDEGRP=2,3,4        VOL[58]=mw[75]     						;VOT 3 Commercial Vehicles 3 axle
		PATH=lw.imped3_s2 EXCLUDEGRP=3   		      VOL[59]=mw[72]       					;VOT 3 Shared Drive 2
		PATH=lw.imped3_s3 						            VOL[60]=mw[73]    						;VOT 3 Shared Drive 3+
       
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
			VOL[11]+VOL[12]*C2PCE+VOL[13]*C3PCE+VOL[14]+VOL[15] +
      VOL[16]+VOL[17]*C2PCE+VOL[18]*C3PCE+VOL[19]+VOL[20] +
			VOL[21]+VOL[22]*C2PCE+VOL[23]*C3PCE+VOL[24]+VOL[25] +
			VOL[26]+VOL[27]*C2PCE+VOL[28]*C3PCE+VOL[29]+VOL[30] +     
      VOL[31]+VOL[32]*C2PCE+VOL[33]*C3PCE+VOL[34]+VOL[35] +
			VOL[36]+VOL[37]*C2PCE+VOL[38]*C3PCE+VOL[39]+VOL[40] +
			VOL[41]+VOL[42]*C2PCE+VOL[43]*C3PCE+VOL[44]+VOL[45] +
      VOL[46]+VOL[47]*C2PCE+VOL[48]*C3PCE+VOL[49]+VOL[50] +
			VOL[51]+VOL[52]*C2PCE+VOL[53]*C3PCE+VOL[54]+VOL[55] +
			VOL[56]+VOL[57]*C2PCE+VOL[58]*C3PCE+VOL[59]+VOL[60]
      
      
      

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
                  
                  (time + (li.tollda + lw.AOcost)*@tolls.ivot1@			 ) * (v16 + v17*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot1@			 ) * (v18*C3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot1@ / HOV2Divisor	 ) * v19 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot1@ / HOV3Divisor	 ) * v20 +

                  (time + (li.tollda + lw.AOcost)*@tolls.ivot2@			 ) * (v21 + v22*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot2@			 ) * (v23*c3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot2@ / HOV2Divisor	 ) * v24 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot2@ / HOV3Divisor	 ) * v25 +

                  (time + (li.tollda + lw.AOcost)*@tolls.ivot3@			 ) * (v26 + V27*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot3@			 ) * (v28*c3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot3@ / HOV2Divisor	 ) * v29 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot3@ / HOV3Divisor	 ) * v30 +
                  
                  (time + (li.tollda + lw.AOcost)*@tolls.ivot1@			 ) * (v31 + v32*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot1@			 ) * (v33*C3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot1@ / HOV2Divisor	 ) * v34 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot1@ / HOV3Divisor	 ) * v35 +

                  (time + (li.tollda + lw.AOcost)*@tolls.ivot2@			 ) * (v36 + v37*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot2@			 ) * (v38*c3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot2@ / HOV2Divisor	 ) * v39 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot2@ / HOV3Divisor	 ) * v40 +

                  (time + (li.tollda + lw.AOcost)*@tolls.ivot3@			 ) * (v41 + v42*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot3@			 ) * (v43*c3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot3@ / HOV2Divisor	 ) * v44 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot3@ / HOV3Divisor	 ) * v45 +
                  
                  (time + (li.tollda + lw.AOcost)*@tolls.ivot1@			 ) * (v46 + v47*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot1@			 ) * (v48*C3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot1@ / HOV2Divisor	 ) * v49 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot1@ / HOV3Divisor	 ) * V50 +

                  (time + (li.tollda + lw.AOcost)*@tolls.ivot2@			 ) * (v51 + v52*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot2@			 ) * (v53*c3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot2@ / HOV2Divisor	 ) * v54 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot2@ / HOV3Divisor	 ) * v55 +

                  (time + (li.tollda + lw.AOcost)*@tolls.ivot3@			 ) * (v56 + v57*C2PCE) +
                  (time + (li.tollcv + lw.AOcost)*@tolls.ivot3@			 ) * (v58*c3PCE) +
                  (time + (li.tolls2 + lw.AOcost)*@tolls.ivot3@ / HOV2Divisor	 ) * v59 +
                  (time + (li.tolls3 + lw.AOcost)*@tolls.ivot3@ / HOV3Divisor	 ) * V60 +

	  0) / CmpNumRetNum(V,'=',0,1,V)

	ENDPHASE

	ENDRUN
	;======================================================================

    ; Skim mid-day congested network and use to calculate intrazonal VMT
  RUN PGM=HWYLOAD
    NETI=vo.@per@_temp.net
    MATO=temp.@per@.SKIM.mat, mo=1-2, name=DIST,TIME
    LOG var=_zones

  PHASE=LINKREAD
     IF (LI.CSPD_1>0) T0=(LI.DISTANCE/LI.CSPD_1)*60    ;use the congested time and do not divide by 0. 
  ENDPHASE
  Phase=ILOOP
       PATHLOAD  PATH=TIME,MW[1]=PATHTRACE(LI.DISTANCE)     ;compute the path distance based on the current time
       PATHLOAD  PATH=TIME,MW[2]=PATHTRACE(TIME,1)  
  EndPhase 
  ENDRUN

  ; Add intrazonal times & distances to skim matrix by calculating half the distance/time to the nearest TAZ
  RUN PGM=MATRIX
    mati=temp.@per@.SKIM.mat  ; Name=Dist, TIME
    MATO[1]=IZ_all.@per@.SKIM.mat, mo=3-4, name=DIST,TIME                                       
          mw[1] = MI.1.DIST                                           
          MW[2]= MI.1.TIME   
          MW[3][I]=lowest(1,1,0.001,99999,I)/2.0  ;shortest distance
          MW[4][I]=lowest(2,1,0.001,99999,I)/2.0  ;shortest time   
  ENDRUN
  RUN PGM=MATRIX
    mati=IZ_all.@per@.SKIM.mat  ; Name=Dist, TIME
    MATO[1]=IZ_II.@per@.SKIM.mat, mo=1-2, name=DIST,TIME
    MATO[2]=IZ_XX.@per@.SKIM.mat, mo=3-4, name=DIST,TIME
      IF (I=@PROJECT1@@PROJECT2@@PROJECT3@)                          ;Isloate project trips                     
          mw[1] = MI.1.DIST INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@    
          MW[2]= MI.1.TIME  INCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@		  
      ELSE
          mw[3] = MI.1.DIST  EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@                                         ;X: IZ non project trips
          MW[4]= MI.1.TIME   EXCLUDE=@PROJECT1@@PROJECT2@@PROJECT3@
      ENDIF
  ENDRUN 

;=======================================================
  
 	;====================================================================== 
  ; add new temp file to simplify period outputs
	RUN PGM=NETWORK  MSG='step: simplify period assignment outputs'
	; Vehicle trip assignnment

	NETI=vo.@per@_temp.net               ; raw select zone volumes networks
	FILEO NETO=vo.@per@_SZ_AllVMT.net,         ; output (new) loaded network
 
   INCLUDE=A,B,DISTANCE,SPEED,NAME,CAPCLASS,CSPD_A,TOT_V_A,SVT_II_A,SVT_IX_A,SVT_XI_A,VT_XX_A,SVMTII_A,SVMTIX_A,SVMTXI_A,VMT_XX_A
  
    CSPD_A=CSPD_1
    TOT_V_A=0
    
    SVT_II_A=li.1.V1_1	+	li.1.V2_1	+	li.1.V3_1	+	li.1.V4_1	+	li.1.V5_1	+	li.1.V6_1	+	li.1.V7_1	+	li.1.V8_1	+	li.1.V9_1	+	li.1.V10_1	+	li.1.V11_1	+	li.1.V12_1	+	li.1.V13_1	+	li.1.V14_1	+	li.1.V15_1 
    
    SVT_IX_A=li.1.V16_1	+	li.1.V17_1	+	li.1.V18_1	+	li.1.V19_1	+	li.1.V20_1	+	li.1.V21_1	+	li.1.V22_1	+	li.1.V23_1	+	li.1.V24_1	+	li.1.V25_1	+	li.1.V26_1	+	li.1.V27_1	+	li.1.V28_1	+	li.1.V29_1	+	li.1.V30_1
    
    SVT_XI_A=li.1.V31_1	+	li.1.V32_1	+	li.1.V33_1	+	li.1.V34_1	+	li.1.V35_1	+	li.1.V36_1	+	li.1.V37_1	+	li.1.V38_1	+	li.1.V39_1	+	li.1.V40_1	+	li.1.V41_1	+	li.1.V42_1	+	li.1.V43_1	+	li.1.V44_1	+	li.1.V45_1 
    
    VT_XX_A=li.1.V46_1	+	li.1.V47_1	+	li.1.V48_1	+	li.1.V49_1	+	li.1.V50_1	+	li.1.V51_1	+	li.1.V52_1	+	li.1.V53_1	+	li.1.V54_1	+	li.1.V55_1	+	li.1.V56_1	+	li.1.V57_1	+	li.1.V58_1	+	li.1.V59_1	+	li.1.V60_1
    
    TOT_V_A=SVT_II_A+SVT_IX_A+SVT_XI_A+VT_XX_A
    
    SVMTII_A=SVT_II_A*LI.1.DISTANCE
    SVMTIX_A=SVT_IX_A*LI.1.DISTANCE				
    SVMTXI_A=SVT_XI_A*LI.1.DISTANCE				
    VMT_XX_A=VT_XX_A*LI.1.DISTANCE
    TOT_VMT_A=(SVMTII_A+SVMTIX_A+SVMTXI_A)*LI.1.DISTANCE
    ENDRUN 
    
	;======================================================================
  	;======================================================================
  ; add new temp file to simplify period outputs
	RUN PGM=NETWORK  MSG='step: split project VMT'
	; Vehicle trip assignnment

	NETI=vo.@per@_SZ_AllVMT.net               ; raw select zone volumes networks
	FILEO NETO=vo.@per@_SZ_PrjVMT.net,         ; output (new) loaded network
 
   INCLUDE=A,B,DISTANCE,SPEED,NAME,CAPCLASS,CSPD_A,TOT_V_A,SVT_II_A,SVT_IX_A,SVT_XI_A,VT_XX_A,SVMTII_A,SVMTIX_A,SVMTXI_A,VMT_XX_A
  
    ;project trip split
    _SVT_II_PJT = SVT_II_A
    _SVT_IX_PJT = SVT_IX_A * 0.5    
    _SVT_XI_PJT = SVT_XI_A * 0.5   
    _VT_XX_PJT = 0  
    _TOT_V_PJT=_SVT_II_PJT+_SVT_IX_PJT+_SVT_XI_PJT
    
    ;project VMT
    TOT_VMT_PJT = 0
    VMTII_PJT = _SVT_II_PJT * LI.1.DISTANCE
    VMTIX_PJT = _SVT_IX_PJT * LI.1.DISTANCE				
    VMTXI_PJT = _SVT_XI_PJT * LI.1.DISTANCE				
    TOT_VMT_PJT = (VMTII_PJT+VMTIX_PJT+VMTXI_PJT)

    ;split speeds into bins
    CSPD_Agrp=0
    if (CSPD_A > 0.000 & CSPD_A <= 5.000) CSPD_Agrp=5
    if (CSPD_A > 5.000 & CSPD_A <= 10.000) CSPD_Agrp=10
    if (CSPD_A > 10.000 & CSPD_A <= 15.000) CSPD_Agrp=15
    if (CSPD_A > 15.000 & CSPD_A <= 20.000) CSPD_Agrp=20
    if (CSPD_A > 20.000 & CSPD_A <= 25.000) CSPD_Agrp=25
    if (CSPD_A > 25.000 & CSPD_A <= 30.000) CSPD_Agrp=30
    if (CSPD_A > 30.000 & CSPD_A <= 35.000) CSPD_Agrp=35
    if (CSPD_A > 35.000 & CSPD_A <= 40.000) CSPD_Agrp=40
    if (CSPD_A > 40.000 & CSPD_A <= 45.000) CSPD_Agrp=45
    if (CSPD_A > 45.000 & CSPD_A <= 50.000) CSPD_Agrp=50
    if (CSPD_A > 50.000 & CSPD_A <= 55.000) CSPD_Agrp=55
    if (CSPD_A > 55.000 & CSPD_A <= 60.000) CSPD_Agrp=60
    if (CSPD_A > 60.000 & CSPD_A <= 65.000) CSPD_Agrp=65
    if (CSPD_A > 65.000 & CSPD_A <= 70.000) CSPD_Agrp=70
    if (CSPD_A > 70.000 & CSPD_A <= 75.000) CSPD_Agrp=75
    if (CSPD_A > 75.000 & CSPD_A <= 80.000) CSPD_Agrp=80
    if (CSPD_A > 80.000 & CSPD_A <= 85.000) CSPD_Agrp=85
    if (CSPD_A > 85.000) CSPD_Agrp=90
    
    ENDRUN 
  
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
	
			filei NETI[1]=vo.@per@_temp.net
	
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
;Rollup and Export Intrazonal
RUN PGM=MATRIX  MSG='Rollup Intrazonal VMT'

mati[1]=IZ_II.h07.SKIM.mat    ; skim
mati[11]=IZ_XX.h07.SKIM.mat    
  

mati[2]=..\veh.avg.h07.mat    ;VT tables= 1-15 vehicle type by VOT bin
mati[3]=..\veh.avg.h08.mat    
mati[4]=..\veh.avg.h09.mat     
mati[5]=..\veh.avg.md5.mat
mati[6]=..\veh.avg.h15.mat    
mati[7]=..\veh.avg.h16.mat     
mati[8]=..\veh.avg.h17.mat
mati[9]=..\veh.avg.ev2.mat    
mati[10]=..\veh.avg.n11.mat  
 

fileo reco[1]=?IntrazonalVMT_pjt.dbf,
fields=I(8.0),
H07IZVMTII(8.0),H08IZVMTII(8.0),H09IZVMTII(8.0),
MD5IZVMTII(8.0),
H15IZVMTII(8.0),H16IZVMTII(8.0),H17IZVMTII(8.0),
EV2IZVMTII(8.0),N11IZVMTII(8.0),
AM3IZVMTII(8.0),M5IZVMTII(8.0),PM3IZVMTII(8.0),N13IZVMTII(8.0),
DayIZVMTII(12.0),
H07IZVMTXX(8.0),H08IZVMTXX(8.0),H09IZVMTXX(8.0),
MD5IZVMTXX(8.0),
H15IZVMTXX(8.0),H16IZVMTXX(8.0),H17IZVMTXX(8.0),
EV2IZVMTXX(8.0),N11IZVMTXX(8.0),
AM3IZVMTXX(8.0),M5IZVMTXX(8.0),PM3IZVMTXX(8.0),N13IZVMTXX,
DayIZVMTXX(12.0)

mw[12]=MI.2.1+MI.2.2+MI.2.3+MI.2.4+MI.2.5+MI.2.6+MI.2.7+MI.2.8+MI.2.9+MI.2.10+MI.2.11+MI.2.12+MI.2.13+MI.2.14+MI.2.15   ;h07 VT
mw[13]=MI.3.1+MI.3.2+MI.3.3+MI.3.4+MI.3.5+MI.3.6+MI.3.7+MI.3.8+MI.3.9+MI.3.10+MI.3.11+MI.3.12+MI.3.13+MI.3.14+MI.3.15   ;h08 VT
mw[14]=MI.4.1+MI.4.2+MI.4.3+MI.4.4+MI.4.5+MI.4.6+MI.4.7+MI.4.8+MI.4.9+MI.4.10+MI.4.11+MI.4.12+MI.4.13+MI.4.14+MI.4.15   ;h09 VT
mw[15]=MI.5.1+MI.5.2+MI.5.3+MI.5.4+MI.5.5+MI.5.6+MI.5.7+MI.5.8+MI.5.9+MI.5.10+MI.5.11+MI.5.12+MI.5.13+MI.5.14+MI.5.15   ;md5 VT
mw[16]=MI.6.1+MI.6.2+MI.6.3+MI.6.4+MI.6.5+MI.6.6+MI.6.7+MI.6.8+MI.6.9+MI.6.10+MI.6.11+MI.6.12+MI.6.13+MI.6.14+MI.6.15   ;h15 VT
mw[17]=MI.7.1+MI.7.2+MI.7.3+MI.7.4+MI.7.5+MI.7.6+MI.7.7+MI.7.8+MI.7.9+MI.7.10+MI.7.11+MI.7.12+MI.7.13+MI.7.14+MI.7.15   ;h16 VT
mw[18]=MI.8.1+MI.8.2+MI.8.3+MI.8.4+MI.8.5+MI.8.6+MI.8.7+MI.8.8+MI.8.9+MI.8.10+MI.8.11+MI.8.12+MI.8.13+MI.8.14+MI.8.15   ;h17 VT
mw[19]=MI.9.1+MI.9.2+MI.9.3+MI.9.4+MI.9.5+MI.9.6+MI.9.7+MI.9.8+MI.9.9+MI.9.10+MI.9.11+MI.9.12+MI.9.13+MI.9.14+MI.9.15   ;ev2 VT
mw[20]=MI.10.1+MI.10.2+MI.10.3+MI.10.4+MI.10.5+MI.10.6+MI.10.7+MI.10.8+MI.10.9+MI.10.10+MI.10.11+MI.10.12+MI.10.13+MI.10.14+MI.10.15   ;n11 VT

jloop j=i                                          ;intrazonal VTs
	mw[21]=mw[12]
	mw[22]=mw[13]
	mw[23]=mw[14]
	mw[24]=mw[15]
	mw[25]=mw[16]
	mw[26]=mw[17]
	mw[27]=mw[18]
	mw[28]=mw[19]
  mw[29]=mw[20]
endjloop


;II
mw[41]=mw[21]*mi.1.1                           ;intrazonal VMT
mw[42]=mw[22]*mi.1.1 
mw[43]=mw[23]*mi.1.1 
mw[44]=mw[24]*mi.1.1 
mw[45]=mw[25]*mi.1.1                   
mw[46]=mw[26]*mi.1.1 
mw[47]=mw[27]*mi.1.1 
mw[48]=mw[28]*mi.1.1 
mw[49]=mw[29]*mi.1.1                   

;XX
mw[50]=mw[21]*mi.11.1                          ;intrazonal VMT
mw[51]=mw[22]*mi.11.1 
mw[52]=mw[23]*mi.11.1 
mw[53]=mw[24]*mi.11.1 
mw[54]=mw[25]*mi.11.1                    
mw[55]=mw[26]*mi.11.1 
mw[56]=mw[27]*mi.11.1 
mw[57]=mw[28]*mi.11.1 
mw[58]=mw[29]*mi.11.1  

H07IZVMTII=ROWSUM(41)
H08IZVMTII=ROWSUM(42)
H09IZVMTII=ROWSUM(43)
MD5IZVMTII=ROWSUM(44)
H15IZVMTII=ROWSUM(45)
H16IZVMTII=ROWSUM(46)
H17IZVMTII=ROWSUM(47)
EV2IZVMTII=ROWSUM(48)
N11IZVMTII=ROWSUM(49)

H07IZVMTXX=ROWSUM(50)
H08IZVMTXX=ROWSUM(51)
H09IZVMTXX=ROWSUM(52)
MD5IZVMTXX=ROWSUM(53)
H15IZVMTXX=ROWSUM(54)
H16IZVMTXX=ROWSUM(55)
H17IZVMTXX=ROWSUM(56)
EV2IZVMTXX=ROWSUM(57)
N11IZVMTXX=ROWSUM(58)


AM3IZVMTII=H07IZVMTII+H08IZVMTII+H09IZVMTII
M5IZVMTII=MD5IZVMTII
PM3IZVMTII=H15IZVMTII+H16IZVMTII+H17IZVMTII
N13IZVMTII=EV2IZVMTII+N11IZVMTII

DayIZVMTII=H07IZVMTII+H08IZVMTII+H09IZVMTII+MD5IZVMTII+H15IZVMTII+H16IZVMTII+H17IZVMTII+EV2IZVMTII+N11IZVMTII

AM3IZVMTXX=H07IZVMTXX+H08IZVMTXX+H09IZVMTXX
M5IZVMTXX=MD5IZVMTXX
PM3IZVMTXX=H15IZVMTXX+H16IZVMTXX+H17IZVMTXX
N13IZVMTXX=EV2IZVMTXX+N11IZVMTXX

DayIZVMTXX=H07IZVMTXX+H08IZVMTXX+H09IZVMTXX+MD5IZVMTXX+H15IZVMTXX+H16IZVMTXX+H17IZVMTXX+EV2IZVMTXX+N11IZVMTXX

WRITE RECO=1
ENDRUN

RUN PGM=MATRIX

FILEI DBI=?IntrazonalVMT_pjt.dbf,sort=I

FILEO PRINTO=?IntrazonalVMT_pjt.csv

zones=1

Print list="I","H07IZVMTII","H08IZVMTII","H09IZVMTII","MD5IZVMTII","H15IZVMTII","H16IZVMTII","H17IZVMTII","EV2IZVMTII","N11IZVMTII","AM3IZVMTII","M5IZVMTII","PM3IZVMTII","N13IZVMTII","DayIZVMTII","H07IZVMTXX","H08IZVMTXX","H09IZVMTXX","MD5IZVMTXX","H15IZVMTXX","H16IZVMTXX","H17IZVMTXX","EV2IZVMTXX","N11IZVMTXX","AM3IZVMTXX","M5IZVMTXX","PM3IZVMTXX","N13IZVMTXX","DayIZVMTXX" printo=1 CSV=T


loop _k=1,DBI.1.NUMRECORDS

    X=DBIReadRecord(1,_k)

    PRINT LIST=di.1.I,di.1.H07IZVMTII, di.1.H08IZVMTII,di.1.H09IZVMTII,
              di.1.MD5IZVMTII,di.1.H15IZVMTII,di.1.H16IZVMTII,di.1.H17IZVMTII,di.1.EV2IZVMTII,di.1.N11IZVMTII,di.1.AM3IZVMTII,di.1.M5IZVMTII,di.1.PM3IZVMTII,di.1.N13IZVMTII,di.1.DayIZVMTII,di.1.H07IZVMTXX, di.1.H08IZVMTXX,di.1.H09IZVMTXX,di.1.MD5IZVMTXX,di.1.H15IZVMTXX,di.1.H16IZVMTXX,di.1.H17IZVMTXX,di.1.EV2IZVMTXX,di.1.N11IZVMTXX,di.1.AM3IZVMTII,di.1.M5IZVMTII,di.1.PM3IZVMTII,di.1.N13IZVMTII,di.1.DayIZVMTXX, PRINTO=1 CSV=T
endloop

ENDRUN


;===========================================================================
;Rollup Network with Select Zone
run pgm=network  MSG='Rollup Select Zone daily network'

filei linki[1]=vo.h07_SZ_PrjVMT.net
      linki[2]=vo.h08_SZ_PrjVMT.net
      linki[3]=vo.h09_SZ_PrjVMT.net
	  
      linki[4]=vo.md5_SZ_PrjVMT.net
	  
      linki[5]=vo.h15_SZ_PrjVMT.net
      linki[6]=vo.h16_SZ_PrjVMT.net
      linki[7]=vo.h17_SZ_PrjVMT.net
	  
      linki[8]=vo.ev2_SZ_PrjVMT.net
      linki[9]=vo.n11_SZ_PrjVMT.net
	  linki[10]=..\?_base.net
	  
fileo neto=?daynet_SZ_PjtVMT.net INCLUDE=A,B,DISTANCE,SPEED,NAME,CAPCLASS

linko=?daynet_SZ_PjtVMT.dbf format=dbf

	;if (capclass=7,99) delete
	county='NA'
	RAD = li.10.RAD
	LANES = li.10.LANES
	TOLLID = li.10.TOLLID
	GPID = li.10.GPID
	AUXID = li.10.AUXID
	USECLASS = li.10.USECLASS
	FWYID =li.10.FWYID 
	
	if (rad=1-29) county='Sacramento'
	if (rad=30-36) county='Sutter'
	if (rad=40-47) county='Yuba'
	if (rad=50-57) county='Yolo'
	if (rad=70-82) county='Placer'
	if (rad=85-96) county='El Dorado'
	if (rad=97) county='External'

    ;project trip split
    _SVT_II_PJT = SVT_II_A
    _SVT_IX_PJT = SVT_IX_A * 0.5    
    _SVT_XI_PJT = SVT_XI_A * 0.5   
    _VT_XX_PJT = 0  
    _TOT_V_PJT=_SVT_II_PJT+_SVT_IX_PJT+_SVT_XI_PJT
    
    ;project VMT
    TOT_VMT_PJT = 0
    VMTII_PJT = _SVT_II_PJT * LI.1.DISTANCE
    VMTIX_PJT = _SVT_IX_PJT * LI.1.DISTANCE				
    VMTXI_PJT = _SVT_XI_PJT * LI.1.DISTANCE				
    TOT_VMT_PJT = (VMTII_PJT+VMTIX_PJT+VMTXI_PJT)

    ;split speeds into bins
    CSPD_Agrp=0

	DYCSPD_A = 0
	DYTOT_V = 0
	DYSVT_II = 0
	DYSVT_IX = 0 
	DYSVT_XI = 0
	DYSVT_XX = 0
	DYSVMTII = 0
	DYSVMTIX = 0
	DYSVMTXI = 0
	DYVMT_XX = 0
	DYVMT_PJT = 0
	DYVMTII_PJT = 0
	DYVMTIX_PJT = 0
	DYVMTXI_PJT = 0
	DYVCSPD_Agrp = 0

	AM3CSPD_A = (li.1.CSPD_A + li.2.CSPD_A + li.3.CSPD_A) * 0.3333 ; divide by 3
	AM3TOT_V = li.1.TOT_V_A + li.2.TOT_V_A + li.3.TOT_V_A
	AM3SVT_II = li.1.SVT_II_A + li.2.SVT_II_A + li.3.SVT_II_A
	AM3SVT_IX = li.1.SVT_IX_A + li.2.SVT_IX_A + li.3.SVT_IX_A
	AM3SVT_XI = li.1.SVT_XI_A + li.2.SVT_XI_A + li.3.SVT_XI_A
	AM3SVT_XX = li.1.VT_XX_A + li.2.VT_XX_A + li.3.VT_XX_A
	AM3SVMTII = li.1.SVMTII_A + li.2.SVMTII_A + li.3.SVMTII_A
	AM3SVMTIX = li.1.SVMTIX_A + li.2.SVMTIX_A + li.3.SVMTIX_A
	AM3SVMTXI = li.1.SVMTXI_A + li.2.SVMTXI_A + li.3.SVMTXI_A
	AM3VMT_XX = li.1.VMT_XX_A + li.2.VMT_XX_A + li.3.VMT_XX_A
	AM3VMT_PJT = li.1.TOT_VMT_PJT + li.2.TOT_VMT_PJT + li.3.TOT_VMT_PJT
	AM3VMTII_PJT = li.1.VMTII_PJT + li.2.VMTII_PJT + li.3.VMTII_PJT
	AM3VMTIX_PJT = li.1.VMTIX_PJT + li.2.VMTIX_PJT + li.3.VMTIX_PJT
	AM3VMTXI_PJT = li.1.VMTXI_PJT + li.2.VMTXI_PJT + li.3.VMTXI_PJT
	AM3CSPD_Agrp = 0

	MD5CSPD_A = li.4.CSPD_A
	MD5TOT_V = li.4.TOT_V_A
	MD5SVT_II = li.4.SVT_II_A
	MD5SVT_IX = li.4.SVT_IX_A
	MD5SVT_XI = li.4.SVT_XI_A
	MD5SVT_XX = li.4.VT_XX_A
	MD5SVMTII = li.4.SVMTII_A
	MD5SVMTIX = li.4.SVMTIX_A
	MD5SVMTXI = li.4.SVMTXI_A
	MD5VMT_XX = li.4.VMT_XX_A
	MD5VMT_PJT = li.4.TOT_VMT_PJT
	MD5VMTII_PJT = li.4.VMTII_PJT
	MD5VMTIX_PJT = li.4.VMTIX_PJT
	MD5VMTXI_PJT = li.4.VMTXI_PJT
	MD5CSPD_Agrp = 0

	PM3CSPD_A = (li.5.CSPD_A + li.6.CSPD_A + li.7.CSPD_A) * 0.3333 ; divide by 3
	PM3TOT_V = li.5.TOT_V_A + li.6.TOT_V_A + li.7.TOT_V_A
	PM3SVT_II = li.5.SVT_II_A + li.6.SVT_II_A + li.7.SVT_II_A
	PM3SVT_IX = li.5.SVT_IX_A + li.6.SVT_IX_A + li.7.SVT_IX_A
	PM3SVT_XI = li.5.SVT_XI_A + li.6.SVT_XI_A + li.7.SVT_XI_A
	PM3SVT_XX = li.5.VT_XX_A + li.6.VT_XX_A + li.7.VT_XX_A
	PM3SVMTII = li.5.SVMTII_A + li.6.SVMTII_A + li.7.SVMTII_A
	PM3SVMTIX = li.5.SVMTIX_A + li.6.SVMTIX_A + li.7.SVMTIX_A
	PM3SVMTXI = li.5.SVMTXI_A + li.6.SVMTXI_A + li.7.SVMTXI_A
	PM3VMT_XX = li.5.VMT_XX_A + li.6.VMT_XX_A + li.7.VMT_XX_A
	PM3VMT_PJT = li.5.TOT_VMT_PJT + li.6.TOT_VMT_PJT + li.7.TOT_VMT_PJT
	PM3VMTII_PJT = li.5.VMTII_PJT + li.6.VMTII_PJT + li.7.VMTII_PJT
	PM3VMTIX_PJT = li.5.VMTIX_PJT + li.6.VMTIX_PJT + li.7.VMTIX_PJT
	PM3VMTXI_PJT = li.5.VMTXI_PJT + li.6.VMTXI_PJT + li.7.VMTXI_PJT
	PM3CSPD_Agrp = 0

	N13CSPD_A = ((li.8.CSPD_A * 2) + (li.9.CSPD_A * 11)) * 0.0769 ; divide by 13
	N13TOT_V = li.8.TOT_V_A + li.9.TOT_V_A
	N13SVT_II = li.8.SVT_II_A + li.9.SVT_II_A
	N13SVT_IX = li.8.SVT_IX_A + li.9.SVT_IX_A 
	N13SVT_XI = li.8.SVT_XI_A + li.9.SVT_XI_A
	N13SVT_XX = li.8.VT_XX_A + li.9.VT_XX_A
	N13SVMTII = li.8.SVMTII_A + li.9.SVMTII_A
	N13SVMTIX = li.8.SVMTIX_A + li.9.SVMTIX_A
	N13SVMTXI = li.8.SVMTXI_A + li.9.SVMTXI_A
	N13VMT_XX = li.8.VMT_XX_A + li.9.VMT_XX_A
	N13VMT_PJT = li.8.TOT_VMT_PJT + li.9.TOT_VMT_PJT
	N13VMTII_PJT = li.8.VMTII_PJT + li.9.VMTII_PJT
	N13VMTIX_PJT = li.8.VMTIX_PJT + li.9.VMTIX_PJT
	N13VMTXI_PJT = li.8.VMTXI_PJT + li.9.VMTXI_PJT
	N13CSPD_Agrp = 0 

	DYCSPD_A = (li.1.CSPD_A + li.2.CSPD_A + li.3.CSPD_A + (li.4.CSPD_A * 5) + li.5.CSPD_A + li.6.CSPD_A + li.7.CSPD_A + (li.8.CSPD_A * 2) + (li.9.CSPD_A * 11)) * 0.0417 ; divide by 24
	DYTOT_V = AM3TOT_V + MD5TOT_V + PM3TOT_V + N13TOT_V
	DYSVT_II = AM3SVT_II + MD5SVT_II + PM3SVT_II + N13SVT_II
	DYSVT_IX = AM3SVT_IX + MD5SVT_IX + PM3SVT_IX + N13SVT_IX 
	DYSVT_XI = AM3SVT_XI + MD5SVT_XI + PM3SVT_XI + N13SVT_XI
	DYSVT_XX = AM3SVT_XX + MD5SVT_XX + PM3SVT_XX + N13SVT_XX
	DYSVMTII = AM3SVMTII + MD5SVMTII + PM3SVMTII + N13SVMTII
	DYSVMTIX = AM3SVMTIX + MD5SVMTIX + PM3SVMTIX + N13SVMTIX
	DYSVMTXI = AM3SVMTXI + MD5SVMTXI + PM3SVMTXI + N13SVMTXI
	DYVMT_XX = AM3VMT_XX + MD5VMT_XX + PM3VMT_XX + N13VMT_XX
	DYVMT_PJT = AM3VMT_PJT + MD5VMT_PJT + PM3VMT_PJT + N13VMT_PJT
	DYVMTII_PJT = AM3VMTII_PJT + MD5VMTII_PJT + PM3VMTII_PJT + N13VMTII_PJT
	DYVMTIX_PJT = AM3VMTIX_PJT + MD5VMTIX_PJT + PM3VMTIX_PJT + N13VMTIX_PJT
	DYVMTXI_PJT = AM3VMTXI_PJT + MD5VMTXI_PJT + PM3VMTXI_PJT + N13VMTXI_PJT
	DYCSPD_Agrp = 0

	;split speeds into bins AM3CSPD_A AM3CSPD_Agrp
    if (AM3CSPD_A > 0.000 & AM3CSPD_A <= 5.000) AM3CSPD_Agrp=5
    if (AM3CSPD_A > 5.000 & AM3CSPD_A <= 10.000) AM3CSPD_Agrp=10
    if (AM3CSPD_A > 10.000 & AM3CSPD_A <= 15.000) AM3CSPD_Agrp=15
    if (AM3CSPD_A > 15.000 & AM3CSPD_A <= 20.000) AM3CSPD_Agrp=20
    if (AM3CSPD_A > 20.000 & AM3CSPD_A <= 25.000) AM3CSPD_Agrp=25
    if (AM3CSPD_A > 25.000 & AM3CSPD_A <= 30.000) AM3CSPD_Agrp=30
    if (AM3CSPD_A > 30.000 & AM3CSPD_A <= 35.000) AM3CSPD_Agrp=35
    if (AM3CSPD_A > 35.000 & AM3CSPD_A <= 40.000) AM3CSPD_Agrp=40
    if (AM3CSPD_A > 40.000 & AM3CSPD_A <= 45.000) AM3CSPD_Agrp=45
    if (AM3CSPD_A > 45.000 & AM3CSPD_A <= 50.000) AM3CSPD_Agrp=50
    if (AM3CSPD_A > 50.000 & AM3CSPD_A <= 55.000) AM3CSPD_Agrp=55
    if (AM3CSPD_A > 55.000 & AM3CSPD_A <= 60.000) AM3CSPD_Agrp=60
    if (AM3CSPD_A > 60.000 & AM3CSPD_A <= 65.000) AM3CSPD_Agrp=65
    if (AM3CSPD_A > 65.000 & AM3CSPD_A <= 70.000) AM3CSPD_Agrp=70
    if (AM3CSPD_A > 70.000 & AM3CSPD_A <= 75.000) AM3CSPD_Agrp=75
    if (AM3CSPD_A > 75.000 & AM3CSPD_A <= 80.000) AM3CSPD_Agrp=80
    if (AM3CSPD_A > 80.000 & AM3CSPD_A <= 85.000) AM3CSPD_Agrp=85
    if (AM3CSPD_A > 85.000) AM3CSPD_Agrp=90

	;split speeds into bins MD5CSPD_A MD5CSPD_Agrp
    if (MD5CSPD_A > 0.000 & MD5CSPD_A <= 5.000) MD5CSPD_Agrp=5
    if (MD5CSPD_A > 5.000 & MD5CSPD_A <= 10.000) MD5CSPD_Agrp=10
    if (MD5CSPD_A > 10.000 & MD5CSPD_A <= 15.000) MD5CSPD_Agrp=15
    if (MD5CSPD_A > 15.000 & MD5CSPD_A <= 20.000) MD5CSPD_Agrp=20
    if (MD5CSPD_A > 20.000 & MD5CSPD_A <= 25.000) MD5CSPD_Agrp=25
    if (MD5CSPD_A > 25.000 & MD5CSPD_A <= 30.000) MD5CSPD_Agrp=30
    if (MD5CSPD_A > 30.000 & MD5CSPD_A <= 35.000) MD5CSPD_Agrp=35
    if (MD5CSPD_A > 35.000 & MD5CSPD_A <= 40.000) MD5CSPD_Agrp=40
    if (MD5CSPD_A > 40.000 & MD5CSPD_A <= 45.000) MD5CSPD_Agrp=45
    if (MD5CSPD_A > 45.000 & MD5CSPD_A <= 50.000) MD5CSPD_Agrp=50
    if (MD5CSPD_A > 50.000 & MD5CSPD_A <= 55.000) MD5CSPD_Agrp=55
    if (MD5CSPD_A > 55.000 & MD5CSPD_A <= 60.000) MD5CSPD_Agrp=60
    if (MD5CSPD_A > 60.000 & MD5CSPD_A <= 65.000) MD5CSPD_Agrp=65
    if (MD5CSPD_A > 65.000 & MD5CSPD_A <= 70.000) MD5CSPD_Agrp=70
    if (MD5CSPD_A > 70.000 & MD5CSPD_A <= 75.000) MD5CSPD_Agrp=75
    if (MD5CSPD_A > 75.000 & MD5CSPD_A <= 80.000) MD5CSPD_Agrp=80
    if (MD5CSPD_A > 80.000 & MD5CSPD_A <= 85.000) MD5CSPD_Agrp=85
    if (MD5CSPD_A > 85.000) MD5CSPD_Agrp=90

	;split speeds into bins PM3CSPD_A PM3CSPD_Agrp
    if (PM3CSPD_A > 0.000 & PM3CSPD_A <= 5.000) PM3CSPD_Agrp=5
    if (PM3CSPD_A > 5.000 & PM3CSPD_A <= 10.000) PM3CSPD_Agrp=10
    if (PM3CSPD_A > 10.000 & PM3CSPD_A <= 15.000) PM3CSPD_Agrp=15
    if (PM3CSPD_A > 15.000 & PM3CSPD_A <= 20.000) PM3CSPD_Agrp=20
    if (PM3CSPD_A > 20.000 & PM3CSPD_A <= 25.000) PM3CSPD_Agrp=25
    if (PM3CSPD_A > 25.000 & PM3CSPD_A <= 30.000) PM3CSPD_Agrp=30
    if (PM3CSPD_A > 30.000 & PM3CSPD_A <= 35.000) PM3CSPD_Agrp=35
    if (PM3CSPD_A > 35.000 & PM3CSPD_A <= 40.000) PM3CSPD_Agrp=40
    if (PM3CSPD_A > 40.000 & PM3CSPD_A <= 45.000) PM3CSPD_Agrp=45
    if (PM3CSPD_A > 45.000 & PM3CSPD_A <= 50.000) PM3CSPD_Agrp=50
    if (PM3CSPD_A > 50.000 & PM3CSPD_A <= 55.000) PM3CSPD_Agrp=55
    if (PM3CSPD_A > 55.000 & PM3CSPD_A <= 60.000) PM3CSPD_Agrp=60
    if (PM3CSPD_A > 60.000 & PM3CSPD_A <= 65.000) PM3CSPD_Agrp=65
    if (PM3CSPD_A > 65.000 & PM3CSPD_A <= 70.000) PM3CSPD_Agrp=70
    if (PM3CSPD_A > 70.000 & PM3CSPD_A <= 75.000) PM3CSPD_Agrp=75
    if (PM3CSPD_A > 75.000 & PM3CSPD_A <= 80.000) PM3CSPD_Agrp=80
    if (PM3CSPD_A > 80.000 & PM3CSPD_A <= 85.000) PM3CSPD_Agrp=85
    if (PM3CSPD_A > 85.000) PM3CSPD_Agrp=90

	;split speeds into bins N13CSPD_A N13CSPD_Agrp
    if (N13CSPD_A > 0.000 & N13CSPD_A <= 5.000) N13CSPD_Agrp=5
    if (N13CSPD_A > 5.000 & N13CSPD_A <= 10.000) N13CSPD_Agrp=10
    if (N13CSPD_A > 10.000 & N13CSPD_A <= 15.000) N13CSPD_Agrp=15
    if (N13CSPD_A > 15.000 & N13CSPD_A <= 20.000) N13CSPD_Agrp=20
    if (N13CSPD_A > 20.000 & N13CSPD_A <= 25.000) N13CSPD_Agrp=25
    if (N13CSPD_A > 25.000 & N13CSPD_A <= 30.000) N13CSPD_Agrp=30
    if (N13CSPD_A > 30.000 & N13CSPD_A <= 35.000) N13CSPD_Agrp=35
    if (N13CSPD_A > 35.000 & N13CSPD_A <= 40.000) N13CSPD_Agrp=40
    if (N13CSPD_A > 40.000 & N13CSPD_A <= 45.000) N13CSPD_Agrp=45
    if (N13CSPD_A > 45.000 & N13CSPD_A <= 50.000) N13CSPD_Agrp=50
    if (N13CSPD_A > 50.000 & N13CSPD_A <= 55.000) N13CSPD_Agrp=55
    if (N13CSPD_A > 55.000 & N13CSPD_A <= 60.000) N13CSPD_Agrp=60
    if (N13CSPD_A > 60.000 & N13CSPD_A <= 65.000) N13CSPD_Agrp=65
    if (N13CSPD_A > 65.000 & N13CSPD_A <= 70.000) N13CSPD_Agrp=70
    if (N13CSPD_A > 70.000 & N13CSPD_A <= 75.000) N13CSPD_Agrp=75
    if (N13CSPD_A > 75.000 & N13CSPD_A <= 80.000) N13CSPD_Agrp=80
    if (N13CSPD_A > 80.000 & N13CSPD_A <= 85.000) N13CSPD_Agrp=85
    if (N13CSPD_A > 85.000) N13CSPD_Agrp=90

	;split speeds into bins DYCSPD_A DYCSPD_Agrp
    if (DYCSPD_A > 0.000 & DYCSPD_A <= 5.000) DYCSPD_Agrp=5
    if (DYCSPD_A > 5.000 & DYCSPD_A <= 10.000) DYCSPD_Agrp=10
    if (DYCSPD_A > 10.000 & DYCSPD_A <= 15.000) DYCSPD_Agrp=15
    if (DYCSPD_A > 15.000 & DYCSPD_A <= 20.000) DYCSPD_Agrp=20
    if (DYCSPD_A > 20.000 & DYCSPD_A <= 25.000) DYCSPD_Agrp=25
    if (DYCSPD_A > 25.000 & DYCSPD_A <= 30.000) DYCSPD_Agrp=30
    if (DYCSPD_A > 30.000 & DYCSPD_A <= 35.000) DYCSPD_Agrp=35
    if (DYCSPD_A > 35.000 & DYCSPD_A <= 40.000) DYCSPD_Agrp=40
    if (DYCSPD_A > 40.000 & DYCSPD_A <= 45.000) DYCSPD_Agrp=45
    if (DYCSPD_A > 45.000 & DYCSPD_A <= 50.000) DYCSPD_Agrp=50
    if (DYCSPD_A > 50.000 & DYCSPD_A <= 55.000) DYCSPD_Agrp=55
    if (DYCSPD_A > 55.000 & DYCSPD_A <= 60.000) DYCSPD_Agrp=60
    if (DYCSPD_A > 60.000 & DYCSPD_A <= 65.000) DYCSPD_Agrp=65
    if (DYCSPD_A > 65.000 & DYCSPD_A <= 70.000) DYCSPD_Agrp=70
    if (DYCSPD_A > 70.000 & DYCSPD_A <= 75.000) DYCSPD_Agrp=75
    if (DYCSPD_A > 75.000 & DYCSPD_A <= 80.000) DYCSPD_Agrp=80
    if (DYCSPD_A > 80.000 & DYCSPD_A <= 85.000) DYCSPD_Agrp=85
    if (DYCSPD_A > 85.000) DYCSPD_Agrp=90

merge record=false
endrun
