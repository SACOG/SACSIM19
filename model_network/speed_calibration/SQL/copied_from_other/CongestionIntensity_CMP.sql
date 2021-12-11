/*
Name: CongestionIntensity_CMP.sql
Purpose: Get data for each TMC for CMP 2020 congestion calcs:
	TMC code,
	Road name,
	Road number,
	F_System,
	off-peak free-flow speed (85th pctl for fwys; for arterials is 60th pctl to account for signal delay, 8pm-6am, all days),
	Avg speed during worst 4 weekday hours,
	Worst hour of day,
	Avg hours per day with data,
	Count of epochs:
		All times
	1/0 NHS status

NOTE - Unlike the MAP-21 based reliability metrics, these congestion metrics are only for TMCs that are
within the CMP metric. The rationale for this extent difference is that we want the reliability metrics to
be completely consistent with MAP-21. OR is it better to limit to CMP network???
           
Author: Darren Conly
Last Updated: June 2020
Updated by: <name>
Copyright:   (c) SACOG
SQL Flavor: SQL Server
*/

--==========PARAMETER VARIABLES=============================================================
USE NPMRDS
GO

--"bad" travel time percentile
DECLARE @PctlCongested FLOAT SET @PctlCongested = 0.8

--free-flow speed time period
DECLARE @FFprdStart INT SET @FFprdStart = 20 --free-flow period starts at or after this time at night
DECLARE @FFprdEnd INT SET @FFprdEnd = 6 --free-flow period ends before this time in the morning

--list of weekdays
DECLARE @weekdays TABLE (day_name VARCHAR(9))
	INSERT INTO @weekdays VALUES ('Monday')
	INSERT INTO @weekdays VALUES ('Tuesday')
	INSERT INTO @weekdays VALUES ('Wednesday')
	INSERT INTO @weekdays VALUES ('Thursday')
	INSERT INTO @weekdays VALUES ('Friday')


--===========CONGESTION METRICS==================================
--get free-flow speed, based on 8p-6a speed
SELECT
	DISTINCT tmc.tmc,
	tmc.f_system,
	CASE WHEN f_system IN (1,2) 
		THEN PERCENTILE_CONT(0.85)
			WITHIN GROUP (ORDER BY speed)
			OVER (PARTITION BY tmc_code) 
		ELSE PERCENTILE_CONT(0.6) 
			WITHIN GROUP (ORDER BY speed)
			OVER (PARTITION BY tmc_code) 
		END AS ff_speed_art60thp --85th percentile speed for freeways; 60th percentile for arterials
INTO #ff_spd_tbl
FROM npmrds_2017_all_tmcs_txt tmc --UPDATE YEAR HERE
	LEFT JOIN npmrds_2016_alltmc_paxtruck_comb tt --UPDATE YEAR HERE
		ON tmc.tmc = tt.tmc_code
WHERE (DATEPART(hh,measurement_tstamp) >= @FFprdStart
		OR DATEPART(hh,measurement_tstamp) < @FFprdEnd)


--get count of epochs during overnight "free flow" period
SELECT
	tmc_code,
	COUNT(*) AS epochs_night
INTO #offpk_85th_epochs
FROM npmrds_2016_alltmc_paxtruck_comb --UPDATE YEAR HERE
WHERE DATEPART(hh,measurement_tstamp) >= 20 --@FFprdStart
		OR DATEPART(hh,measurement_tstamp) < 6 --@FFprdEnd
GROUP BY tmc_code


--get speeds by hour of day, long table
SELECT
	tt.tmc_code,
	DATEPART(hh,tt.measurement_tstamp) AS hour_of_day,
	COUNT(*) AS total_epochs_hr,
	ff.ff_speed_art60thp,
	COUNT(*) / SUM(1.0/tt.speed) AS havg_spd_weekdy,
	AVG(tt.travel_time_seconds) AS avg_tt_sec_weekdy,
	(COUNT(*) / SUM(1.0/tt.speed)) / ff.ff_speed_art60thp AS cong_ratio_hr_weekdy,
	RANK() OVER (
		PARTITION BY tt.tmc_code 
		ORDER BY (COUNT(*) / SUM(1.0/tt.speed)) / ff.ff_speed_art60thp ASC
		) AS hour_cong_rank
