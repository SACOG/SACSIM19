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

   
        votcl=1 
        tnt=1
        ivot=60/12.51 ;need to update to match tolling ivots
        tntst = 'nt'

      ;----------------------------------------------------------------------
      ;step 8
      IF (p=1,2,3,5,6,7) ; am,pm end loop at 739
          RUN PGM=HIGHWAY  MSG='step 8 Highway skims'
          ; Highway skims for all occupancies, at one period, VOT, tolling class at a time

          NETI=vo.@per@.net                      ; input network
         MATO=tempsk@per@.mat, MO=1-9,dec=9*2,    ; output skim matrices
         name=da_time, da_dist,da_cdist, s2_time,s2_dist,s2_cdist, s3_time, s3_dist,s3_cdist

        ;IFCLUSTER:
         DistributeIntraStep processid='sacsimsub', ProcessList=1-3, mingroupsize=400

         PHASE=LINKREAD                        ;define link groups

            if (li.vc_1>=1.0)
               comp lw.vc10dist=li.distance
            else
               lw.vc10dist=0.0
            ENDIF
          

          ; Settings for network path choice based on configuration settings
          CostPerMile = 0.17
          HOV2Divisor = 1.00;  was 1.66 - No need to divide by occupancy since DaySim places shared ride trips in higher VOT class
          HOV3Divisor = 1.00; was 2.23

		   IF (li.USECLASS == 0) ADDTOGROUP=1        ;GENERAL PURPOSE 
           IF (li.USECLASS == 2) ADDTOGROUP=2        ;HOV2
           IF (li.USECLASS == 3) ADDTOGROUP=3        ;HOV3+
            
            lw.AOCost = li.distance * CostPerMile
            if (@tnt@ <= 0)     ;if No-Toll class...
                tollivot = 150   ;severe perception factor for tolls, for the no-toll class
            else
                tollivot = @ivot@
            endif
            
            lw.imped_da = li.time_1 + (li.tollda*tollivot + lw.AOCost*@ivot@)
            lw.imped_s2 = li.time_1 + (li.tolls2*tollivot + lw.AOCost*@ivot@) / HOV2Divisor
            lw.imped_s3 = li.time_1 + (li.tolls3*tollivot + lw.AOCost*@ivot@) / HOV3Divisor
          endphase


		PHASE=ILOOP
		 ;Skim SOV paths without HOV links
			PATHLOAD PATH=lw.imped_da,EXCLUDEGRP=2,3,
			   mw[1]=pathtrace(li.time_1), noaccess=0,
			   mw[2]=pathtrace(li.distance), noaccess=0,
			   mw[3]=pathtrace(lw.vc10dist), noaccess=0

		 ; Skim SR2 paths with HOV links
			PATHLOAD PATH=lw.imped_s2,EXCLUDEGRP=3,
			   mw[4]=pathtrace(li.time_1), noaccess=0,  
			   mw[5]=pathtrace(li.distance), noaccess=0,
			   mw[6]=pathtrace(lw.vc10dist), noaccess=0

		 ; Skim SR3 paths with HOV links
		   PATHLOAD PATH=lw.imped_s3,
			   mw[7]=pathtrace(li.time_1), noaccess=0,  
			   mw[8]=pathtrace(li.distance), noaccess=0,
			   mw[9]=pathtrace(lw.vc10dist), noaccess=0


           ;Intrazonals
               ;Intrazonals
			iz1=lowest(1,1,0.005,10000)*0.5
			iz2=lowest(2,1,0.005,10000)*0.5
			iz4=lowest(4,1,0.005,10000)*0.5
			iz5=lowest(5,1,0.005,10000)*0.5
			iz7=lowest(7,1,0.005,10000)*0.5
			iz8=lowest(8,1,0.005,10000)*0.5
			jloop j=i
				mw[1]=iz1
				mw[2]=iz2
				mw[4]=iz4
				mw[5]=iz5
				mw[7]=iz7
				mw[8]=iz8
			endjloop
              
          ENDPHASE
    ENDRUN
      ;======md,ev,ni==========================

	  ELSE 
	  
          RUN PGM=HIGHWAY  MSG='step 8 Highway skims'
            ; Highway skims for all occupancies, at one period, VOT, tolling class at a time

            NETI=vo.@per@.net                      ; input network
            MATO=tempsk@per@.mat, MO=1-9,dec=9*2,    ; output skim matrices
         name=da_time, da_dist,da_cdist, s2_time,s2_dist,s2_cdist, s3_time, s3_dist,s3_cdist

        ;IFCLUSTER:
         DistributeIntraStep processid='sacsimsub', ProcessList=1-3, mingroupsize=400

         PHASE=LINKREAD                        ;define link groups

            if (li.vc_1>=1.0)
               comp lw.vc10dist=li.distance
            else
               lw.vc10dist=0.0
            ENDIF
          

            ; Settings for network path choice based on configuration settings
            CostPerMile = 0.17
            HOV2Divisor = 1.00;  was 1.66 - No need to divide by occupancy since DaySim places shared ride trips in higher VOT class
            HOV3Divisor = 1.00; was 2.23

		   IF (li.USECLASS == 0) ADDTOGROUP=1        ;GENERAL PURPOSE 
           IF (li.USECLASS == 2) ADDTOGROUP=2        ;HOV2
           IF (li.USECLASS == 3) ADDTOGROUP=3        ;HOV3+
		   IF (li.USECLASS == 4) ADDTOGROUP=4        ;3+ axle commercial (for off peak)
              
              lw.AOCost = li.distance * CostPerMile
              if (@tnt@ <= 0)     ;if No-Toll class...
                  tollivot = 150   ;severe perception factor for tolls, for the no-toll class
              else
                  tollivot = @ivot@
              endif
              
              lw.imped_da = li.time_1 + (li.tollda*tollivot + lw.AOCost*@ivot@)
              lw.imped_s2 = li.time_1 + (li.tolls2*tollivot + lw.AOCost*@ivot@) / HOV2Divisor       
              lw.imped_s3 = li.time_1 + (li.tolls3*tollivot + lw.AOCost*@ivot@) / HOV3Divisor      
            endphase


               PHASE=ILOOP
                  
                     ;Skim SOV paths without HOV links
              PATHLOAD PATH=lw.imped_da,EXCLUDEGRP=2,3,
                 mw[1]=pathtrace(li.time_1), noaccess=0,
                 mw[2]=pathtrace(li.distance), noaccess=0,
                 mw[3]=pathtrace(lw.vc10dist), noaccess=0

          ; Skim SR2 paths with HOV links
              PATHLOAD PATH=lw.imped_s2,EXCLUDEGRP=3,
                 mw[4]=pathtrace(li.time_1), noaccess=0,  
                 mw[5]=pathtrace(li.distance), noaccess=0,
                 mw[6]=pathtrace(lw.vc10dist), noaccess=0

          ; Skim SR3 paths with HOV links
               PATHLOAD PATH=lw.imped_s3,
                 mw[7]=pathtrace(li.time_1), noaccess=0,  
                 mw[8]=pathtrace(li.distance), noaccess=0,
                 mw[9]=pathtrace(lw.vc10dist), noaccess=0

               ;Intrazonals
			iz1=lowest(1,1,0.005,10000)*0.5
			iz2=lowest(2,1,0.005,10000)*0.5
			iz4=lowest(4,1,0.005,10000)*0.5
			iz5=lowest(5,1,0.005,10000)*0.5
			iz7=lowest(7,1,0.005,10000)*0.5
			iz8=lowest(8,1,0.005,10000)*0.5
			jloop j=i
				mw[1]=iz1
				mw[2]=iz2
				mw[4]=iz4
				mw[5]=iz5
				mw[7]=iz7
				mw[8]=iz8
			endjloop
		endphase
        ENDRUN

      ; 9 auto time periods
      endif
  ENDLOOP
