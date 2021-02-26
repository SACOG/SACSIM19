***ADD Description and Update Notes for scripts in Folder
----------------------------------------------------

3/15/19
Based on adding Pricing and review from John Gibbs at DKS
•	Network fixes, gateways, metering, ramps
•	Sponsor comments project coding updates
•	VDF curve adjustment
•	New Airport VOT distribution
•	Revised tolling corridor managed lanes and gp lane capacity
•	Transit lines and fares
•	User fee urban\rural boundaries based on Community Type codes


Last Version Of Script full SACSIM19 script:
11/21 RUN_sacsim19_wTolling_wTNC_AO17_BaseCap_wAdv
  -Includes TNCS AV feature
  -All Lane Tolling
  -Advanced Tolling features: Reverse, Take a Lane, Shoulder Rds  
  -Peak Off Peak Auto Type Use adjustments


2040 Model Run Script
_______________________
RUN_sacsim19_wTolling_wTNC_AO17_BaseCap_wAdvT.s

3/5/19 - notes

RUN_sacsim19_wTolling_wTNC_AO17_BaseCap_wAdvT_noCVaccess.s - for testing only, changes paths to not allow access to commercial vehicles in managed lanes.


RUN_sacsim19_wTolling_wTNC_AO17_BaseCap_wAdvT_wUserFee_v3.s
- user fee built into skimming process AND Tolling combined, ****AutoCost must be set to 0 in config files
- requires file 'RAD_UserFee.csv' with the following ordered columns (no headers) RAD #, Userfee Factor(multiplier), Peak adjustment (cents), OffPeak adjustment (cents)

2016 Base Year Model Run Script
______________________________
RUN_sacsim19_wTolling_wTNC_AO13_BaseCap_wAdvT.s




RUN_sacsim19_wTolling_AO17_Cap20_10.s -*** Needs Description (AV Capacity adjustment???)

