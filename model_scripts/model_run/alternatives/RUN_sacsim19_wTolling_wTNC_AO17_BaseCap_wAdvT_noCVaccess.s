; 4/25 increase capacities 10%
; 4/21 require input variables tollda, tolls2, tolls3
; 4/21 expect three toll variables in network
; 4/12/2014 jag: distinguish all combos of toll/notoll and VOT,
;                apply 3 VOT classes (top & bottom quintiles, and middle)
;                in skims, daysim, assigns
; 2/12/2014 jag: improve P&R input and prep
;      add transit roll-up & summaries
; 2/3/2014 jag: improve relgap schedule,
;      incorporate bike skims verbatim (after transit skims)
;      add walk skims to the bike skim process
;      revert vdf to sa3e as sacsim15
; 12/5/12 jag: (sacsim18) accommodate daysim p&r
; 5/4/12 jag: corrected references to taz sum data
;             get P&R records from local p_r_nodes.dat entirely
;             test 2 instead of 1 worker-job SP runs per cycle

;this version will be stardard version of running sacsim19 with toll. The purpose of creating this version
;is for the convenience of comparing it with a no toll version.


;12/07/2015: this v0 version tests: 1) trace imped_da, imped_s2, and pmped_s3 to see the impacts of distance-based costs; 2) 
;add c2 and c3 volumes in assignment;3)incorporate HOV lane violators in assignment as done in sacsim15

;10/2016: add more time periods
;01/03/2017: Comments are revised based on changes in time period.

;======================================================================

;prompt question='Several Voyager windows will appear, then a Cluster window.',
;       answer = 'When Cluster window appears, close it to begin the run.'

;IFCLUSTER:
 *cluster sacsimsub 1,2,3 starthide exit
; *cluster sacsimsub 1,2,3 start exit
 
; Option: add "exit" after "start" to automatically proceed
; Otherwise, Cluster will pause to be checked, and await being closed to proceed.

;======================================================================
; Initialize statistics log files

*echo Time log - start run - preliminaries>timelog.start.txt

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
; **** GLOBAL PARAMETERS FOR TOLLING AND VALUE-OF-TIME CLASSES ****
; These must be entered consistently with the roster file.

; Global parameter - number of VOT classes in assignment and skimming (1 to 3)
tolls.ntc = 3

; Declare the inverse value of time to use in skimming (dollars per minute)
tolls.ivot1 = 60/ 7.25   ;33rd percentile ; 0.1205 dollars per minute
tolls.ivot2 = 60/16.85   ;66th percentile ; 0.2808 dollars per minute
tolls.ivot3 = 60/38.80   ;90th percentile ; 0.646 dollars per minute
; etc. as many as tolls.ntc

;----------------------------------------------------------------------
; Code activation selection.
; - This creates text-substitution variables that comment-out script 
;   handling unneeded toll classes.
	if (tolls.ntc >= 1)
		tolls.code1 = ' '
	else
		tolls.code1 = ';'
	endif
	if (tolls.ntc >= 2)
		tolls.code2 = ' '
	else
		tolls.code2 = ';'
	endif
	if (tolls.ntc >= 3)
		tolls.code3 = ' '
	else
		tolls.code3 = ';'
	endif
	if (tolls.ntc >= 4)
		tolls.code4 = ' '
	else
		tolls.code4 = ';'
	endif
	if (tolls.ntc >= 5)
		tolls.code5 = ' '
	else
		tolls.code5 = ';'
	endif
	; etc if any more toll classes

; this block of code calculates the total length of each toll segments, which will later be used to apportion tolls to each link
	AllLaneToll = 0 ;1 True, 0 False. Turn true if all lane toll facilities exist.
	run pgm = hwynet  MSG='step 0 Calculate toll segment length'
 
   neti = ?_base.net
   fileo printo[1] = tollseg_length.csv
  
   array tseg_length = 200
   array nseg_length= 200
     
   phase = linkmerge
   
	   loop _segment=1,200
	   
			if (_segment = TOLLID) 	   
			   tseg_length[_segment] = tseg_length[_segment] + li.1.distance
			endif
			if (_segment = GPID) 	   
			   nseg_length[_segment] = nseg_length[_segment] + li.1.distance
			endif
			if ((_segment = TOLLID) && (_numseg<TOLLID))
				_numseg = TOLLID
			endif

		endloop
		
	
	endphase
	
    phase = summary
	
	 loop _segment=1,200
	 
		 if (tseg_length[_segment] > 0)
	     		absDiffLen = ABS(tseg_length[_segment] - nseg_length[_segment])
				IF(@AllLaneToll@ > 0)
				  tseg_length[_segment] = nseg_length[_segment] ;set toll segment to GP distance
				  absDIFfLen = ABS(tseg_length[_segment] - nseg_length[_segment])
				ENDIF
				if(absDiffLen > 0.25) exit   ;add an error message here
	
		   PRINT CSV=T LIST=_segment, tseg_length[_segment] , nseg_length[_segment] PRINTO=1
		 endif
		
	 endloop
	 
	endphase
	
	LOG PREFIX=network, VAR=_numseg
   
	LOG VAR = _numseg

endrun

   ;allseg = @network._numseg@

;======================================================================
;loop time period; endloop at line 239
	loop p=1,9                       
    if (p=01) per='h07'
    if (p=02) per='h08'
    if (p=03) per='h09'
    if (p=04) per='md5'
    if (p=05) per='h15'
    if (p=06) per='h16'
    if (p=07) per='h17'
    if (p=08) per='ev2'
    if (p=09) per='n11'

  ;----------------------------------------------------------------------
  ;step 1 initialize network and some network variables
  ; RSG: note the use of wildcard for network name; dangerous!
  run pgm=network    MSG='step 1 Initialize network'
    ; Initialize networks for run
    neti=?_base.net
    neto=vo.@per@.net
	;linko=vo.@per@.csv, FORMAT=CSV
	
    	; the input tolls file
		; format of tolls.csv is index(tollseg*100+per),tollseg,per,0,factype,adjust,tollda,tolls2,tolls3,tollcv
		FILEI LOOKUPI[1] = tolls.csv
		FILEI LOOKUPI[2] = tollseg_length.csv


    ; Placeholder for carryover volume
    v_1  = 0
    vt_1 = 0	
	

    ; Speed-flow curve selection
    if (capclass=1,6,8,9,16,18,26,36,40,46,51,56)  ; Freeway or freeway ramps
        spdcurv=1
    elseif (capclass=2,22,24) ; express and other highways
        spdcurv=2
    else
        spdcurv=3
    endif

    
	if ((capclass=0,7,99) || speed=0)   ;walk, bike only, or switched-off link
		spdcurv=0
		time_1 = 9999 	
 	else 
   		time_1 = 60*distance/li.1.speed       ;set free-flow time
    endif
	
	
	 ; for the off peak periods, change HOV and HOV3 lanes to General Purpose lanes
	 
	 if ((@p@=4) | (@p@=8) | (@p@=9))
	 
		if ((USECLASS == 2) | (USECLASS == 3) | (TOLLID > 0 && CAPCLASS == 8))
			USECLASS  = 4
		endif
		
	 endif
     
	 ; end of changing hov lanes to gp lanes for off peak periods
	
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
  ;step 2
  run pgm=matrix MSG='step 2 Initialize successive-average vehicle trips matrices'
  ; Initialize successive-average matrices

        zones=@network._zones@
        fileo mato[1]=veh.avg.@per@.mat, mo=1-24

        @tolls.code1@ mw[01] = 0
        @tolls.code1@ mw[02] = 0
        @tolls.code1@ mw[03] = 0
        @tolls.code1@ mw[04] = 0
        @tolls.code1@ mw[05] = 0
        
        @tolls.code1@ mw[06] = 0
        @tolls.code1@ mw[07] = 0
        @tolls.code1@ mw[08] = 0
        @tolls.code2@ mw[09] = 0
        @tolls.code2@ mw[10] = 0
        @tolls.code2@ mw[11] = 0
        @tolls.code2@ mw[12] = 0
        @tolls.code2@ mw[13] = 0
        @tolls.code2@ mw[14] = 0
        @tolls.code2@ mw[15] = 0
        @tolls.code2@ mw[16] = 0
        @tolls.code3@ mw[17] = 0
        @tolls.code3@ mw[18] = 0
        @tolls.code3@ mw[19] = 0
        @tolls.code3@ mw[20] = 0
        @tolls.code3@ mw[21] = 0
        @tolls.code3@ mw[22] = 0
        @tolls.code3@ mw[23] = 0
        @tolls.code3@ mw[24] = 0
        @tolls.code4@ mw[25] = 0
        @tolls.code4@ mw[26] = 0
        @tolls.code4@ mw[27] = 0
        @tolls.code4@ mw[28] = 0
        @tolls.code4@ mw[29] = 0
        @tolls.code4@ mw[30] = 0
        @tolls.code4@ mw[31] = 0
        @tolls.code4@ mw[32] = 0
        @tolls.code5@ mw[33] = 0
        @tolls.code5@ mw[34] = 0
        @tolls.code5@ mw[35] = 0
        @tolls.code5@ mw[36] = 0
        @tolls.code5@ mw[37] = 0
        @tolls.code5@ mw[38] = 0
        @tolls.code5@ mw[39] = 0
        @tolls.code5@ mw[40] = 0

  endrun

;----------------------------------------------------------------------
; end of highway periods loop  line 105
	endloop

======================================================================
	step 3
	run pgm=matrix msg='step 3 Prepare park-and-ride data from raw file'
    ; Copy the raw parcels, adding the park-and-ride lots to the end
    ; Copy the P&R data to formats needed by DaySim and post-analysis

    dbi[1]=.\?_raw_parcel.txt, delimiter[1]=',', fields=1
    dbi[2]=?_pnr.dbf

    ; Output (1) to raw_parcel_pnr.dat, raw parcels augmented with P&Rs for Daysim

    ; Output (2) to p_r_nodes.dat for DaySim use
    ;   For Daysim, use the P&R record number as the NodeID, not the network node number

    ; Output (3) to p_r_lookup.dat for post-analysis of P&R loadings

    parameters zones=1

    pno = 0
    recno = 0

    ; First, just copy all the parcel records verbatim
    loop k=1,dbi.1.NUMRECORDS
       _read1=DBIReadRecord(1,k)
       print file=.\?_raw_parcel_pnr.txt, list=dbi.1
       pno = max(pno, dbi.1.nfield[1])    ;to get highest parcel ID 
    endloop

    ; Next, append special parcels for P&R lots

    loop k=1,dbi.2.NUMRECORDS
       _read1=DBIReadRecord(2,k)
       if (di.2.pnr_node>0 && di.2.zone>0 && di.2.pnrcap>0)

         ; Output (1)
          pno = pno + 1
          print file=.\?_raw_parcel_pnr.txt, form=(12SL), 
             list=pno(12L),',', di.2.x,',', di.2.y,',', (20*di.2.pnrcap), ',', di.2.zone,',',
             ' 1, 0 ,0 ,0, 0, 0 ,0, 0 ,0 ,0, 0, 0, 0, 0 ,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1'

         ; Output (2) and (3)
          recno = recno + 1
          print file=p_r_nodes.dat, form='12L', list=recno, ' ', di.2.zone, ' ', di.2.x, ' ', di.2.y, ' ', di.2.pnrcap, ' ', di.2.prkcost
          print file=p_r_lookup.dat, form='12', list=recno, di.2.zone, di.2.pnrcap, pno, di.2.sta_node
       endif      

    endloop