;-------------------------------------------------------------------------------------
run pgm=matrix
; Attach skim data to trip records

;dbi[1]=.\_trip_1.tsv, delimiter[1]=',t', fields=1

FILEI RECI = _trip.tsv, id=1,tour_id=2,hhno=3,pno=4,day=5,tour=6,half=7,tseg=8,tsvid=9,opurp=10,dpurp=11,oadtyp=12,dadtyp=13,opcl=14,otaz=15,dpcl=16,dtaz=17,
mode=18,pathtype=19,dorp=20,deptm=21,arrtm=22,endacttm=23,travtime=24,travcost=25,travdist=26,vot=27,trexpfac=28,
delimiter[1]=' ,t', SORT=otaz

MATI[1]=tempskh07.mat ;7am skim file
MATI[2]=tempskh08.mat
MATI[3]=tempskh09.mat
MATI[4]=tempskmd5.mat
MATI[5]=tempskh15.mat
MATI[6]=tempskh16.mat
MATI[7]=tempskh17.mat
MATI[8]=tempskev2.mat
MATI[9]=tempskn11.mat


if (reci.recno=1)
    loop f=1, reci.numfields
        if (reci.cfield[f]='id')       f_id       = f
        if (reci.cfield[f]='tour_id')  f_tour_id  = f
        if (reci.cfield[f]='hhno')     f_hhno       = f
        if (reci.cfield[f]='pno')      f_pno       = f
        if (reci.cfield[f]='day')      f_day      = f
        if (reci.cfield[f]='tour')      f_tour     = f
        if (reci.cfield[f]='half')     f_half      = f
        if (reci.cfield[f]='tseg')     f_tseg      = f
        if (reci.cfield[f]='tsvid')    f_tsvid     = f
        if (reci.cfield[f]='opurp')     f_opurp      = f
        if (reci.cfield[f]='dpurp')     f_dpurp      = f
        if (reci.cfield[f]='oadtyp')     f_oadtyp      = f
        if (reci.cfield[f]='dadtyp')     f_dadtyp      = f
        if (reci.cfield[f]='opcl')     f_opcl      = f
        if (reci.cfield[f]='otaz')     f_otaz     = f
        if (reci.cfield[f]='dpcl')     f_dpcl      = f
        if (reci.cfield[f]='dtaz')     f_dtaz     = f
        if (reci.cfield[f]='mode')     f_mode     = f
        if (reci.cfield[f]='pathtype') f_pathtype = f
        if (reci.cfield[f]='dorp')     f_dorp     = f
        if (reci.cfield[f]='deptm')    f_deptm  = f
        if (reci.cfield[f]='arrtm')    f_arrtm  = f
        if (reci.cfield[f]='endacttm')    f_endacttm  = f
        if (reci.cfield[f]='travtime')    f_travtime  = f
        if (reci.cfield[f]='travcost')    f_travcost  = f
        if (reci.cfield[f]='travdist')    f_travdist  = f
        if (reci.cfield[f]='vot')      f_vot      = f
        if (reci.cfield[f]='trexpfac') f_trexpfac = f
    endloop
  print file=.\_trip_1_1.csv, list= 'id,tour_id,hhno,pno,day,tour,half,tseg,tsvid,opurp,dpurp,oadtyp,dadtyp,opcl,otaz,dpcl,dtaz,mode,pathtype,dorp,deptm,arrtm,endacttm,travtime,travcost,travdist,vot,trexpfac,timeau,distau,distcong'