INTO #avspd_x_tmc_hour
FROM npmrds_2016_alltmc_paxtruck_comb tt --UPDATE YEAR HERE
	JOIN #ff_spd_tbl ff
		ON tt.tmc_code = ff.tmc
WHERE DATENAME(dw, measurement_tstamp) IN (SELECT day_name FROM @weekdays) 
GROUP BY 
	tt.tmc_code,
	DATEPART(hh,measurement_tstamp),
	ff.ff_speed_art60thp
HAVING COUNT(tt.measurement_tstamp) >= 100 --eliminate hours where there's little to no data


--get harmonic average speed from epochs that are in the worst 4 weekday hours
SELECT
	tt.tmc_code,
	COUNT(*) AS epochs_worst4hrs,
	ff.ff_speed_art60thp,
	COUNT(*) / SUM(1.0/tt.speed) AS havg_spd_worst4hrs
INTO #most_congd_hrs
FROM npmrds_2016_alltmc_paxtruck_comb tt --UPDATE YEAR HERE
	JOIN #ff_spd_tbl ff
		ON tt.tmc_code = ff.tmc
	JOIN #avspd_x_tmc_hour avs
		ON tt.tmc_code = avs.tmc_code
		AND DATEPART(hh, tt.measurement_tstamp) = avs.hour_of_day
WHERE DATENAME(dw, tt.measurement_tstamp) IN (SELECT day_name FROM @weekdays) 
	AND avs.hour_cong_rank < 5
	--AND tt.tmc_code = '105+04687'
GROUP BY 
	tt.tmc_code,
	ff.ff_speed_art60thp


--return most congested hour of the day
SELECT DISTINCT tt.tmc_code,
	COUNT(tt.measurement_tstamp) AS epochs_slowest_hr,
	avs.hour_of_day AS slowest_hr,
	avs.havg_spd_weekdy AS slowest_hr_speed
INTO #slowest_hr
FROM npmrds_2016_alltmc_paxtruck_comb tt --UPDATE YEAR HERE
	JOIN #avspd_x_tmc_hour avs
		ON tt.tmc_code = avs.tmc_code
		AND DATEPART(hh, tt.measurement_tstamp) = avs.hour_of_day
WHERE avs.hour_cong_rank = 1
	AND DATENAME(dw, tt.measurement_tstamp) IN (SELECT day_name FROM @weekdays) 
GROUP BY tt.tmc_code, avs.hour_of_day, avs.havg_spd_weekdy 


--=========COMBINE ALL TOGETHER FOR FINAL TABLE==================================