endrun

	;======================================================================
	; 
	; **** INSERT ANY FEEDBACK-INVARIANT SKIMMING HERE ***
	;
	;      bike skims depend on auto volumes;
	;      walk skims made concurrently.
	;      both are done after transit skims
	;
	;----------------------------------------------------------------------
	;step 4
	run pgm=highway  msg='step 4 Highway distance skim'
		; Freeflow highway distance skim
	
		NETI=vo.md5.net               ; any network with the exclusion groups worked out
		MATO="skim.auto.distance.mat", MO=1,dec=4,    ; output skim matrix
			name=autodist
	
	
		;IFCLUSTER:
		DistributeIntraStep processid='sacsimsub', ProcessList=1-3, mingroupsize=400
	
		PHASE=LINKREAD                         ;define link groups
		if (li.capclass=0,7,99 || li.speed=0|| li.distance=0)  ADDTOGROUP=1 ;walk, bike only, or switched-off link
		
	
		;if (capclass=8,9,18)  ADDTOGROUP=1 ;HOV lanes & bypasses
	
		;if (capclass= ????)   ADDTOGROUP=1 ;S3-only lanes
		
		endphase
	
		PHASE=ILOOP
		;Skim HOV paths (Not sure what is going on here)
			PATHLOAD PATH=li.distance,EXCLUDEGRP=1,
			MW[1]=pathcost, noaccess=0
	
		;Intrazonals
			iz1=lowest(1,1,0.005,10000)*0.5
			jloop j=i
				mw[1]=iz1
			endjloop
		endphase
	ENDRUN
	
	;======================================================================
	;step 5 get zone number from network
	; tazsumdata.s
	
	run pgm=network  MSG='step 5 get zones from network'
		filei neti=?_base.net
		log var=_zones
		endrun
	
		;----------------------------------------------------------------------
		;step 6
		run pgm=matrix msg='step 6 Compile zonal housing and employment'
		; Compile zonal housing for use by other modules
	
		FILEI RECI = .\?_raw_household.txt,
			delimiter[1]=','
	
		array zhhs=@network._zones@, zwkrs=@network._zones@, zpop=@network._zones@
	
		; Parse header record to locate field names
		if (reci.recno=1)
			loop f=1, reci.numfields
				if (reci.cfield[f]='hhtaz')    f_taz      = f
				if (reci.cfield[f]='hhsize')   f_hhsize   = f
				if (reci.cfield[f]='hhwkrs')   f_hhwkrs   = f
				if (reci.cfield[f]='hhexpfac') f_hhexpfac = f
			endloop
		else
			hhtaz    = val(reci.cfield[f_taz])
			hhsize   = val(reci.cfield[f_hhsize])
			hhwkrs   = val(reci.cfield[f_hhwkrs])
			hhexpfac = val(reci.cfield[f_hhexpfac])
	
			zhhs[hhtaz]  = zhhs[hhtaz]  + hhexpfac
			zwkrs[hhtaz] = zwkrs[hhtaz] + hhexpfac*hhwkrs
			zpop[hhtaz]  = zpop[hhtaz]  + hhexpfac*hhsize
		endif
	
		if (i=0)  ;end of file
			loop hhtaz=1,@network._zones@
				print file=tazhhsums.txt, form=12.2, list=hhtaz(5.0), zhhs[hhtaz], zwkrs[hhtaz], zpop[hhtaz]
			endloop
		endif
	
	endrun
	
	;----------------------------------------------------------------------
	;step 7
	run pgm=matrix   MSG='step 7 Compile zonal employment'
	; Compile zonal employment for use by other modules
	
		FILEI RECI = .\?_raw_parcel.txt, delimiter[1]=','   
			
	
		zdati[1]=tazhhsums.txt, z=#1, tothh=2, wkrs=3, pop=4      ;household data pass-through
	
		array stugrd=@network._zones@,
			stuhgh=@network._zones@,
			stuuni=@network._zones@,
			empedu=@network._zones@,
			empfoo=@network._zones@,
			empgov=@network._zones@,
			empind=@network._zones@,
			empmed=@network._zones@,
			empofc=@network._zones@,
			empret=@network._zones@,
			empsvc=@network._zones@,
			empoth=@network._zones@,
			emptot=@network._zones@
	
		; Parse header record to locate field names
		if (reci.recno=1)
			loop f=1, reci.numfields
				if (reci.cfield[f]='taz_p')    f_taz    = f
				if (reci.cfield[f]='stugrd_p') f_stugrd = f
				if (reci.cfield[f]='stuhgh_p') f_stuhgh = f
				if (reci.cfield[f]='stuuni_p') f_stuuni = f
				if (reci.cfield[f]='empedu_p') f_empedu = f
				if (reci.cfield[f]='empfoo_p') f_empfoo = f
				if (reci.cfield[f]='empgov_p') f_empgov = f
				if (reci.cfield[f]='empind_p') f_empind = f
				if (reci.cfield[f]='empmed_p') f_empmed = f
				if (reci.cfield[f]='empofc_p') f_empofc = f
				if (reci.cfield[f]='empret_p') f_empret = f
				if (reci.cfield[f]='empsvc_p') f_empsvc = f
				if (reci.cfield[f]='empoth_p') f_empoth = f
				if (reci.cfield[f]='emptot_p') f_emptot = f
			endloop
		else
			p         =             val(reci.cfield[f_taz])
			stugrd[p] = stugrd[p] + val(reci.cfield[f_stugrd])
			stuhgh[p] = stuhgh[p] + val(reci.cfield[f_stuhgh])
			stuuni[p] = stuuni[p] + val(reci.cfield[f_stuuni])
			empedu[p] = empedu[p] + val(reci.cfield[f_empedu])
			empfoo[p] = empfoo[p] + val(reci.cfield[f_empfoo])
			empgov[p] = empgov[p] + val(reci.cfield[f_empgov])
			empind[p] = empind[p] + val(reci.cfield[f_empind])
			empmed[p] = empmed[p] + val(reci.cfield[f_empmed])
			empofc[p] = empofc[p] + val(reci.cfield[f_empofc])
			empret[p] = empret[p] + val(reci.cfield[f_empret])
			empsvc[p] = empsvc[p] + val(reci.cfield[f_empsvc])
			empoth[p] = empoth[p] + val(reci.cfield[f_empoth])
			emptot[p] = emptot[p] + val(reci.cfield[f_emptot])
		endif
	
		if (i=0)  ;end of file
			loop p=1,@network._zones@
				print file=tazsumdata_15.txt, form=12.2, list=p(5.0), zi.1.tothh[p], zi.1.wkrs[p],
				stugrd[p],
				stuhgh[p],
				stuuni[p],
				empedu[p],
				empfoo[p],
				empgov[p],
				empind[p],
				empmed[p],
				empofc[p],
				empret[p],
				empsvc[p],
				empoth[p],
				emptot[p],
				zi.1.pop[p]
			endloop
		endif
	endrun
	
	;======================================================================
	
	; **** BEGIN ITERATION OF DEMAND AND ASSIGNMENT MODEL SYSTEM ****
	; change to 3 loops with 100% sample each; use tightest relative gap convergence for third iteration.
	
	loop iteration=1,3             ;endloop is at the end of the script line 3966
		iter.i = iteration
		if (iter.i=1)
		; First pass: every 16 household
		;	iter.s=16
        ;   iter.m=8
		    iter.s=1
            iter.m=1			
		    iter.ssi=1
			iter.pnrss=1
    		iter.relgap = 0.0006
	;*** Delete park-and-ride shadow-price file to start fresh, or else keep the previous one as warmstart ***
			*if exist working\park_and_ride_shadow_prices.txt del working\park_and_ride_shadow_prices.txt
		;elseif(iter.i = 2-3)
         elseif(iter.i = 2)
			;iter.s = 16
			;iter.m = iter.i+7
			iter.s = 1
			iter.m = 1
			iter.ssi=2
			iter.pnrss=2/(iter.i+1)
			iter.relgap = 0.0003
	    elseif(iter.i = 3)
			;iter.s = 16
			;iter.m = iter.i+7
			iter.s = 1
			iter.m = 1
			iter.ssi=2
			iter.pnrss=2/(iter.i+1)
			iter.relgap = 0.0002
		elseif(iter.i = 4)
			iter.s=8
			iter.m=4
			iter.ssi=2
			iter.pnrss=2/(iter.i+1)
			iter.relgap = 0.0012
		elseif(iter.i=5)
			iter.s=4
			iter.m=2
			iter.ssi=2
			iter.pnrss=2/(iter.i+1)
			iter.relgap = 0.0006
		elseif(iter.i=6)
			iter.s = 2
			iter.m = 1
			iter.ssi=2
			iter.pnrss=2/(iter.i+1)
			iter.relgap = 0.0003
		else
		; Every household.
			iter.s = 1
			iter.m = 1
			iter.ssi=2
			iter.pnrss=2/(iter.i+1)
			iter.relgap = 0.0002
		endif
	
    *echo Begin highway skims Iter @iter.i@>timelog.beginhwyskims.iter@iter.i@.txt

    ;======================================================================
    ; Highway skims for each period
	; skim periods
	; h07   7-8 AM

    loop p=1,9                          ;endloop at line 843
          if (p=01) per='h07'
          if (p=02) per='h08'
          if (p=03) per='h09'
          if (p=04) per='md5'
          if (p=05) per='h15'
          if (p=06) per='h16'
          if (p=07) per='h17'
          if (p=08) per='ev2'
          if (p=09) per='n11'

      ;----------------------------------------------------------------------
      ;   Highway skims by value-of-time class
        loop votcl=1,3

		;if (votcl > tolls.ntc) break    ;funny method because loop limits must be constants
			if (votcl=1) ivot = tolls.ivot1
			if (votcl=2) ivot = tolls.ivot2
			if (votcl=3) ivot = tolls.ivot3


		          
			if (iter.i > 1) 
				*copy skim.auto.@per@.@votcl@.mat *.old.mat
			endif
          
			*copy vo.@per@.net vo.@per@_@iter.i@.net

      ;----------------------------------------------------------------------
      ;step 8
      ; previous script had different logic for peak and off-peak periods, where HOV lanes were assumed
	  ; to be GP lanes in off-peak periods. This logic has been removed. 
	  ; ***** 
	  ; TODO: Make USECLASS period-specific in network.


         RUN PGM=HIGHWAY  MSG='step 8 Highway skims'
          ; Highway skims for all occupancies, at one period, VOT, tolling class at a time

          NETI= vo.@per@.net                      ; input network
          MATO="skim.auto.@per@.@votcl@.mat", MO=1-9,dec=9*2,    ; output skim matrices
              name=dati@per@_@votcl@,  tollda@per@_@votcl@, dadi@per@_@votcl@, s2ti@per@_@votcl@, tolls2@per@_@votcl@, s2di@per@_@votcl@,
                  s3ti@per@_@votcl@,  tolls3@per@_@votcl@, s3di@per@_@votcl@
          ;   The period must be included in the matrix name for the sake of the binary conversion.

          ;IFCLUSTER:
           DistributeIntraStep processid='sacsimsub', ProcessList=1-3, mingroupsize=400

          PHASE=LINKREAD                        ;define link groups
          ; Parameters in Configuration
          ;PathImpedance_AutoOperatingCostPerMile="0.12"
          ;Coefficients_HOV2CostDivisor_Work="1.741"     
          ;Coefficients_HOV2CostDivisor_Other="1.625"
          ;Coefficients_HOV3CostDivisor_Work="2.408"
          ;Coefficients_HOV3CostDivisor_Other="2.158"
          ;Coefficients_BaseCostCoefficientPerDollar="-0.15"
          ;Coefficients_MeanTimeCoefficient_Work="-0.03"
          ;Coefficients_MeanTimeCoefficient_Other="-0.015"

          ; Settings for network path choice based on configuration settings
          CostPerMile = 0.17
          HOV2Divisor = 1.00;  was 1.66 - No need to divide by occupancy since DaySim places shared ride trips in higher VOT class
          HOV3Divisor = 1.00; was 2.23

		   IF (li.USECLASS == 0) ADDTOGROUP=1        ;GENERAL PURPOSE 
           IF (li.USECLASS == 2) ADDTOGROUP=2        ;HOV2+
           IF (li.USECLASS == 3) ADDTOGROUP=3        ;HOV3+
           IF (li.USECLASS == 4) ADDTOGROUP=4        ;3+ axle commercial (for off peak)
		   
            lw.AOCost = li.distance * CostPerMile
			
            tollivot = @ivot@      ; will take values according to the votcl loop
            
            lw.imped_da = li.time_1 + (li.tollda*@ivot@ + lw.AOCost*@ivot@)
            lw.imped_s2 = li.time_1 + (li.tolls2*@ivot@ + lw.AOCost*@ivot@) / HOV2Divisor
            lw.imped_s3 = li.time_1 + (li.tolls3*@ivot@ + lw.AOCost*@ivot@) / HOV3Divisor
			
          endphase


		PHASE=ILOOP
		 ;Skim SOV paths without HOV links
			PATHLOAD PATH=lw.imped_da,EXCLUDEGRP=2,3,
			   mw[1]=pathtrace(li.time_1), noaccess=0,
			   mw[2]=pathtrace(li.tollda), noaccess=0,
			   mw[3]=pathtrace(li.distance), noaccess=0

		 ; Skim SR2 paths with HOV links
			PATHLOAD PATH=lw.imped_s2,EXCLUDEGRP=3,
			   mw[4]=pathtrace(li.time_1), noaccess=0,  
			   mw[5]=pathtrace(li.tolls2), noaccess=0,
			   mw[6]=pathtrace(li.distance), noaccess=0

		 ; Skim SR3 paths with HOV links
		   PATHLOAD PATH=lw.imped_s3,
			   mw[7]=pathtrace(li.time_1), noaccess=0,  
			   mw[8]=pathtrace(li.tolls3), noaccess=0,
			   mw[9]=pathtrace(li.distance), noaccess=0

           ;Intrazonals
              iz1=lowest(1,1,0.005,10000)*0.5
              iz3=lowest(3,1,0.005,10000)*0.5
              iz4=lowest(4,1,0.005,10000)*0.5
              iz6=lowest(6,1,0.005,10000)*0.5
			  iz7=lowest(7,1,0.005,10000)*0.5
              iz9=lowest(9,1,0.005,10000)*0.5
              jloop j=i
                  mw[1]=iz1
                  mw[3]=iz3
                  mw[4]=iz4
                  mw[6]=iz6
				  mw[7]=iz7
                  mw[9]=iz9
              ENDJLOOP
          ENDPHASE

        ENDRUN
  

      ; Convert auto skims to binary Daysim format
      ;*..\daysim\CubeMatrixExporter -i=skim.auto.@per@.@votcl@.mat -o=.

      ;----------------------------------------------------------------------
      ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      if (iter.i > 1)            ;set up convergence criteria for each iteration                 

        ;----------------------------------------------------------------------
        ;step 9
        RUN PGM=MATRIX MSG='step 9 report iteration progress statistics'
        ; Report iteration progress statistics:
        ; Travel time delta frequencies, weighted by trips
        ;    (Each VOT class)

        mati[1]=veh.@per@.mat
        mati[5]=skim.auto.@per@.@votcl@.old.mat
        mati[9]=skim.auto.@per@.@votcl@.mat

        ; Initialize
        if (i=1)
        jloop j=1
            TotTrips = 0
            AbsDiff = 0
            SSq = 0
            MaxAbs = 0
            VxT = 0
        endjloop
        endif

        ; Count comm veh trips as drive alone toll-users

            jloop
                mw[4] = mi.1.c2@votcl@+mi.1.c3@votcl@
            endjloop
    
        jloop

        ; Trips
        mw[1]=mi.1.da@votcl@ + mw[4]
        mw[2]=mi.1.s2@votcl@
        mw[3]=mi.1.s3@votcl@
        TotTrips = TotTrips + mw[1]+mw[2]+mw[3]

        ; Settings for network path choice based on configuration settings (same as in skims)
        CostPerMile = 0.17
        HOV2Divisor = 1.00   ;compromise between work and nonwork
        HOV3Divisor = 1.00

          ;if (@tnt@ <= 0)     ;if No-Toll class...
           ;   tollivot = 150   ;severe perception factor for tolls, for the no-toll class
          ;else
              tollivot = @ivot@
          ;endif


        ; Skim impedence deltas
			mw[11] = mi.5.1 + (mi.5.2*tollivot + mi.5.3*CostPerMile*@ivot@)
			mw[12] = mi.5.4 + (mi.5.5*tollivot + mi.5.6*CostPerMile*@ivot@) / HOV2Divisor
			mw[13] = mi.5.7 + (mi.5.8*tollivot + mi.5.9*CostPerMile*@ivot@) / HOV3Divisor
			mw[14] = mi.9.1 + (mi.9.2*tollivot + mi.9.3*CostPerMile*@ivot@)
			mw[15] = mi.9.4 + (mi.9.5*tollivot + mi.9.6*CostPerMile*@ivot@) / HOV2Divisor
			mw[16] = mi.9.7 + (mi.9.8*tollivot + mi.9.9*CostPerMile*@ivot@) / HOV3Divisor
			mw[7] = mw[14] - mw[11]
			mw[8] = mw[15] - mw[12]
			mw[9] = mw[16] - mw[13]
        ;sgao: mi.5.2, mi.5.5, mi.5.8=0, so it does not matter tollivot=@ivot@>0

		; Summary statistics
		SSq = SSq + mw[7]*mw[7]*mw[1] + mw[8]*mw[8]*mw[2] + mw[9]*mw[9]*mw[3]        ;For RMS
		AbsDiff = AbsDiff + abs(mw[7])*mw[1] + abs(mw[8])*mw[2] + abs(mw[9])*mw[3]
		MaxAbs = max(MaxAbs, abs(mw[7]), abs(mw[8]), abs(mw[9]))
		VxT = VxT + mw[1]*mw[14] + mw[2]*mw[15] + mw[3]*mw[16]

		endjloop

		if (i=_zones && TotTrips>0)
			iter = @iter.i@
			RMS = sqrt(SSq/TotTrips)
			AvgAbs = AbsDiff/TotTrips
			ATL = VxT/TotTrips
			print file=skimdeltas.txt, append=T, list=iter(3), ' @per@', ' @votcl@',
			   TotTrips(12), ATL(9.4), AvgAbs(9.4), RMS(9.4), MaxAbs(9.3)
		endif


        endrun

      ;----------------------------------------------------------------------
      ; end if iter > 1
      ENDIF
      ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      ;======================================================================
      ; End of loop for VOT classes
      endloop
      ;endloop

    ;======================================================================
    ; end of highway periods loop start at 525
    ENDLOOP
    ;endloop      ;double check here
    ;-------------------------------------------
    ;---convert MAT to OMX
    CONVERTMAT FROM="skim.auto.h07.1.mat" TO="skim.auto.h07.1.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h08.1.mat" TO="skim.auto.h08.1.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h09.1.mat" TO="skim.auto.h09.1.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.md5.1.mat" TO="skim.auto.md5.1.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h15.1.mat" TO="skim.auto.h15.1.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h16.1.mat" TO="skim.auto.h16.1.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h17.1.mat" TO="skim.auto.h17.1.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.ev2.1.mat" TO="skim.auto.ev2.1.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.n11.1.mat" TO="skim.auto.n11.1.omx" FORMAT=OMX COMPRESSION=7
	
	CONVERTMAT FROM="skim.auto.h07.2.mat" TO="skim.auto.h07.2.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h08.2.mat" TO="skim.auto.h08.2.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h09.2.mat" TO="skim.auto.h09.2.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.md5.2.mat" TO="skim.auto.md5.2.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h15.2.mat" TO="skim.auto.h15.2.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h16.2.mat" TO="skim.auto.h16.2.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h17.2.mat" TO="skim.auto.h17.2.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.ev2.2.mat" TO="skim.auto.ev2.2.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.n11.2.mat" TO="skim.auto.n11.2.omx" FORMAT=OMX COMPRESSION=7
	
	CONVERTMAT FROM="skim.auto.h07.3.mat" TO="skim.auto.h07.3.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h08.3.mat" TO="skim.auto.h08.3.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h09.3.mat" TO="skim.auto.h09.3.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.md5.3.mat" TO="skim.auto.md5.3.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h15.3.mat" TO="skim.auto.h15.3.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h16.3.mat" TO="skim.auto.h16.3.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.h17.3.mat" TO="skim.auto.h17.3.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.ev2.3.mat" TO="skim.auto.ev2.3.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.auto.n11.3.mat" TO="skim.auto.n11.3.omx" FORMAT=OMX COMPRESSION=7
    
    ;==========================================================================
    ;step 10
    *echo Begin transit skims Iter @iter.i@>timelog.begintranskims.iter@iter.i@.txt

    RUN PGM=NETWORK MSG='step 10 Transit background network prep'
      ; generate reverse of one-way links
      neti[1]=?_base.net

      fftime=li.1.distance*20 ;or more likely,
      if (li.1.speed>0) fftime=li.1.distance*60/li.1.speed

      linko=templink.dbf, format=DBF, include=a,b,distance,fftime,capclass
    ENDRUN

    ;----------------------------------------------------------------------
    ;step 11
    RUN PGM=NETWORK MSG='step 11 Transit background network'
      ; Insert transit-only links into copy of highway network, making full transit background network
      neti[1]=vo.h07.net  ; 7-8am auto skims
      neti[2]=vo.md5.net  
      neti[3]=vo.h15.net  ; 3-4pm auto skims
      neti[4]=vo.ev2.net
      neti[5]=vo.n11.net


      linki[7]='?_transit_links.csv',
          var=A,B,Distance,Speed,REV,Mode,Or_ToMode    ;,Name
      linki[8]='?_station_links.csv',
          var=A,B,distance,
          rev=2
      linki[9]=templink.dbf,
          rename=A-temp, B-A, temp-B
      linki[10]=?_pnr.dbf,rename=zone-A, pnr_node-B, rev=2     ;build zone to P&R short links
      merge record=true

      am4time = li.1.time_1
      md6time = li.2.time_1
      pm3time = li.3.time_1
      ev2time = li.4.time_1
      ni9time = li.5.time_1


      if (am4time=0) am4time=li.9.fftime*1.2
      if (md6time=0) md6time=li.9.fftime*1.1
      if (pm3time=0) pm3time=li.9.fftime*1.2
      if (ev2time=0) ev2time=li.9.fftime*1.05
      if (ni9time=0) ni9time=li.9.fftime


      distance=li.1.distance
      if (li.7.distance>0) distance=li.7.distance
      if (li.8.distance>0) distance=li.8.distance
      if (distance=0) distance=li.9.distance
      if (li.10.pnrcap > 0)
           if (distance=0 || distance>0.10) distance = 0.10
      endif
      if (distance=0) 
          _dx=b.x-a.x
          _dy=b.y-a.y
          distance=sqrt(_dx*_dx + _dy*_dy)/5280
      endif

      ; 15 mph if time still empty
      if (am4time = 0 || am4time >= 999) am4time = distance*4
      if (md6time = 0 || md6time >= 999) md6time = distance*4
      if (pm3time = 0 || pm3time >= 999) pm3time = distance*4
      if (ev2time = 0 || ev2time >= 999) ev2time = distance*4
      if (ni9time = 0 || ni9time >= 999) ni9time = distance*4

      if (li.7.speed>0)
          am4time=distance*60/li.7.speed
          md6time=distance*60/li.7.speed
          pm3time=distance*60/li.7.speed
          ev2time=distance*60/li.7.speed
          ni9time=distance*60/li.7.speed

      endif

      mode=li.7.mode
      or_tomode=li.7.or_tomode

      neto=transitbackground.net, exclude=prevtime,prevvol,v_1,time_1,vc_1,cspd_1,vhd_1,
                                  vht_1,v1_1,v2_1,v3_1,v4_1,v5_1,vt_1,v1t_1,v2t_1,v3t_1,v4t_1,v5t_1
    ENDRUN
    ;----------------------------------------------------------------------

    loop p=1,6                          ;endloop at line 1060
        if (p=1) trper='am4'
        if (p=2) trper='md6'
        if (p=3) trper='pm3'
        if (p=4) trper='ev2'
        if (p=5) trper='ni9'


        if (p=1) pid=1
        if (p=2) pid=2
        if (p=3) pid=3
        if (p=4) pid=1
        if (p=5) pid=2
        if (p=6) pid=3 ; dummy thread to carry wait4files

    ;IFCLUSTER:
     DistributeMultiStep ProcessID='sacsimsub', ProcessNum=@pid@

    ;==========================================================================
    ;step 12
    IF (p = 1-5)
      run pgm=public transport msg='step 12 transit skims'
        ; transit skims
        ; general and submodes one run
        ; - general all-network may be commented out

        ;Input Files  
        FILEI SYSTEMI    = ..\input\PTsystem.txt
        FILEI FACTORI[1] = ..\input\PTfactor.onlyloc.txt,
              FACTORI[2] = ..\input\PTfactor.mustlrt.txt,
              FACTORI[3] = ..\input\PTfactor.mustcom.txt,
              FACTORI[4] = ..\input\PTfactor.txt
              
        FILEI LINEI[1]   = ?_tranline.txt
        FILEI FAREI      = ..\input\PTfare.txt
        FILEI NETI       = transitbackground.net

        ;Output files
        FILEO REPORTO = trans@trper@.prn
        FILEO NETO = trans@trper@.net 

        FILEO routeo[1] = tran@trper@.rte, REPORTI=691 REPORTJ=807
        FILEO routeo[2] = tran@trper@.rte, REPORTI=691 REPORTJ=807
        FILEO routeo[3] = tran@trper@.rte, REPORTI=691 REPORTJ=807
        FILEO routeo[4] = tran@trper@.rte, REPORTI=691 REPORTJ=807
        ;   The period must be included in the matrix name for the sake of the binary conversion.
        fileo mato[1]=skim.tran.@trper@.onlyloc.mat,  mo=1-11, name=ivtt@trper@lo,railt@trper@lo,commt@trper@lo,walk@trper@lo,iwait@trper@lo,xwait@trper@lo,fare@trper@lo,brds@trper@lo,rabrds@trper@lo,cobrds@trper@lo,compti@trper@lo
        fileo mato[2]=skim.tran.@trper@.mustrail.mat, mo=1-11, name=ivtt@trper@ra,railt@trper@ra,commt@trper@ra,walk@trper@ra,iwait@trper@ra,xwait@trper@ra,fare@trper@ra,brds@trper@ra,rabrds@trper@ra,cobrds@trper@ra,compti@trper@ra
        fileo mato[3]=skim.tran.@trper@.mustcomm.mat, mo=1-11, name=ivtt@trper@co,railt@trper@co,commt@trper@co,walk@trper@co,iwait@trper@co,xwait@trper@co,fare@trper@co,brds@trper@co,rabrds@trper@co,cobrds@trper@co,compti@trper@co
        fileo mato[4]=skim.tran.@trper@.mat,          mo=1-11, name=ivtt@trper@  ,railt@trper@  ,commt@trper@  ,walk@trper@  ,iwait@trper@  ,xwait@trper@  ,fare@trper@  ,brds@trper@  ,rabrds@trper@  ,cobrds@trper@  ,compti@trper@  

        ;Globals
        PARAMETERS TRANTIME = (li.@trper@time)
            HDWAYPERIOD = @p@
            FARE=T

        PHASE=DATAPREP

          ;;;;GENERATE READNTLEGI=1
          ;;;;;(xfer non-transit legs are input)

          ;generate access/egress links
          GENERATE,
          fromnode=31-1999, tonode=2000-20000,
          COST=li.distance*20,   ;*60 / 3mph
          MAXCOST[1]=10*30.,   ;(minutes)
          ;SLACK[1]=10*5.,
          NTLEGMODE=13,
          ONEWAY=F,
          DIRECTION=3,
          MAXNTLEGS=10*5,
          EXCLUDELINK = ((li.capclass-(10.0*int(li.capclass*0.1))) = 1,6,8,9)

          ; bus-to-bus transfer access
          GENERATE,
          fromnode=2000-20000, tonode=2000-20000,
          COST=li.distance*20,   ;*60 / 3mph
          MAXCOST[1]=10*10.,   ;(minutes)
          ;SLACK[1]=10*5.,
          NTLEGMODE=12,   ;temporary; may create another mode
          ONEWAY=F,
          DIRECTION=3,
          MAXNTLEGS=10*3,
          EXCLUDELINK = ((li.capclass-(10.0*int(li.capclass*0.1))) = 1,6,8,9)

        ENDPHASE

        phase=skimij
          mw[01]=timea(0,tmodes)   ; actual travel time on all links
          mw[02]=timea(0,1)        ; actual travel time by LRT
          mw[03]=timea(0,2)        ; actual travel time by Commuter bus
          mw[04]=timea(0,12,-17)   ; transfrer, walk time
          mw[05]=iwaita(0)         ; actual initial wait time, by wait curves on the node
          mw[06]=xwaita(0)         ; actual transfer wait time, by curves
          mw[07]=farea(0,tmodes)   ; average fare
          mw[08]=brdings(0,tmodes) ;
          mw[09]=brdings(0,1)
          mw[10]=brdings(0,2)
          mw[11]=compcost(0)
        endphase

      ENDRUN

      ;--------------------------------------------------------------------------
      ;endif at line 939 time period
    ENDIF
    ;==========================================================================
    ; Cluster: End of parallel threads

    ;IFCLUSTER:
     EndDistributeMultiStep
     if (p=3)
         Wait4Files Files=sacsimsub1.script.end, 
                          sacsimsub2.script.end,
                          sacsimsub3.script.end,
                          
         CheckReturnCode=T,
         PrintFiles=Merge, 
         DelDistribFiles=T

     elseif (p=5)
         Wait4Files Files=sacsimsub1.script.end, 
                          sacsimsub2.script.end,
                          
         CheckReturnCode=T,
         PrintFiles=Merge, 
         DelDistribFiles=T
     ENDIF
     
     *copy trans@trper@.prn trans@trper@_@iter.i@.prn

    ;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ; End of transit periods loop  started at 931
    ENDLOOP
    
    *copy skim.tran.am4.mustrail.mat skim.tran.am4.mustrail_@iter.i@.mat
    *copy skim.tran.pm3.mustrail.mat skim.tran.pm3.mustrail_@iter.i@.mat
    
    *copy skim.tran.am4.mustcomm.mat skim.tran.am4.mustcomm_@iter.i@.mat
    *copy skim.tran.pm3.mustcomm.mat skim.tran.pm3.mustcomm_@iter.i@.mat
    ;+++++++++++++++++++++++++++++++++++++++++++++
    CONVERTMAT FROM="skim.tran.am4.onlyloc.mat" TO="skim.tran.am4.onlyloc.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.am4.mustrail.mat" TO="skim.tran.am4.mustrail.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.am4.mustcomm.mat" TO="skim.tran.am4.mustcomm.omx" FORMAT=OMX COMPRESSION=7

    CONVERTMAT FROM="skim.tran.md6.onlyloc.mat" TO="skim.tran.md6.onlyloc.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.md6.mustrail.mat" TO="skim.tran.md6.mustrail.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.md6.mustcomm.mat" TO="skim.tran.md6.mustcomm.omx" FORMAT=OMX COMPRESSION=7

    CONVERTMAT FROM="skim.tran.pm3.onlyloc.mat" TO="skim.tran.pm3.onlyloc.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.pm3.mustrail.mat" TO="skim.tran.pm3.mustrail.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.pm3.mustcomm.mat" TO="skim.tran.pm3.mustcomm.omx" FORMAT=OMX COMPRESSION=7

    CONVERTMAT FROM="skim.tran.ev2.onlyloc.mat" TO="skim.tran.ev2.onlyloc.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.ev2.mustrail.mat" TO="skim.tran.ev2.mustrail.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.ev2.mustcomm.mat" TO="skim.tran.ev2.mustcomm.omx" FORMAT=OMX COMPRESSION=7
    
    CONVERTMAT FROM="skim.tran.ni9.onlyloc.mat" TO="skim.tran.ni9.onlyloc.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.ni9.mustrail.mat" TO="skim.tran.ni9.mustrail.omx" FORMAT=OMX COMPRESSION=7
    CONVERTMAT FROM="skim.tran.ni9.mustcomm.mat" TO="skim.tran.ni9.mustcomm.omx" FORMAT=OMX COMPRESSION=7


    ;==========================================================================
    ;step 13
    *echo Begin bike walk skims Iter @iter.i@>timelog.beginbikeskims.iter@iter.i@.txt

    RUN PGM=network  msg='step 13 Compute daily volume'
    ; Accumulate daily volume.  Must do it in stages.  First stage.
        NETI[1]=?_base.net
        neti[02]=vo.h07.net
        neti[03]=vo.h08.net
        neti[04]=vo.h09.net
        neti[05]=vo.md5.net

        neto=temp.net
        dyv=(li.02.vt_1 + li.03.vt_1 + li.04.vt_1 + li.05.vt_1) ; + li.06.vt_1 + li.07.vt_1)
    endrun

    ;step 14
    RUN PGM=NETWORK  MSG='step 14Build Bike Skim Matrix'
      ; Accumulate daily volume, final stage.
      ; Calculate bike route choice weights.
          NETI[1]=temp.net
          neti[02]=vo.h15.net
          neti[03]=vo.h16.net
          neti[04]=vo.h17.net
          neti[05]=vo.ev2.net
          neti[06]=vo.n11.net


          comp _func=capclass-(10.0*int(capclass*0.1))
          if (_func=1,6,8,9)delete
          LINKO=bike07l.dbf format=DBF exclude=screen spdcurv rad
          nodeo=bike07n.dbf
          LOG var=_zones
          comp tsva=100
          comp dyv=(dyv +
                    li.02.vt_1 + li.03.vt_1 + li.04.vt_1 + li.05.vt_1 + li.06.vt_1)  ; + li.07.vt_1)    ;Daily total 2-way volume
      ;
      ;Apply bike route choice distance adjustments accounting for bike lanes and daily volume
      ;
      ; First set default=1.0
         distfac=1.0
      ; And compute repeated values
         dv2=dyv*dyv
      ;
      ; No bike facility (bike=0)
      ;
      distfac0=0.0
      if (bike=0&&dyv>=10000)
         distfac0=1.00 - 1.0E-06*dyv + 1.0E-09*dv2
      endif
      if (bike=0&&distfac0>2.5)
         distfac0=2.5
      endif
      if (bike=0&&distfac0<1.0)
         distfac0=1.0
      endif
      if (bike=0)
         distfac=distfac0
      endif
      ;
      ; Class 1 bike lanes (bike=1)
      if (bike=1)
         distfac=0.80
      endif
      ;
      ; Class 2 bike facility (bike=2)
      ;
      distfac2=0.0
      if (bike=2&&dyv>=10000)
         distfac2=0.9 - 1.0E-06*dyv + 4.5E-10*dv2
      endif
      if (bike=2&&distfac2>1.5)
         distfac2=1.5
      endif
      if (bike=2&&distfac2<0.90)
         distfac2=0.90
      endif
      if (bike=2)
         distfac=distfac2
      endif
      ;
      ; Class 3 bike facility (bike=3)
      ;
      distfac3=0.0
      if (bike=3&&dyv>=10000)
         distfac3=1.0 - 1.0E-06*dyv + 6.0E-10*dv2
      endif
      if (bike=3&&distfac3>2.0)
         distfac3=2.0
      endif
      if (bike=3&&distfac3<1.00)
         distfac3=1.00
      endif
      if (bike=3)
         distfac=distfac3
      endif
      ;
      ; "Gauntlet" facility w/out bike lane (bike=8)
      ;
      distfac8=0.0
      if (bike=8&&dyv>=10000)
         distfac8=1.1 - 1.0E-06*dyv + 1.85E-09*dv2
      endif
      if (bike=8&&distfac8>4.0)
         distfac8=4.0
      endif
      if (bike=8&&distfac8<1.10)
         distfac8=1.10
      endif
      if (bike=8)
         distfac=distfac8
      endif
      ;
      ; "Gauntlet" facility w/ bike lane (bike=8)
      ;
      distfac9=0.0
      if (bike=9&&dyv>=10000)
         distfac9=1.0 - 1.0E-06*dyv + 1.3E-09*dv2
      endif
      if (bike=9&&distfac9>3.0)
         distfac9=3.0
      endif
      if (bike=9&&distfac9<1.00)
         distfac9=1.00
      endif
      if (bike=9)
         distfac=distfac9
      endif
      ;
      ;Compute BikeDist Variables
      ;
      ; first set default values for all variables
      ; bikedist=generalized bike distance
      ; bikedist01=distance on class 1 facility
      ; bikedist02=distance on class 2 low vol (<15k)
      ; bikedist03=distance on <=high vol w lane, OR >=mod vol w/out lane
      ; bikedist04=distance on veryhigh vol w lane, OR high vol or above w/out lane
      ;
      bikedist=0.0
      dist01=0.0
      dist02=0.0
      dist03=0.0
      dist04=0.0
      ;
      bikedist=distance*distfac
      ;
      ;dist01=path distance on class 1 bike lanes
      ;
      if(bike=1)
         dist01=distance
      endif
      ;
      ;dist02=path distance on lower volume class 2 bike lanes
      ;
      if (bike=2&&dyv<=15000)
         dist02=distance
      endif
      ;
      ;dist03=path distance on high vol roads w/ bike lanes, or mod vol roads with no bike lanes
      ;
      if ((bike=0&&dyv>15000)||(bike=2&&dyv>20000)||(bike=3&&dyv>15000)||(bike>=8&&dyv>10000))
         dist03=distance
      endif
      ;
      ;dist04=path distance on very high vol roads w/ bike lanes, or high vol roads with no bike lanes
      ;
      if ((bike=0&&dyv>25000)||(bike=2&&dyv>40000)||(bike=3&&dyv>30000)||(bike>=8&&dyv>20000))
         dist04=distance
      endif
    endrun
    ;
    ;Next build network
    ;
    ;step 14
    RUN PGM=NETWORK
            FILEI linki=bike07l.dbf
              nodei=bike07n.dbf
              zones=@network._zones@
        fileo neto=bike07.net
    ENDRUN

    ;step 15
    RUN PGM=highway MSG='step 15 build bike skims'
        NETI=bike07.net                          ; input network
        MATO="skim.bike.mat", MO=1-7, name=BIKEDIST,DISTANCE,dist01,dist02,dist03,dist04,WALKDIST,
                                      FORMAT=tpp          ; output skim matrix
    PHASE=ILOOP                                  ; skim path building
        ; minimum generalized bike distance
        PATHLOAD PATH=li.BikeDist, thrunode=31,
           MW[1]=pathcost,NOACCESS=0,
           MW[2]=PATHTRACE(LI.DISTANCE),NOACCESS=0,
           MW[3]=PATHTRACE(LI.dist01),NOACCESS=0,
           MW[4]=PATHTRACE(LI.dist02),NOACCESS=0,
           MW[5]=PATHTRACE(LI.dist03),NOACCESS=0,
           MW[6]=PATHTRACE(LI.dist04),NOACCESS=0
        ; minimum distance on walkable links
        PATHLOAD PATH=li.distance, thrunode=31,
           mw[7]=pathcost,noaccess=0
    ;
        iz1=lowest(1,1,0.0005,10000)*0.5
        iz2=lowest(2,1,0.0005,10000)*0.5
        iz3=lowest(3,1,0.0005,10000)*0.5
        iz4=lowest(4,1,0.0005,10000)*0.5
        iz5=lowest(5,1,0.0005,10000)*0.5
        iz6=lowest(6,1,0.0005,10000)*0.5
        iz7=lowest(6,1,0.0005,10000)*0.5
    ;
        jloop j=i
            mw[1]=iz1
            mw[2]=iz2
            mw[3]=iz3
            mw[4]=iz4
            mw[5]=iz5
            mw[6]=iz6
            mw[7]=iz7
        endjloop
    endphase
    ENDRUN

    ; Convert bike skims to binary Daysim format
    ;*..\daysim\CubeMatrixExporter -i=skim.bike.mat -o=.
    CONVERTMAT FROM="skim.bike.mat" TO="skim.bike.omx" FORMAT=OMX COMPRESSION=7
    ;==========================================================================
    *echo Begin externals Iter @iter.i@>timelog.beginexternals.iter@iter.i@.txt

    ;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ;step 16

    ; external.s
    ;  (from "work gravity.s")
    RUN PGM=NETWORK
      filei neti=?_base.net
      log var=_zones
    endrun

    ;step 17
    RUN PGM=GENERATION  MSG='step 17external.s: External trip distribution'
        ; Compile workers living in each TAZ and gateway, and working in each.

        zones = @network._zones@

        zdati[1] = tazsumdata_15.txt, z=#1, tothh=2, empres=3, univenr=6, emptot=16
        zdati[2] = .\?_ixxi.dbf, sum=hbwix,hbwxi

        ; employed residents
        p[1] = zi.1.empres + zi.2.hbwxi/1.7

        ; employment
        a[1] = zi.1.emptot + zi.1.univenr + zi.2.hbwix/1.7

        phase=adjust
            ; Factors attractions to control total of productions
            a[1] = a[1] * p[1][0] / a[1][0]
        endphase

        ; Output
        pao = workpa.txt, form=12.2, 
            list = z(5) p[1] a[1]

    endrun

    ;--------------------------------------------------------------------------
    ;step 18
    RUN PGM=DISTRIBUTION  MSG='step 18 trip distribution of external trips'

        ; Worker-workplace distribution gravity model
        ; NOTE: Distribution units are workers, not trips

        ZDATI[1] = workpa.txt,Z=#1,P1=2,A1=3
        zdati[2] = .\?_ixxi.dbf, avex0=termtime

        MATI[1] = "skim.auto.h08.1.mat"

        MATO = "workers.gravitydist.mat", MO=1, NAME=Workers

        LOOKUP  FAIL=999999,0,0  LIST=N, FILE=..\input\sacfftpp.txt, NAME=FF,
                LOOKUP[1]=1, RESULT=2,
                INTERPOLATE=Y, SETUPPER=N

        MAXITERS=25 MAXRMSE=10

        SETPA  P[1]=ZI.1.P1
        SETPA  A[1]=ZI.1.A1

        ; Set up terminal times
        tti = max(1, zi.2.termtime[i])   ;now in external data file
        if (tti > 100) tti = tti*0.01    ;should be whole minutes, but rescale if likely in hundredths

        jloop
            ttj = max(1, zi.2.termtime[j])
            if (ttj > 100) ttj = ttj*0.01

            if (i<=30 && j<=30)   ; suppress thru trips
                mw[8]=32767
            else
                mw[8]=mi.1.1 + tti + ttj
            endif
        endjloop

        gravity purpose=1, los=mw[8], ffactors=FF, losrange=1-200

        FREQUENCY BASEMW=8,VALUEMW=1,RANGE=1-100-1,TITLE='Workers TLF (minutes)'

    endrun

    ;--------------------------------------------------------------------------
    ;step 19
    RUN PGM=MATRIX MSG='step 19 calculate ix & xi fractions'
        ; calculate ix & xi fractions for Daysim 2012

        mati[1]=workers.gravitydist.mat
        ZDATI[1] = workpa.txt,Z=#1,P1=2,A1=3

        mw[1] = mi.1.1
        mw[2] = mi.1.1.t

        ixworkers = 0
        xiworkers = 0

        jloop j=1,30
            ixworkers = ixworkers + mw[1]
            xiworkers = xiworkers + mw[2]
        endjloop

        if (zi.1.P1[i] > 0)
            ixfrac = min(0.9, ixworkers / zi.1.P1[i])
        else
            ixfrac = 0
        endif
        if (zi.1.A1[i] > 0)
            xifrac = min(0.9, xiworkers / zi.1.A1[i])
        else
            xifrac = 0
        endif

        if (i>30)
            print file=worker_ixxifractions.dat, list=i(5l), ixfrac(5.3ls), xifrac(5.3ls)
        endif

    ENDRUN

    ;======================================================================
    ;step 20
    RUN PGM=MATRIX MSG='step 20 Generate and distribute external trips'
        ; Generate and distribute external trips to add to activity model
        ;
        filei mati[1]="skim.auto.md5.1.mat"

        zdati[1]=.\?_ixxi.dbf ;with added fields for activity model

        zdati[2]=tazsumdata_15.txt, z=#1, tothh=2, empres=3, stugrd=4, stuhgh=5, stuuni=6,
        empedu=7, empfoo=8, empgov=9, empind=10, empmed=11, empofc=12, 
        empret=13, empsvc=14, empoth=15, emptot=16

        fileo mato="trips.external1.mat", mo=1-6, dec=6*2, name=ixpb,xipb,ixsh,xish,ixsr,xisr

        ; Singly-constrained trip distribution model for IX and XI vehicle travel
        ; Externals are always the I zone,
        ; Internals are always the J zone.
        ; IX and XI are separate matrices for each purpose.
        ; Deterrence function is exp(coeff * md auto travel time)

        ; Purposes in activity model:
        ;    Personal Business
        ;    Shop
        ;    Social-Recreation

        ; Additional purposes in activity model disregarded from externals:
        ;    School?
        ;    Escort
        ;    Meal

        array pbprodj=_zones, pbattrj=_zones, 
              shprodj=_zones, shattrj=_zones,
              srprodj=_zones, srattrj=_zones

        jloop

           ;Internal zone production rates
            pbprodj[j] = 0.76*zi.2.tothh[j] + 0.20*zi.2.emptot[j]
            shprodj[j] = 0.88*zi.2.tothh[j] + 0.18*zi.2.emptot[j]
            srprodj[j] = 1.01*zi.2.tothh[j] + 0.21*zi.2.emptot[j]

           ;Internal zone attraction rates
            pbattrj[j] = 
                zi.2.empedu[j]  * 0.26 +
                zi.2.empfoo[j]  * 0.107 +
                zi.2.empgov[j]  * 0.286 +
                zi.2.empofc[j]  * 0.324 +
                zi.2.empret[j]  * 0.244 +
                zi.2.empsvc[j]  * 0.538 +
                zi.2.empmed[j]  * 1 +
                zi.2.empind[j]  * 0.063 +
                zi.2.tothh[j]   * 0.035 +
                zi.2.stugrd[j]  * 0.113 +
                zi.2.stuhgh[j]  * 0.113

            shattrj[j] = 
                zi.2.empfoo[j]  * 0.136 +
                zi.2.empofc[j]  * 0.022 +
                zi.2.empret[j]  * 1 +
                zi.2.empsvc[j]  * 0.088

            srattrj[j] = 
                zi.2.empedu[j]  * 0.213 +
                zi.2.empfoo[j]  * 0.351 +        ; + maybe a little more in place of IX meals
                zi.2.empgov[j]  * 0.112 +
                zi.2.empofc[j]  * 0.146 +
                zi.2.empoth[j]  * 0.095 +
                zi.2.empret[j]  * 0.142 +
                zi.2.empsvc[j]  * 1 +
                zi.2.empmed[j]  * 0.467 +
                zi.2.tothh[j]   * 0.092 +
                zi.2.stuuni[j]  * 0.266 +
                zi.2.stugrd[j]  * 0.173 +
                zi.2.stuhgh[j]  * 0.173

        endjloop

        if (zi.1.pbprod + zi.1.pbattr +
            zi.1.shprod + zi.1.shattr +
            zi.1.srprod + zi.1.srattr > 0)    ;if I is a gateway with trips

            jloop
                pbdeter = exp(-0.0823 * 0.5*(mi.1.1+mi.1.1.t))   ;round trip time
                shdeter = exp(-0.0916 * 0.5*(mi.1.1+mi.1.1.t))
                srdeter = exp(-0.0555 * 0.5*(mi.1.1+mi.1.1.t))

                mw[1] = pbdeter * pbprodj[j]   ;PB IX
                mw[2] = pbdeter * pbattrj[j]   ;PB XI
                mw[3] = shdeter * shprodj[j]   ;Sh IX
                mw[4] = shdeter * shattrj[j]   ;Sh XI
                mw[5] = srdeter * srprodj[j]   ;SR IX
                mw[6] = srdeter * srattrj[j]   ;SR XI

            endjloop
            
            fac1 = 0
            fac2 = 0
            fac3 = 0
            fac4 = 0
            fac5 = 0
            fac6 = 0
            
            rs1 = rowsum(1)
            rs2 = rowsum(2)
            rs3 = rowsum(3)
            rs4 = rowsum(4)
            rs5 = rowsum(5)
            rs6 = rowsum(6)
            
            if (rs1 > 0) fac1 = zi.1.pbattr / rs1
            if (rs2 > 0) fac2 = zi.1.pbprod / rs2
            if (rs3 > 0) fac3 = zi.1.shattr / rs3
            if (rs4 > 0) fac4 = zi.1.shprod / rs4
            if (rs5 > 0) fac5 = zi.1.srattr / rs5
            if (rs6 > 0) fac6 = zi.1.srprod / rs6

            jloop
            ; Normallize rows
                mw[1] = mw[1] * fac1
                mw[2] = mw[2] * fac2
                mw[3] = mw[3] * fac3
                mw[4] = mw[4] * fac4
                mw[5] = mw[5] * fac5
                mw[6] = mw[6] * fac6
            endjloop

        endif

    endrun

    ;----------------------------------------------------------------------
    ;step 21
    RUN PGM=MATRIX MSG='step 21 external trips matrix'
        ; Combine external trips into one P-A matrix per purpose for assignment

        filei mati[1]="trips.external1.mat",
              mati[2]="workers.gravitydist.mat"
        fileo mato[1]="trips.external.mat", mo=1-4,dec=4*2, name=xwk,xpb,xsh,xsr

        jloop

          ; Select ix,xi cells; factor to trips
          if (i<=30 || j<=30)
              mw[1] = mi.2.1 * 1.7
          else
              mw[1] = 0
          endif

          ; Consolidate non-work tables into p->a orientation
          mw[2] = mi.1.1.t + mi.1.2
          mw[3] = mi.1.3.t + mi.1.4
          mw[4] = mi.1.5.t + mi.1.6

        endjloop

    endrun

    ;======================================================================
    ;step 22
    RUN PGM=MATRIX MSG='step 22 ixxi'
        ; Output IX, XI workers and trips to text matrix file for DaySim

        zdati[1] = tazsumdata_15.txt, z=#1, univenr=6, emptot=16

        filei mati[1]="workers.gravitydist.mat",
              mati[2]="trips.external1.mat"
        fileo mato=ixximat.txt, mo=1-10, dec=10*2, pattern=ijm:v, fields=5,5,0,10

        if (i <= 30)    ;i = external zones only
          jloop
              mw[1]=mi.1.1.t   ;workers ix
              mw[2]=mi.1.1     ;workers xi
              mw[3]=mi.2.1     ;pb ix
              mw[4]=mi.2.2     ;pb xi
              mw[5]=mi.2.3     ;sh ix
              mw[6]=mi.2.4     ;sh xi
              mw[7]=mi.2.5     ;sr ix
              mw[8]=mi.2.6     ;sr xi

          ; Split workers and college students
              ;     IX assumed to be workers only, no college out-commuters
              mw[9] = 0
              ;     XI split in proportion to attraction zone employment and enrollment
              mw[10] = mw[2] * zi.1.univenr[j] / (zi.1.emptot[j] + zi.1.univenr[j] + 0.00001)  ;students
              mw[10] = max(0, min(mw[2], mw[10]))    ;out-of-range extra protection
              mw[2] = mw[2] - mw[10]                 ;remainder are workers

              ; prevent left-shift of output fields
              mw[11]=mw[1]+mw[2]+mw[3]+mw[4]+mw[5]+mw[6]+mw[7]+mw[8]+mw[9]+mw[10]
              if (mw[11]>0)
                  mw[1] = max(mw[1], 0.00001)
                  mw[10] = max(mw[10], 0.00001)
              endif

          endjloop
        endif

    endrun


   ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ;======================================================================
   ; *** RUN DAYSIM PART 1: Person models only,
   ;     to update job and school location shadow prices ***

   *echo Begin Daysim Iter @iter.i@>timelog.begindaysim.iter@iter.i@.txt

   ; Get local copy of the roster
   *copy ..\daysim\sacsim_roster_mat.csv

   ; Run work & school locations on full population
   if (iter.i <= 1)
       if (FilesExist('shadow_prices_start.txt')>=1)
           *copy shadow_prices_start.txt .\working\shadow_prices.txt
       else
           *del .\working\shadow_prices.txt
       endif
       *copy config.sacsim.wkscloc.xml .\config.run1.xml
       *echo ShouldRunRawConversion="true">>config.run1.xml
       *type ..\daysim\trailerxml.txt >>config.run1.xml
       *..\daysim\daysim -c config.run1.xml
       *copy ..\daysim\last-run.log last-run.wkscloc0.@iter.i@.log
       *copy .\working\shadow_prices.txt .\working\shadow_prices_0.txt
       
       *copy config.sacsim.wkscloc.xml .\config.run1.xml
       *echo ShouldRunRawConversion="false">>config.run1.xml
       *type ..\daysim\trailerxml.txt >>config.run1.xml
       
       loop spiter=1,4                                     ;run one iteration only
           *..\daysim\daysim -c config.run1.xml
           *copy ..\daysim\last-run.log last-run.wkscloc@spiter@.@iter.i@.log
           *copy .\working\shadow_prices.txt .\working\shadow_prices_@spiter@.txt
       endloop
       
       *copy .\working\shadow_prices.txt .\working\shadow_prices_save.txt
       *copy .\working\park_and_ride_shadow_prices.txt .\working\park_and_ride_shadow_prices_save.txt
   endif


   ;----------------------------------------------------------------------


   ;======================================================================
   ; *** RUN DAYSIM PART 2 ***
   ; Full demand model upon current sample of households

   *copy config.sacsim.trips.xml .\config.run2.xml
   *echo HouseholdSamplingRateOneInX="@iter.s@">>config.run2.xml
   *echo HouseholdSamplingStartWithY="@iter.m@">>config.run2.xml
   *echo ParkAndRideShadowPriceStepSize="@iter.pnrss@">>config.run2.xml
   *type ..\daysim\trailerxml.txt >>config.run2.xml

   ; Run Daysim
   *..\daysim\daysim -c config.run2.xml
   *copy ..\daysim\last-run.log last-run.trips.@iter.i@.log

   ; Restore shadow-prices from all-persons run
   if (iter.s >= 2)
       *copy .\working\shadow_prices_save.txt .\working\shadow_prices.txt
   endif

   ; Save iterations p&r shadow prices, for checking
   *copy working\park_and_ride_shadow_prices.txt .\park_and_ride_shadow_prices@iter.i@.txt

   ;Save iterations trips
   ;*copy _trip.tsv _trip.@iter.i@.tsv

   ;-----------------------------------------------------------------------------------
   ;step 23 --- move down after daysim run2.xml
   RUN PGM=MATRIX  MSG='step 24 Get workers and students by taz modeled from DaySim'

       zones = @network._zones@

       FILEI RECI = _person.tsv,
           delimiter[1]=' ,t'
           

       array Workers=zones, Students=zones

       ; Parse header record to locate field names
       if (reci.recno=1)
           loop f=1, reci.numfields
               if (reci.cfield[f]='id')       f_id       = f
               if (reci.cfield[f]='hhno')     f_hhno     = f
               if (reci.cfield[f]='pno')      f_pno      = f
               if (reci.cfield[f]='pptype')   f_pptype   = f
               if (reci.cfield[f]='pwtaz')    f_pwtaz    = f
               if (reci.cfield[f]='pstaz')    f_pstaz    = f
               if (reci.cfield[f]='psexpfac') f_psexpfac = f

           endloop
       else
           idd      = val(reci.cfield[f_id])
           hhno     = val(reci.cfield[f_hhno])
           pno      = val(reci.cfield[f_pno])
           pptype   = val(reci.cfield[f_pptype])
           pwtaz    = val(reci.cfield[f_pwtaz])
           pstaz    = val(reci.cfield[f_pstaz])
           psexpfac = val(reci.cfield[f_psexpfac])
       endif

       if (pwtaz>0) Workers[pwtaz]  = Workers[pwtaz] + psexpfac
       if (pstaz>0) Students[pstaz] = Students[pstaz] + psexpfac

       if (i=0)  ;end of file
           loop k=1,zones
               print file='workers and students by taz.@iter.i@.txt', list=k(5),workers[k](10),students[k](10)
           endloop
       endif

   ENDRUN

   ;======================================================================
   ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


   ;step 25
   *echo Begin converting trips Iter @iter.i@>timelog.beginconverttrips.iter@iter.i@.txt

   run pgm=network
       ; token run to get number of zones
       neti=?_base.net
       log var=_zones
   endrun

   ;======================================================================
   ;step 26
   RUN PGM=MATRIX  msg='step 26 Get trips from DaySim into matrices'

       FILEI RECI = _trip.tsv,
           delimiter[1]=' ,t'
           
       FILEO reco[1] = alltrips.dbf,
           fields=id(12.0),otaz(5.0),dtaz(5.0),mode(3.0),pathtype(3.0),dorp(2.0),deptime(5.0),arrtime(5.0),votclass(2.0),trexpfac(7.2)

       array Trips=10,10

       ; Parse header record to locate field names
       if (reci.recno=1)
           loop f=1, reci.numfields
               if (reci.cfield[f]='id')       f_id       = f
               if (reci.cfield[f]='otaz')     f_otaz     = f
               if (reci.cfield[f]='dtaz')     f_dtaz     = f
               if (reci.cfield[f]='mode')     f_mode     = f
               if (reci.cfield[f]='pathtype') f_pathtype = f
               if (reci.cfield[f]='dorp')     f_dorp     = f
               if (reci.cfield[f]='deptm')    f_deptime  = f
               if (reci.cfield[f]='arrtm')    f_arrtime  = f
               if (reci.cfield[f]='vot')      f_vot      = f
               if (reci.cfield[f]='trexpfac') f_trexpfac = f
           endloop
       else
           ro.id    = val(reci.cfield[f_id])
           otaz     = val(reci.cfield[f_otaz])
           dtaz     = val(reci.cfield[f_dtaz])
           mode     = val(reci.cfield[f_mode])
           pathtype = val(reci.cfield[f_pathtype])
           dorp     = val(reci.cfield[f_dorp])
           deptime  = val(reci.cfield[f_deptime])      ;minutes since midnight 0...1440
           arrtime  = val(reci.cfield[f_arrtime])      ;minutes since midnight
           vot      = val(reci.cfield[f_vot])
           trexpfac = @iter.s@  ; ***or:*** val(reci.cfield[f_trexpfac])

       ; Select value-of-time class
           vot = max(1.00, vot)   
           if (vot <= 7.23)  ;first quintile
               votclass = 1
           elseif (vot <= 16.85)   ;middle three quintiles
               votclass = 2
           else
               votclass = 3  ;last quintile
           endif

           write reco=1

           if (mode=1-10 && pathtype=0-9)
               _pti = pathtype+1
               Trips[mode][_pti] = Trips[mode][_pti] + trexpfac
           endif
       endif

       if (i=0) ;end of file: report summary
           loop mode=1,10
               loop pathtype=0,9
                   _iter = @iter.i@
                   _pti = pathtype+1
                   _trips = Trips[mode][_pti]
                   if (_trips > 0)
                       print file=persontripslog.txt, append=T, 
                       list=_iter(3), mode(3), pathtype(3), _trips(12)
                   endif
               endloop
           endloop
       endif

   endrun

   ;----------------------------------------------------------------------
   ;step 27
   RUN PGM=MATRIX MSG='step 27 autotrips by time period'
       ; Process auto trips

       array seghr=9, tripseg=9
       seghr[ 1]= 7
       seghr[ 2]= 8
       seghr[ 3]= 9
       seghr[ 4]= 10
       seghr[ 5]= 15
       seghr[ 6]= 16
       seghr[ 7]= 17
       seghr[ 8]= 18
       seghr[ 9]= 20

       filei reci = alltrips.dbf, sort=otaz

       fileo reco[1]  = autotrips.h07.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),h07(10.2)
       fileo reco[2]  = autotrips.h08.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),h08(10.2)
       fileo reco[3]  = autotrips.h09.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),h09(10.2)
       fileo reco[4]  = autotrips.md5.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),md5(10.2)
       fileo reco[5]  = autotrips.h15.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),h15(10.2)
       fileo reco[6]  = autotrips.h16.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),h16(10.2)
       fileo reco[7]  = autotrips.h17.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),h17(10.2)
       fileo reco[8]  = autotrips.ev2.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),ev2(10.2)
       fileo reco[9]  = autotrips.n11.dbf, fields=id(12.0),otaz(5.0),dtaz(5.0),autoclass(3.0),n11(10.2)

       ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       ; If tolling is active (by global setting tolls.ntc),
       ;    then pathtype 2 is non-tolled, pathtype 1 trips are tolled.
       ;    All trips are split by VOT for assignment user-classes.
       ; If tolling is not active, then all vehicle trips go to the non-toll assignment user-classes,
       ;    even though pathtype may be 1 for many or all vehicle trips,

       tollclass = 1       ; toll default
       
		;if (@tolls.ntc@ > 0) 
           ;if (ri.pathtype = 2) 
              ; tollclass = 0
          ; else
          ;     tollclass = 1
         ;  endif
       ; endif

       ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       ; Set assignment user-classes
    
       if (ri.mode=3)      ; SOV
           autoclass=(ri.votclass-1)*3 + 1
           trips = ri.trexpfac
       elseif (ri.mode=4)       ; HOV 2
           autoclass=(ri.votclass-1)*3 + 2
           trips = ri.trexpfac * 0.5
       elseif (ri.mode=5)  ; HOV 3+
           autoclass=(ri.votclass-1)*3 + 3
           trips = ri.trexpfac * 0.3
       elseif (ri.mode=9)       ; HOV 2
            autoclass=(ri.votclass-1)*3 + 2
            trips = ri.trexpfac * 0.6  ; 60% (or may be higher if use DORP=1, 0.67) of TNC vehicle trips go to HOV 2
       ELSE
           autoclass=0
           trips = 0
       endif

       ; ; If selecting based on drivers only
       ; if (ri.dorp = 1)
       ;     trips = ri.trexpfac
       ; else
       ;     trips = 0
       ; endif

       ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       if (autoclass>0 && trips>0)

       ; Segment the trip time
           arrhr = ri.arrtime/60
           dephr = ri.deptime/60
           durhr = (arrhr - dephr)
           if (durhr = 0)
               arrhr = arrhr + 0.0001
               durhr = 0.0001
           elseif (durhr < 0)
               durhr = durhr + 24
           endif

       ; Separate the after-midnight portion only if trip straddles midnight
       ;       into trip1: dephr to 24 (alias arrhr),
       ;        and trip2: 0 to arrhr (alias arr2)
           if (arrhr < dephr)
               arr2 = arrhr
               arrhr = 24
           else
               arr2 = 0
           endif

       ; Fraction of trip within each period
          n11 = 1
           loop s=1,8
               hrbeg = seghr[s]
               hrend = seghr[s+1]
               tseg = (max(0, min(hrend, arrhr) - max(hrbeg, dephr)) +
                       max(0, min(hrend, arr2 ) - hrbeg)) / durhr
               tripseg[s] = tseg
        ;       n11 = n11 - tseg
                n11 = n11 -tseg
           endloop
           n11 = max(0, n11)

       ; To fields
           ro.h07 = tripseg[1]  * trips
           ro.h08 = tripseg[2]  * trips
           ro.h09 = tripseg[3]  * trips
           ro.md5 = tripseg[4]  * trips
           ro.h15 = tripseg[5]  * trips
           ro.h16 = tripseg[6]  * trips
           ro.h17 = tripseg[7]  * trips
           ro.ev2 = tripseg[8]  * trips
           ro.n11 = n11          * trips
                                   
       ; Select records
           if (ro.h07 > 0) write reco= 1
           if (ro.h08 > 0) write reco= 2
           if (ro.h09 > 0) write reco= 3
           if (ro.md5 > 0) write reco= 4
           if (ro.h15 > 0) write reco= 5
           if (ro.h16 > 0) write reco= 6
           if (ro.h17 > 0) write reco= 7
           if (ro.ev2 > 0) write reco= 8
           if (ro.n11 > 0) write reco= 9
           

       endif
   endrun

   ;----------------------------------------------------------------------
   loop p=1,9
       if (p=01) per='h07'
       if (p=02) per='h08'
       if (p=03) per='h09'
       if (p=04) per='md5'
       if (p=05) per='h15'
       if (p=06) per='h16'
       if (p=07) per='h17'
       if (p=08) per='ev2'
       if (p=09) per='n11'


   ;step 28
       RUN PGM=MATRIX MSG='step 28 autotrips matrix'

	mati[1]=autotrips.@per@.dbf, fields=otaz,dtaz,autoclass,@per@, pattern=ijm:v
	mato[1]=autotrips.@per@.mat, mo=1-9, dec=9*4

	zones=@network._zones@

	array Trips=9

	@tolls.code1@ mw[01] = mi.1.01
	@tolls.code1@ mw[02] = mi.1.02
	@tolls.code1@ mw[03] = mi.1.03

	@tolls.code2@ mw[04] = mi.1.04
	@tolls.code2@ mw[05] = mi.1.05
	@tolls.code2@ mw[06] = mi.1.06

	@tolls.code3@ mw[07] = mi.1.07
	@tolls.code3@ mw[08] = mi.1.08
	@tolls.code3@ mw[09] = mi.1.09



	loop aclass=1,9
		Trips[aclass] = Trips[aclass] + rowsum(aclass)
		if (i=zones)
			_iter = @iter.i@
			_vtrips = Trips[aclass]
			if (_vtrips > 0)
				print file=vehtripslog.txt, append=T, list=_iter(3), ' @per@', aclass(3), _vtrips(12)
			endif
		endif
	endloop

	endrun

	; end of highway periods loop
	endloop
    ;----------------------------------------------------------------------

    ;======================================================================
    ;step 29
    RUN PGM=MATRIX  msg='step 29 Get P&R trips from DaySim'

        FILEI RECI = _trip.tsv,
            delimiter[1]=' ,t'

        ; p_r_lookup new format as of 10/7/2012
        ; 1 PRindex    1 thru number of P&R lot locations
        ; 2 ZoneID     TAZ
        ; 3 Capacity   Parking capacity
        ; 4 ParcelID   Parcel number
        ; 5 Sta_Node   Station (stop) node of P&R

        lookup fail=0,0,0 list=N, file=p_r_lookup.dat, name=PNR,
            lookup[1]=4, result=2,   ;P&R zone, from P&R ParcelID
            lookup[2]=4, result=1,   ;P&R index num (1-46+/-), from P&R ParcelID
            lookup[3]=1, result=3,   ;P&R capacity, from P&R index
            lookup[4]=1, result=5    ;P&R station node, from P&R index

        FILEO reco[1] = pnrtrips.dbf,
            fields=id(8.0),hhno(8.0),pno(2.0),otaz(5.0),dtaz(5.0),opcl(8.0),dpcl(8.0),
            opurp(3.0),dpurp(3.0),mode(3.0),dorp(3.0),pathtype(3.0),
            deptime(5.0),arrtime(5.0),votclass(2.0),trexpfac(7.2)

        zones=@network._zones@
        array Trips=10,10
        array Load=200,1440     ;something > number of P&R lots, x num of intervals
        array TotLoad = 200, TotTours = 200    ;something > number of P&R lots
        array price=1440

        ; Parse header record to locate field names
        if (reci.recno=1)
            loop f=1, reci.numfields
                if (reci.cfield[f]='id')       f_id       = f
                if (reci.cfield[f]='hhno')     f_hhno     = f
                if (reci.cfield[f]='pno')      f_pno      = f
                if (reci.cfield[f]='otaz')     f_otaz     = f
                if (reci.cfield[f]='dtaz')     f_dtaz     = f
                if (reci.cfield[f]='opcl')     f_opcl     = f
                if (reci.cfield[f]='dpcl')     f_dpcl     = f
                if (reci.cfield[f]='opurp')    f_opurp    = f
                if (reci.cfield[f]='dpurp')    f_dpurp    = f
                if (reci.cfield[f]='mode')     f_mode     = f
                if (reci.cfield[f]='pathtype') f_pathtype = f
                if (reci.cfield[f]='dorp')     f_dorp     = f
                if (reci.cfield[f]='deptm')    f_deptime  = f
                if (reci.cfield[f]='arrtm')    f_arrtime  = f
                if (reci.cfield[f]='vot')      f_vot      = f
                if (reci.cfield[f]='trexpfac') f_trexpfac = f
            endloop
        else
            ro.id    = val(reci.cfield[f_id])
            hhno     = val(reci.cfield[f_hhno])
            pno      = val(reci.cfield[f_pno])
            otaz     = val(reci.cfield[f_otaz])
            dtaz     = val(reci.cfield[f_dtaz])
            opcl     = val(reci.cfield[f_opcl])
            dpcl     = val(reci.cfield[f_dpcl])
            opurp    = val(reci.cfield[f_opurp])
            dpurp    = val(reci.cfield[f_dpurp])
            mode     = val(reci.cfield[f_mode])
            pathtype = val(reci.cfield[f_pathtype])
            dorp     = val(reci.cfield[f_dorp])
            deptime  = val(reci.cfield[f_deptime])      ;minutes since start (3am?) 0...1440
            arrtime  = val(reci.cfield[f_arrtime])      ;minutes since start
            vot      = val(reci.cfield[f_vot])
            trexpfac = val(reci.cfield[f_trexpfac])    ;*** or 1 or *** @iter.s@  ; ***or:*** 

        ; Convert time to SP convention
          deptime = (deptime + 1440 - 180) % 1440
          arrtime = (arrtime + 1440 - 180) % 1440

          ; Select value-of-time class from specific value
          ; ***Also, place non toll-users to one special VOT, when defined ***
          ;if (vot <= 0)
              ;votclass=1
          ;else
              ;votclass=1   ;real values to be determined, just use one class for now
          ;endif

          if (opurp=10 || dpurp=10)
              write reco=1
          endif

          if (mode=1-10 && pathtype=0-9)
              _pti = pathtype+1
              Trips[mode][_pti] = Trips[mode][_pti] + trexpfac
          endif

          ; Summary accumulation of person-tours by P&R
          if (mode=3,4,5 && dpurp=10) 
                  loadindex = PNR(2,dpcl)
                  TotTours[loadindex] = TotTours[loadindex] + trexpfac
          endif

          ; Zone-level P&R accumulations
          ;    *** presumes records are in chronological sequence, properly matched,
          ;        and that tours crossing the "midnight" time are in order from leave home to arrive home ***
          if (mode=3,4,5 && dorp=1)
              if (dpurp=10)       ;drive to P&R
                  loadstart = arrtime+1
                  TotLoad[loadindex] = TotLoad[loadindex] + trexpfac
              elseif (opurp=10)   ;depart P&R
                  loadend = deptime+1
                  if (loadstart <= loadend)
                      loop intv = loadstart, loadend
                          Load[loadindex][intv] = Load[loadindex][intv] + trexpfac
                      endloop
                  else  ;wraps around "midnight" expected to be properly represented, as is in tested example
                      loop intv = loadstart, 1440
                          Load[loadindex][intv] = Load[loadindex][intv] + trexpfac
                      endloop
                      loop intv = 1, loadend
                          Load[loadindex][intv] = Load[loadindex][intv] + trexpfac
                      endloop
                  endif
              endif
          ENDIF
          
       endif

        if (i=0)  ;end of file
            loop loadindex=1, 200
                ; write loads to matrix-compatible file
                if (TotLoad[loadindex] > 0)
                    MaxLoad = 0
                    loop intv=1,1440
                        ;;;;; print file=pnrload.txt, list=loadindex(4), intv(5), Load[loadindex][intv](9.2)
                        MaxLoad = max(MaxLoad, Load[loadindex][intv])
                    endloop
                    stanode = PNR(4,loadindex)
                    print file=pnr_tot_load.txt, form=(8), list=loadindex(4), stanode(6),
                          TotLoad[loadindex], MaxLoad, TotTours[loadindex]
                endif
            endloop
        endif

    endrun

    *copy pnrtrips.dbf pnrtrips_@iter.i@.dbf
    *copy pnr_tot_load.txt pnr_tot_load_@iter.i@.txt

    ;==============================================================================
    ; Airport auxiliary model for Sacsim
    ; 3/2012

    *echo Begin airport model Iter @iter.i@>timelog.beginairport.iter@iter.i@.txt

    ;==============================================================================
    ; Constrained P&R Choice skim for Sacmet
    ; Replaces TrnBuild drive-to-transit skims
    ;  8/18/2011 thru 12/2011 jag iterative proportional adjustment constraint
    ;  3/2012 adapt for SacSim airport mode choice

    ;perr=1
    ;CostPerMile = 15.1
    ;VehPerPers = 0.89
    pertr='md6'   ;transit period md6
    perau='md5'   ;auto period md5
    CostPerMile = 17
    VehPerPers = 0.57

    ;step 30
    RUN PGM=MATRIX MSG='step 30 Park-and-ride skim for airport'
        ; Constrained P&R Choice for Sacmet
        ;    Choice set is zones with P&R capacity coded

        ; prepare generalized cost data for P&R choice
        ;
        ;mati[1]=skim.auto.@perau@.1.mat
        mati[1]=skim.auto.@perau@.1.mat
        mati[2]=skim.tran.@pertr@.mat

        ; any source for terminal times?
        ;zdati[1]=.\?zbas.dbf,     ;z=3-6,TermP=37-42,TermA=43-48,ParkCost=49-54,
        ;    avex0=ptime,atime      ;were TermP,TermA,ParkCost

        zdati[2]=?_pnr.dbf, avex0=prkcost, sum=pnrcap

        fileo mato="exputil.Tskim.mat",mo=1-2,dec=2*8, name=eua,eut

        ; Coefficients from mode choice model,
        ; to compute generallized costs

        CostPerMin  = @CostPerMile@ *35/60    ;10 c/mile was MC model change by BG
        TDVehPerPers = @VehPerPers@

        ; Weighted coefficients = coefficient / cIVTT = weight that could be used in skimming
        ; "Good practice" weight factors
        wtAutoTime = 2
        wtWalkTime = 2    
        wtWaitTime = 1.5
        wtXferTime = 2
        wtCost     = 1.75*5.58/100  ;cCost(per equiv min)/cIVTT * conversion of cents to minutes

        jloop

            AuTime = mi.1.dati@perau@_1        ;minutes
            AuDist = mi.1.dadi@perau@_1        ;miles
            ;AuToll = mi.1.dato@perau@_1     ;dollars
            TWInVe = mi.2.ivtt@pertr@      ;minutes  
            TWWalk = mi.2.walk@pertr@      ;minutes
            TWWait = mi.2.iwait@pertr@     ;minutes
            TWXfer = mi.2.xwait@pertr@     ;minutes
            TWFare = mi.2.fare@pertr@      ;cents

            AuCost = (AuDist*@CostPerMile@ + zi.2.prkcost/2)*TDVehPerPers   ;per minute, was per mile

            ; Generallized Costs
            if (AuTime > 0 && zi.2.pnrcap[j]>0)
                mw[1] = exp(-0.07*(wtAutoTime*AuTime + 
                    wtWalkTime +                                ; *** terminal time***  *(zi.1.ptime)/100 +
                    wtCost*AuCost))
            else
                mw[1] = 0
            endif

            if (TWInVe > 0 && zi.2.pnrcap[i]>0)
                mw[2] = exp(-0.07*(mi.2.compti@pertr@ + wtCost*TWFare))
                    ; TWInVe +
                    ; wtWalkTime*TWWalk +
                    ; wtWaitTime*TWWait +
                    ; wtXferTime*TWXfer +
            else
                mw[2] = 0
            endif

        endjloop

    endrun

    ;------------------------------------------------------------------------------
    ;step 31
    RUN PGM=MATRIX MSG='step 31 DTW with constrained choices of parking location'
        ;  DTW with constrained choices of parking location

        matvalcache = 400  ;should be >= Num of PNRs * 8

        filei mati[1]=exputil.Tskim.mat,     ;generallized costs
              mati[2]=skim.auto.@perau@.1.mat,   ;auto skims
              mati[3]=skim.tran.@pertr@.mat     ;pnr-j transit skims

        zdati[1]=?_pnr.dbf, z=zone, sum=pnrcap

        ; ***Sacmet had *** zdati[2]=pnrloads.txt,z=#1, pnrcum=#2, pnrfac=#3, sum=pnrcum

        fileo mato[1]=skim.pnr.airport.mat,mo=7-16,dec=2,
        name=ivtt,walk,iwait,xwait,fare,brds,autime,audist,comptime,parkzone
        ;  ***was***  name=INVEHTIME,XFERTIME,IWAIT,DRIVETIME,FARE,DRIVEDIST,comptime,WALKTIME,XFERS,PARKZONE  ;Sacmet order

        array pnrzone = _zones   ;pnrzone only needs num of PNR zones
        array pnrfac =  _zones
        array euk =     _zones

        fillmw mw[1] = mi.1.1    ;auto gc
        fillmw mw[2] = mi.2.1, mw[3]=mi.2.2  ;auto skims

        ; Set up PNR capacity list array.
        ; (Elements are numbered 1 thru number of pnr lot zones)
        if (i = 1)
            npnr = 0
            loop jj=1,zones
                if (zi.1.pnrcap[jj] >= 1)
                    npnr = npnr + 1
                    pnrzone[npnr] = jj
                endif
            endloop
            ; p&r factor
            loop p=1,npnr
                k = pnrzone[p]
        ;        if (zi.2.pnrcum[k] > 0)
        ;            if (@perr@=1)   ;peak
        ;                pnrfac[k] = zi.2.pnrfac[k]
        ;            else            ;offpeak gets remainder, deter if nearly full
        ;                pnrfac[k] = max(0.13, min(1, zi.2.pnrfac[k], (1 - zi.2.pnrcum[k]/zi.1.pnrcap[k])/0.25))
        ;            endif
        ;        else
                    pnrfac[k] = 1
        ;        endif
            endloop
        endif

        jj=285 ;airport only, otherwise: loop jj=1,zones
        if (!(i=jj))
            ; Accumulate denominator
            denom = 0
            bestk = 0
            besteu = 0
            loop p=1,npnr
                k = pnrzone[p]
                eu = mw[1][k] * matval(1,2,k,jj,0) * pnrfac[k]
                euk[k] = eu
                denom = denom + eu
                if (eu > besteu)   ;for some extra skim attributes
                    besteu = eu
                    bestk  = k
                endif
            endloop

            if (denom > 0)
                loop p=1,npnr
                    k = pnrzone[p]
                    share = euk[k]/denom
                    ; Accumulate weighted skims         ;Sacmet order
                    mw[7][jj]  = mw[7][jj]  + share * matval(3,1,k,jj)   ;transit values from k to j
                    mw[8][jj]  = mw[8][jj]  + share * matval(3,4,k,jj)
                    mw[9][jj]  = mw[9][jj]  + share * matval(3,5,k,jj)
                    mw[10][jj] = mw[10][jj] + share * matval(3,6,k,jj)
                    mw[11][jj] = mw[11][jj] + share * (matval(3,7,k,jj) + zi.1.prkcost[k])   ;fare + parking cost
                    mw[12][jj] = mw[12][jj] + share * matval(3,8,k,jj)
                    mw[13][jj] = mw[13][jj] + share * mw[2][k]        ;drive access from i to k
                    mw[14][jj] = mw[14][jj] + share * mw[3][k]
                endloop
                mw[15][jj] = ln(denom)/(-0.07) - mw[11][jj]*1.75*5.58/100 ;logsum->true composite time, deduct cost
                mw[16][jj] = bestk                 ;save best choice
                mw[17][jj] = ln(besteu)/(-0.07)   ;best-only generallized cost i-j
            endif

        endif
        ; if not airport only: endloop

    ENDRUN

    ;==============================================================================
    ;   Trip Generation - Home-Based Airport
    ;   Substitute for ClassGen.bas process
    ;   For DaySim Application
    ; 
    ;   Rev 3/2012 based on 
    ;       11 thru 12/2009 revision to the generation model
    ;               2-way plus externals
    ;       8/2011 correction (autime + 10*seg34)
    ;       8 thru 12/2011 Sacmet application

    ;==============================================================================
    ;step 32

    RUN PGM=NETWORK
      filei neti=?_base.net
      log var=_zones
    endrun

    ;==============================================================================
    ;step 33
    RUN PGM=MATRIX  MSG='step 33 Airport trips model'
        ; Airport trip generation
        ;
        ;     Persons data from DaySim household table
        filei reci=.\?_raw_household.txt,         ; z=htaz, persons=persons, hinc=hinc, vehicl=vehicl, expfac=expfac
            delimiter[1]=','

        ;     External population
        zdati[1]=.\?_ixxi.dbf, sum=smfpop

        array t11=@network._zones@
        array t12=@network._zones@
        array t21=@network._zones@
        array t22=@network._zones@

        ; Parse header record to locate field names
        if (reci.recno=1)
            loop f=1, reci.numfields
                if (reci.cfield[f]='hhno')     f_hhno     = f
                if (reci.cfield[f]='hhtaz')    f_hhtaz    = f
                if (reci.cfield[f]='hhsize')   f_hhsize   = f
                if (reci.cfield[f]='hhvehs')   f_hhvehs   = f
                if (reci.cfield[f]='hhincome') f_hhincome = f
                if (reci.cfield[f]='hhexpfac') f_hhexpfac = f
            endloop
            records = 0
            households = 0
            persons = 0
        else
            hhno     = val(reci.cfield[f_hhno])
            hhtaz    = val(reci.cfield[f_hhtaz])
            hhsize   = val(reci.cfield[f_hhsize])
            hhvehs   = val(reci.cfield[f_hhvehs])
            hhincome = val(reci.cfield[f_hhincome])
            hhexpfac = val(reci.cfield[f_hhexpfac])

            records    = records    + 1
            households = households + hhexpfac
            persons    = persons    + hhexpfac * hhsize

            ; Trip generation and income class

            ; (Approximate Sacmets five categories)
            if (hhincome < 15000)
                ci    = 1
                trips = 0.0060 * hhexpfac
            elseif (hhincome >=15000 && hhincome < 35000)
                ci    = 1
                trips = 0.0068 * hhexpfac
            elseif (hhincome >=35000 && hhincome < 50000)
                ci    = 1
                trips = 0.0133 * hhexpfac
            elseif (hhincome >=50000 && hhincome < 75000)
                ci    = 2
                trips = 0.0156 * hhexpfac
            elseif (hhincome >=75000)
                ci    = 2
                trips = 0.0269 * hhexpfac
            endif

        ; Vehicles per Person category (rev 12/09 to match mc logic)
            ca = 1
            if (hhvehs=0) ca = 2
            if (hhvehs<2 && hhsize>1) ca = 2

        ; Accumulate trips by class
            if (ci=1 && ca=1) t11[hhtaz] = t11[hhtaz] + trips
            if (ci=1 && ca=2) t12[hhtaz] = t12[hhtaz] + trips
            if (ci=2 && ca=1) t21[hhtaz] = t21[hhtaz] + trips
            if (ci=2 && ca=2) t22[hhtaz] = t22[hhtaz] + trips
            totaltrips = totaltrips + trips

        endif

        if (i=0) ;i.e. if EOF, add externals, write out the zone x class trips
            loop zz=1,30     ;Gateways
                t11[zz] = t11[zz] + zi.1.smfpop[zz]*0.00090
                t12[zz] = t12[zz] + zi.1.smfpop[zz]*0.00039
                t21[zz] = t21[zz] + zi.1.smfpop[zz]*0.00179
                t22[zz] = t22[zz] + zi.1.smfpop[zz]*0.00022
            endloop
            loop zz=1,@network._zones@
                print file=airporthbtg.txt, form=10.4, list=zz(5),t11[zz],t12[zz],t21[zz],t22[zz]
                      
            endloop
        endif

    endrun

    ;--------------------------------------------------------------------
    ;step 34
    RUN PGM=GENERATION  MSG='step 34 airport model trip generation'
        ; Airport access travel model application
        ; Generate zonal demands and survey record weights

        ; Use number of zones in the highway network
        zones=@network._zones@
        log var=zones

        ; Inputs

        ; Non-retail employment source
        zdati[1]=tazsumdata_15.txt, z=#1, tothh=2, empres=3, stugrd=4, stuhgh=5, stuuni=6,
        empedu=7, empfoo=8, empgov=9, empind=10, empmed=11, empofc=12, 
        empret=13, empsvc=14, empoth=15, emptot=16

        zdati[2]=..\input\airportsurvey.dbf, 
            z=RNO  ;use record number as its "zone" (must be unique and <=zones)

        zdati[3]=airporthbtg.txt, z=#1,
            aphbtrips11=2, aphbtrips12=3, aphbtrips21=4, aphbtrips22=5,
            sum=aphbtrips11, aphbtrips12, aphbtrips21, aphbtrips22

        ;     External population
        zdati[4]=.\?_ixxi.dbf, sum=smfpop


        lookup fail=0,0,0 list=N, file=.\?_taz.dbf, name=rad,
            lookup[1]=taz, result=rad


        ; Demand
        demhb  = zi.3.aphbtrips11 +
                 zi.3.aphbtrips12 +
                 zi.3.aphbtrips21 +
                 zi.3.aphbtrips22

        ; All employees except retail and food-service
        nonret = zi.1.empedu+zi.1.empgov+zi.1.empofc+zi.1.empoth+zi.1.empsvc+zi.1.empmed+zi.1.empind

        demnhb = 0.006*nonret + 0.00095*zi.4.smfpop     ;rev 11/20/09
        if (rad(1,i)=13) demnhb = 0.010*nonret   ;downtown special rate


        ; Weights of survey records, place into HB or NHB status
        if (zi.2.hbnhb = 1)
            srvhb  = zi.2.exfac
            srvnhb = 0
        elseif (zi.2.hbnhb=2)
            srvhb  = 0
            srvnhb = zi.2.exfac
        else
            srvhb  = 0
            srvnhb = 0
        endif

        ; Eliminate invalid survey records
        if (zi.2.taz<=0 || zi.2.taz>zones)   ;** || apdist(1,rad(1,zi.2.taz))<=0)
            srvhb  = 0
            srvnhb = 0
        endif

        p[1]=demhb
        p[2]=demnhb
        a[1]=srvhb
        a[2]=srvnhb


        phase=adjust

        ; If wanted, put user-coded overriding control totals in this file, and activate:
        ; read file=airportcontroltotals.txt

        ; This factors to specified control totals
        a[1] = a[1] * p[1][0] / a[1][0]
        a[2] = a[2] * p[2][0] / a[2][0]

        endphase

        ; Output
        pao = tripends.airport.dbf, form=15.6, dbf=y,
            list = z(5) p[1] p[2] a[1] a[2]

    endrun

    ;---------------------------------------------------------------------
    ;step 35
    RUN PGM=MATRIX  MSG='step 35 airport model build compatibility matrix'
        ; Build zone-survey compatibility matrix for spreading representative
        ; survey records across compatible zones

        zones = @generation.zones@

        ; Inputs
        zdati[1]=tripends.airport.dbf
        zdati[2]=..\input\airportsurvey.dbf, 
            z=RNO  ;use record number as its "zone" (must be unique and <=zones)

        zdati[3] =airporthbtg.txt, z=#1, c11=2, c12=3, c21=4, c22=5

        lookup fail=0,0,0 list=N, file=.\?_taz.dbf, name=rad,
            lookup[1]=taz, result=rad

        ; Outputs
        fileo mato=airportalloccompatibility.mat, mo=1-2

        array hbtg=22
        hbtg[11] = zi.3.c11
        hbtg[12] = zi.3.c12
        hbtg[21] = zi.3.c21
        hbtg[22] = zi.3.c22

        jloop

        ; Calculate geographic compatibilities
            mw[1]=0
            mw[2]=0

        ;**    if (apdist(1,rad(1,i)) = apdist(1,zi.2.rad[j]))   ;was = apdist(1,rad(1,zi.2.taz[j])))
                if (zi.2.hbnhb[j] = 1)             ;HB
        ;            HB fills in the number of like-demographic households as j into zone i.
                    IncLT50k=0
                    if (zi.2.hhinc<4) IncLT50k = 1
                    AuLTpers=0
                    if (zi.2.hvehs[j]=0) AuLTpers = 1
                    if (zi.2.hvehs[j]=1 && zi.2.hsize[j]>1) AuLTpers = 1
                    mw[1]=hbtg[(2-IncLT50k)*10+(AuLTpers+1)]
                endif

                if (zi.2.hbnhb[j] = 2) mw[2]=1     ;NHB
        ;**    endif

        ; Zero out row and columns with no trips - prevent Fratar problems
            if (zi.1.p1 = 0)    mw[1]=0
            if (zi.1.p2 = 0)    mw[2]=0
            if (zi.1.a1[j] = 0) mw[1]=0
            if (zi.1.a2[j] = 0) mw[2]=0

        endjloop
    endrun

    ;---------------------------------------------------------------------
    ;step 36
    RUN PGM=FRATAR  MSG='step 36 airport model fratar'
        ; Distribute allocation weights of airport survey records to zones

        zdati[1]=tripends.airport.dbf
        mati[1]=airportalloccompatibility.mat
        mato = airportallocweight.mat, mo=1-2 

        setpa p[1]=zi.1.P1, a[1]=zi.1.A1, mw[1]=mi.1.1, control=p,
              p[2]=zi.1.P2, a[2]=zi.1.A2, mw[2]=mi.1.2, control=p

        ;---------------------------------------------------------------------
        ;step 37
        RUN PGM=MATRIX  MSG='step 37 airport model matrix adjustment'
          ; Airport Access Model: Mode Choice

          ; Input files
          mati[1]=airportallocweight.mat  
          mati[2]=skim.auto.@perau@.1.mat         ; highway skim file
          mati[3]=skim.tran.@pertr@.mat          ; transit skim file
          mati[4]=skim.pnr.airport.mat          ; transit skim file

          zdati[1]=..\input\airportsurvey.dbf,     ; survey
              z=RNO    ;use record number as its "zone" (must be unique and <=zones)
              ; Mandatory fields are referenced herein by name ("zi.1.?[j]")


          ; Coefficient Array

          lookup fail=-999999,-999999,-999999 list=N, name=coef,
          lookup[1]=1, result=2,
          lookup[2]=1, result=3,
          lookup[3]=1, result=4,
          lookup[4]=1, result=5,
          ;  index  res/bus  res/leis vis/bus  vis/leis     Variable
          r='    1        1        2        3        4 ',  ; segment
            '    2        0        0        0        0 ',  ; auto drop const
            '    3   0.5303   0.5303    0.106  -1.1104 ',  ; auto park const
            '    4  -1.5858  -2.1639  -0.3116  -1.8789 ',  ; taxi const
            '    5  -1.0737  -0.5921  -0.4271  -1.2767 ',  ; van const
            '    6   0.5281   0.5281    0.705    0.705 ',  ; wacc const
            '    7   0.1097   0.1097  -0.5949  -0.5949 ',  ; dacc const
            '    8  -0.2191  -0.2191   0.3275   0.3275 ',  ; drop const
            '    9        0        0        0        0 ',  ; wacc const (inactive 2nd transit mode)
            '   10        0        0        0        0 ',  ; dacc const (inactive 2nd transit mode)
            '   11        0        0        0        0 ',  ; drop const (inactive 2nd transit mode)
            '   12  -0.2494  -0.2494        0        0 ',  ; auto<pers
            '   13  -0.3995        0        0        0 ',  ; 1 pers
            '   14        0   0.6422        0        0 ',  ; 3+ pers
            '   15        0   0.7416        0        0 ',  ; inc<50k
            '   16  -0.0155  -0.0155        0        0 ',  ; parking
            '   17  -0.0191  -0.0003  -0.0191  -0.0003 ',  ; van/taxi
            '   18  -0.0422  -0.0422  -0.0422  -0.0422 ',  ; transit
            '   19  -0.0095  -0.0095  -0.0095  -0.0095 ',  ; main mode
            '   20  -0.0518  -0.0518  -0.0518  -0.0518 ',  ; wacc/xfr
            '   21  -0.0079  -0.0079  -0.0079  -0.0079 ',  ; dacc
            '   22  -0.0055  -0.0003  -0.0055  -0.0003 ',  ; chauf1
            '   23        0        0        0        0 ',  ; xfr1
            '   24   -0.845   -0.845   -0.845   -0.845 ',  ; xfr2
            '   25 -0.01825 -0.01825 -0.01825 -0.01825 ',  ; walk egr time
            '   26  -0.0916  -0.0916  -0.0916  -0.0916 ',  ; walk egr dummy
            '   27  -0.0053  -0.0053  -0.0053  -0.0053 ',  ; shut egr time
            '   28 -0.05255 -0.05255 -0.05255 -0.05255 ',  ; shut egr dummy
            '   29    1.865    1.865   3.0869   3.0869 ',  ; scale
            '   30  -0.0155  -0.0155  -0.0155  -0.0155 '   ; tolls (adapted from parking cost coefficient)

          ; Get skims to airport (constant for all survey records)

          ;if (i=930)
          jloop j=285 ; airport
              autime = mi.2.dati@perau@_1
              audist = mi.2.dadi@perau@_1
          ;    autoll = mi.2.dato@perau@_1  ;added 4/2014
              twivtt = mi.3.ivtt@pertr@
              twovtt = mi.3.iwait@pertr@+mi.3.xwait@pertr@+mi.3.walk@pertr@
              twwalk = mi.3.walk@pertr@
              twfare = mi.3.fare@pertr@*1.36                  ;used to be 1.36 [*$1.50/$1.10 ratio of used to skim]
              twxfrs = max(0,mi.3.brds@pertr@-1)
              tdivtt = mi.4.ivtt
              tdovtt = mi.4.iwait+mi.4.xwait+mi.4.walk
              tdwalk = mi.4.walk
              tddriv = mi.4.autime
              tdfare = mi.4.fare*1.36                  ;used to be 1.36 [*$1.50/$1.10 ratio of used to skim]
              tdxfrs = max(0,mi.4.brds-1)
          endjloop

          ; Settings
          parkcharge    = 10.00  ;$
          walkcrit      = 15    ;min
          overnitepark  = 0     ;1=yes, 0=no
          ; (transit fare is taken from skims)

          ; Airport egress settings
          ;
          ; Option packages:
          ;  1: remote station at rental
          ;  2: combination station between terminals (stand-in for final alt.)
          ;  3: station/stop at each terminal

          ;                        Option package values
          ;                           1    2    3
          ;                         ---- ---- ----
          egrivtt       = 0       ;  -3    0    2
          egrovtt       = 0       ;  10    0    0
          egrshuttime   = 0       ;  10    0    0
          egrwalktime   = 2       ;   1    2   1.5
          egrshutdumy   = 0       ;   1    0    0
          egrwalkdumy   = 1       ;   0    1    1

          jloop j=1,786 ; j = survey record number   ;786=final rno

            ; Derived Variables
            ; Costs
            parkcost      = parkcharge * zi.1.stay[j] * 0.5 / min(zi.1.acmp4[j]+1, 5)
            taxicost      = (5.9 + 1.3*audist) / min(zi.1.acmp4[j]+1, 5)

            if (audist <=40)
                vancost   = 6 + 0.55*audist
            else
                vancost   = 999999
            endif

            ; Transfers
            twxfr1 = 0
            twxfr2 = 0
            tdxfr1 = 0
            tdxfr2 = 0
            if (twxfrs>=1) twxfr1 = 1
            if (twxfrs>=2) twxfr2 = 1
            if (tdxfrs>=1) tdxfr1 = 1
            if (tdxfrs>=2) tdxfr2 = 1


            ; Demographics
            PersEQ1       = 0
            PersGE3       = 0
            IncLT50k      = 0
            AuLTpers      = 0

            if (zi.1.hsize[j] = 1 && zi.1.hbnhb[j]=1) PersEQ1 = 1
            if (zi.1.hsize[j] >=3 && zi.1.hbnhb[j]=1) PersGE3 = 1
            if (zi.1.hhinc[j] <4  && zi.1.hbnhb[j]=1) IncLT50k = 1
            if (zi.1.hbnhb[j]=1)
                if (zi.1.hvehs[j]=0) AuLTpers = 1
                if (zi.1.hvehs[j]=1 && zi.1.hsize[j]>1) AuLTpers = 1
            endif

            seg = zi.1.seg[j]
            mw[10]=seg                      ;***for reporting
            seg12 = 0
            seg34 = 0
            if (seg = 1,2) seg12 = 1
            if (seg = 3,4) seg34 = 1

            ; Trips (allocation weights between i and survey record j)
            mw[8] = mi.1.1 + mi.1.2
            trips=mi.1.1+mi.1.2
            ; Mode Choice Calculations
            if (mw[8] > 0)   ;if there are trips
                UtilAuDrop = coef(seg, 19) * autime +
                             coef(seg, 13) * PersEQ1*seg12 +
                             coef(seg, 14) * PersGE3*seg12 +
                             coef(seg, 22) * 2 * autime 
            ;                 coef(seg, 30) * autoll

                UtilAuPark = coef(seg,  3) +
                             coef(seg, 19) * (autime + 10*seg34) +
                             coef(seg, 16) * parkcost*seg12 +
                             coef(seg, 12) * AuLTpers*seg12 +
                             coef(seg, 26)       ;* egrwalkdumy
            ;                 coef(seg, 30) * autoll

                UtilTaxi   = coef(seg,  4) +
                             coef(seg, 19) * autime +
                             coef(seg, 17) * taxicost
             
                UtilVan    = coef(seg,  5) +
                             coef(seg, 19) * autime +
                             coef(seg, 17) * vancost

                UtilTrWalk = coef(seg,  6) +
                             coef(seg, 15) * IncLT50k*seg12 +
                             coef(seg, 18) * twfare +
                             coef(seg, 19) * (twivtt + egrivtt) +
                             coef(seg, 20) * (twovtt + egrovtt-5) +
                             coef(seg, 25) * egrwalktime +
                             coef(seg, 26) * egrwalkdumy +
                             coef(seg, 27) * egrshuttime +
                             coef(seg, 28) * egrshutdumy +
                             coef(seg, 23) * twxfr1 +
                             coef(seg, 24) * twxfr2
               
                UtilTrDriv = coef(seg,  7) +
                             coef(seg, 12) * AuLTpers*seg12 +
                             coef(seg, 15) * IncLT50k*seg12 +
                             coef(seg, 18) * tdfare +
                             coef(seg, 19) * (tdivtt + egrivtt) +
                             coef(seg, 20) * (tdovtt + egrovtt-5) +
                             coef(seg, 21) * tddriv +
                             coef(seg, 25) * egrwalktime +
                             coef(seg, 26) * egrwalkdumy +
                             coef(seg, 27) * egrshuttime +
                             coef(seg, 28) * egrshutdumy +
                             coef(seg, 23) * tdxfr1 +
                             coef(seg, 24) * tdxfr2

                UtilTrDrop = coef(seg,  8) +
                             coef(seg, 13) * PersEQ1*seg12 +
                             coef(seg, 14) * PersGE3*seg12 +
                             coef(seg, 15) * IncLT50k*seg12 +
                             coef(seg, 18) * tdfare +
                             coef(seg, 19) * (tdivtt + egrivtt) +
                             coef(seg, 20) * (tdovtt + egrovtt-5) +
                             coef(seg, 21) * tddriv +
                             coef(seg, 22) * tddriv*2 +
                             coef(seg, 25) * egrwalktime +
                             coef(seg, 26) * egrwalkdumy +
                             coef(seg, 27) * egrshuttime +
                             coef(seg, 28) * egrshutdumy +
                             coef(seg, 23) * tdxfr1 +
                             coef(seg, 24) * tdxfr2

            ; Exponentiated Utilities, Availability
                UtilScale = coef(seg,29)

                EUAuDrop = exp(UtilScale * UtilAuDrop)
                EUAuPark = exp(UtilScale * UtilAuPark)
                EUTaxi   = exp(UtilScale * UtilTaxi)

                if (AuDist<=40)
                    EUVan    = exp(UtilScale * UtilVan)
                else
                    EUVan = 0
                endif
                
                if (twwalk<walkcrit && twivtt>0)
                    EUTrWalk = exp(UtilScale * UtilTrWalk)
                else
                    EUTrWalk = 0
                endif
                
                if ((overnitepark>0 || zi.1.stay[j]<3) && tdivtt>0 && tddriv>0)
                    EUTrDriv = exp(UtilScale * UtilTrDriv)
                else
                    EUTrDriv = 0
                endif
                
                if (tdivtt>0 && tddriv>0)
                    EUTrDrop = exp(UtilScale * UtilTrDrop)
                else
                    EUTrDrop =0
                endif

            ; Multinomial logit calculation

                denom = EUAuDrop + EUAuPark + EUTaxi + EUVan +EUTrWalk + EUTrDriv +EUTrDrop
                
                mw[1] = mw[8] * EUAuDrop/denom
                mw[2] = mw[8] * EUAuPark/denom
                mw[3] = mw[8] * EUTaxi  /denom
                mw[4] = mw[8] * EUVan   /denom
                mw[5] = mw[8] * EUTrWalk/denom
                mw[6] = mw[8] * EUTrDriv/denom
                mw[7] = mw[8] * EUTrDrop/denom

            ; Vehicle trips: divide by party size (or maximum likely vehicle occupancy),
            ;  and add the reverse pick-up, drop-off, and deadhead trips
            ;  Matrices 11-13 are trips to/from airport, DA, S2, and S3+
            ;  Matrices 14-16 are to/from PNR lots, DA, S2, and S3+
                if (zi.1.party[j] <= 1)
                    mw[11] =  mw[1]*0.8 + mw[2] + mw[3]*0.5
                    mw[12] =  mw[1]             + mw[3]
                    mw[13] =  mw[1]*0.2                     + mw[4]/10
                    mw[14] =  mw[6]     + mw[7]*0.8
                    mw[15] =              mw[7]
                    mw[16] =              mw[7]*0.2
                elseif(zi.1.party[j] = 2)
                    mw[11] = (mw[1]*0.8         + mw[3]*0.5  )/2
                    mw[12] = (mw[1]*0.2 + mw[2]              )/2
                    mw[13] = (mw[1]             + mw[3]      )/2 + mw[4]/10
                    mw[14] = (            mw[7]*0.8          )/2
                    mw[15] = (mw[6]     + mw[7]*0.2          )/2
                    mw[16] = (            mw[7]              )/2
                else
                    mw[11] = (mw[1]*0.9         + mw[3]*0.5  )/min(zi.1.party[j], 4)
                    mw[12] = (mw[1]*0.1                      )/min(zi.1.party[j], 4)
                    mw[13] = (mw[1]     + mw[2] + mw[3]      )/min(zi.1.party[j], 4) + mw[4]/10
                    mw[14] = (            mw[7]*0.9          )/min(zi.1.party[j], 4)
                    mw[15] = (            mw[7]*0.1          )/min(zi.1.party[j], 4)
                    mw[16] = (mw[6]     + mw[7]              )/min(zi.1.party[j], 4)
                endif

            ; Insert matrix computations for Summit here
            ;

            ;
              endif
          endjloop

          ; Output accumulated trips by mode

          report marginrec=y, file=airportmc.txt, print=n, form=10.4, 
              list=j(5),r1,r2,r3,r4,r5,r6,r7,r11,r12,r13,r14,r15,r16

          frequency basemw=10, valuemw=1, range=1-4-1, title='AuDrop trips by SEG'
          frequency basemw=10, valuemw=2, range=1-4-1, title='AuPark trips by SEG'
          frequency basemw=10, valuemw=3, range=1-4-1, title='Taxi trips by SEG'
          frequency basemw=10, valuemw=4, range=1-4-1, title='Van trips by SEG'
          frequency basemw=10, valuemw=5, range=1-4-1, title='TrWalk trips by SEG'
          frequency basemw=10, valuemw=6, range=1-4-1, title='TrDriv trips by SEG'
          frequency basemw=10, valuemw=7, range=1-4-1, title='TrDrop trips by SEG'

          log var=zones
          ;endif 
    endrun
    ;
    ;----------------------------------------------------------------------
    ; step 38
    RUN PGM=MATRIX  MSG='step 38 convert airport trips to matrix'
        ; Convert airport trips into trip matrix format

        zdati[1]=airportmc.txt, z=1-5,
            AuDrop=6-15,
            AuPark=16-25,
            Taxi  =26-35,
            Van   =36-45,
            TrWalk=46-55,
            TrDriv=56-65,
            TrDrop=66-75,
            APVTDA=76-85,
            APVTS2=86-95,
            APVTS3=96-105,
            DTVTDA=106-115,
            DTVTS2=116-125,
            DTVTS3=126-135

        zones=@matrix.zones@

        mato=trips.airport.mat, mo=1-13, dec=13*5, name=AuDrop,AuPark,Taxi,Van,TrWalk,TrDriv,TrDrop,
            APVTDA,APVTS2,APVTS3,DTVTDA,DTVTS2,DTVTS3

        jloop j=285
            mw[1] = zi.1.AuDrop[i]
            mw[2] = zi.1.AuPark[i]
            mw[3] = zi.1.Taxi[i]
            mw[4] = zi.1.Van[i]
            mw[5] = zi.1.TrWalk[i]
            mw[6] = zi.1.TrDriv[i]
            mw[7] = zi.1.TrDrop[i]
            mw[8]  = zi.1.APVTDA[i]
            mw[9]  = zi.1.APVTS2[i]
            mw[10] = zi.1.APVTS3[i]
            mw[11] = zi.1.DTVTDA[i]
            mw[12] = zi.1.DTVTS2[i]
            mw[13] = zi.1.DTVTS3[i]
        endjloop

    ENDRUN

    ;======================================================================
    ; Time of day factors updated Dec09 (jag):
    ;
    ;  Period   P->A    A->P
    ;  ------  ------  ------
    ;    A3     0.107   0.035
    ;    MD     0.165   0.178
    ;    P3     0.083   0.081
    ;    EV     0.145   0.206
    ;
    ;==============================================================================
    ;step 39
    RUN PGM=MATRIX  MSG='step 39 airport P&R'
        ;  DTW airport

        matvalcache = 400  ;should be >= Num of PNRs * 8

        mati[1]=exputil.tskim.mat     ;generalized costs
        mati[7]=trips.airport.mat

        zdati[1]=?_pnr.dbf, z=zone, sum=pnrcap
        ; sacmet: zdati[2]=pnrloads.txt,z=#1, pnrcum=#2, pnrfac=#3, sum=pnrcum

        mato[1] = pnrautopersik.airport.mat, mo=7-9, dec=3*4, name=ap1td,ap2td,ap3td

        array pnrzone = _zones   ;pnrzone only needs num of PNR zones
        array pnrload = _zones
        array pnrfac =  _zones
        array euk =     _zones
        array kjtrips=100,_zones   ;***first dimension must be >= number of P&Rs, or else fatal error***

        fillmw mw[1] = mi.1.1    ;auto gc

        ; Set up PNR capacity list array.
        ; (Elements are numbered 1 thru number of pnr lot zones)
        if (i = 1)
            npnr = 0
            loop jj=1,zones
                if (zi.1.pnrcap[jj] >= 1)
                    npnr = npnr + 1
                    pnrzone[npnr] = jj
                endif
            endloop
            ; p&r factor
            loop p=1,npnr
                k = pnrzone[p]
                pnrfac[k] = 1.0 ;*** or if constrained: max(0.13, min(1, zi.2.pnrfac[k], (1 - zi.2.pnrcum[k]/zi.1.pnrcap[k])/0.25))   ;offpeak
            endloop
        endif

        loop jj=1,zones
          apttr = mi.7.trdriv[jj]+mi.7.trdrop[jj]  ;airport TD PT
          ap1tr = mi.7.dtvtda[jj]                  ;airport TD VT DA
          ap2tr = mi.7.dtvts2[jj]                  ;airport TD VT S2
          ap3tr = mi.7.dtvts3[jj]                  ;airport TD VT S3
          loading = apttr
          if (!(i=jj) && loading>0)
            ; Accumulate denominator
            denom = 0
            loop p=1,npnr
                k = pnrzone[p]
                eu = mw[1][k] * matval(1,2,k,jj,0) * pnrfac[k]
                euk[k] = eu
                denom = denom + eu
            endloop

            ;split and accumulate auto-access person trips
            if (denom > 0)
                loop p=1,npnr
                    k = pnrzone[p]
                    share = euk[k]/denom
                    ap1load = ap1tr*share
                    ap2load = ap2tr*share
                    ap3load = ap3tr*share
                    aptload = apttr*share
                    mw[7][k] = mw[7][k] + ap1load
                    mw[8][k] = mw[8][k] + ap2load
                    mw[9][k] = mw[9][k] + ap3load
                    kjtrips[p][jj] = kjtrips[p][jj] + aptload
                endloop
            endif

          endif
        endloop

        if (i=_zones)  ;when done
            loop p = 1, npnr
                k = pnrzone[p]
                loop jj = 1, zones
                    tripsout5 = kjtrips[p][jj]
                    if (tripsout5 > 0.0001)
                        print file=pnrtranperskj.airport.txt, list=k(5), jj(5),
                          tripsout5(11.4)
                    endif
                endloop
            endloop
        endif

    endrun

    ;----------------------------------------------------------------------
    ;step 40
    RUN PGM=MATRIX  MSG='step 40 airport transittraips matrix'
        ; compile airport transit trips
        mati[1]=trips.airport.mat
        mati[2] = pnrtranperskj.airport.txt,pattern=IJM:V, fields=#1,2,0,3
        mato[1]=transittrips.airport.mat, mo=1-5
        mw[1] = mi.1.trwalk+mi.2.1
        mw[2] = 0
        mw[3] = 0
        mw[4] = 0
        mw[5] = 0
    endrun


    ;======================================================================

    *echo Begin comm veh model Iter @iter.i@>timelog.begincommveh.iter@iter.i@.txt

    ;======================================================================
    ;step 41
    RUN PGM=NETWORK  MSG='step 41'
        ; token run to get number of zones
        neti=?_base.net
        log var=_zones
    endrun

    ;======================================================================
    ;step 42
    RUN PGM=GENERATION  MSG='step 42Commercial vehicle trips model'

        ; Use number of zones in the highway network
        zones=@network._zones@

        ; Zonal trip generation input files

        zdati[1]=tazsumdata_15.txt, z=#1, tothh=2, empres=3, stugrd=4, stuhgh=5, stuuni=6,
        empedu=7, empfoo=8, empgov=9, empind=10, empmed=11, empofc=12, 
        empret=13, empsvc=14, empoth=15, emptot=16
          
        zdati[2]=.\?_ixxi.dbf

        empnr = zi.1.empedu+zi.1.empgov+zi.1.empofc+zi.1.empoth+zi.1.empsvc+zi.1.empmed+zi.1.empind

        ;  Commercial Vehicle trip generation rates revised according to Table 13 of Sacmet-2001 document    
        cv2x  = 1.23 * (0.25*zi.1.tothh + 0.68*(zi.1.empret+zi.1.empfoo) + 0.40*empnr)
        cv3x  = 0.90 * (0.003*zi.1.tothh + 0.057*(zi.1.empofc+zi.1.empmed+zi.1.empedu) + 0.110*(zi.1.empind+zi.1.empoth))


            p[1] = cv2x  + zi.2.c2xi
            p[2] = cv3x  + zi.2.c3xi

            a[1] = cv2x  + zi.2.c2ix
            a[2] = cv3x  + zi.2.c3ix
         

        phase=adjust

        a[1] = p[1][0] / a[1][0] * a[1]
        a[2] = p[2][0] / a[2][0] * a[2]

        pao = tripends.cv.dbf, dbf=1, form=20.3slr, 
          list = Z P[1] P[2] A[1] A[2]

        endphase

    endrun

    ;======================================================================
    ;step 43
    RUN PGM=DISTRIBUTION  MSG='step 43 airport commercial vehicle trip distribution'

        ; Trip distribution

        ZDATI[1] = tripends.cv.dbf
        perau='md5'
        MATI[1] = skim.auto.@perau@.1.mat  ; auto period md5

        MATO = "trips.cv.mat", MO=1-2, NAME=CV2X,CV3X, DEC=2*4

        LOOKUP  FAIL=999999,0,0  LIST=N, FILE=..\input\sacfftpp.txt, NAME=FF,
                LOOKUP[1]=1, RESULT=8,
                LOOKUP[2]=1, RESULT=9,
                INTERPOLATE=Y, SETUPPER=N

        MAXITERS=25 MAXRMSE=10

        SETPA  P[1]=ZI.1.P1 P[2]=ZI.1.P2
        SETPA  A[1]=ZI.1.A1 A[2]=ZI.1.A2

        ;  Combine terminal times with auto travel time
        mw[8]=mi.1.1 + 2

        jloop
            if (i<=30 && j<=30)   ; suppress "thru-trip"
                mw[8]=32767
            else
                mw[8]=mi.1.1+2
            endif
        endjloop

        gravity purpose=1, los=mw[8], ffactors=FF, losrange=1-200
        gravity purpose=2, los=mw[8], ffactors=FF, losrange=1-200

        FREQUENCY BASEMW=8,VALUEMW=1,RANGE=1-100-1,TITLE='CV 2-Axle TLF (minutes)'
        FREQUENCY BASEMW=8,VALUEMW=2,RANGE=1-100-1,TITLE='CV 3+Axle TLF (minutes)'

    ENDRUN

    ;======================================================================

    *echo Begin compile vehicle trips Iter @iter.i@>timelog.beginvehtrips.iter@iter.i@.txt


    ;======================================================================
    ;step 44
    RUN PGM=NETWORK  MSG='step 44'
        ; token run to get number of zones
        neti=.\?_base.net
        log var=_zones
    endrun

    ;======================================================================
    ;step 45
    RUN PGM=MATRIX MSG='step 45 Prepare thru trips'
        ; Convert thru trips
        filei mati[1]=.\?_thru.dbf, pattern=IJM:V, fields=i,j,0,auxx,c3xx    ;,fields=1-5,6-10,0,11-15,16-20

        fileo mato=trips.thru.mat, mo=1-2, name=auxx,c3xx

        zones=@network._zones@

        ; Thru trips (daily non-directional vehicle trips)
        mw[1] = mi.1.1   ;autos
        mw[2] = mi.1.2   ;comm veh

    endrun

    ;======================================================================
    ;step 46
    RUN PGM=MATRIX MSG='step 46 Compile auxiliary model vehicle trips'
        ; Compile auxiliary-model vehicle trips

        mati[1]=trips.thru.mat
        mati[2]=trips.airport.mat
        mati[3]=trips.external.mat
        mati[4]=trips.cv.mat
        mati[5]=pnrautopersik.airport.mat

        ; Time-of-day factors entered like a zdat file
        zdati[1]=..\input\todfactors.txt,z=#1,
        pb_pa=3,
        sh_pa=4,
        sr_pa=5,
        wk_pa=6,
        pb_ap=7,
        sh_ap=8,
        sr_ap=9,
        wk_ap=10,
        cv2=11,
        cv3=12,
        xxcv=13,
        xxau=14,
        ap_pa=15,
        ap_ap=16

        fileo mato[1]="veh.aux.h07.mat", mo=11-15, dec=5*4, name=DA,S2,S3,C2,C3,
              mato[2]="veh.aux.h08.mat", mo=16-20, dec=5*4, name=DA,S2,S3,C2,C3,
              mato[3]="veh.aux.h09.mat", mo=21-25, dec=5*4, name=DA,S2,S3,C2,C3,
              mato[4]="veh.aux.md5.mat", mo=26-30, dec=5*4, name=DA,S2,S3,C2,C3,
              mato[5]="veh.aux.h15.mat", mo=31-35, dec=5*4, name=DA,S2,S3,C2,C3,
              mato[6]="veh.aux.h16.mat", mo=36-40, dec=5*4, name=DA,S2,S3,C2,C3,
              mato[7]="veh.aux.h17.mat", mo=41-45, dec=5*4, name=DA,S2,S3,C2,C3,
              mato[8]="veh.aux.ev2.mat", mo=46-50, dec=5*4, name=DA,S2,S3,C2,C3,
              mato[9]="veh.aux.n11.mat", mo=51-55, dec=5*4, name=DA,S2,S3,C2,C3


        ; Thru trips (daily non-directional vehicle trips)
        mw[1] = (mi.1.auxx + mi.1.auxx.t)*0.5
        mw[2] = (mi.1.c3xx + mi.1.c3xx.t)*0.5


        ; Commercial Vehicles (daily non-directional vehicle trips)
        mw[3] = (mi.4.cv2x + mi.4.cv2x.t)*0.5
        mw[4] = (mi.4.cv3x + mi.4.cv3x.t)*0.5


        ; Airport vehicle trips
        mw[5] = mi.2.apvtda   + mi.5.ap1td
        mw[6] = mi.2.apvts2   + mi.5.ap2td/2
        mw[7] = mi.2.apvts3   + mi.5.ap3td/3.5
        mw[8] = mi.2.apvtda.t + mi.5.ap1td.t
        mw[9] = mi.2.apvts2.t + mi.5.ap2td.t/2
        mw[10]= mi.2.apvts3.t + mi.5.ap3td.t/3.5

        loop p=1,9

            jloop

                xwk = mi.3.xwk*zi.1.wk_pa[p] + mi.3.xwk.t*zi.1.wk_ap[p]
                xpb = mi.3.xpb*zi.1.pb_pa[p] + mi.3.xpb.t*zi.1.pb_ap[p]
                xsh = mi.3.xsh*zi.1.sh_pa[p] + mi.3.xsh.t*zi.1.sh_ap[p]
                xsr = mi.3.xsr*zi.1.sr_pa[p] + mi.3.xsr.t*zi.1.sr_ap[p]
                xx  = mw[1]   *zi.1.xxau[p]

                matp = 5 + p*5  ;10, 15, 20,...65
                ;              ext occ     ext occ    ext occ    ext occ        thru occ   airport
                mw[matp+1]  = (xwk*0.890 + xpb*0.54 + xsh*0.45 + xsr*0.29)     + xx*0.40 + mw[5] *zi.1.ap_pa[p] + mw[8] *zi.1.ap_ap[p]
                mw[matp+2]  = (xwk*0.085 + xpb*0.29 + xsh*0.40 + xsr*0.31)/2   + xx*0.35 + mw[6] *zi.1.ap_pa[p] + mw[9] *zi.1.ap_ap[p]
                mw[matp+3]  = (xwk*0.025 + xpb*0.17 + xsh*0.15 + xsr*0.40)/3.5 + xx*0.25 + mw[7] *zi.1.ap_pa[p] + mw[10]*zi.1.ap_ap[p]
                mw[matp+4]  = mw[3]*zi.1.cv2[p]
                mw[matp+5]  = mw[4]*zi.1.cv3[p]+mw[2]*zi.1.xxcv[p]

            endjloop
        endloop

    endrun

   ;----------------------------------------------------------------------
   ;----------------------------------------------------------------------
   if (iter.ssi <= 0) iter.ssi=1

   loop p=1,9
       if (p=01) per='h07'
       if (p=02) per='h08'
       if (p=03) per='h09'
       if (p=04) per='md5'
       if (p=05) per='h15'
       if (p=06) per='h16'
       if (p=07) per='h17'
       if (p=08) per='ev2'
       if (p=09) per='n11'


       
     *copy veh.avg.@per@.mat veh.avg.@per@.previous.mat

     ;step 47
     RUN PGM=MATRIX  MSG= 'step 47 create vehicle trips matrices' 
	  ; Update successive-average vehicle-trip matrices
	  
             mati[1] = autotrips.@per@.mat
             mati[2] = veh.aux.@per@.mat
             mati[3] = veh.avg.@per@.previous.mat
             
             mato[1] = veh.@per@.mat, mo=1-15 dec=15*4, 
                  name=da1,s21,s31,c21,c31 @tolls.code2@,
				   @tolls.code2@ da2, s22, s32, c22,c32 @tolls.code3@,
				   @tolls.code3@ da3, s23,s33,c23,c33
				   
				  

             mato[2] = veh.avg.@per@.mat, mo=41-55, dec=15*4, 
                  name=da1,s21,s31,c21,c31 @tolls.code2@,
				   @tolls.code2@ da2, s22, s32, c22,c32 @tolls.code3@,
				   @tolls.code3@ da3, s23,s33,c23,c33

			nfac = 1/@iter.ssi@
			ofac = 1 - nfac

			
             jloop
                 @tolls.code1@ mw[1] = mi.2.1 * 0.2 + mi.1.1
                 @tolls.code1@ mw[2] = mi.2.2 * 0.2 + mi.1.2
                 @tolls.code1@ mw[3] = mi.2.3 * 0.2 + mi.1.3
                 
                 @tolls.code2@ mw[6] = mi.2.1*0.6 + mi.1.4
                 @tolls.code2@ mw[7] = mi.2.2*0.6 + mi.1.5
                 @tolls.code2@ mw[8] = mi.2.3*0.6 + mi.1.6
                 
				  @tolls.code3@ mw[11] = mi.2.1*0.2 + mi.1.7
                 @tolls.code3@ mw[12] = mi.2.2*0.2 + mi.1.8
                 @tolls.code3@ mw[13] = mi.2.3*0.2 + mi.1.9
                 
                 
				  ; Distribute commercial vehicles into VOT classes
			if (@tolls.ntc@ = 3)    ;the other segmentations do not work
				   mw[4] =   mi.2.4 * 0.08
				   mw[9] =   mi.2.4 * 0.31
				   mw[14] = mi.2.4 * 0.61
				   mw[5] =   mi.2.5 * 0.07
				   mw[10] = mi.2.5 * 0.29
				   mw[15] = mi.2.5 * 0.64
			endif
       
     mw[60] = 0 ; placeholder
                 
               @tolls.code1@ mw[41] = (mi.3.01*ofac + mw[01]*nfac)*10000    ;Scale...
               @tolls.code1@ mw[42] = (mi.3.02*ofac + mw[02]*nfac)*10000   
               @tolls.code1@ mw[43] = (mi.3.03*ofac + mw[03]*nfac)*10000
               @tolls.code1@ mw[44] = (mi.3.04*ofac + mw[04]*nfac)*10000
               @tolls.code1@ mw[45] = (mi.3.05*ofac + mw[05]*nfac)*10000
               
               @tolls.code2@ mw[46] = (mi.3.06*ofac + mw[06]*nfac)*10000
               @tolls.code2@ mw[47] = (mi.3.07*ofac + mw[07]*nfac)*10000
               @tolls.code2@ mw[48] = (mi.3.08*ofac + mw[08]*nfac)*10000
               @tolls.code2@ mw[49] = (mi.3.09*ofac + mw[09]*nfac)*10000
               @tolls.code2@ mw[50] = (mi.3.10*ofac + mw[10]*nfac)*10000
               
				@tolls.code3@ mw[51] = (mi.3.11*ofac + mw[11]*nfac)*10000
               @tolls.code3@ mw[52] = (mi.3.12*ofac + mw[12]*nfac)*10000
               @tolls.code3@ mw[53] = (mi.3.13*ofac + mw[13]*nfac)*10000
               @tolls.code3@ mw[54] = (mi.3.14*ofac + mw[14]*nfac)*10000
               @tolls.code3@ mw[55] = (mi.3.15*ofac + mw[15]*nfac)*10000
       
		endjloop
             @tolls.code1@ m41 = rowfix(41)    ;...bucket-round...
             @tolls.code1@ m42 = rowfix(42)
             @tolls.code1@ m43 = rowfix(43)
             @tolls.code1@ m44 = rowfix(44)
             @tolls.code1@ m45 = rowfix(45)
             
             @tolls.code2@ m46 = rowfix(46)
             @tolls.code2@ m47 = rowfix(47)
             @tolls.code2@ m48 = rowfix(48)
             @tolls.code2@ m49 = rowfix(49)
             @tolls.code2@ m50 = rowfix(50)
			  
             @tolls.code3@ m51 = rowfix(51)
             @tolls.code3@ m52 = rowfix(52)
             @tolls.code3@ m53 = rowfix(53)
             @tolls.code3@ m54 = rowfix(54)
             @tolls.code3@ m55 = rowfix(55)
			  
             @tolls.code1@ m41 = rowfac(41,0.0001)   ;...and rescale for output.
             @tolls.code1@ m42 = rowfac(42,0.0001)   ;   - Corrects for rounding-up(?!)
             @tolls.code1@ m43 = rowfac(43,0.0001)
             @tolls.code1@ m44 = rowfac(44,0.0001)
             @tolls.code1@ m45 = rowfac(45,0.0001)
             
             @tolls.code2@ m46 = rowfac(46,0.0001)
             @tolls.code2@ m47 = rowfac(47,0.0001)
             @tolls.code2@ m48 = rowfac(48,0.0001)
             @tolls.code2@ m49 = rowfac(49,0.0001)
             @tolls.code2@ m50 = rowfac(50,0.0001)
			  
             @tolls.code3@ m51 = rowfac(51,0.0001)
             @tolls.code3@ m52 = rowfac(52,0.0001)
             @tolls.code3@ m53 = rowfac(53,0.0001)
             @tolls.code3@ m54 = rowfac(54,0.0001)
             @tolls.code3@ m55 = rowfac(55,0.0001)
                     
         endrun

   ;----------------------------------------------------------------------
   ; end of highway periods loop
   ENDLOOP

    ;======================================================================
    ;Assign period matrices to highway network
    ;
    *echo Begin highway assignments Iter @iter.i@>timelog.beginhwyassign.iter@iter.i@.txt

    ;======================================================================
    if (iter.ssi <= 0) iter.ssi=1 ;
    if (iter.i   <= 0) iter.i=1 ;

    ;======================================================================
	; Loop through all periods
	loop p=1,9
		
		if (p=01) per='h07'   ;better order for assignment in Cluster:
		if (p=02) per='h08'   ;group in threes taking similar run-times
		if (p=03) per='h09'
		if (p=04) per='md5'
		if (p=05) per='h15'
		if (p=06) per='h16'
		if (p=07) per='h17'
		if (p=08) per='ev2'
		if (p=09) per='n11'


		capfac = 1.0
		if (per='md5') capfac = 5.00
		if (per='ev2') capfac = 2.00
		if (per='n11') capfac = 5.30
		
		rampmeter = 999  ;if no metering, set to a value not in link data
		if (per='h07') rampmeter=1
		if (per='h08') rampmeter=1
		if (per='h09') rampmeter=1
		if (per='h15') rampmeter=2
		if (per='h16') rampmeter=2
		if (per='h17') rampmeter=2

	; Cluster    
		if (p=01) pid=1
		if (p=02) pid=2
		if (p=03) pid=3
		if (p=04) pid=1
		if (p=05) pid=2 
		if (p=06) pid=3 
		if (p=07) pid=1 
		if (p=08) pid=2 
		if (p=09) pid=3 

		*copy tollseg_length.csv tollseg_length.@per@.csv
	;----------------------------------------------------------------------
		
      ;step 48

      ;IFCLUSTER:

      DistributeMultiStep ProcessID='sacsimsub', ProcessNum=@pid@

	      ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	  ; creating the toll optimization loop

	_maxTollChange = 0
	change_thresh = 0.05 ; If toll doesnt change by more than this amount stop iterating -KS adjusted from 0.50 to 0.05

	loop toop = 1,5    ;toll_loop = toop
	
		if (toop=01) toll_loop='loop1'
		if (toop=02) toll_loop='loop2'
		if (toop=03) toll_loop='loop3'
		if (toop=04) toll_loop='loop4'
		if (toop=05) toll_loop='loop5'

	  
      RUN PGM=NETWORK  MSG='step 48 set prevvol and prevtime'
          ; Set up assignments input network with information from previous assignment
          neti=vo.@per@.net

          ; Previous volume and time
          prevvol  = v_1
          prevtime = time_1

          ;drop previous loading variables (need to add as many excludes as there are)
          neto=vi.@per@.net, exclude=v_1,time_1,vc_1,cspd_1,vdt_1,vht_1,vt_1,
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

      endrun
		  
		; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		;step 49
		RUN PGM=HIGHWAY  MSG='step 49 Vehicle trip assignment'
		; Vehicle trip assignnment

		NETI=vi.@per@.net               ; previous (in) increments loaded network
		MATI=veh.avg.@per@.mat         ; 'veh.avg' for successively-averaged matrices
		FILEO NETO=vo.@per@.net         ; output (new) loaded network

		CAPFAC = @capfac@
		METERCLASS=@rampmeter@
		COMBINE=EQUI,MAXITERS=300,RELATIVEGAP=@iter.relgap@,gap=0,raad=0,aad=0;rmse=0.01

        ;------ Note:  basic classes are 1-9, special classes are two-digit classes
        ;10/5/2018 - for AV testing, freeways increased +20%, all other arterials +10%
          SPDCAP CAPACITY[1]=2000,1000,850,800,700,1500,0,2000,1500                ;basic capacity classes 1-9 | SPDCAP CAPACITY[1]=2000,1000,850,800,700,1500,0,2000,1500
          SPDCAP CAPACITY[11]=0,1500,0,0,0,2000,0,0,0                              ;special classes:  12=hi-cap river crossing;16=hi-cap ramp | SPDCAP CAPACITY[11]=0,1500,0,0,0,2000,0,0,0
          SPDCAP CAPACITY[21]=0,1000,0,750,0,500,0,0,0                               ;special classes:  22=rural state hwy; 24=rural min art; 26=lo-cap ramp | SPDCAP CAPACITY[21]=0,1000,0,750,0,500,0,0,0
          SPDCAP CAPACITY[51]=2000,0,0,0,0,1500,0,0,0                               ;Auxiliary lane classes: 51 = Aux links >1 mile; 56 = Aux links <1 mile | SPDCAP CAPACITY[51]=2000,0,0,0,0,1500,0,0,0
          SPDCAP CAPACITY[62]=0,0                                                  ;special classes:  62=pnr dummy link; 63=centroid conn
          SPDCAP CAPACITY[99]=0

		; Scalar factors
		  C2PCE = 1.5
		  C3PCE = 2.0
		  HOV2Divisor = 1.00   ;cost divisors no longer needed since shared-ride trips put into higher VOT bins
		  HOV3Divisor = 1.00
		  CostPerMile = 0.17   ;from configuration file

		PHASE=LINKREAD                        ;define link groups
		  SPEED = li.speed
		  t0 = li.distance * 60 / CmpNumRetNum(li.speed,'=',0,1,li.speed)
		  t1 = li.prevtime
		  
		if (li.USECLASS == 0) ADDTOGROUP=1        ;GENERAL PURPOSE 
		if (li.USECLASS == 2) ADDTOGROUP=2        ;HOV2+
		if (li.USECLASS == 3) ADDTOGROUP=3        ;HOV3+
		if (li.USECLASS == 4) ADDTOGROUP=4        ;
		if (li.TOLLID > 0) ADDTOGROUP=5			 ;CV all periods		
		
		  if (li.speed = 0) 
			  ADDTOGROUP=1
			  ADDTOGROUP=2
			  ADDTOGROUP=3
			  ADDTOGROUP=4
			  ADDTOGROUP=5
		  endif
		  if (li.capclass = 99)
			  ADDTOGROUP=1
			  ADDTOGROUP=2
			  ADDTOGROUP=3
			  ADDTOGROUP=4
			  ADDTOGROUP=5			  
		  endif

        ;------ ramp meter flag
        IF (METERCLASS=1 & li.DELCURV=1)
			lw.RAMP=1
        ELSEIF (METERCLASS=2 & li.DELCURV=2)
			lw.RAMP=1
        ELSE
            lw.RAMP=0
        ENDIF

		  lw.AOCost = li.distance * CostPerMile

		if (iteration=0)
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

		endif

		ENDPHASE

		;------ path load
		PHASE=ILOOP

		  PATHLOAD PATH=lw.imped1_da EXCLUDEGRP=2,3   VOL[01]=mi.1.da1 

		  PATH=lw.imped1_c3 EXCLUDEGRP=5         VOL[02]=mi.1.c21 ,VOL[03]=mi.1.c31

			PATH=lw.imped1_s2 EXCLUDEGRP=3   					VOL[04]=mi.1.s21 
			
			PATH=lw.imped1_s3   												VOL[05]=mi.1.s31 

			PATH=lw.imped2_da EXCLUDEGRP=2,3   				VOL[06]=mi.1.da2  
		  PATH=lw.imped2_c3 EXCLUDEGRP=5         VOL[07]=mi.1.c22, VOL[08]=mi.1.c32

			PATH=lw.imped2_s2 EXCLUDEGRP=3   					VOL[09]=mi.1.s22  
			
			PATH=lw.imped2_s3 							   					VOL[10]=mi.1.s32
			
			PATH=lw.imped3_da EXCLUDEGRP=2,3   				VOL[11]=mi.1.da3   
		  PATH=lw.imped3_c3 EXCLUDEGRP=5         VOL[12]=mi.1.c23, VOL[13]=mi.1.c33

			PATH=lw.imped3_s2 EXCLUDEGRP=3   					VOL[14]=mi.1.s23  
			
			PATH=lw.imped3_s3 												VOL[15]=mi.1.s33
		  
		ENDPHASE

		PHASE=ADJUST  
		FUNCTION,
		;   Conical (2 - beta) - alpha(1-x) + 
		;           sqrt(alpha^2*(1-x)^2 + beta^2)
		;   where x = factor*v/c, 
		;         beta=(2*alpha-1)/(2*alpha-2)
		;   Unchanged, from Sacmet15
		
		  TC[1]=T0*min((0.9-6.0*(1-0.88*(V/C))+sqrt(36.0*(1-0.88*(V/C))*(1-0.88*(V/C))+1.21)),11.0+0.000708*(V/C))+lw.ramp*min((-0.03+sqrt(324.0*(1-1.8*(v/c))*(1-1.8*(v/c))+1.06)-18.0*(1-1.8*(v/c))),15)
		  
		  TC[2]=T0*min((0.939-9.16*(1-0.92*(V/C))+sqrt(83.9*(1- 0.92*(V/C))*(1-0.92*(V/C))+1.126)),11.0+0.000615*(V/C))+lw.ramp*min((-0.03+sqrt(324.0*(1-1.8*(v/c))*(1-1.8*(v/c))+1.06)-18.0*(1-1.8*(v/c))),15)
		  
		  TC[3]=T0*min((0.908-6.44*(1-0.89*(V/C))+sqrt(41.47*(1-0.89*(V/C))*(1-0.89*(V/C))+1.19)),7.0+0.000185*(V/C))+lw.ramp*min((-0.03+sqrt(324.0*(1-1.8*(v/c))*(1-1.8*(v/c))+1.06)-18.0*(1-1.8*(v/c))),15)

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


		; "Cost" function used in adjust and converge phases
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

	   run pgm=network    MSG='step xx optimize tolls'
		 neti=vo.@per@.net 
		
			; the input tolls file
			; format of tolls.csv is index(tollseg*100+per),tollseg,per,0,factype,adjust,tollda,tolls2,tolls3,tollcv
			
			FILEI LOOKUPI[1] = tolls.csv
			
			fileo printo[1] = nextToll.@per@.@toll_loop@.csv
			
			
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
		  		
		phase = linkmerge
		
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
  
	   
			if (TOLLID > 0)
				tseg_toll_time[TOLLID] = tseg_toll_time[TOLLID] + TIME_1
				
	            tseg_lastda[TOLLID] = tseg_lastda[TOLLID] + TOLLDA
                tseg_lasts2[TOLLID] =  tseg_lasts2[TOLLID] + TOLLS2
		        tseg_lasts3[TOLLID] = tseg_lasts3[TOLLID] + TOLLS3
		        tseg_lastcv[TOLLID] = tseg_lastcv[TOLLID] + TOLLCV
				
				if(VC_1 > tseg_maxvoc[TOLLID])
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
				endif
			endif
	 
			if (GPID > 0 )
				 tseg_gp_time[GPID] = tseg_gp_time[GPID] + TIME_1
			endif

		endphase
		
		
		phase = summary
		

			loop _segment=1,@network._numseg@

				fac_index = _segment*100+@p@
				
				adjust = tolls(3,fac_index)
				
				if(adjust==1)

					tseg_time_saved[_segment] = tseg_gp_time[_segment]  - tseg_toll_time[_segment] 
					tseg_vottoll[_segment] = tseg_time_saved[_segment]/60 * @avg_vot@ ; in dollars
			
					;***DA***
					
					minDA = tolls(8, fac_index)
					maxDA = tolls(12,fac_index)
					iniDA = tseg_lastda[_segment]
										
					if(maxDA>0)
					
					   if((iniDA > tseg_vottoll[_segment]) && (tseg_maxvoc[_segment] > @maxvoc_allowed@ ) )
						  nextTollDA = min((iniDA * @toll_incr@), maxDA)
					   else
						  nextTollDA = max(min(tseg_vottoll[_segment],maxDA),minDA)
					   endif
					else
					   nextTollDA = 0
					 endif
					 
					 avgTollDA = (tseg_lastda[_segment]+nextTollDA)/2
					 
					_maxTollChange = max(_maxTollChange,abs(iniDA - avgTollDA))
					
					;***S2***

					minS2 = tolls(9, fac_index)
					maxS2 = tolls(13,fac_index)
					iniS2 = tseg_lasts2[_segment]
					
					nextTollS2 = 0
					
					if(maxS2>0)
					
					   if((iniS2 > tseg_vottoll[_segment]) && (tseg_maxvoc[_segment] > @maxvoc_allowed@ ))
						  nextTollS2 = min((iniS2 * @toll_incr@), maxS2)
					   else
						  nextTollS2 = max(min(tseg_vottoll[_segment],maxS2),minS2)
						endif
					else
					  nextTollS2 = 0
					endif
					
					avgTollS2 = (tseg_lastS2[_segment]+nextTollS2)/2
					
					
					_maxTollChange = max(_maxTollChange,abs(iniS2 - avgTollS2))

					;***S3+***

					minS3 = tolls(10, fac_index)
					maxS3 = tolls(14,fac_index)
					iniS3 = tseg_lasts3[_segment]
					
					nextTollS3 = 0
					
					if(maxS3>0)
					
					   if((iniS3 > tseg_vottoll[_segment]) && (tseg_maxvoc[_segment] > @maxvoc_allowed@ ))
						  nextTollS3 = min((iniS3 * @toll_incr@), maxS3)
					   else
						  nextTollS3 = max(min(tseg_vottoll[_segment],maxS3),minS3)
						endif
					else
					  nextTollS3 = 0
					endif
					
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
					if((tseg_maxvoc[_segment] > @maxvoc_allowed@ ) && (maxCV>0)) 
					
					   if(iniCV > tseg_vottoll[_segment])
					      nextTollCV = iniCV * @toll_incr@
					   else
						  nextTollCV = max(min(tseg_vottoll[_segment],maxS3),minS3)
						endif
					else
					  nextTollCV = max(min(tseg_vottoll[_segment],maxCV),minCV)
					endif
					_maxTollChange = max(_maxTollChange,abs(iniCV - avgTollCV))
				
				endif
			   
							
				 PRINT CSV=T LIST=_segment, tseg_toll_time[_segment], tseg_gp_time[_segment],tseg_time_saved[_segment] , tseg_vottoll[_segment], tseg_maxvoc[_segment],avgTollDA,avgTollS2,avgTollS3,avgTollCV,_maxTollChange,
												da_low[_segment], cv2_low[_segment], cv3_low[_segment], s2_low[_segment], s3_low[_segment], da_med[_segment], cv2_med[_segment], 
												cv3_med[_segment], s2_med[_segment], s3_med[_segment], da_hi[_segment], cv2_hi[_segment], cv3_hi[_segment], s2_hi[_segment], s3_hi[_segment],total_vol[_segment]   PRINTO=1
						
			endloop
		 
		LOG VAR=_maxTollChange
	 
		endphase
		
    
		endrun
		
		
		; if the maximum toll change across any segment in this time period is less than the tollchange_threshold, stop running
		; assignments in this period and move to the next period
		
	    *echo @toll_loop@ @network._maxTollChange@ @change_thresh@ >> tollOptimizeConvergence.@per@.csv
		
	    if(network._maxTollChange <  change_thresh) 
		  break
		endif
		
		*copy nextToll.@per@.@toll_loop@.csv prev_toll.csv
		;=====================================================

		; reading new toll values into the network

		; format of nextToll.@per@.@toll_loop@.csv is   _segment, tseg_toll_time[_segment], tseg_gp_time[_segment],tseg_time_saved[_segment] , tseg_vottoll[_segment], tseg_maxvoc[_segment],avgTollDA,avgTollS2,avgTollS3,avgTollCV,_maxTollChange
		
		run pgm=network    MSG='step xx apportion new tolls to the links'
			 neti=vo.@per@.net 
			 neto=vo.@per@.out.net
			 
			FILEI LOOKUPI[1] = nextToll.@per@.@toll_loop@.csv
			FILEI LOOKUPI[2] = tollseg_length.@per@.csv
			
			loop _segment=1,@network._numseg@
			
			
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
			

			
			if (TOLLID>0)
			
			TOLLDA = nextToll(2,TOLLID)*DISTANCE/tollseg_length(2,TOLLID)
			TOLLS2 = nextToll(3,TOLLID)* DISTANCE/tollseg_length(2,TOLLID)
			TOLLS3 = nextToll(4,TOLLID)* DISTANCE/tollseg_length(2,TOLLID)
			TOLLCV = nextToll(5,TOLLID)* DISTANCE/tollseg_length(2,TOLLID)		

			endif
			
			endloop
		endrun
		
	*copy vo.@per@.out.net vo.@per@.net

	endloop

	;======================================================================
	;======================================================================
	; Cluster
     EndDistributeMultiStep

     if (pid=3)
         Wait4Files Files=sacsimsub1.script.end, 
                          sacsimsub2.script.end,
                          sacsimsub3.script.end, 
         CheckReturnCode=T,
         PrintFiles=Merge, 
         DelDistribFiles=T
     endif
    ; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ; end of highway periods loop
	endloop
	;======================================================================
	loop p=1,9
		if (p=01) per='h07'
		if (p=02) per='h08'
		if (p=03) per='h09'
		if (p=04) per='md5'
		if (p=05) per='h15'
		if (p=06) per='h16'
		if (p=07) per='h17'
		if (p=08) per='ev2'
		if (p=09) per='n11'
	
	
		;step 50
		RUN PGM=NETWORK  MSG='step 50 summary convergence monitoring'
			; Summarize vehicle-minutes statistics for convergence monitoring
	
			filei neti[1]=vo.@per@.net
	
			_VXTold = _VXTold + li.1.v_1 * li.1.prevtime
			_VXTnew = _VXTnew + li.1.v_1 * li.1.time_1
			_period = '@per@'
	
			; Maximum delta-vol and delta-time
			_delv = abs(li.1.v_1 - li.1.prevvol)
			_maxdelv = max(_maxdelv, _delv)
			if (li.1.v_1 + li.1.prevvol >= 1)
				_maxdelt = max(_maxdelt, abs(li.1.time_1 - li.1.prevtime))
			endif
	
			; RMS delta-vol (weighted)
			_SSq = _SSq + _delv*_delv
			; Calculate RMS by dividing by respective VXTnew
	
			phase=summary
				print file=convergencestats.txt, append=T, 
				list='@iter.i@'(4), '@iter.ssi@'(4), _period,
				_VXTold(12), _VXTnew(12),
				_maxdelv(12), _maxdelt(8.2), _SSq(12)
			endphase
		endrun
		; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; end of highway periods loop
	ENDLOOP
	
	;======================================================================
	; end of iteration loop of demand and assignment models at line 456
	
	*echo End Iter @iter.i@>timelog.endloop.iter@iter.i@.txt
	ENDLOOP
	;==============================================================================
	
	
	;==============================================================================
	;Transit assignment  - outside 7 iterration loop
	;=============================================================================
	RUN PGM=MATRIX MSG='create trip.dbf from Daysim trip table'
		FILEI RECI = _trip.tsv, delimiter[1]=' ,t'
		
		RECO[1]=?_trip.dbf, fields=tour_id(12),hhno(12),pno(2),day(2),tour(2),half(2),tseg(2),tsvid(2),opurp(2),dpurp(2),oadtyp(2),
									dadtyp(2),opcl(8),otaz(4),dpcl(8),dtaz(4),mode(2),pathtype(2),dorp(4),deptm(6.2),
									arrtm(6.2),endacttm(6.2),travtime(6.2),travcost(6.2),travdist(6.2),vot(6.2),trexpfac(4)
									
		array persons=27,27                              
		
		if (reci.recno=1)
			loop f=1, reci.numfields
				if (reci.cfield[f]='tour_id')       f_tour_id = f
				if (reci.cfield[f]='hhno')          f_hhno    = f
				if (reci.cfield[f]='pno')           f_pno     = f
				if (reci.cfield[f]='day')           f_day     = f
				if (reci.cfield[f]='tour')          f_tour    = f
				if (reci.cfield[f]='half')          f_half    = f
				if (reci.cfield[f]='tseg')          f_tseg    = f
				if (reci.cfield[f]='tsvid')         f_tsvid   = f
				if (reci.cfield[f]='opurp')         f_opurp   = f
				if (reci.cfield[f]='dpurp')         f_dpurp   = f
				if (reci.cfield[f]='oadtyp')        f_oadtyp  = f
				if (reci.cfield[f]='dadtyp')        f_dadtyp  = f
				if (reci.cfield[f]='opcl')          f_opcl    = f
				if (reci.cfield[f]='otaz')          f_otaz    = f
				if (reci.cfield[f]='dpcl')          f_dpcl    = f
				if (reci.cfield[f]='dtaz')          f_dtaz    = f
				if (reci.cfield[f]='mode')          f_mode    = f
				if (reci.cfield[f]='pathtype')      f_pathtype  = f
				if (reci.cfield[f]='dorp')          f_dorp    = f
				if (reci.cfield[f]='deptm')         f_deptm   = f
				if (reci.cfield[f]='arrtm')         f_arrtm   = f
				if (reci.cfield[f]='endacttm')      f_endacttm  = f
				if (reci.cfield[f]='travtime')      f_travtime  = f
				if (reci.cfield[f]='travcost')      f_travcost  = f
				if (reci.cfield[f]='travdist')      f_travdist  = f
				if (reci.cfield[f]='vot')           f_vot     = f
				if (reci.cfield[f]='trexpfac')      f_trexpfac  = f 
	
			endloop
		else
	
			ro.tour_id  = val(reci.cfield[f_tour_id])
			ro.hhno     = val(reci.cfield[f_hhno])
			ro.pno      = val(reci.cfield[f_pno])
			ro.day      = val(reci.cfield[f_day])
			ro.tour     = val(reci.cfield[f_tour])
			ro.half     = val(reci.cfield[f_half])
			ro.tseg     = val(reci.cfield[f_tseg])
			ro.tsvid    = val(reci.cfield[f_tsvid])
			ro.OPURP    = val(reci.cfield[f_opurp])
			ro.DPURP    = val(reci.cfield[f_dpurp])
			ro.oadtyp   = val(reci.cfield[f_oadtyp])
			ro.dadtyp   = val(reci.cfield[f_dadtyp])
			ro.opcl     = val(reci.cfield[f_opcl])
			ro.otaz     = val(reci.cfield[f_otaz])
			ro.dpcl     = val(reci.cfield[f_dpcl])
			ro.dtaz     = val(reci.cfield[f_dtaz])
			ro.mode     = val(reci.cfield[f_mode])
			ro.pathtype = val(reci.cfield[f_pathtype])
			ro.dorp     = val(reci.cfield[f_dorp])
			ro.DEPTM    = val(reci.cfield[f_deptm])
			ro.ARRTM    = val(reci.cfield[f_arrtm])
			ro.endacttm = val(reci.cfield[f_endacttm])      
			ro.travtime = val(reci.cfield[f_travtime])
			ro.travcost = val(reci.cfield[f_travcost])
			ro.TRAVDIST = val(reci.cfield[f_travdist])
			ro.vot      = val(reci.cfield[f_vot])
			ro.trexpfac   = val(reci.cfield[f_trexpfac])
					
			
			write reco=1
		ENDIF 
	
	ENDRUN
	
	;======================================================================
	run pgm=network
	
		neti=?_base.net
		log var=_zones
	endrun
	
	;======================================================================
	;sgao:step 58
	;transit trips by all households
	;===========================================================================
	run pgm=matrix MSG='create transit trip table by time period'
		; Process transit trips
	
		array seghr=5, tripseg=5
		seghr[ 1]= 5
		seghr[ 2]= 9
		seghr[ 3]= 15
		seghr[ 4]= 18
		seghr[ 5]= 20
	
		filei reci = ?_trip.dbf, sort=otaz
	
		fileo reco[1] = transittrips.am4.dbf, fields=id(8.0),otaz(5.0),dtaz(5.0),pathtype(3.0),am4(7.2)
		fileo reco[2] = transittrips.md6.dbf, fields=id(8.0),otaz(5.0),dtaz(5.0),pathtype(3.0),md6(7.2)
		fileo reco[3] = transittrips.pm3.dbf, fields=id(8.0),otaz(5.0),dtaz(5.0),pathtype(3.0),pm3(7.2)
		fileo reco[4] = transittrips.ev2.dbf, fields=id(8.0),otaz(5.0),dtaz(5.0),pathtype(3.0),ev2(7.2)
		fileo reco[5] = transittrips.ni9.dbf, fields=id(8.0),otaz(5.0),dtaz(5.0),pathtype(3.0),ni9(7.2)
		fileo reco[6] = transittrips.all.dbf, fields=tour_id(8.0),otaz(5.0),dtaz(5.0),pathtype(3.0),all(7.2)
		
	
		if (ri.mode=6 && ri.trexpfac>0)      ; Transit
			trips = ri.trexpfac
			
			pathtype = ri.pathtype
			if (ri.pathtype=0)
				pathtype=1
			endif
	
		; Segment the trip to time periods by arrive time for the trips in the first half tour and departure time for trips in the second half tour
			arrhr = ri.arrtm/60
			dephr = ri.deptm/60
			IF (ri.half=1)  ; first half tour
			useTM = arrhr
			ELSE
			useTM = dephr
			ENDIF
			
			ro.am4=0
			ro.md6=0
			ro.pm3=0
			ro.ev2=0
			ro.ni9=0
			ro.all=0
			
			IF (useTM >= 5 && useTM < 9)
				;ro.am4 = trips
				ro.all=1
			ELSEIF (useTM >=9 && useTM < 15)
				;ro.md6 = trips
				ro.all=2
			ELSEIF (useTM >=15 && useTM < 18)
				;ro.pm3 = trips
				ro.all=3
			ELSEIF (useTM >= 18 && useTM < 20)
				;ro.ev2 = trips
				ro.all=4
		ELSEIF (useTM >= 20)
				;ro.ni9 = trips
				ro.all=5
		ELSEIF (useTM >= 0 && useTM < 5)
				;ro.ni9 = trips
				ro.all=5
		ENDIF
		
		IF (ri.half=1 && useTM < 15 && ri.pathtype=5 && ri.dpurp=1)
			;ro.am4 = trips
			ro.all=1   
		ENDIF
		
		IF (ri.half=2 && useTM >= 15 && useTM <= 24 && ri.pathtype=5 && ri.opurp=1)
			;ro.pm3 = trips
			ro.all=3   
		ENDIF
		
		IF (ro.all=1) ro.am4=trips
		IF (ro.all=2) ro.md6=trips
		IF (ro.all=3) ro.pm3=trips
		IF (ro.all=4) ro.ev2=trips
		IF (ro.all=5) ro.ni9=trips
			
								
		; Select records
			if (ro.am4 > 0) write reco= 1
			if (ro.md6 > 0) write reco= 2
			if (ro.pm3 > 0) write reco= 3
			if (ro.ev2 > 0) write reco= 4
			if (ro.ni9 > 0) write reco= 5
			write reco=6
		ENDIF
	ENDRUN
	
	;----------------------------------------------------------------------------
	;sgao:step 59
	
	run pgm=matrix MSG='create airport transit trip matrix by time period'
		; split airport transit trips to times of day for assignment
		; - simple method: prorate among periods served by transit, 
		;   in proportion to same factors used for auto trips (added 2/2014 jag)
		mati[1]=skim.tran.am4.mat
		mati[2]=skim.tran.md6.mat
		mati[3]=skim.tran.pm3.mat
		mati[4]=skim.tran.ev2.mat
		mati[5]=skim.tran.ni9.mat
		mati[6]=transittrips.airport.mat
	
		zdati[1]=..\input\todfactors.txt,z=#1,
		ap_pa=15,
		ap_ap=16
	
		mato=transittrips.airportod.mat,
		mo=4-8, name=am4,md6,pm3,ev2,ni9 dec=5*3
	
		if (i=1)
		; Combine pa and ap factors from 9 periods into the 5 used in transit
		; p->a
			pa_am4 = zi.1.ap_pa[1] + zi.1.ap_pa[2] + zi.1.ap_pa[3]   ;a1-a3
			pa_md6 = zi.1.ap_pa[4]   ;md4
			pa_pm3 = zi.1.ap_pa[5] + zi.1.ap_pa[6] + zi.1.ap_pa[7]  
			pa_ev2 = zi.1.ap_pa[8]                                  ;ev2
			pa_ni9 = zi.1.ap_pa[9]                  ;ni9 h05
	
		; a->p
			ap_am4 = zi.1.ap_ap[1] + zi.1.ap_ap[2] + zi.1.ap_ap[3]
			ap_md6 = zi.1.ap_ap[4]
			ap_pm3 = zi.1.ap_ap[5] + zi.1.ap_ap[6] + zi.1.ap_ap[7]
			ap_ev2 = zi.1.ap_ap[8]
			ap_ni9 = zi.1.ap_ap[9]
	
			patot = pa_am4 + pa_md6 + pa_pm3 + pa_ev2 + pa_ni9
			aptot = ap_am4 + ap_md6 + ap_pm3 + ap_ev2 + ap_ni9
			grtot = patot + aptot
		endif
	
		; Transit trips (all in the local-service class)
		mw[1] = mi.6.1
		mw[2] = mi.6.1.t
		mw[3] = mw[1]+mw[2]
	
		jloop
			if (mw[3] > 0)    ;If trips in either direction (should be to or from zone 285 only)
	
				if (mi.1.1 = 0.01-300)
				patotav = pa_am4
				aptotav = ap_am4
				else
				patotav = 0
				aptotav = 0
				endif
				if (mi.2.1 = 0.01-300)
				patotav = patotav + pa_md6
				aptotav = aptotav + ap_md6
				endif
				if (mi.3.1 = 0.01-300)
				patotav = patotav + pa_pm3
				aptotav = aptotav + ap_pm3
				endif
				if (mi.4.1 = 0.01-300)
				patotav = patotav + pa_ev2
				aptotav = aptotav + ap_ev2
				endif
				
				if (mi.5.1 = 0.01-300)
				patotav = patotav + pa_ni9
				aptotav = aptotav + ap_ni9
				ENDIF
				
	
				if (patotav > 0)
				pafac = mw[1] * patot / (patotav * grtot)
				else
				pafac = 0
				endif
				
				if (aptotav > 0)
				apfac = mw[2] * aptot / (aptotav * grtot)
				else
				apfac = 0
				endif
	
				mw[4] = pa_am4 * pafac  + ap_am4 * apfac  
				mw[5] = pa_md6 * pafac  + ap_md6 * apfac
				mw[6] = pa_pm3 * pafac  + ap_pm3 * apfac
				mw[7] = pa_ev2 * pafac  + ap_ev2 * apfac
				mw[8] = pa_ni9 * pafac  + ap_ni9 * apfac
	
			endif
		endjloop
	ENDRUN
	
	;----------------------------------------------------------------------
	
	run pgm=network
		; token run to get number of zones
		neti=?_base.net
		log var=_zones
	ENDRUN
	
	;
	loop p=1,5
		if (p=01) per='am4'
		if (p=02) per='md6'
		if (p=03) per='pm3'
		if (p=04) per='ev2'
		if (p=05) per='ni9'
	
		;sgao:step 60
		
		run pgm=matrix   MSG='combine regular transit trips and airport transit trips'
	
			mati[1]=transittrips.@per@.dbf, fields=otaz,dtaz,pathtype,@per@, pattern=ijm:v
			mati[2]=transittrips.airportod.mat
			mato[1]=transittrips.@per@.mat, mo=1-4, dec=4*2, name=allpath,loc,lrt,prem
	
			mw[01] = mi.1.1 + mi.2.@per@
			mw[02] = mi.1.3
			mw[03] = mi.1.4
			mw[04] = mi.1.5
		ENDRUN
	endloop
	
	
	;======================================================================
	*echo Begin transit assignment>timelog.begintranasn.txt
	
	;======================================================================
	
	;sgao:step 61
	
	run pgm=network msg='Transit background network prep 1'
		; generate reverse of one-way links
		neti[1]=?_base.net
	
		fftime=li.1.distance*20 ;or more likely,
		if (li.1.speed>0) fftime=li.1.distance*60/li.1.speed
	
		linko=templink.dbf, format=DBF, include=a,b,distance,fftime,capclass
	
		log var=_zones
	endrun
	
	;----------------------------------------------------------------------
	;sgao:step 62
	
	run pgm=network  msg='Transit background network prep 2'
		; Insert transit-only links into copy of highway network, making full transit background network
		neti[1]=vo.h07.net   ; 7-8 am  Auto skim
		neti[2]=vo.md5.net
		neti[3]=vo.h15.net    ; 3-4 pm Auto skim
		neti[4]=vo.ev2.net
		neti[5]=vo.n11.net
	
	
		linki[7]='?_transit_links.csv',
			var=A,B,Distance,Speed,REV,Mode,Or_ToMode    ;,Name
		linki[8]='?_station_links.csv',
			var=A,B,distance,
			rev=2
		linki[9]=templink.dbf,
			rename=A-temp, B-A, temp-B
		linki[10]=?_pnr.dbf,rename=zone-A, sta_node-B, rev=2     ;build zone to P&R short links
		merge record=true
	
		am4time = li.1.time_1
		md6time = li.2.time_1
		pm3time = li.3.time_1
		ev2time = li.4.time_1
		ni9time = li.5.time_1
	
		if (am4time=0) am4time=li.9.fftime*1.2     ;1.2 in sacsim15
		if (md6time=0) md6time=li.9.fftime*1.1     ;1.1 in sacsim15
		if (pm3time=0) pm3time=li.9.fftime*1.2     ;1.2 in sacsim15
		if (ev2time=0) ev2time=li.9.fftime*1.05    ;1.1 in sacsim15
		if (ni9time=0) ni9time=li.9.fftime         ;free flow time
	
		distance=li.1.distance
		if (li.7.distance>0) distance=li.7.distance
		if (li.8.distance>0) distance=li.8.distance
		if (distance=0) distance=li.9.distance
		if (li.10.pnrcap > 0)
			if (distance=0 || distance>0.10) distance = 0.10
		endif
	
		if (distance=0) 
			_dx=b.x-a.x
			_dy=b.y-a.y
			distance=sqrt(_dx*_dx + _dy*_dy)/5280
		endif
	
		; 15 mph if time still empty
		if (am4time = 0 || am4time >= 999) am4time = distance*4
		if (md6time = 0 || md6time >= 999) md6time = distance*4
		if (pm3time = 0 || pm3time >= 999) pm3time = distance*4
		if (ev2time = 0 || ev2time >= 999) ev2time = distance*4
		if (ni9time = 0 || ni9time >= 999) ni9time = distance*4
	
		if (li.7.speed>0)
			am4time=distance*60/li.7.speed
			md6time=distance*60/li.7.speed
			pm3time=distance*60/li.7.speed
			ev2time=distance*60/li.7.speed
			ni9time=distance*60/li.7.speed
		endif
	
		mode=li.7.mode
		or_tomode=li.7.or_tomode
	
		neto=transitbackground.net, exclude=prevtime,prevvol,v_1,time_1,vc_1,cspd_1,vhd_1,
									vht_1,v1_1,v2_1,v3_1,vt_1,v1t_1,v2t_1,v3t_1
	endrun
	
	
	;*cluster sacsimsub 1,2,3,4 starthide exit
	;----------------------------------------------------------------------
	loop p=1,6
		if (p=1) trper='am4'
		if (p=2) trper='md6'
		if (p=3) trper='pm3'
		if (p=4) trper='ev2'
		if (p=5) trper='ni9'
	
		if (p=1) pid=1
		if (p=2) pid=2
		if (p=3) pid=3
		if (p=4) pid=1
		if (p=5) pid=2
		if (p=6) pid=3  ; dummy 
	
	
	;IFCLUSTER:
	DistributeMultiStep ProcessID='sacsimsub', ProcessNum=@pid@
	
		;==========================================================================
		;sgao:step 63
	
		IF (p = 1-5)
			run pgm=public transport msg='transit assignment'
				; transit assignment
				; general and submodes one run
	
				;Input Files  
				FILEI SYSTEMI    = ..\input\PTsystem.txt
				FILEI FACTORI[1] = ..\input\PTfactor.onlyloc.txt,
					FACTORI[2] = ..\input\PTfactor.mustlrt.txt,
					FACTORI[3] = ..\input\PTfactor.mustcom.txt,
					FACTORI[4] = ..\input\PTfactor.txt
				FILEI LINEI[1]   = ?_tranline.txt
				FILEI FAREI      = ..\input\PTfare.txt
				FILEI NETI       = transitbackground.net
	
				mati[1] = transittrips.@trper@.mat
	
				;Output files
				FILEO REPORTO = trans.load.@trper@.prn
				FILEO NETO = trans.load.@trper@.net 
				fileo lineo = lineload.@trper@.txt
				fileo linko = trans.link.@trper@.dbf, onoffs=Y,BYCLASS=Y
	
				FILEO routeo[1] = tran@trper@.rte, REPORTI=691 REPORTJ=807
				FILEO routeo[2] = tran@trper@.rte, REPORTI=691 REPORTJ=807
				FILEO routeo[3] = tran@trper@.rte, REPORTI=691 REPORTJ=807
				FILEO routeo[4] = tran@trper@.rte, REPORTI=691 REPORTJ=807
	
				;Globals
				PARAMETERS TRANTIME = (li.@trper@time)
					HDWAYPERIOD = @p@
					FARE=T
				parameters tripsij[1]=mi.1.loc,
	
						tripsij[2]=mi.1.lrt,
	
						tripsij[3]=mi.1.prem,
	
						tripsij[4]=mi.1.allpath
	
				;parameters NOROUTEERRS=1000, NOROUTEMSGS=10
				parameters NOROUTEERRS=10000, NOROUTEMSGS=10000  ;****TEMP high tolerance until P&R zone fixed in Daysim***
	
				REPORT LINES=T, SORT=name, LINEVOLS=T, STOPSONLY=T, SKIP0=T,USERCLASSES=4
	
				PHASE=DATAPREP
	
					;;;;GENERATE READNTLEGI=1
					;;;;;(xfer non-transit legs are input)
	
					;generate access/egress links
					GENERATE,
					fromnode=31-1999, tonode=2000-20000,
					COST=li.distance*20,   ;*60 / 3mph
					MAXCOST[1]=10*30.,   ;(minutes)
					;SLACK[1]=10*5.,
					NTLEGMODE=13,
					ONEWAY=F,
					DIRECTION=3,
					MAXNTLEGS=10*5,
					EXCLUDELINK = ((li.capclass-(10.0*int(li.capclass*0.1))) = 1,6,8,9)
	
					; bus-to-bus transfer access
					GENERATE,
					fromnode=2000-20000, tonode=2000-20000,
					COST=li.distance*20,   ;*60 / 3mph
					MAXCOST[1]=10*10.,   ;(minutes)
					;SLACK[1]=10*5.,
					NTLEGMODE=12,   ;temporary; may create another mode
					ONEWAY=F,
					DIRECTION=3,
					MAXNTLEGS=10*3,
					EXCLUDELINK = ((li.capclass-(10.0*int(li.capclass*0.1))) = 1,6,8,9)
	
				ENDPHASE
	
			ENDRUN
	
		ENDIF
	
		;======================================================================
		; Cluster: End of parallel threads
		EndDistributeMultiStep
		if (p=3)  ; p not p
			Wait4Files Files=sacsimsub1.script.end, 
							sacsimsub2.script.end,
							sacsimsub3.script.end, 
			CheckReturnCode=T,
			PrintFiles=Merge, 
			DelDistribFiles=T
		elseif (p=5)
			Wait4Files Files=sacsimsub1.script.end, 
							sacsimsub2.script.end,
							
			CheckReturnCode=T,
			PrintFiles=Merge, 
			DelDistribFiles=T
		endif
	
	
	; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; end of Transit periods loop
	endloop
	; end of transit assignment
	
	;************************************
	;  TRANSIT ROLL-UP SUMMARIES
	;************************************
	
	;************************************
	;  TRANSIT ROLL-UP SUMMARIES
	;************************************
	
	;step 41
		RUN PGM=NETWORK  MSG='step 41'
			; token run to get number of zones
			neti=?_base.net
			log var=_zones
		ENDRUN
	
	
	run pgm=matrix msg='transit roll-up'
	; Combine transit loading files from periods into one file
	
		dbi[1] = trans.link.am4.dbf, sort=name,linkseq
		dbi[2] = trans.link.md6.dbf, sort=name,linkseq
		dbi[3] = trans.link.pm3.dbf, sort=name,linkseq
		dbi[4] = trans.link.ev2.dbf, sort=name,linkseq
		dbi[5] = trans.link.ni9.dbf, sort=name,linkseq
	
	
		fileo reco[1] = trans.link.all.dbf, fields=
		period,A(6),B(6),MODE(2),OPERATOR,NAME,LONGNAME,SHORTNAME(c4),LINECODE(4), DIST,TIME,LINKSEQ(6),HEADWAY,STOPA(2),STOPB(2),
		VOL,ONA,OFFA,ONB,OFFB,REV_VOL,REV_ONA,REV_OFFA,REV_ONB,REV_OFFB
	
		;fileo reco[2] = trans.link.lines.dbf, fields=
		;period,A(6),B(6),MODE(2),OPERATOR,NAME,LONGNAME,SHORTNAME(c4),LINECODE(4), DIST,TIME,LINKSEQ(6),HEADWAY,STOPA(2),STOPB(2),
		;VOL,ONA,OFFA,ONB,OFFB,REV_VOL,REV_ONA,REV_OFFA,REV_ONB,REV_OFFB
	
	
		parameters zones=1
	
		maxnode = 0
	
		LOOP k=1,dbi.1.NUMRECORDS
		_Read1=DBIReadRecord(1,k)
			ro.period = 'AM4'
			ro.A = di.1.A
			ro.B = di.1.B
			ro.MODE = di.1.MODE
			ro.OPERATOR = di.1.OPERATOR
			ro.NAME = di.1.NAME
			ro.LONGNAME = di.1.LONGNAME
			ro.DIST = di.1.DIST
			ro.TIME = di.1.TIME
			ro.LINKSEQ = di.1.LINKSEQ
			ro.HEADWAY = di.1.HEADWAY_1
			ro.STOPA = di.1.STOPA
			ro.STOPB = di.1.STOPB
			ro.VOL = di.1.VOL
			ro.ONA = di.1.ONA
			ro.OFFA = di.1.OFFA
			ro.ONB = di.1.ONB
			ro.OFFB = di.1.OFFB
			ro.REV_VOL = di.1.REV_VOL
			ro.REV_ONA = di.1.REV_ONA
			ro.REV_OFFA = di.1.REV_OFFA
			ro.REV_ONB = di.1.REV_ONB
			ro.REV_OFFB = di.1.REV_OFFB
		write reco=1
		maxnode = max(maxnode, di.1.A, di.1.B)
		ENDLOOP
	
		LOOP k=1,dbi.2.NUMRECORDS
		_Read1=DBIReadRecord(2,k)
			ro.period = 'MD6'
			ro.A = di.2.A
			ro.B = di.2.B
			ro.MODE = di.2.MODE
			ro.OPERATOR = di.2.OPERATOR
			ro.NAME = di.2.NAME
			ro.LONGNAME = di.2.LONGNAME
			ro.DIST = di.2.DIST
			ro.TIME = di.2.TIME
			ro.LINKSEQ = di.2.LINKSEQ
			ro.HEADWAY = di.2.HEADWAY_2
			ro.STOPA = di.2.STOPA
			ro.STOPB = di.2.STOPB
			ro.VOL = di.2.VOL
			ro.ONA = di.2.ONA
			ro.OFFA = di.2.OFFA
			ro.ONB = di.2.ONB
			ro.OFFB = di.2.OFFB
			ro.REV_VOL = di.2.REV_VOL
			ro.REV_ONA = di.2.REV_ONA
			ro.REV_OFFA = di.2.REV_OFFA
			ro.REV_ONB = di.2.REV_ONB
			ro.REV_OFFB = di.2.REV_OFFB
		write reco=1
		maxnode = max(maxnode, di.2.A, di.2.B)
		ENDLOOP
	
		LOOP k=1,dbi.3.NUMRECORDS
		_Read1=DBIReadRecord(3,k)
			ro.period = 'PM3'
			ro.A = di.3.A
			ro.B = di.3.B
			ro.MODE = di.3.MODE
			ro.OPERATOR = di.3.OPERATOR
			ro.NAME = di.3.NAME
			ro.LONGNAME = di.3.LONGNAME
			ro.DIST = di.3.DIST
			ro.TIME = di.3.TIME
			ro.LINKSEQ = di.3.LINKSEQ
			ro.HEADWAY = di.3.HEADWAY_3
			ro.STOPA = di.3.STOPA
			ro.STOPB = di.3.STOPB
			ro.VOL = di.3.VOL
			ro.ONA = di.3.ONA
			ro.OFFA = di.3.OFFA
			ro.ONB = di.3.ONB
			ro.OFFB = di.3.OFFB
			ro.REV_VOL = di.3.REV_VOL
			ro.REV_ONA = di.3.REV_ONA
			ro.REV_OFFA = di.3.REV_OFFA
			ro.REV_ONB = di.3.REV_ONB
			ro.REV_OFFB = di.3.REV_OFFB
		write reco=1
		maxnode = max(maxnode, di.3.A, di.3.B)
		ENDLOOP
	
		LOOP k=1,dbi.4.NUMRECORDS
		_Read1=DBIReadRecord(4,k)
			ro.period = 'EV2'
			ro.A = di.4.A
			ro.B = di.4.B
			ro.MODE = di.4.MODE
			ro.OPERATOR = di.4.OPERATOR
			ro.NAME = di.4.NAME
			ro.LONGNAME = di.4.LONGNAME
			ro.DIST = di.4.DIST
			ro.TIME = di.4.TIME
			ro.LINKSEQ = di.4.LINKSEQ
			ro.HEADWAY = di.4.HEADWAY_4
			ro.STOPA = di.4.STOPA
			ro.STOPB = di.4.STOPB
			ro.VOL = di.4.VOL
			ro.ONA = di.4.ONA
			ro.OFFA = di.4.OFFA
			ro.ONB = di.4.ONB
			ro.OFFB = di.4.OFFB
			ro.REV_VOL = di.4.REV_VOL
			ro.REV_ONA = di.4.REV_ONA
			ro.REV_OFFA = di.4.REV_OFFA
			ro.REV_ONB = di.4.REV_ONB
			ro.REV_OFFB = di.4.REV_OFFB
		write reco=1
	
		maxnode = max(maxnode, di.4.A, di.4.B)
		ENDLOOP
	
		LOOP k=1,dbi.5.NUMRECORDS
		_Read1=DBIReadRecord(5,k)
			ro.period = 'NI9'
			ro.A = di.5.A
			ro.B = di.5.B
			ro.MODE = di.5.MODE
			ro.OPERATOR = di.5.OPERATOR
			ro.NAME = di.5.NAME
			ro.LONGNAME = di.5.LONGNAME
			ro.DIST = di.5.DIST
			ro.TIME = di.5.TIME
			ro.LINKSEQ = di.5.LINKSEQ
			ro.HEADWAY = di.5.HEADWAY_5
			ro.STOPA = di.5.STOPA
			ro.STOPB = di.5.STOPB
			ro.VOL = di.5.VOL
			ro.ONA = di.5.ONA
			ro.OFFA = di.5.OFFA
			ro.ONB = di.5.ONB
			ro.OFFB = di.5.OFFB
			ro.REV_VOL = di.5.REV_VOL
			ro.REV_ONA = di.5.REV_ONA
			ro.REV_OFFA = di.5.REV_OFFA
			ro.REV_ONB = di.5.REV_ONB
			ro.REV_OFFB = di.5.REV_OFFB
		write reco=1
	
		maxnode = max(maxnode, di.5.A, di.5.B)
		ENDLOOP
	
		log var=maxnode
	
	endrun
	
	
	;----------------------------------------------------------------------
	;sgao:step 66
	
	run pgm=matrix
		; Summary by line & LRT station
	
		reci = trans.link.all.dbf, sort=name, linkseq, period
	
		reco[1] = line_summary.dbf, fields=name(c12), mode(4), operator(4), revenuhrs(8.2), 
			board_day, board_am, board_md, board_pm, board_ev, board_ni,
			peakload, pkloadper(2), personmin, personmil
	
		array n_ons=@matrix.maxnode@, n_offs=@matrix.maxnode@, n_lrt=@matrix.maxnode@
		array n_acc=@matrix.maxnode@, n_egr=@matrix.maxnode@, n_bd_busx=@matrix.maxnode@, n_al_busx=@matrix.maxnode@
	
		zones=1
	
		array _boardings=5
	
		; duration of periods (hours)
		array duration=5
		duration[1] = 4
		duration[2] = 6
		duration[3] = 3
		duration[4] = 2
		duration[5] = 9  ; the rest of the hours or ???
	
		_recno = _recno + 1
		if (_recno <= 1) _name = ''   ;initialize to empty string
	
		if (ri.period = 'AM4') per = 1
		if (ri.period = 'MD6') per = 2
		if (ri.period = 'PM3') per = 3
		if (ri.period = 'EV2') per = 4
		if (ri.period = 'NI9') per = 5
	
	
		if (ri.mode=1-4)
			;if (_name = leftstr(ri.name,4))
			if (_name = ri.name)
				; continue accumulations
				_boardings[per] = _boardings[per] + ri.ona
				_personmin = _personmin + ri.vol*ri.time
				_personmil = _personmil + ri.vol*ri.dist
				if (ri.headway > 0) _revenuhrs = _revenuhrs + ri.time / ri.headway * duration[per]
				currpeakload = ri.vol / duration[per] * ri.headway/60
				if (currpeakload > _peakload)
					_peakload = currpeakload
					_pkloadper = per
				endif
			else
					if (strlen(_name) > 0)
						; flush record
							ro.name       = _name
							ro.mode       = _mode
							ro.operator   = _operator
							ro.board_day  = arraysum(_boardings)
							ro.board_am   = _boardings[1]
							ro.board_md   = _boardings[2]
							ro.board_pm   = _boardings[3]
							ro.board_ev   = _boardings[4]
							ro.board_ni   = _boardings[5]
							ro.personmin  = _personmin
							ro.personmil  = _personmil
							ro.revenuhrs  = _revenuhrs
							ro.peakload   = _peakload
							ro.pkloadper  = _pkloadper
							write reco=1
					endif
			; begin accumulations
				_name       = ri.name
				_mode       = ri.mode
				_operator   = ri.operator
				_boardings  = 0  ;initialize all elements
				_boardings[per] = ri.ona
				_personmin  = ri.vol*ri.time
				_personmil  = ri.vol*ri.dist
				if (ri.headway > 0)
					_revenuhrs  = ri.time / ri.headway * duration[per]
				else
					_revenuhrs = 0
				endif
				_peakload   = ri.vol / duration[per] * ri.headway/60
				_pkloadper  = per
			endif
	
		;node accumulations
		n_ons[ri.A]  = n_ons[ri.A]  + ri.ona
		n_offs[ri.B] = n_offs[ri.B] + ri.offb
		if (ri.mode = 1)   ;Flag LRT stations
			n_lrt[ri.A] = 1
			n_lrt[ri.B] = 1
		endif
	
		elseif (ri.mode=12)   ;accumulate bus transfer link volumes nodes
		n_al_busx[ri.A] = n_al_busx[ri.A] + ri.vol
		n_bd_busx[ri.B] = n_bd_busx[ri.B] + ri.vol
	
		elseif (ri.mode=13)   ;accumulate non-transfer boards and alights to nodes
		if (ri.A > @network._zones@) n_egr[ri.A] = n_egr[ri.A] + ri.vol
		if (ri.B > @network._zones@) n_acc[ri.B] = n_acc[ri.B] + ri.vol
		endif
	
		if (i=0)  ;end of file
			;flush last record
					ro.name       = _name
					ro.mode       = _mode
					ro.operator   = _operator
					ro.board_day  = arraysum(_boardings)
					ro.board_am4   = _boardings[1]
					ro.board_md6   = _boardings[2]
					ro.board_pm3   = _boardings[3]
					ro.board_ev2   = _boardings[4]
					ro.board_ni9   = _boardings[5]
					ro.personmin  = _personmin
					ro.personmil  = _personmil
					ro.revenuhrs  = _revenuhrs
					ro.peakload   = _peakload
					ro.pkloadper  = _pkloadper
					write reco=1
				
			;output station summary
			loop s=1, @matrix.maxnode@
					if (n_lrt[s] >= 1) print file=sta_summary.txt, form=(12),
						list=s(6), n_ons[s], n_offs[s], n_acc[s], n_egr[s], n_bd_busx[s], n_al_busx[s]
			endloop
		endif
	
	ENDRUN
	
	;==========================================================================
	*echo End run>timelog.endrun.txt
	*dir timelog*.txt /od >alltimelogs.txt
	
	;===========================================================================
	
	