else
       trip_id = val(reci.cfield[f_id])     
       tour_id = val(reci.cfield[f_tour_id])  
       hhno  = val(reci.cfield[f_hhno])    
       pno  = val(reci.cfield[f_pno])      
       day  = val(reci.cfield[f_day])      
       tour  = val(reci.cfield[f_tour])    
       half   = val(reci.cfield[f_half])   
       tseg  = val(reci.cfield[f_tseg])    
       tsvid = val(reci.cfield[f_tsvid])    
       opurp  = val(reci.cfield[f_opurp])     
       dpurp  = val(reci.cfield[f_dpurp])     
       oadtyp  = val(reci.cfield[f_oadtyp])    
       dadtyp  = val(reci.cfield[f_dadtyp])    
       opcl  = val(reci.cfield[f_opcl])    
       otaz  = val(reci.cfield[f_otaz])    
       dpcl  = val(reci.cfield[f_dpcl])     
       dtaz  = val(reci.cfield[f_dtaz])     
       mode  = val(reci.cfield[f_mode])    
       pathtype  = val(reci.cfield[f_pathtype])
       dorp  = val(reci.cfield[f_dorp])   
       deptm  = val(reci.cfield[f_deptm])   
       arrtm = val(reci.cfield[f_arrtm])    
       endacttm  = val(reci.cfield[f_endacttm])    
       travtime  = val(reci.cfield[f_travtime])   
       travcost  = val(reci.cfield[f_travcost])    
       travdist  = val(reci.cfield[f_travdist])    
       vot  = val(reci.cfield[f_vot])     
       trexpfac  = val(reci.cfield[f_trexpfac])

