
--Input tables: model output trip file w/skim data, model output tour table, 
			--IXXI trip table, commercial veh trip table, and count of jobs at each parcel taken by external workers (ixxi workers fraction.dat)


--Eventually, the output table of this should also be a temporary table once all steps can be consolidated into single script

SET NOCOUNT ON

IF OBJECT_ID('{5}', 'U') IS NOT NULL 
DROP TABLE {5}; --ilut person output table name

--===============BEGIN PROCESS FOR MAKING COMMERCIAL VEH DATA AT PARCEL LEVEL TABLE=========
CREATE TABLE #trips_jobs (
	parcelid INT,
	hh_p FLOAT,
	empret_p FLOAT,
	empfoo_p FLOAT,
	empedu_p FLOAT,
	empgov_p FLOAT,
	empofc_p FLOAT,
	empoth_p FLOAT,
	empsvc_p FLOAT,
	empmed_p FLOAT,
	empind_p FLOAT,
	taz_p INT,
	tripXjob_2ax FLOAT,
	tripXjob_3ax FLOAT
	)

INSERT INTO #trips_jobs
	SELECT 
		parcelid,
		hh_p,
		empret_p,
		empfoo_p,
		empedu_p,
		empgov_p,
		empofc_p,
		empoth_p,
		empsvc_p,
		empmed_p,
		empind_p,
		taz_p,
		CAST(1.23*(0.25*hh_p 
					+ 0.68*(empret_p+empfoo_p) 
					+ 0.40*(empedu_p+empgov_p+empofc_p+empoth_p+empsvc_p+empmed_p+empind_p)) AS FLOAT) 
		AS tripXjob_2ax, --estimated 2-axle commercial veh trips generated on parcel
		CAST(0.90*(0.003*hh_p
					+0.057*(empofc_p+empmed_p+empedu_p)
					+0.110*(empind_p+empoth_p)) AS FLOAT)
		AS tripXjob_3ax --estimated 3-axle commercial veh trips generated on parcel
	FROM {0} --raw scenario parcel file

--==========make table summing tripXjob factors at TAZ level===============

CREATE TABLE #trips_jobs_TAZ (
	taz INT,
	tripXjob_2axTAZ FLOAT,
	tripXjob_3axTAZ FLOAT
	)

INSERT INTO #trips_jobs_TAZ
	SELECT
		cv.I,
		SUM(t.tripXjob_2ax) AS tripXjob_2axTAZ,
		SUM(t.tripXjob_3ax) AS tripXjob_3axTAZ
	FROM {1} cv --raw cveh table
		LEFT JOIN #trips_jobs t
			ON cv.I = t.taz_p
	GROUP BY cv.I

--=======get commercial vehicle trip data at the parcel level===================

CREATE TABLE #pcl_cveh_data (
	parcelid INT,
	TAZ INT,
	tripXjob_2ax FLOAT,
	tripXjob_2axTAZ FLOAT,
	tripXjob_3ax FLOAT,
	tripXjob_3axTAZ FLOAT,
	CV2_VT FLOAT,
	CV2_VMT FLOAT,
	CV2_CVMT FLOAT,
	CV2_VHT FLOAT,
	CV3_VT FLOAT,
	CV3_VMT FLOAT,
	CV3_CVMT FLOAT,
	CV3_VHT FLOAT
	)

