/*
Purpose: get aggregate values of ILUT variables at desired aggregation level (whole region, RAD, TAZ, block group, census tract, county, etc)
Comment/uncomment and edit the GROUP BY statement at the bottom as needed.

Following fields are weighted by population: mix index, mix-density index, half-mile employment, half-mile hhs, transit stop distances,
*/

USE MTP2020

SELECT
	TAZ07,
	RAD07_NEW,
	--County,
	--JURIS,
	--ComType_BO,
	--plan_area,
	--TPA_16,
	--TPA_40,
	--TPA36_16,
	--EJ_2018,
	--PJOBC_NAME,
	--PJOBC_4MI,
	--PSJOBC_4MI,
	--BG_10,
	--TRACT10,
	SUM(GISac) AS ACRES,
	SUM(DU_TOT) AS DU_TOT,
	SUM(POP_TOT) AS POP_TOT,
	SUM(EMP_TOT) AS EMP_TOT,
	CASE WHEN SUM(POP_TOT) = 0
			OR SUM(CASE WHEN DIST_BUS < 999 THEN POP_TOT ELSE NULL END) = 0 THEN -1 --if subarea has no people in it, we can't know pop-weighted avg bus distance, so set to -1
			--potential change: if subarea has no people, then get unweighted average distance from parcel to bus stop.
		ELSE SUM(CASE WHEN DIST_BUS < 999 AND DIST_BUS >= 0 --exclude values of -1, which represents parcels with missing data
			THEN POP_TOT * DIST_BUS
			ELSE NULL END) / 
			SUM(CASE WHEN DIST_BUS < 999 AND DIST_BUS >= 0
			THEN POP_TOT 
			ELSE NULL END)
		END AS DIST_BUS,
	CASE WHEN SUM(POP_TOT) = 0
			OR SUM(CASE WHEN DIST_LRT < 999 THEN POP_TOT ELSE NULL END) = 0 THEN -1 
		ELSE SUM(CASE WHEN DIST_LRT < 999 AND DIST_LRT >= 0
			THEN POP_TOT * DIST_LRT
			ELSE NULL END) / 
			SUM(CASE WHEN DIST_LRT < 999 AND DIST_LRT >= 0
			THEN POP_TOT 
			ELSE NULL END)
		END AS DIST_LRT,
	CASE WHEN SUM(POP_TOT) = 0
			OR SUM(CASE WHEN DIST_MIN < 999 THEN POP_TOT ELSE NULL END) = 0 THEN -1 
		ELSE SUM(CASE WHEN DIST_MIN < 999 AND DIST_MIN >= 0
			THEN POP_TOT * DIST_MIN
			ELSE NULL END) / 
			SUM(CASE WHEN DIST_MIN < 999 AND DIST_MIN >= 0
			THEN POP_TOT 
			ELSE NULL END)
		END AS DIST_MIN,
	SUM(TRN_TOT_RES) AS TRN_TOT_RES,
	SUM(TRN_LBUS_RES) AS TRN_LBUS_RES,
	SUM(TRN_LRT_RES) AS TRN_LRT_RES,  
	SUM(TRN_EBUS_RES) AS TRN_EBUS_RES
FROM 
	mtpuser.ilut_combined2040_7
GROUP BY RAD07_NEW,TAZ07
ORDER BY RAD07_NEW,TAZ07

