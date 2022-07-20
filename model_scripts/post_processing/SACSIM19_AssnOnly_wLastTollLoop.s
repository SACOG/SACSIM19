/*
SACSIM19 Assignment-Only script.
Purpose: Holding land use and trip table constant, this script assigns trips to the SACSIM network.
	In starting the assignment, it takes the volumes and travel times from the final loaded
	output networks (vo.<per>.net files) from the parent SACSIM full model run.
	
INSTRUCTIONS:
1) Within the completed full model run folder, create a subfolder, name is not important.
2) Put the following into the subfolder:
	-This script
	-Copy of the base network from the parent model run folder 
3) Make changes on the copied base network if desired (e.g., to reflect implementation of transportation project)
4) Run this script from inside the subfolder.


*/

;Based on Full SacSIM19 Script
;Assignment Only using last toll facility pricing costs. -Kyle Shipley
; 	-to adjust toll costs, must update at link level or use assignment script with toll optimization loop.

;Last update: 9/14/2021 - KS
;   -adjusted base net cspd_1 and time step 48
;	-updated TDF TC[] to match full model functions
;   - added enhanced metering capabilities
;   -fixed bug, added conditional clause for hot network changes
;	-fixed bug, updated speed input
;======================================================================
;inputs

;Set per-mile auto operating cost here
auto_cost_per_mile = 0.17
iter.relgap = 0.0002

;inputs
;Base Network
BaseNetwork = '?_base.net' ;must update in step 48

;Speed Attribute
;SpeedA = cspd_1 ;LI.<Speed for unloaded or CSPD_1 for loaded> must update in Step 48
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
		
		; ******* GENERAL RAMP METER PERIOD SETUP *******
		;    Specify the DELCURV values metered within each period here
		rampmeter = '999'  ;if no metering, quote a value not in DELCURV link data field
		if (per='h07') rampmeter='1,3,4,5'
		if (per='h08') rampmeter='1,3,4,5'
		if (per='h09') rampmeter='1,3,4,5'
		if (per='md5') rampmeter=    '4,5'
		if (per='h15') rampmeter='2,3,4,5'
		if (per='h16') rampmeter='2,3,4,5'
		if (per='h17') rampmeter='2,3,4,5'
		if (per='ev2') rampmeter=      '5'
		if (per='n11') rampmeter=      '5'

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
	  NETI[2]=?_base.net	  

	  lanes = li.2.lanes
	  capclass = li.2.capclass
	  speed = li.2.speed
	  spdcurv = li.2.spdcurv 
	  
	  ; Previous volume and time
	  if (li.2.capclass <> 99 & li.1.capclass <>99)
		  prevvol  = li.1.v_1
		  prevtime = li.1.time_1
		  precspd = li.1.cspd_1
	  
	  elseif(li.2.capclass <> 99)
	  ;from base
	      prevvol  = 0
		  precspd = li.2.speed
		  prevtime = 60*li.2.distance/li.2.speed ;set free-flow time
		  
      elseif ((li.1.capclass=0,7,99) || li.1.speed=0)   ;walk, bike only, or switched-off link
		spdcurv=0
		prevvol=0
		precspd=0
		prevtime = 9999  
	  endif
 					 
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

	NETI=vi.@per@.net               ; previous (in) increments loaded network
	MATI=..\veh.avg.@per@.mat         ; 'veh.avg' for successively-averaged matrices
	FILEO NETO=vo.@per@.net         ; output (new) loaded network

	CAPFAC = @capfac@
	COMBINE=EQUI,MAXITERS=300,RELATIVEGAP=@iter.relgap@,gap=0,raad=0,aad=0;rmse=0.01

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
	  t0 = li.distance * 60 / CmpNumRetNum(SPEED,'=',0,1,SPEED)
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

	; --------------------- ***	;------ ramp meter flag *** GENERAL PERIOD SETUP ***
								 
		   
	IF (li.DELCURV=@rampmeter@)
		lw.RAMP=1
	ELSE
		lw.RAMP=0
	ENDIF
	; --------------------- ***

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

	  PATHLOAD PATH=lw.imped1_da EXCLUDEGRP=2,3 VOL[01]=mi.1.da1,VOL[02]=mi.1.c21		;VOT 1  Drive Alone VOT Class 1,Commercial Vehicles 2 axle

		PATH=lw.imped1_c3 EXCLUDEGRP=2,3,4      VOL[03]=mi.1.c31						;VOT 1  Commercial Vehicles 3 axle

		PATH=lw.imped1_s2 EXCLUDEGRP=3   		VOL[04]=mi.1.s21 						;VOT 1  Shared Drive 2
	
		PATH=lw.imped1_s3   					VOL[05]=mi.1.s31 						;VOT 1  Shared Drive 3+
		
		PATH=lw.imped2_da EXCLUDEGRP=2,3   		VOL[06]=mi.1.da2, VOL[07]=mi.1.c22   	;VOT 2  Drive Alone, Commercial Vehicles 2 axle	
	
		PATH=lw.imped2_c3 EXCLUDEGRP=2,3,4      VOL[08]=mi.1.c32						;VOT 2  Commercial Vehicles 3 axle

		PATH=lw.imped2_s2 EXCLUDEGRP=3   		VOL[09]=mi.1.s22  						;VOT 2  Shared Drive 2
	
		PATH=lw.imped2_s3 						VOL[10]=mi.1.s32						;VOT 2  Shared Drive 3+

		PATH=lw.imped3_da EXCLUDEGRP=2,3   		VOL[11]=mi.1.da3, VOL[12]=mi.1.c23   	;VOT 3  Drive Alone, Commercial Vehicles 2 axle
				
		PATH=lw.imped3_c3 EXCLUDEGRP=2,3,4      VOL[13]=mi.1.c33   						;VOT 3 Commercial Vehicles 3 axle

		PATH=lw.imped3_s2 EXCLUDEGRP=3   		VOL[14]=mi.1.s23     					;VOT 3 Shared Drive 2

		PATH=lw.imped3_s3 						VOL[15]=mi.1.s33   						;VOT 3 Shared Drive 3+
	  
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
	  