; Segment the trip time
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

            arrhr = ri.arrtm/60 ;arrival hour
            dephr = ri.deptm/60 ;departure hour
            durhr = (arrhr - dephr) ;trip duration, in hours
            if (durhr = 0)
                arrhr = arrhr + 0.0001 ;ensure there are no trips with zero duration
                durhr = 0.0001
            elseif (durhr < 0)
                durhr = durhr + 24
            endif

        ; Separate the after-midnight portion only if trip straddles midnight
        ;       into trip1: dephr to 24 (alias arrhr),
        ;        and trip2: 0 to arrhr (alias arr2)
            if (arrhr < dephr) ;if departure hour is from previous day (e.g., from 11pm-1am), then split trip into two, with first ending at midnight and second starting at midnight
                arr2 = arrhr
                arrhr = 24
            else
                arr2 = 0
            endif

        ; Fraction of trip within each period
        ; E.g. if trip started at 8:30 and ended 9:30, for loop s = 2 it'd be (9am - 8:30am) + 0, or 30mins, or 50% of trip in time period one, then 1-50%, or 0.5, in period 2
        ; does this work for trips that straddle 3 or more time periods? Yes, it does. Tested.
           ni = 1 ;ni = network in?
            loop s=1,8 ;don't loop through s[9] because each loop goes to s[n+1]
                hrbeg = seghr[s] ;returns hour of period s
                hrend = seghr[s+1] ;returns hour of period (s+1)
                t_part = (max(0, min(hrend, arrhr) - max(hrbeg, dephr)) + ;(duration of trip in period)/total duration of trip. 
                        max(0, min(hrend, arr2 ) - hrbeg)) / durhr
                tripseg[s] = t_part
         ;       ni9 = ni9 - tseg
                 ni = ni -t_part
            endloop
            ni = max(0, ni)

        ; To fields
            a1 = tripseg[1] ;portion of trip happening in time segment 1
            a2 = tripseg[2]
            a3 = tripseg[3] 
            md = tripseg[4] 
            p1 = tripseg[5] 
            p2 = tripseg[6]
            p3 = tripseg[7]
            ev = tripseg[8]
            ni = ni        


; Select skims

IF (mode = 5)   ; S3
    a1timeau   = a1*matval(1, 7, otaz, dtaz)    ;MatVal( filenumber, tablenumber, i, j, failvalue)
    a1distau   = a1*matval(1, 8, otaz, dtaz) ;(portion of trip in time period 1) * (period 1 skim distance from trip's origin to trip's destination)
    a1distcong   = a1*matval(1, 9, otaz, dtaz) ;matrix value for i-j combo in the congested distance tab (tab 9) of the first skim file (7am period)
    a2timeau   = a2*matval(2, 7, otaz, dtaz)    
    a2distau   = a2*matval(2, 8, otaz, dtaz)
    a2distcong   = a2*matval(2, 9, otaz, dtaz)
    a3timeau   = a3*matval(3, 7, otaz, dtaz)    
    a3distau   = a3*matval(3, 8, otaz, dtaz)
    a3distcong   = a3*matval(3, 9, otaz, dtaz)
    
    mdtimeau   = MD*matval(4, 7, otaz, dtaz)
    mddistau   = MD*matval(4, 8, otaz, dtaz)
    mddistcong   = MD*matval(4, 9, otaz, dtaz)
    
    p1timeau   = P1*matval(5, 7, otaz, dtaz)    
    p1distau   = P1*matval(5, 8, otaz, dtaz) 
    p1distcong   = P1*matval(5, 9, otaz, dtaz)
     p2timeau   = P2*matval(6, 7, otaz, dtaz)    
    p2distau   = P2*matval(6, 8, otaz, dtaz) 
    p2distcong   = P2*matval(6, 9, otaz, dtaz)
     p3timeau   = P3*matval(7, 7, otaz, dtaz)    
    p3distau   = P3*matval(7, 8, otaz, dtaz) 
    p3distcong   = P3*matval(7, 9, otaz, dtaz)
    
    evtimeau   = EV*matval(8, 7, otaz, dtaz)
    evdistau   = EV*matval(8, 8, otaz, dtaz)
    evdistcong   = EV*matval(8, 9, otaz, dtaz)
    
    nitimeau   = ni*matval(9, 7, otaz, dtaz)
    nidistau   = ni*matval(9, 8, otaz, dtaz)
    nidistcong   = ni*matval(9, 9, otaz, dtaz)

 ELSEIF (mode = 4) ; S2
    a1timeau   = a1*matval(1, 4, otaz, dtaz)    
    a1distau   = a1*matval(1, 5, otaz, dtaz)
    a1distcong   = a1*matval(1, 6, otaz, dtaz)
    a2timeau   = a2*matval(2, 4, otaz, dtaz)    
    a2distau   = a2*matval(2, 5, otaz, dtaz)
    a2distcong   = a2*matval(2, 6, otaz, dtaz)
    a3timeau   = a3*matval(3, 4, otaz, dtaz)    
    a3distau   = a3*matval(3, 5, otaz, dtaz)
    a3distcong   = a3*matval(3, 6, otaz, dtaz)
    
    mdtimeau   = MD*matval(4, 4, otaz, dtaz)
    mddistau   = MD*matval(4, 5, otaz, dtaz)
    mddistcong   = MD*matval(4, 6, otaz, dtaz)
    
    p1timeau   = P1*matval(5, 4, otaz, dtaz)    
    p1distau   = P1*matval(5, 5, otaz, dtaz) 
    p1distcong   = P1*matval(5, 6, otaz, dtaz)
     p2timeau   = P2*matval(6, 4, otaz, dtaz)    
    p2distau   = P2*matval(6, 5, otaz, dtaz) 
    p2distcong   = P2*matval(6, 6, otaz, dtaz)
     p3timeau   = P3*matval(7, 4, otaz, dtaz)    
    p3distau   = P3*matval(7, 5, otaz, dtaz) 
    p3distcong   = P3*matval(7, 6, otaz, dtaz)
    
    evtimeau   = EV*matval(8, 4, otaz, dtaz)
    evdistau   = EV*matval(8, 5, otaz, dtaz)
    evdistcong   = EV*matval(8, 6, otaz, dtaz)
    
    nitimeau   = ni*matval(9, 4, otaz, dtaz)
    nidistau   = ni*matval(9, 5, otaz, dtaz)
    nidistcong   = ni*matval(9, 6, otaz, dtaz)
