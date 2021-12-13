/*
Name: cong_speed_model_prds.sql
Purpose: calculate congested speeds for 9 SACSIM time periods.
	This script meant to be called from python script, so many parameters are just placeholders.
           
Author: Darren Conly
Last Updated: Dec 2021
Updated by: <name>
Copyright:   (c) SACOG
SQL Flavor: SQL Server
*/

SET NOCOUNT ON


SELECT
	tmc_code,
	measurement_tstamp,
	speed
INTO #speeds_prd
FROM {0} tt --speed data table
WHERE DATEPART(mm, tt.measurement_tstamp) IN ('3', '4', '5', '10') -- months of Mar, Apr, May, Oct
	AND DATENAME(dw, tt.measurement_tstamp) IN ('Tuesday', 'Wednesday', 'Thursday') -- SACSIM's day of week assumption
	AND DATEPART(hh, tt.measurement_tstamp) IN ({1}) --list of hours in each sacsim time period

SELECT
	tmc.tmc,
	COUNT(*) / SUM(1.0/sp.speed) AS avspd_{2}, --tag for sacsim period (e.g. h07 for 7am, md5 for midday 5-hour period, etc.)
	SUM(CASE WHEN sp.tmc_code IS NULL THEN 0
		ELSE 1 END)
		AS epcnt_{2},
	STDEV(sp.speed) / (COUNT(*) / SUM(1.0/sp.speed)) AS spd_stderr_{2}
FROM {3} tmc -- TMC table
	LEFT JOIN #speeds_prd sp
		ON tmc.tmc = sp.tmc_code
--WHERE tmc.tmc = '105-16680'
GROUP BY tmc.tmc

--DROP TABLE #speeds_prd