fileo neto=?daynet_AssnOnly_temp.net

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


merge record=false
endrun

;===========================================================================
;Rollup Network with Select LINK LINK
run pgm=network  MSG='create daily network'
filei linki[1]=?daynet_AssnOnly_temp.net
      linki[2]=vo.h07.net
      linki[3]=vo.h08.net
      linki[4]=vo.h09.net
      linki[5]=vo.md5.net
      linki[6]=vo.h15.net
      linki[7]=vo.h16.net
      linki[8]=vo.h17.net
      linki[9]=vo.ev2.net
      linki[10]=vo.n11.net
	  
fileo neto=?daynet_AssnOnly.net exclude=bike,MINTOLLDA,MINTOLLS2,MINTOLLS3,MINTOLLCV,MAXTOLLCV,MAXTOLLDA,MAXTOLLS2,MAXTOLLS3,
			 prevvol,prevvol,vc_1,cspd_1,tollda,tolls2,tolls3,tollcv,
             Vdt_1,Vht_1,V1_1,V2_1,V3_1,Vt_1,V1t_1,V2t_1,V3t_1,
			 V_1,V4_1,V5_1,V6_1,V7_1,V8_1,V9_1,V10_1,V11_1,V12_1,V13_1,V14_1,V15_1,
			 V4T_1,V5T_1,V6T_1,V7T_1,V8T_1,V9T_1,V10T_1,V11T_1,V12T_1,V13T_1,V14T_1,V15T_1
      linko=?daynet_AssnOnly.dbf format=dbf exclude=bike,MINTOLLDA,MINTOLLS2,MINTOLLS3,MINTOLLCV,MAXTOLLCV,MAXTOLLDA,MAXTOLLS2,MAXTOLLS3,
			 prevvol,prevvol,vc_1,cspd_1,
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

pkv=0
opv=0


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


