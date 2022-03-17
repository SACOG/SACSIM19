;Compare VED Network and Create Delta Network

RUN PGM=NETWORK

FILEI NETI[1] = "I:\Projects\Kyle\2020MTP\SACSIM19_scripts\run_2016_AO13_nTNC\2016day_ghg_full model.net" ;am peak volume-Ved network
FILEI NETI[2] = "I:\Projects\Kyle\2020MTP\SACSIM19_scripts\run_2016_AO13_nTNC\Assign_Test_00005\2016day_ghg.net"

;Call Reverse
FILEI NETI[3] = "I:\Projects\Kyle\2020MTP\SACSIM19_scripts\run_2016_AO13_nTNC\2016day_ghg_full model.net"
FILEI NETI[4] = "I:\Projects\Kyle\2020MTP\SACSIM19_scripts\run_2016_AO13_nTNC\Assign_Test_00005\2016day_ghg.net"

FILEO NETO = "I:\Projects\Kyle\2020MTP\SACSIM19_scripts\run_2016_AO13_nTNC\Assign_Test_00005\Compare_sameNets\2016_AO13_nTNC_Compare.net",
     INCLUDE=A B,
   DYV1 DYV2 DYVCHG ABSDYVCHG PRCDYVCHG,
   DYVT1 DYVT2 DYVTCHG ABSDYVTCHG PRCDYVTCHG,
   VMT1 VMT2 VMTCHG ABSVMTCHG PRCVMTCHG,
   VMTT1 VMTT2 VMTTCHG ABSVMTTCHG PRCVMTTCHG,
            TIME1 TIME2 TIMECHG ABSTIMECHG PRCTIMECHG

;convert reverse networks to calc link totals
phase=input, filei=li.3
_temp1=a
a=b
b=_temp1
endphase
			
phase=input, filei=li.4
_temp2=a
a=b
b=_temp2
endphase	

;Volume Daily
   
   DYV1=LI.1.DYV ;volume on link in first input file
   DYV2=LI.2.DYV ;volume on link in second input file
   DYVCHG=(DYV2-DYV1) ;change in volume between the two files
   ABSDYVCHG=ABS(DYV2-DYV1)
   if (DYV1>0) PRCDYVCHG=DYVCHG/DYV1
   
   DYVT1=LI.1.DYV + LI.3.DYV
   DYVT2=LI.2.DYV + LI.4.DYV
   DYVTCHG=(DYVT2-DYVT1)
   ABSDYVTCHG=ABS(DYVT2-DYVT1)
   if (DYVT1>0) PRCDYVTCHG=DYVTCHG/DYVT1

;VMT
   VMT1=LI.1.DAYVMT ;volume on link in first input file
   VMT2=LI.2.DAYVMT ;volume on link in second input file
   VMTCHG=(VMT2-VMT1) ;change in volume between the two files
   ABSVMTCHG=ABS(VMT2-VMT1)
   if (VMT1>0) PRCVMTCHG=VMTCHG/VMT1
   
   VMTT1=LI.1.DAYVMT + LI.3.DAYVMT
   VMTT2=LI.2.DAYVMT + LI.4.DAYVMT
   VMTTCHG=(VMTT2-VMTT1)
   ABSVMTTCHG=ABS(VMTT2-VMTT1)
   if (VMTT1>0) PRCVMTTCHG=VMTTCHG/VMTT1
     
;Time (link travel time change)
   TIME1=LI.1.TIME_1
   TIME2=LI.2.TIME_1
   TIMECHG=(TIME1-TIME2)
   ABSTIMECHG=ABS(TIME1-TIME2)
   if (TIME1>0) PRCTIMECHG=TIMECHG/TIME1
   
ENDRUN