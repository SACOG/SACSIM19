/*
Name: HoursCongestedConditions.sql
Purpose: On an average weekday, for how many hours is the TMC "congested", with its observed speed being less than
some % of the free-flow (reference) speed?
           
Author: Darren Conly
Last Updated: 8/29/2019
Updated by: <name>
Copyright:   (c) SACOG
SQL Flavor: SQL Server

Test TMC (I-5 SB over American River) = '105-04713'
*/

USE NPMRDS
;

SELECT
	DISTINCT tt.tmc_code,
	tmc.road,
	tmc.direction,
	CASE WHEN tmc.f_system IN (1,2) 
		THEN PERCENTILE_CONT(0.85)
			WITHIN GROUP (ORDER BY speed)
			OVER (PARTITION BY tmc_code) 
		ELSE PERCENTILE_CONT(0.6) 
			WITHIN GROUP (ORDER BY speed)
			OVER (PARTITION BY tmc_code) 
		END AS ff_speed_85th60th --85th percentile speed for freeways; 60th percentile for arterials
INTO #ff_speed
FROM npmrds_2018_all_tmcs_txt tmc
	JOIN npmrds_2018_alltmc_paxveh tt
		ON tmc.tmc = tt.tmc_code
WHERE (DATEPART(hh,measurement_tstamp) >=20
		OR DATEPART(hh,measurement_tstamp) < 6)
;

WITH all_days_cong AS (
SELECT
	tt.tmc_code,
	DATEPART(dy, tt.measurement_tstamp) AS doy,
	SUM(CASE WHEN speed / p.ff_speed_85th60th <= 0.6 
			THEN 0.25 ELSE 0 END) AS congested_hours, --using manually-determined reference speed since it's missing from some TMCs for no apparent reason, also because don't want to use overnight FF for arterials
	COUNT(*)*0.25 AS total_hours
FROM npmrds_2018_alltmc_paxveh tt
	LEFT JOIN #ff_speed p
		ON tt.tmc_code = p.tmc_code
WHERE DATEPART(dw, tt.measurement_tstamp) IN (2,3,4,5,6) --weekdays only
GROUP BY tt.tmc_code, DATEPART(dy, tt.measurement_tstamp)
)


SELECT
	tmc.tmc,
	tmc.road,
	tmc.direction,
	CASE WHEN ffs.ff_speed_85th60th IS NULL THEN -1 ELSE ffs.ff_speed_85th60th END AS ff_speed_85th60th,
	CASE WHEN AVG(c.congested_hours) IS NULL THEN -1 ELSE AVG(c.congested_hours) END AS avg_daily_conghrs,
	CASE WHEN MIN(c.total_hours) IS NULL THEN -1 ELSE MIN(c.total_hours) END AS min_day_hrs_w_data,
	CASE WHEN AVG(c.total_hours) IS NULL THEN -1 ELSE AVG(c.total_hours) END AS avg_daily_hrs_w_data
FROM npmrds_2018_all_tmcs_txt tmc 
	LEFT JOIN all_days_cong c
		ON tmc.tmc = c.tmc_code
	LEFT JOIN #ff_speed ffs
		ON tmc.tmc = ffs.tmc_code
GROUP BY tmc.tmc,
		tmc.road,
		tmc.direction,
		CASE WHEN ffs.ff_speed_85th60th IS NULL THEN -1 ELSE ffs.ff_speed_85th60th END

--drop table #ff_speed