ELSEIF (mode=3) ; Drive Alone
    a1timeau   = a1*matval(1, 1, otaz, dtaz)    
    a1distau   = a1*matval(1, 2, otaz, dtaz)
    a1distcong   = a1*matval(1, 3, otaz, dtaz)
    a2timeau   = a2*matval(2, 1, otaz, dtaz)    
    a2distau   = a2*matval(2, 2, otaz, dtaz)
    a2distcong   = a2*matval(2, 3, otaz, dtaz)
    a3timeau   = a3*matval(3, 1, otaz, dtaz)    
    a3distau   = a3*matval(3, 2, otaz, dtaz)
    a3distcong   = a3*matval(3, 3, otaz, dtaz)
    
    mdtimeau   = MD*matval(4, 1, otaz, dtaz)
    mddistau   = MD*matval(4, 2, otaz, dtaz)
    mddistcong   = MD*matval(4, 3, otaz, dtaz)
    
    p1timeau   = P1*matval(5, 1, otaz, dtaz)    
    p1distau   = P1*matval(5, 2, otaz, dtaz) 
    p1distcong   = P1*matval(5, 3, otaz, dtaz)
     p2timeau   = P2*matval(6, 1, otaz, dtaz)    
    p2distau   = P2*matval(6, 2, otaz, dtaz) 
    p2distcong   = P2*matval(6, 3, otaz, dtaz)
     p3timeau   = P3*matval(7, 1, otaz, dtaz)    
    p3distau   = P3*matval(7, 2, otaz, dtaz) 
    p3distcong   = P3*matval(7, 3, otaz, dtaz)
    
    evtimeau   = EV*matval(8, 1, otaz, dtaz)
    evdistau   = EV*matval(8, 2, otaz, dtaz)
    evdistcong   = EV*matval(8, 3, otaz, dtaz)
    
    nitimeau   = ni*matval(9, 1, otaz, dtaz)
    nidistau   = ni*matval(9, 2, otaz, dtaz)
    nidistcong   = ni*matval(9, 3, otaz, dtaz)
