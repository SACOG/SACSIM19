--Use this script for years for which an envision tomorrow land use file is not available.
--It gets vehicle-related data (VMT, etc.) but none of the land use data, which requires envision tomorrow table as input.


USE MTP2020

SELECT
	SUM(PT_TOT_RES) AS PT_TOT_RES,
	SUM(SOV_TOT_RES) AS SOV_TOT_RES,
	SUM(HOV_TOT_RES) AS HOV_TOT_RES,
	SUM(TRN_TOT_RES) AS TRN_TOT_RES,
	SUM(BIK_TOT_RES) AS BIK_TOT_RES,
	SUM(WLK_TOT_RES) AS WLK_TOT_RES,
	SUM(SCB_TOT_RES) AS SCB_TOT_RES,
	SUM(VMT_TOT_RES) AS VMT_TOT_RES,
	SUM(ix.IX_VMT_RES) AS IX_VMT_RES
FROM ilut_triptour2036_2 tt
	JOIN ilut_ixxicveh2036_2 ix
		ON tt.parcelid = ix.parcelid

