/*
--------------------------------
 Name:Model_sensitivity_avg_compare.s
 Purpose: average and compare 5 run averages of random seed assignments for PEP sensitivity analysis
           
 Author: Kyle Shipley & Darren Conly
 Last Updated: 8/17/2021
 Updated by: KS
 Copyright:   (c) SACOG
 Voyager Version:   6.5.0
--------------------------------
*/

;random seeds (user inputs based on runs) run name must be <year>daynetPEP<randomseednum>_<wo or wp>.net
n1 = '1234'
n2 = '2362'
n3 = '6625'
n4 = '8386'
n5 = '8193'


RUN PGM=network
filei neti[1]=?daynetPEP@n1@_wp.net
      linki[2]=?daynetPEP@n2@_wp.net
	  linki[3]=?daynetPEP@n3@_wp.net
	  linki[4]=?daynetPEP@n4@_wp.net
	  linki[5]=?daynetPEP@n5@_wp.net
	  
	  linki[6]=?daynetPEP@n1@_wo.net
      linki[7]=?daynetPEP@n2@_wo.net
	  linki[8]=?daynetPEP@n3@_wo.net
	  linki[9]=?daynetPEP@n4@_wo.net
	  linki[10]=?daynetPEP@n5@_wo.net
	  
fileo neto=?daynetPEP_5runavg_@n1@_@n2@_@n3@_@n4@_@n5@_details.net,include=name,distance,rad,sactrak,c16dyd,capclass,lanes,speed

	PDYVAVG = 0 ; with-project 5-run daily average link volume
	PDYV@n1@ = li.1.DYV ; with-project daily link volume for indicated random seed value
	PDYV@n2@ = li.2.DYV ; with-project daily link volume for indicated random seed value
	PDYV@n3@ = li.3.DYV ; with-project daily link volume for indicated random seed value
	PDYV@n4@ = li.4.DYV ; with-project daily link volume for indicated random seed value
	PDYV@n5@ = li.5.DYV ; with-project daily link volume for indicated random seed value

	PVMTAVG = 0 ; with-project 5-run daily average link VMT
	PVMT@n1@ = li.1.dayvmt ; with-project daily link VMT for indicated random seed value
	PVMT@n2@ = li.2.dayvmt ; with-project daily link VMT for indicated random seed value
	PVMT@n3@ = li.3.dayvmt ; with-project daily link VMT for indicated random seed value
	PVMT@n4@ = li.4.dayvmt ; with-project daily link VMT for indicated random seed value
	PVMT@n5@ = li.5.dayvmt ; with-project daily link VMT for indicated random seed value

	PCVMTAVG = 0 ; with-project 5-run daily average link CVMT
	PCVMT@n1@ = li.1.daycvmt ; with-project daily link CVMT for indicated random seed value
	PCVMT@n2@ = li.2.daycvmt ; with-project daily link CVMT for indicated random seed value
	PCVMT@n3@ = li.3.daycvmt ; with-project daily link CVMT for indicated random seed value
	PCVMT@n4@ = li.4.daycvmt ; with-project daily link CVMT for indicated random seed value
	PCVMT@n5@ = li.5.daycvmt ; with-project daily link CVMT for indicated random seed value

	NPDYVAVG = 0 ; without-project 5-run daily average link volume
	NPDYV@n1@ = li.6.DYV ; without-project daily link volume for indicated random seed value
	NPDYV@n2@ = li.7.DYV ; without-project daily link volume for indicated random seed value
	NPDYV@n3@ = li.8.DYV ; without-project daily link volume for indicated random seed value
	NPDYV@n4@ = li.9.DYV ; without-project daily link volume for indicated random seed value
	NPDYV@n5@ = li.10.DYV ; without-project daily link volume for indicated random seed value

	NPVMTAVG = 0 ; without-project 5-run daily average link VMT
	NPVMT@n1@ = li.6.dayvmt  ; without-project daily link VMT for indicated random seed value
	NPVMT@n2@ = li.7.dayvmt  ; without-project daily link VMT for indicated random seed value
	NPVMT@n3@ = li.8.dayvmt  ; without-project daily link VMT for indicated random seed value
	NPVMT@n4@ = li.9.dayvmt  ; without-project daily link VMT for indicated random seed value
	NPVMT@n5@ = li.10.dayvmt ; without-project daily link VMT for indicated random seed value

	NPCVMTAVG = 0 ; without-project 5-run daily average link CVMT
	NPCVMT@n1@ = li.6.daycvmt  ; without-project daily link CVMT for indicated random seed value
	NPCVMT@n2@ = li.7.daycvmt  ; without-project daily link CVMT for indicated random seed value
	NPCVMT@n3@ = li.8.daycvmt  ; without-project daily link CVMT for indicated random seed value
	NPCVMT@n4@ = li.9.daycvmt  ; without-project daily link CVMT for indicated random seed value
	NPCVMT@n5@ = li.10.daycvmt ; without-project daily link CVMT for indicated random seed value

	_PDYVTOT = PDYV@n1@ + PDYV@n2@ + PDYV@n3@ + PDYV@n4@ + PDYV@n5@
	_PVMTTOT = PVMT@n1@ + PVMT@n2@ + PVMT@n3@ + PVMT@n4@ + PVMT@n5@
	_PCVMTTOT = PCVMT@n1@ + PCVMT@n2@ + PCVMT@n3@ + PCVMT@n4@ + PCVMT@n5@
	_NPDYVTOT = NPDYV@n1@ + NPDYV@n2@ + NPDYV@n3@ + NPDYV@n4@ + NPDYV@n5@
	_NPVMTTOT = NPVMT@n1@ + NPVMT@n2@ + NPVMT@n3@ + NPVMT@n4@ + NPVMT@n5@
	_NPCVMTTOT = NPCVMT@n1@ + NPCVMT@n2@ + NPCVMT@n3@ + NPCVMT@n4@ + NPCVMT@n5@

	IF (_PDYVTOT > 0) PDYVAVG = _PDYVTOT/5
	IF (_PVMTTOT > 0) PVMTAVG = _PVMTTOT/5
	IF (_PCVMTTOT > 0) PCVMTAVG = _PCVMTTOT/5
	IF (_NPDYVTOT > 0) NPDYVAVG = _NPDYVTOT/5
	IF (_NPVMTTOT > 0) NPVMTAVG = _NPVMTTOT/5
	IF (_NPCVMTTOT > 0) NPCVMTAVG = _NPCVMTTOT/5

	DYVCHG = NPDYVAVG - PDYVAVG ; daily link volume difference between with- and without project
	VMTCHG = NPVMTAVG - PVMTAVG; daily link VMT difference between with- and without project
	CVMTCHG = NPCVMTAVG - PCVMTAVG ; daily link CVMT difference between with- and without project


merge record=false
endrun

RUN PGM=network
neti=?daynetPEP_5runavg_@n1@_@n2@_@n3@_@n4@_@n5@_details.net
neto=?daynetPEP_5runavg_@n1@_@n2@_@n3@_@n4@_@n5@.net,include=name,distance,rad,sactrak,c16dyd,capclass,lanes,speed,
PDYVAVG,PVMTAVG,PCVMTAVG,NPDYVAVG,NPVMTAVG,NPCVMTAVG,DYVCHG,VMTCHG,CVMTCHG
endrun