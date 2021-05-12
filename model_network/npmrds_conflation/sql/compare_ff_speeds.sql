/*
Name: compare_ff_speeds.sql
Purpose: Relevant to determining a method for calculating free-flow speeds for model links, compare following
	methods for getting a "free-flow" speed:
	1. 85th percentile speed between 8pm-6am
	2. 3am-6am harmonic avg speed between 3am-6am
	3. 3am-6am harmonic avg speed between 3am-6am, but average excludes records with extreme high travel times (above 99th percentile)
           
Author: Darren Conly
Last Updated: May 2021
Updated by: <name>
Copyright:   (c) SACOG
SQL Flavor: SQL Server
*/

--=========85TH PERCENTILE SPEED, NO OUTLIER EXCLUSION=========
SELECT
	DISTINCT tmc.tmc,
	tmc.f_system,
	PERCENTILE_CONT(0.85)
		WITHIN GROUP (ORDER BY speed)
		OVER (PARTITION BY tmc_code) 
		AS ffs_85
INTO #ffs_85
FROM npmrds_2019_all_tmcs_txt tmc --UPDATE YEAR HERE
	LEFT JOIN npmrds_2019_alltmc_paxtruck_comb tt --UPDATE YEAR HERE
		ON tmc.tmc = tt.tmc_code
WHERE (DATEPART(hh,measurement_tstamp) >= 20
		OR DATEPART(hh,measurement_tstamp) < 6)



--=========AVERAGE 3AM-6AM SPEED, NO OUTLIER EXCLUSION=========
SELECT
	tmc.tmc,
	tmc.f_system,
	COUNT(*) AS epochs_3a6a,
	COUNT(*) / SUM(1.0/tt.speed) AS havgspd_3a6a
INTO #ffs_3a6a
FROM npmrds_2019_all_tmcs_txt tmc --UPDATE YEAR HERE
	LEFT JOIN npmrds_2019_alltmc_paxtruck_comb tt --UPDATE YEAR HERE
		ON tmc.tmc = tt.tmc_code
GROUP BY 
	tmc.tmc,
	tmc.f_system





--=========AVERAGE 3AM-6AM SPEED, WITH OUTLIER EXCLUSION=========

--recommend creating view table that is the raw speed table with outliers removed
--don't run this query every time because it will be very slow.



--=========JOIN ALL SPEED TOGETHER, WITH OUTLIER EXCLUSION=========
--Fields needed: TMC, f_system, 85th pctl speed, 3am-6am average with outliers, 3am-6am average without outliers