INSERT INTO #pcl_cveh_data
	SELECT
		p.parcelid,
		tjt.taz,
		tripXjob_2ax,
		tripXjob_2axTAZ,
		tripXjob_3ax,
		tripXjob_3axTAZ,
		--parcel-level P1 CV trips * total taz_p CV trips/P1 taz_p CV trips
		--concept: if parcel has X percent of P1 CV trips, it'll also have X percent of modeled total CV trips
		CASE WHEN tjt.tripXjob_2axTAZ = 0 THEN 0
			ELSE (tj.tripXjob_2ax/tjt.tripXjob_2axTAZ)*cv.C2_VT_I 
			END AS CV2_VT_P,
		CASE WHEN tjt.tripXjob_2axTAZ = 0 THEN 0
			ELSE (tj.tripXjob_2ax/tjt.tripXjob_2axTAZ)*cv.C2_VMT_I 
			END AS CV2_VMT_P,
		CASE WHEN tjt.tripXjob_2axTAZ = 0 THEN 0
			ELSE (tj.tripXjob_2ax/tjt.tripXjob_2axTAZ)*cv.C2_CVMT_I 
			END AS CV2_CVMT_P,
		CASE WHEN tjt.tripXjob_2axTAZ = 0 THEN 0
			ELSE (tj.tripXjob_2ax/tjt.tripXjob_2axTAZ)*cv.C2_VHT_I 
			END AS CV2_VHT_P,
		CASE WHEN tjt.tripXjob_3axTAZ = 0 THEN 0
			ELSE (tj.tripXjob_3ax/tjt.tripXjob_3axTAZ)*cv.C3_VT_I 
			END AS CV3_VT_P,
		CASE WHEN tjt.tripXjob_3axTAZ = 0 THEN 0
			ELSE (tj.tripXjob_3ax/tjt.tripXjob_3axTAZ)*cv.C3_VMT_I 
			END AS CV3_VMT_P,
		CASE WHEN tjt.tripXjob_3axTAZ = 0 THEN 0
			ELSE (tj.tripXjob_3ax/tjt.tripXjob_3axTAZ)*cv.C3_CVMT_I 
			END AS CV3_CVMT_P,
		CASE WHEN tjt.tripXjob_3axTAZ = 0 THEN 0
			ELSE (tj.tripXjob_3ax/tjt.tripXjob_3axTAZ)*cv.C3_VHT_I 
			END AS CV3_VHT_P
	FROM {1} cv --raw cveh table
		LEFT JOIN {0} p --raw scenario parcel file
			ON cv.I = p.taz_p
		LEFT JOIN #trips_jobs_TAZ tjt
			ON cv.I = tjt.taz
		LEFT JOIN #trips_jobs tj
			ON p.parcelid = tj.parcelid
	--WHERE p.parcelid IS NULL
	ORDER BY tjt.TAZ

DROP TABLE #trips_jobs
DROP TABLE #trips_jobs_TAZ

--====================BEGIN PROCESS FOR MAKING IXXI DATA AT PARCEL LEVEL TABLE=========

--===========get population and non-food/retail/service jobs by RAD==========

--need to first summarize population at parcel level because if you do direct sum of pop at RAD level, you'll get cartesian product (parcel row for each HH row, potential multiple counting)
CREATE TABLE #parcel_pop1 (
	parcelid INT,
	pcl_pop FLOAT
	)

INSERT INTO #parcel_pop1
	SELECT
		p.parcelid,
		SUM(CASE
			WHEN hh.hhsize IS NULL THEN 0 ELSE hhsize
			END) AS pop_pcl
	FROM {0} p --raw parcel table
		LEFT JOIN {3} hh --raw hh table
			ON p.parcelid = hh.hhparcel
	GROUP BY p.parcelid


CREATE TABLE #rad_pop_aggreg (
	RAD INT,
	pop_rad FLOAT,
	emp_rad FLOAT
	)

INSERT INTO #rad_pop_aggreg
	SELECT
		tr.RAD,
		SUM(p1.pcl_pop) AS pop_rad,
		SUM(CASE
			WHEN p.emptot_p-p.empfoo_p-p.empret_p-0.25*p.empsvc_p IS NULL THEN 0
			ELSE p.emptot_p-p.empfoo_p-p.empret_p-0.25*p.empsvc_p
			END) AS emp_rad
	FROM {0} p ----raw parcel table
		LEFT JOIN #parcel_pop1 p1 --raw hh table
			ON p.parcelid = p1.parcelid
		LEFT JOIN {2} tr  --taz-rad lookup table
			ON p.TAZ_p = tr.taz
	GROUP BY tr.RAD

--=================get residential and non-res IXXI trips at the TAZ then RAD level=============

--TAZ level
CREATE TABLE #taz_ixxi_vehdata (
	TAZ INT,
	RAD INT,
	IX_VT_RES FLOAT,
	IX_VHT_RES FLOAT,
	IX_VMT_RES FLOAT,
	IX_CVMT_RES FLOAT,
	IX_VT_TOT FLOAT,
	IX_VHT_TOT FLOAT,
	IX_VMT_TOT FLOAT,
	IX_CVMT_TOT FLOAT
	)

INSERT INTO #taz_ixxi_vehdata
	SELECT 
		ix.I,
		tr.RAD,
		(IX_VT_I+IX_VT_J)*(HHS/(1+HHS+1.1*(EMPTOT-FOOD-RET-0.25*SVC))) AS IX_VT_RES, --IX TRIPS MADE BY TAZ RESIDENTS, BOTH LEAVING AND ENDING IN TAZ
		(IX_VHT_I+IX_VHT_J)*(HHS/(1+HHS+1.1*(EMPTOT-FOOD-RET-0.25*SVC))) AS IX_VHT_RES,
		(IX_VMT_I+IX_VMT_J)*(HHS/(1+HHS+1.1*(EMPTOT-FOOD-RET-0.25*SVC))) AS IX_VMT_RES,
		(IX_CVMT_I+IX_CVMT_J)*(HHS/(1+HHS+1.1*(EMPTOT-FOOD-RET-0.25*SVC))) AS IX_CVMT_RES,
		(IX_VT_I+IX_VT_J) AS IX_VT_TOT, --TOTAL INTERNAL-EXTERNAL VEHICLE TRIPS
		(IX_VHT_I+IX_VHT_J) AS IX_VHT_TOT,
		(IX_VMT_I+IX_VMT_J)AS IX_VMT_TOT,
		(IX_CVMT_I+IX_CVMT_J) AS IX_CVMT_TOT
	FROM {4} ix --raw ixxi table
		LEFT JOIN {2} tr --taz-rad lookup table
			ON ix.I = tr.TAZ
	WHERE I > 30 --for all non-gateway TAZs

