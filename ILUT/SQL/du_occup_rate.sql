/*
Purpose: get occupancy rate by parcel or by TAZ

This script creates a temporary table, #occup_rate_pcl, which has all numbers at parcel level. It then aggregates to TAZ level

occupancy rate = count of non-dorm HHs / dwelling units
*/


USE MTP2020
GO

IF EXISTS (SELECT * FROM sys.tables WHERE Object_ID = Object_ID(N'raw_parcel2016_15'))
DROP TABLE #occup_rate_pcl
;

SELECT
	ic16.parcelid,
	ic16.TAZ07,
	ic16.HH_hh AS hh_16,
	ic16.DU_TOT AS du_16,
	CASE WHEN ic16.DU_TOT = 0 THEN 0 
		ELSE ic16.HH_hh/ic16.DU_TOT 
		END AS occup_16,
	ic35.HH_hh AS hh_35,
	ic35.DU_TOT AS du_35,
	CASE WHEN ic35.DU_TOT = 0 THEN 0 
		ELSE ic35.HH_hh/ic35.DU_TOT 
		END AS occup_35,
	ic40.HH_hh AS hh_40, 
	ic40.DU_TOT AS du_40,
	CASE WHEN ic40.DU_TOT = 0 THEN 0 
		ELSE ic40.HH_hh/ic40.DU_TOT 
		END AS occup_40,
	ic35.HH_hh - ic16.HH_hh AS delt_hh_1635,
	ic35.DU_TOT - ic16.DU_TOT AS delt_du_1635,
	ic40.HH_hh - ic35.HH_hh AS delt_hh_3540,
	ic40.DU_TOT - ic35.DU_TOT AS delt_du_3540
INTO #occup_rate_pcl
FROM mtpuser.ilut_combined2016_13_ppa ic16
	JOIN mtpuser.ilut_combined2035_101 ic35
		ON ic16.parcelid = ic35.parcelid
	JOIN mtpuser.ilut_combined2040_16 ic40
		ON ic16.parcelid = ic40.parcelid

--SELECT * FROM #occup_rate_pcl

SELECT
	TAZ07,
	SUM(hh_16) AS hh_16,
	SUM(du_16) AS du_16,
	CASE WHEN SUM(du_16) = 0 THEN 0
		ELSE SUM(hh_16)/SUM(du_16) 
		END AS occup_16,
	SUM(hh_35) AS hh_35,
	SUM(du_35) AS du_35,
	CASE WHEN SUM(du_35) = 0 THEN 0
		ELSE SUM(hh_35)/SUM(du_35) 
		END AS occup_35,
	SUM(hh_40 ) AS hh_40,
	SUM(du_40) AS du_40,
	CASE WHEN SUM(du_40) = 0 THEN 0
		ELSE SUM(hh_40)/SUM(du_40) 
		END AS occup_40,
	SUM(delt_hh_1635) AS delt_hh_1635,
	SUM(delt_du_1635) AS delt_du_1635,
	SUM(delt_hh_3540) AS delt_hh_3540,
	SUM(delt_du_3540) AS delt_du_3540,
	(CASE WHEN SUM(du_35) = 0 THEN 0
		ELSE SUM(hh_35)/SUM(du_35) 
		END) -
	(CASE WHEN SUM(du_16) = 0 THEN 0
		ELSE SUM(hh_16)/SUM(du_16) 
		END)
	AS delt_occ_1635,
	(CASE WHEN SUM(du_40) = 0 THEN 0
		ELSE SUM(hh_40)/SUM(du_40) 
		END) -
	(CASE WHEN SUM(du_35) = 0 THEN 0
		ELSE SUM(hh_35)/SUM(du_35) 
		END)
	AS delt_occ_3540
FROM #occup_rate_pcl
GROUP BY TAZ07
ORDER BY
	(CASE WHEN SUM(du_35) = 0 THEN 0
		ELSE SUM(hh_35)/SUM(du_35) 
		END) -
	(CASE WHEN SUM(du_16) = 0 THEN 0
		ELSE SUM(hh_16)/SUM(du_16) 
		END),
	(CASE WHEN SUM(du_40) = 0 THEN 0
		ELSE SUM(hh_40)/SUM(du_40) 
		END) -
	(CASE WHEN SUM(du_35) = 0 THEN 0
		ELSE SUM(hh_35)/SUM(du_35) 
		END)

