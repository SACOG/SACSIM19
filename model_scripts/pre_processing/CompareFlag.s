;>>> COMPARE Networks & Flag
;>>> 
;>>> Info on output
; -2 = link in NET1, not in NET2 
; -1 = link in NET2, not in NET1    
;  0 = links identical
; +n = number of attributes that are different

RUN PGM=NETWORK

; Compare 2 highway networks and flags the links that are different
FILEI NETI[1]="I:\Projects\Kyle\2020MTP\SACSIM19_scripts\run_2016_AO13_nTNC\2016_org_base.net"
FILEI NETI[2]="I:\Projects\Kyle\2020MTP\SACSIM19_scripts\run_2016_AO13_nTNC\Assign_Test_00005\2016_base.net"

FILEO NETO="I:\Projects\Kyle\2020MTP\SACSIM19_scripts\run_2016_AO13_nTNC\Assign_Test_00005\Compare_sameNets\Base_CompareFlag.net"

  MERGE RECORD=T 

  PHASE=LINKMERGE

    COMPARE RECORD=1-2, LIST=10000  TITLE="Comparison Summary Report: Old vs New Base Network" ; compare link record 1 with 2

    CMPFLAG=_COMPARE             ; save comparison flag

ENDRUN