--TEMP STUFF 5/2/2018
--SELECT
	--RAD,
	--SUM(IX_VT_RES)
--FROM #taz_ixxi_vehdata WHERE RAD = 52
--GROUP BY RAD

--select * from #rad_pop_aggreg WHERE RAD = 52

--RAD level trip generation/vmt/cvmt/vht rates (per job, per person)
CREATE TABLE #rad_ixxi_rates (
	RAD INT,
	RES_VT_RATE FLOAT,
	RES_VHT_RATE FLOAT,
	RES_VMT_RATE FLOAT,
	RES_CVMT_RATE FLOAT,
	NRES_VT_RATE FLOAT, --NRES = non-resident, assumed to be employees traveling from outside the RAD
	NRES_VHT_RATE FLOAT,
	NRES_VMT_RATE FLOAT,
	NRES_CVMT_RATE FLOAT,
	)


INSERT INTO #rad_ixxi_rates
	SELECT
		ixr.RAD,
		CASE WHEN rpop.pop_rad > 0 THEN SUM(ixr.IX_VT_RES)/CAST(rpop.pop_rad AS FLOAT)
			ELSE 0
			END AS RES_VT_RATE, --resident-created vehicle trips per resident
		CASE WHEN rpop.pop_rad > 0 THEN SUM(ixr.IX_VHT_RES)/CAST(rpop.pop_rad AS FLOAT)
			ELSE 0
			END AS RES_VHT_RATE,
		CASE WHEN rpop.pop_rad > 0 THEN SUM(ixr.IX_VMT_RES)/CAST(rpop.pop_rad AS FLOAT)
			ELSE 0
			END AS RES_VMT_RATE,
		CASE WHEN rpop.pop_rad > 0 THEN SUM(ixr.IX_CVMT_RES)/CAST(rpop.pop_rad AS FLOAT)
			ELSE 0
			END AS RES_CVMT_RATE,
		CASE WHEN rpop.emp_rad > 0 THEN (SUM(ixr.IX_VT_TOT) - SUM(ixr.IX_VT_RES))/CAST(rpop.emp_rad AS FLOAT)
			ELSE 0
			END AS NRES_VT_RATE, 
		CASE WHEN rpop.emp_rad > 0 THEN (SUM(ixr.IX_VHT_TOT) - SUM(ixr.IX_VHT_RES))/CAST(rpop.emp_rad AS FLOAT)
			ELSE 0
			END AS NRES_VHT_RATE,
		CASE WHEN rpop.emp_rad > 0 THEN (SUM(ixr.IX_VMT_TOT) - SUM(ixr.IX_VMT_RES))/CAST(rpop.emp_rad AS FLOAT)
			ELSE 0
			END AS NRES_VMT_RATE,
		CASE WHEN rpop.emp_rad > 0 THEN (SUM(ixr.IX_CVMT_TOT) - SUM(ixr.IX_CVMT_RES))/CAST(rpop.emp_rad AS FLOAT)
			ELSE 0
			END AS NRES_CVMT_RATE
	FROM #taz_ixxi_vehdata ixr
		LEFT JOIN #rad_pop_aggreg rpop
			ON ixr.RAD = rpop.RAD
	GROUP BY ixr.RAD, rpop.pop_rad, rpop.emp_rad
	ORDER BY ixr.RAD

--=========get parcel-level IXXI vehicle trip generation data============================
--concept: the RAD-level per-job or per-resident IXXI travel rates (e.g., VT/person)
--will apply at the parcel level to all parcels within the RAD

CREATE TABLE #parcel_pop_emp (
	parcelid INT,
	pcl_pop FLOAT,
	emp_nretail_p FLOAT,
	tot_user_p FLOAT --total jobs + total hh pop on parcel
	)

