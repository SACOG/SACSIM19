/*
Name: cong_speed_model_prds.sql
Purpose: calculate congested speeds for 9 SACSIM time periods.
           
Author: Darren Conly
Last Updated: <date>
Updated by: <name>
Copyright:   (c) SACOG
SQL Flavor: SQL Server
*/


USE NPMRDS
GO


--list of weekdays
DECLARE @weekdays TABLE (day_name VARCHAR(9))
	INSERT INTO @weekdays VALUES ('Tuesday')
	INSERT INTO @weekdays VALUES ('Wednesday')
	INSERT INTO @weekdays VALUES ('Thursday')


SELECT
	tmc_code,
	measurement_tstamp,
	speed
INTO #speeds_prd
FROM npmrds_2016_alltmc_paxtruck_comb tt
WHERE DATEPART(mm, tt.measurement_tstamp) IN ('3', '4', '5', '10')
	AND DATENAME(dw, tt.measurement_tstamp) IN (SELECT day_name FROM @weekdays)
	AND DATEPART(hh, tt.measurement_tstamp) IN (7)

SELECT
	tmc.tmc,
	COUNT(*) / SUM(1.0/sp.speed) AS avspd_h07,
	COUNT(*) AS epcnt_h07,
	STDEV(sp.speed) AS spd_stdev_h07,
	STDEV(sp.speed) / (COUNT(*) / SUM(1.0/sp.speed)) AS spd_stderr_h07
FROM npmrds_2020_alltmc_txt tmc
	LEFT JOIN #speeds_prd sp
		ON tmc.tmc = sp.tmc_code
--WHERE tmc.tmc = '105-16680'
GROUP BY tmc.tmc

--DROP TABLE #speeds_prd