ELSEIF (mode=9) ; TNC (4/30/2018 - using drive-alone skims for now, but this should be changed in future to reflect shared TNCs)
    a1timeau   = a1*matval(1, 1, otaz, dtaz)    
    a1distau   = a1*matval(1, 2, otaz, dtaz)
    a1distcong   = a1*matval(1, 3, otaz, dtaz)
    a2timeau   = a2*matval(2, 1, otaz, dtaz)    
    a2distau   = a2*matval(2, 2, otaz, dtaz)
    a2distcong   = a2*matval(2, 3, otaz, dtaz)
    a3timeau   = a3*matval(3, 1, otaz, dtaz)    
    a3distau   = a3*matval(3, 2, otaz, dtaz)
    a3distcong   = a3*matval(3, 3, otaz, dtaz)
    
    mdtimeau   = MD*matval(4, 1, otaz, dtaz)
    mddistau   = MD*matval(4, 2, otaz, dtaz)
    mddistcong   = MD*matval(4, 3, otaz, dtaz)
    
    p1timeau   = P1*matval(5, 1, otaz, dtaz)    
    p1distau   = P1*matval(5, 2, otaz, dtaz) 
    p1distcong   = P1*matval(5, 3, otaz, dtaz)
     p2timeau   = P2*matval(6, 1, otaz, dtaz)    
    p2distau   = P2*matval(6, 2, otaz, dtaz) 
    p2distcong   = P2*matval(6, 3, otaz, dtaz)
     p3timeau   = P3*matval(7, 1, otaz, dtaz)    
    p3distau   = P3*matval(7, 2, otaz, dtaz) 
    p3distcong   = P3*matval(7, 3, otaz, dtaz)
    
    evtimeau   = EV*matval(8, 1, otaz, dtaz)
    evdistau   = EV*matval(8, 2, otaz, dtaz)
    evdistcong   = EV*matval(8, 3, otaz, dtaz)
    
    nitimeau   = ni*matval(9, 1, otaz, dtaz)
    nidistau   = ni*matval(9, 2, otaz, dtaz)
    nidistcong   = ni*matval(9, 3, otaz, dtaz)
ENDIF
IF (mode=1,2,6,7,8)   ;if mode is not a car mode, then auto time and congested distance all = 0
    timeau   = 0    
    distau   = 0 
    distcong = 0
    print file=.\_trip_1_1.csv, list= trip_id(20.0),',',tour_id(12.0),',',hhno(10.0),',',pno(2.0),',',day(2.0),',',tour(2.0),',',half(2.0),',',tseg(2.0),',',tsvid(2.0),',',opurp(2.0),',',dpurp(2.0),',',oadtyp(2.0),',',dadtyp(2.0),',',opcl(10.0),',',otaz(10.0),',',dpcl(10.0),',',dtaz(10.0),',',mode(2.0),',',pathtype(2.0),',',dorp(2.0),',',deptm(10.0),',',arrtm(10.0),',',endacttm(10.0),',',travtime(10.2),',',travcost(10.2),',',travdist(10.2),',',vot(8.2),',',trexpfac(2.0),',',timeau(10.2),',',distau(10.2),',',distcong(10.2)
    
ELSEIF (mode=3,4,5,9) ;if mode is a car mode, then get total times, distance, congested distance as follows:
    
    timeau=a1timeau+a2timeau+a3timeau+mdtimeau+p1timeau+p2timeau+p3timeau+evtimeau+nitimeau ;sum the skim-based times 
    distau=a1distau+a2distau+a3distau+mddistau+p1distau+p2distau+p3distau+evdistau+nidistau ;sum the skim-based total distances 
    distcong=a1distcong+a2distcong+a3distcong+mddistcong+p1distcong+p2distcong+p3distcong+evdistcong+nidistcong ;sum the skim-based congested distances
   print file=.\_trip_1_1.csv, list= trip_id(20.0),',',tour_id(12.0),',',hhno(10.0),',',pno(2.0),',',day(2.0),',',tour(2.0),',',half(2.0),',',tseg(2.0),',',tsvid(2.0),',',opurp(2.0),',',dpurp(2.0),',',oadtyp(2.0),',',dadtyp(2.0),',',opcl(10.0),',',otaz(10.0),',',dpcl(10.0),',',dtaz(10.0),',',mode(2.0),',',pathtype(2.0),',',dorp(2.0),',',deptm(10.0),',',arrtm(10.0),',',endacttm(10.0),',',travtime(10.2),',',travcost(10.2),',',travdist(10.2),',',vot(8.2),',',trexpfac(2.0),',',timeau(10.2),',',distau(10.2),',',distcong(10.2)
    
ENDIF

ENDIF ; reco

ENDRUN

;----------------------------------------------------------------------------------