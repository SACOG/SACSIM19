
--Summarize hh data at parcel level
--Script version for model runs WITH AVs ENABLED
--Input tables: model output hh file, population file
--FYI - RELATE = 0 in the pop file indicates head of household. Dorm HHs do not have a household head.

--Eventually, the output table of this should also be a temporary table once all steps can be consolidated into single script
SET NOCOUNT ON

IF OBJECT_ID('{3}', 'U') IS NOT NULL 
DROP TABLE {3}; --ilut person output table name

CREATE TABLE #temp_pers_relate (
	serialno INT,
	hh_hd_type INT
	)

--get each hh's head age category
INSERT INTO #temp_pers_relate
	SELECT DISTINCT
		serialno,
		CASE 
			WHEN RELATE = 0 AND AGE < 35 THEN 1
			WHEN RELATE = 0 AND AGE >= 35 AND AGE < 65 THEN 2
			WHEN RELATE = 0 AND AGE >= 65 THEN 3
		END AS hh_hd_type
	FROM {0} --raw population table
	WHERE RELATE = 0

--create temp table with all the attributes you want to summarize from all tables
CREATE TABLE #temp_hh (
	parcelid INT,
	hhno INT,
	hhincome INT,
	hh_hd_type INT,
	hrestype INT, --0/1; 1 means any HH vehicles are AVs
	hhvehs INT
	)



--populate the table w hh level data
INSERT INTO #temp_hh
	SELECT DISTINCT
		pop.hhcel,
		pop.serialno,
		hh.hhincome,
		CASE WHEN tp.hh_hd_type IS NULL THEN 0 ELSE tp.hh_hd_type END AS hh_hd_type, --
		hh.hrestype,
		hh.hhvehs
	FROM {0} pop --raw population table
		JOIN {1} hh --raw hh table
			ON pop.serialno = hh.hhno 
		LEFT JOIN #temp_pers_relate tp
			ON pop.serialno = tp.serialno


--get count of hhs on each parcel by income, hh head age, and vehicle type, and if dorms
SELECT
	p.parcelid,
	COUNT(hhno) AS HH_TOT_P, --count of all HHs, including dorm HHs
	SUM(CASE WHEN hh_hd_type = 0 OR hh_hd_type IS NULL THEN 0 ELSE 1 END) AS HH_hh, --total HHs minus dorm HHs
	SUM(CASE WHEN hhincome < 15000 THEN 1 ELSE 0 END) AS HH_INC_1,
	SUM(CASE WHEN hhincome >= 15000 AND hhincome < 30000 THEN 1 ELSE 0 END) AS HH_INC_2,
	SUM(CASE WHEN hhincome >= 30000 AND hhincome < 50000 THEN 1 ELSE 0 END) AS HH_INC_3,
	SUM(CASE WHEN hhincome >= 50000 AND hhincome < 75000 THEN 1 ELSE 0 END) AS HH_INC_4,
	SUM(CASE WHEN hhincome >= 75000 THEN 1 ELSE 0 END) AS HH_INC_5,
	SUM(CASE WHEN hh_hd_type = 1 THEN 1 ELSE 0 END) AS HH_HD_1, --head of hh age <35
	SUM(CASE WHEN hh_hd_type = 2 THEN 1 ELSE 0 END) AS HH_HD_2, --head of hh age 35-64
	SUM(CASE WHEN hh_hd_type = 3 THEN 1 ELSE 0 END) AS HH_HD_3, --head of hh age 65+
	SUM(CASE WHEN hhvehs IS NULL THEN 0 ELSE hhvehs END) AS VEHICLE,
	SUM(CASE WHEN hhvehs = 0 THEN 1 ELSE 0 END) AS HH_NOVEH,
	SUM(CASE WHEN hrestype = 1 THEN hhvehs ELSE 0 END) AS VEH_AV
INTO {3}
FROM {2} p --raw scenario parcel table
	LEFT JOIN #temp_hh th
		ON p.parcelid = th.parcelid
GROUP BY p.parcelid 		

--drop the table to free space
DROP TABLE #temp_hh
DROP TABLE #temp_pers_relate