INSERT INTO #parcel_pop_emp
	SELECT
		p.parcelid,
		p2.pcl_pop,
		CASE
			WHEN p.emptot_p-p.empfoo_p-p.empret_p-0.25*p.empsvc_p IS NULL THEN 0
			ELSE p.emptot_p-p.empfoo_p-p.empret_p-0.25*p.empsvc_p
		END AS emp_nretail_p,
		p.emptot_p + p2.pcl_pop AS tot_user_p
	FROM {0} p --raw scenario parcel file
		LEFT JOIN #parcel_pop1 p2 --raw hh file
			ON p.parcelid = p2.parcelid

CREATE TABLE #parcel_ixxi_data (
	parcelid INT,
	RAD INT,
	TAZ INT,
	pcl_pop FLOAT,
	pcl_emp_nretail FLOAT,
	pcl_tot_user FLOAT,
	IX_VT_RES FLOAT,
	IX_VMT_RES FLOAT,
	IX_CVMT_RES FLOAT,
	IX_VHT_RES FLOAT,
	IX_VT_NRES FLOAT,
	IX_VMT_NRES FLOAT,
	IX_CVMT_NRES FLOAT,
	IX_VHT_NRES FLOAT
	)

INSERT INTO #parcel_ixxi_data
	SELECT
		p.parcelid,
		rir.RAD,
		tr.TAZ,
		ppop.pcl_pop,
		ppop.emp_nretail_p,
		ppop.tot_user_p,
		CASE WHEN ppop.pcl_pop > 0 THEN ppop.pcl_pop*rir.RES_VT_RATE ELSE 0 END AS IX_VT_RES,
		CASE WHEN ppop.pcl_pop > 0 THEN ppop.pcl_pop*rir.RES_VMT_RATE ELSE 0 END AS IX_VMT_RES,
		CASE WHEN ppop.pcl_pop > 0 THEN ppop.pcl_pop*rir.RES_CVMT_RATE ELSE 0 END AS IX_CVMT_RES,
		CASE WHEN ppop.pcl_pop > 0 THEN ppop.pcl_pop*rir.RES_VHT_RATE ELSE 0 END AS IX_VHT_RES,
		CASE WHEN ppop.tot_user_p > 0 THEN ppop.emp_nretail_p*rir.NRES_VT_RATE ELSE 0 END AS IX_VT_NRES,
		CASE WHEN ppop.tot_user_p > 0 THEN ppop.emp_nretail_p*rir.NRES_VMT_RATE ELSE 0 END AS IX_VMT_NRES,
		CASE WHEN ppop.tot_user_p > 0 THEN ppop.emp_nretail_p*rir.NRES_CVMT_RATE ELSE 0 END AS IX_CVMT_NRES, --non-resident IXXI vmt = total parcel jobs * parcel's non-res VMT rate (# of NON-RETAIL employees * non-res IX VMT per employee = parcel's total non-res VMT)
		CASE WHEN ppop.tot_user_p > 0 THEN ppop.emp_nretail_p*rir.NRES_VHT_RATE ELSE 0 END AS IX_VHT_NRES
	FROM {2} tr --tazrad lookup table
		LEFT JOIN #rad_ixxi_rates rir --left join to ensure all RADs initially included
			ON tr.RAD = rir.RAD
		JOIN {0} p --raw scen parcel table; do inner join because we don't want RADs/TAZs without parcels returned
			ON tr.TAZ = p.taz_p
		LEFT JOIN #parcel_pop_emp ppop --left join so all parcels included
			ON p.parcelid = ppop.parcelid
	WHERE p.parcelid IS NOT NULL

SELECT
	pcv.*, --all the cveh data at parcel level, includes parcelid, TAZ cols
	pix.RAD,
	pix.pcl_pop,
	pix.pcl_emp_nretail,
	pix.pcl_tot_user,
	pix.IX_VT_RES,
	pix.IX_VMT_RES,
	pix.IX_CVMT_RES,
	pix.IX_VHT_RES,
	pix.IX_VT_RES + pix.IX_VT_NRES AS IX_VT,
	pix.IX_VMT_RES + IX_VMT_NRES AS IX_VMT,
	pix.IX_CVMT_RES + IX_CVMT_NRES AS IX_CVMT,
	pix.IX_VHT_RES + IX_VHT_NRES AS IX_VHT
INTO {5} --cveh-ixxi output ilut table
FROM #parcel_ixxi_data pix
	JOIN #pcl_cveh_data pcv
		ON pix.parcelid = pcv.parcelid

DROP TABLE #rad_pop_aggreg
DROP TABLE #taz_ixxi_vehdata
DROP TABLE #rad_ixxi_rates
DROP TABLE #parcel_pop_emp
DROP TABLE #parcel_ixxi_data
DROP TABLE #pcl_cveh_data

--SELECT * FROM #parcel_ixxi_data
--SELECT * FROM #pcl_cveh_data