--Set up as subquery to eliminate duplicate rows (some TMCs got duplicated bcause there were 2 or more hours with congestion rank of 1)
SELECT * INTO #final_cong_tbl FROM (
	SELECT
		tmc.tmc,
		tmc.road,
		tmc.route_numb,
		tmc.f_system,
		tmc.nhs,
		tmc.miles,
		tmc.cmp_tag,
		CASE WHEN ffs.ff_speed_art60thp IS NULL THEN -1.0 ELSE ffs.ff_speed_art60thp END AS ff_speed_art60thp,
		CASE WHEN cong4.havg_spd_worst4hrs IS NULL THEN -1.0 ELSE cong4.havg_spd_worst4hrs END AS havg_spd_worst4hrs,
		CASE WHEN cong4.havg_spd_worst4hrs / ffs.ff_speed_art60thp IS NULL THEN -1.0 
			WHEN cong4.havg_spd_worst4hrs / ffs.ff_speed_art60thp > 1 THEN 1.0 --sometimes the overnight speed won't be the fastest speed if there are insufficient data
			ELSE cong4.havg_spd_worst4hrs / ffs.ff_speed_art60thp
			END AS congratio_worst4hrs,
		CASE WHEN slowest1.slowest_hr IS NULL THEN -1 ELSE slowest1.slowest_hr END AS slowest_hr,
		CASE WHEN slowest1.slowest_hr_speed IS NULL THEN -1 ELSE slowest1.slowest_hr_speed END AS slowest_hr_speed,
		CASE WHEN slowest1.slowest_hr_speed / ffs.ff_speed_art60thp IS NULL THEN -1.0 
			ELSE slowest1.slowest_hr_speed / ffs.ff_speed_art60thp
			END AS congratio_worsthr,
		CASE WHEN cong4.epochs_worst4hrs IS NULL THEN -1 ELSE cong4.epochs_worst4hrs END AS epochs_worst4hrs,
		CASE WHEN slowest1.epochs_slowest_hr IS NULL THEN -1 ELSE slowest1.epochs_slowest_hr END AS epochs_slowest_hr,
		CASE WHEN epon.epochs_night IS NULL THEN -1 ELSE epon.epochs_night END AS epochs_night,
		ROW_NUMBER() OVER (PARTITION BY tmc.tmc ORDER BY slowest1.slowest_hr_speed) AS tmc_appearance_n
	FROM npmrds_2017_all_tmcs_txt tmc --UPDATE YEAR HERE
		LEFT JOIN #ff_spd_tbl ffs
			ON tmc.tmc = ffs.tmc
		LEFT JOIN #most_congd_hrs cong4
			ON tmc.tmc = cong4.tmc_code
		LEFT JOIN #slowest_hr slowest1
			ON tmc.tmc = slowest1.tmc_code
		LEFT JOIN #offpk_85th_epochs epon
			ON tmc.tmc = epon.tmc_code
	) subqry1
WHERE tmc_appearance_n = 1

--get ratio of CMP congested miles
SELECT
	CASE WHEN f_system = 1 THEN 'Interstate CMP' ELSE 'Non-Interstate CMP' END AS FSystem,
	SUM(CASE WHEN congratio_worst4hrs > 0 AND congratio_worst4hrs < 0.6 THEN miles ELSE 0 END)
		AS cong_dirmiles,
	SUM(CASE WHEN congratio_worst4hrs > 0 THEN miles ELSE 0 END)
		AS tot_dirmiles,
	SUM(CASE WHEN congratio_worst4hrs > 0 AND congratio_worst4hrs < 0.6 THEN miles ELSE 0 END) /
		SUM(CASE WHEN congratio_worst4hrs > 0 THEN miles ELSE 0 END) AS pct_cong_dirmiles
FROM #final_cong_tbl
WHERE cmp_tag = 1
GROUP BY CASE WHEN f_system = 1 THEN 'Interstate CMP' ELSE 'Non-Interstate CMP' END

SELECT
	tmc,
	road,
	route_numb,
	cmp_tag,
	f_system,
	nhs,
	miles,
	ff_speed_art60thp,
	havg_spd_worst4hrs,
	congratio_worst4hrs,
	slowest_hr,
	slowest_hr_speed,
	congratio_worsthr,
	epochs_worst4hrs,
	epochs_slowest_hr,
	epochs_night
FROM #final_cong_tbl

/*
DROP TABLE #tt_pctl_ampk
DROP TABLE #tt_pctl_midday
DROP TABLE #tt_pctl_pmpk
DROP TABLE #tt_pctl_weekend
DROP TABLE #ff_spd_tbl
DROP TABLE #avspd_x_tmc_hour
DROP TABLE #most_congd_hrs
DROP TABLE #slowest_hr
DROP TABLE #offpk_85th_epochs
DROP TABLE #final_cong_tbl
*/

