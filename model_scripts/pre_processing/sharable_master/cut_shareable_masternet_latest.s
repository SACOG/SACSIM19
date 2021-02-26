;======================================================================
; Name:cut_shareable_masternet.s
; Purpose: From SACOG internal master network, cut a shareable
	; master network with all MTP scenario years for users
	; users should be able to cut their own individual scenario years from master
;			
; Last Updated: 12/23/2020
; Last Updated By: Darren Conly
; SACOG
;======================================================================

RUN PGM=NETWORK

;input_network = "Q:\SACSIM19\2020MTP\highway\network update\Project Coding\2020 MTIP Amendment\meteringtest_cut\masterSM19ProjCoding_latest.net"
;output_network = "Q:\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\test_sharablemaster2.net"

;temp_dbf_link = "Q:\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\LINK_DBF_TEMP.dbf"
;temp_dbf_node = "Q:\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\NODE_DBF_TEMP.dbf"

;input
FILEI LINKI[1]= "Q:\SACSIM19\2020MTP\highway\network update\Project Coding\masterSM19ProjCoding_latest.net"

;output file to dbf with reordered attribute names and specified columns
FILEO LINKO="Q:\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\LINK_DBF_TEMP.dbf",
INCLUDE=A B DISTANCE RAD NAME SACTRAK SCREEN TOLLID GPID AUXID TRAV_DIR,
CAPC16 LANE16 SPD16 BIKE16,
CAPC27 LANE27 SPD27 BIKE27,
CAPC35_DPS LANE35_DPS SPD35_DPS BIKE35_DPS,
CAPC40_DPS LANE40_DPS SPD40_DPS BIKE40_DPS,
FWYID HWYSEG COUNTID C05DYD C08DYD C12DYD C16DYD

NODEO = "Q:\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\NODE_DBF_TEMP.dbf"

ENDRUN

; from link and node DBFs, remake into NET file with correct attribute order
RUN PGM=NETWORK

LINKI[1]="Q:\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\LINK_DBF_TEMP.dbf"
NODEI[1]="Q:\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\NODE_DBF_TEMP.dbf"

;want to rename to get rid of the "_dps" from the field names
FILEO NETO="Q:\SACSIM19\2020MTP\SACSIM19_scripts\Make_Shareable_MasterNet\test_output\test_sharable_net.net",
INCLUDE=A B DISTANCE RAD NAME SACTRAK SCREEN TOLLID GPID AUXID TRAV_DIR,
CAPC16 LANE16 SPD16 BIKE16 USECLASS16,
CAPC27 LANE27 SPD27 BIKE27 USECLASS27,
CAPC35 LANE35 SPD35 BIKE35 USECLASS35B USECLASS35P,
CAPC40 LANE40 SPD40 BIKE40 USECLASS40B USECLASS40P
;FWYID HWYSEG COUNTID C05DYD C08DYD C12DYD C16DYD CS ; for some reason these fields arrange themselves to appear between the 2027 attributes and the 2035 attributes.

;renaming to remove "DPS" flag from the sharable version
CAPC35 = LI.1.CAPC35_DPS
LANE35 = LI.1.LANE35_DPS
SPD35 = LI.1.SPD35_DPS
BIKE35 = LI.1.BIKE35_DPS

CAPC40 = LI.1.CAPC40_DPS
LANE40 = LI.1.LANE40_DPS
SPD40 = LI.1.SPD40_DPS
BIKE40 = LI.1.BIKE40_DPS

;calculate use class

USECLASS16 = 0
USECLASS27 = 0
USECLASS35B = 0
USECLASS35P = 0
USECLASS40B = 0
USECLASS40P = 0

; for base year and 2027, if capclass is HOV lane, HOV connector, or HOV meter bypass, set USECLASS=2
IF (LI.1.CAPC16=8, 9, 30)
   USECLASS16 = 2
ENDIF

; for base year and 2027, if capclass is HOV lane, HOV connector, or HOV meter bypass, set USECLASS=2
IF (LI.1.CAPC27=8, 9, 30)
   USECLASS27 = 2
ENDIF

; if it is for base (non-pricing) then 2035 and 2040 have same USECLASS rules as for 2016 and 2027
IF (LI.1.CAPC35_DPS= 8, 9, 30)
   USECLASS35B = 2  
ENDIF

; pricing, set all bypass ramps as USECLASS=2, but set HOV lanes and connectors USECLASS=0 so SOV can use them
; Set HOV lanes and connectors to USECLASS=0 if there is TOLLID so that SOVs can use them. If no TOLLID assume they have HOV
; restriction.
IF (LI.1.CAPC35_DPS=30)
   USECLASS35P = 2 
ELSEIF (LI.1.CAPC35_DPS=8, 9 & LI.1.TOLLID = 0)
   USECLASS35P = 2 
ELSE 
   USECLASS35P = 0 
ENDIF   

; for 2040 useclasses
IF (LI.1.CAPC40_DPS= 8, 9, 30)
   USECLASS40B = 2  
ENDIF

; pricing, set all bypass ramps as USECLASS=2, but set HOV lanes and connectors USECLASS=0 so SOV can use them
; Set HOV lanes and connectors to USECLASS=0 if there is TOLLID so that SOVs can use them. If no TOLLID assume they have HOV
; restriction.
IF (LI.1.CAPC40_DPS=30)
   USECLASS40P = 2 
ELSEIF (LI.1.CAPC40_DPS=8, 9 & LI.1.TOLLID = 0)
   USECLASS40P = 2 
ELSE 
   USECLASS40P = 0 
ENDIF  

ENDRUN