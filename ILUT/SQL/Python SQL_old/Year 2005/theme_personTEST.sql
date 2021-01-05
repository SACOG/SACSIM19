--Summarize person data at parcel level
--Input tables: model output person file, population file
--Eventually, the output table of this should also be a temporary table once all steps can be consolidated into single script

--create temp table with all the attributes you want to summarize from all tables
SET NOCOUNT ON

IF OBJECT_ID('#temp_output', 'U') IS NOT NULL 
DROP TABLE #temp_output; --ilut person output table name

CREATE TABLE #temp_person (
	pertbl_pid INT,
	poptbl_pid INT,
	hhparcel INT,
	pptyp INT,
	ethc INT,
	pwpcl INT,
	dorm INT
	)

--populate the table
INSERT INTO #temp_person
	SELECT
		--complex casting needed in case any of the concatenated hhno/pno values start out as non-integers (i.e., have decimals)
		--this problem cropped up while loading the 2035 person table on 8/1/2018.
		CAST(CAST(per.hhno AS INT) AS NVARCHAR) + CAST(CAST(per.pno AS INT) AS NVARCHAR) AS pertbl_pid,
		0 AS poptbl_pid, --CAST(CAST(pop.serialno AS INT) AS NVARCHAR) + CAST(CAST(pop.pnum AS INT) AS NVARCHAR) AS poptbl_pid,
		hh.hhparcel AS hhcel, --pop.hhcel,
		per.pptyp,
		0 AS ethc, --pop.ethc,
		per.pwpcl, --usual work TAZ
		0 AS dorm --pop.dorm
	FROM raw_person2005_5 per --raw_person_testscen
		JOIN raw_hh2005_5 hh
			ON per.hhno = hh.hhno

CREATE TABLE #temp_wkrs_x_parcel (
	parcelid INT,
	workers_on_pcl INT
	)

--get all parcels with workers who have that parcel as their work location; enter zero workers if no workers have the parcel as their pwpcl
INSERT INTO #temp_wkrs_x_parcel	
	SELECT
		rp.parcelid,
		COUNT(tp.pwpcl) AS wrkrs_on_pcl
	FROM raw_parcel2005_5 rp --raw parcel table
		LEFT JOIN #temp_person tp
			ON rp.parcelid = tp.pwpcl
	GROUP BY rp.parcelid

--get count of people on each parcel by person type and ethnicity
--also get wo
SELECT
	wp.parcelid, --parcelid
	SUM(CASE WHEN tp.pertbl_pid IS NULL THEN 0 ELSE 1 END) AS POP_TOT, --total population based on person file
	SUM(CASE WHEN tp.dorm = 0 THEN 1 ELSE 0 END) AS POP_HH, --population not living in dorms
	SUM(CASE WHEN tp.pptyp = 1 THEN 1 ELSE 0 END) AS PPTYP1, --FT worker
	SUM(CASE WHEN tp.pptyp = 2 THEN 1 ELSE 0 END) AS PPTYP2, --PT worker
	SUM(CASE WHEN tp.pptyp = 3 THEN 1 ELSE 0 END) AS PPTYP3, --non-working age 65+
	SUM(CASE WHEN tp.pptyp = 4 THEN 1 ELSE 0 END) AS PPTYP4, --non-working age <65
	SUM(CASE WHEN tp.pptyp = 5 THEN 1 ELSE 0 END) AS PPTYP5, --univ student
	SUM(CASE WHEN tp.pptyp = 6 THEN 1 ELSE 0 END) AS PPTYP6, --HS student 16+
	SUM(CASE WHEN tp.pptyp = 7 THEN 1 ELSE 0 END) AS PPTYP7, --child age 5-15
	SUM(CASE WHEN tp.pptyp = 8 THEN 1 ELSE 0 END) AS PPTYP8, -- child age <5
	SUM(CASE WHEN tp.ethc = 1 THEN 1 ELSE 0 END) AS PPWHT,
	SUM(CASE WHEN tp.ethc = 2 THEN 1 ELSE 0 END) AS PPBLK,
	SUM(CASE WHEN tp.ethc = 3 THEN 1 ELSE 0 END) AS PPHIS,
	SUM(CASE WHEN tp.ethc = 4 THEN 1 ELSE 0 END) AS PPOTH, --Incl Asian/Pacific Islander
	SUM(CASE WHEN tp.hhparcel = tp.pwpcl THEN 1 ELSE 0 END) AS WAH, --work at home
	wp.workers_on_pcl AS WKRS_JOBLOCN --workers who use parcel as their primary work location (pwpcl)
INTO #temp_output --output theme table name
FROM #temp_wkrs_x_parcel wp 
	LEFT JOIN #temp_person tp
		ON tp.hhparcel = wp.parcelid 
GROUP BY wp.parcelid, wp.workers_on_pcl	

--drop the table to free space
--DROP TABLE #temp_person
--DROP TABLE #temp_wkrs_x_parcel

--SELECT top 100 * from #temp_output
--select top 100 * from #temp_person

select sum(case when pertbl_pid is null then 0 else 1 end) as tot_pop
FROM #temp_wkrs_x_parcel wp 
	LEFT JOIN #temp_person tp
		ON tp.hhparcel = wp.parcelid

select top 100 *
FROM #temp_wkrs_x_parcel wp 
	LEFT JOIN #temp_person tp
		ON tp.hhparcel = wp.parcelid