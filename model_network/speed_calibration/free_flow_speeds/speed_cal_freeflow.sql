/*
Name: speed_cal_freeflow.sql
Purpose: Pull the following NPMRDS-based speeds to calibrate SACSIM model network free-flow speeds
	Output fields:
		o	TMC from 2020 (line up w SHP) 
		o	TMC length from 2020 
		o	TMC length from 2016 
		o	PPA free-flow speed (85th percentile for fwy, 60th pctl for arterials
		o	Straight 85th percentile (for all roads
		o	Avg speed 10p-4a, all days of year

           
Author: Darren Conly
Last Updated:  Dec 2021
Updated by: <name>
Copyright:   (c) SACOG
SQL Flavor: SQL Server
*/

SET NOCOUNT ON --

--==============DEFINITION 1 and 2: PPA FREE-FLOW SPEED DEFINITION ("85/60")======================
-- Get PPA free-flow definition: 85th percentile for freeways, 60th percentile for arterials,
-- for 8pm-6am time period
SELECT
	DISTINCT tt.tmc_code,
	CASE WHEN tmc.f_system IN (1,2) 
		THEN PERCENTILE_CONT(0.85)
			WITHIN GROUP (ORDER BY speed)-- NOTE - may want to try redoing with with manually calculated speed?
			OVER (PARTITION BY tmc_code) 
		ELSE PERCENTILE_CONT(0.6) 
			WITHIN GROUP (ORDER BY speed)
			OVER (PARTITION BY tmc_code) 
		END AS ffs_85th60th, --85th percentile speed for freeways; 60th percentile for arterials--used in PPA v2
	PERCENTILE_CONT(0.85)
		WITHIN GROUP (ORDER BY speed)
		OVER (PARTITION BY tmc_code)
		AS ffs_85 --just 85th percentile speed, for all roads
INTO #ff_speed_pctls
FROM {0} tmc -- TMCs used for GIS mapping
	LEFT JOIN {1} tt -- travel time data table
		ON tmc.tmc = tt.tmc_code
WHERE (DATEPART(hh,measurement_tstamp) >=20
		OR DATEPART(hh,measurement_tstamp) < 6)



--==============DEFINITION 3: AVG SPEED 10PM-4AM======================

SELECT
	tt.tmc_code,
	COUNT(*) / SUM(1.0/tt.speed) AS avspd_10p4a,
	COUNT(*) AS epoch_cnt10p4a
INTO #ffs_ovngt_avg
FROM {1} tt -- travel time data table
	WHERE DATEPART(hh, tt.measurement_tstamp) >= 22
		OR DATEPART(hh, tt.measurement_tstamp) < 4
GROUP BY tt.tmc_code

SELECT
	tmc_geomyr.tmc,
	tmc_geomyr.road,
	tmc_geomyr.f_system,
	tmc_geomyr.Miles AS len_mi{2}, -- data year for TMCs
	tmc_spdyr.Miles AS len_mi{3}, -- data year for the speed data
	pctl.ffs_85th60th,
	pctl.ffs_85,
	av.avspd_10p4a,
	av.epoch_cnt10p4a
FROM {0} tmc_geomyr -- TMCs used for GIS mapping
	LEFT JOIN {4} tmc_spdyr -- tmc table for same data year as speed data
		ON tmc_geomyr.tmc = tmc_spdyr.tmc
	LEFT JOIN #ff_speed_pctls pctl
		ON tmc_geomyr.tmc = pctl.tmc_code
	LEFT JOIN #ffs_ovngt_avg av
		ON tmc_geomyr.tmc = av.tmc_code


DROP TABLE #ff_speed_pctls; 
DROP TABLE #ffs_ovngt_avg; 
DROP TABLE #data_for_export




