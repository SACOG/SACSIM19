/*
Purpose: get aggregate values of ILUT variables at desired aggregation level (whole region, RAD, TAZ, block group, census tract, county, etc)
Comment/uncomment and edit the GROUP BY statement at the bottom as needed.

Following fields are weighted by population: mix index, mix-density index, half-mile employment, half-mile hhs, transit stop distances,
*/

--drop table mtpuser.ilut_combined2040_20_ppaMay19_grid_id

USE MTP2020

SELECT 
	--TAZ07,
	--RAD07_new,
	--GRID_ID, --Hexagon within which the parcel's centroid falls
    county,tract10,
	--JURIS,
	--plan_area,
	--county,tpa_40,
	--county,tpa_16,
	--ComType_BO,
	
	--TPA_16,
	--TPA_40,
	--TPA36_16,
	--EJ_2018,
	--PJOBC_NAME,
	--PJOBC_4MI,
	--PSJOBC_4MI,
	--BG_10,
	--TRACT10,
	--lutype,
	--grid_id,
	SUM(GISac) AS ACRES,
	SUM(DU_TOT) AS DU_TOT,
	SUM(POP_TOT) AS POP_TOT,
	SUM(POP_HH) AS POP_HH,
	SUM(PPTYP1) AS PPTYP1,
	SUM(PPTYP2) AS PPTYP2,
	SUM(PPTYP3) AS PPTYP3,
	SUM(PPTYP4) AS PPTYP4,
	SUM(PPTYP5) AS PPTYP5,
	SUM(PPTYP6) AS PPTYP6,
	SUM(PPTYP7) AS PPTYP7,
	SUM(PPTYP8) AS PPTYP8,
	SUM(PPWHT) AS PPWHT,
	SUM(PPHIS) AS PPHIS,
	SUM(PPBLK) AS PPBLK,
	SUM(PPOTH) AS PPOTH,
	SUM(WAH) AS WAH,
	SUM(WKRS_JOBLOCN) AS WKRS_JOBLOCN,
	SUM(HH_TOT_P) AS HH_TOT_P,
	SUM(HH_hh) AS HH_hh,
	SUM(HH_INC_1) AS HH_INC_1,
	SUM(HH_INC_2) AS HH_INC_2,
	SUM(HH_INC_3) AS HH_INC_3,
	SUM(HH_INC_4) AS HH_INC_4,
	SUM(HH_INC_5) AS HH_INC_5,
	SUM(HH_HD_1) AS HH_HD_1,
	SUM(HH_HD_2) AS HH_HD_2,
	SUM(HH_HD_3) AS HH_HD_3,
	SUM(VEHICLE) AS VEHICLE,
	SUM(HH_NOVEH) AS HH_NOVEH,
	SUM(VEH_AV) AS VEH_AV,
	SUM(ENR_K12) AS ENR_K12,
	SUM(ENR_UNI) AS ENR_UNI,
	SUM(EMPTOT) AS EMPTOT,
	SUM(EMPEDU) AS EMPEDU,
	SUM(EMPFOOD) AS EMPFOOD,
	SUM(EMPGOV) AS EMPGOV,
	SUM(EMPOFC) AS EMPOFC,
	SUM(EMPOTH) AS EMPOTH,
	SUM(EMPRET) AS EMPRET,
	SUM(EMPSVC) AS EMPSVC,
	SUM(EMPMED) AS EMPMED,
	SUM(EMPIND) AS EMPIND,
	SUM(HOMEEMP) AS HOMEEMP,
	SUM(DAYPARKS) AS DAYPARKS,
	CASE WHEN SUM(POP_TOT+emptot) = 0
			OR SUM(CASE WHEN DIST_BUS < 999 THEN (POP_TOT+emptot) ELSE NULL END) = 0 THEN -1 --if subarea has no people in it, we can't know pop-weighted avg bus distance, so set to -1
			--potential change: if subarea has no people, then get unweighted average distance from parcel to bus stop.
		ELSE SUM(CASE WHEN DIST_BUS < 999 AND DIST_BUS >= 0 --exclude values of -1, which represents parcels with missing data
			THEN (POP_TOT+emptot) * DIST_BUS
			ELSE NULL END) / 
			SUM(CASE WHEN DIST_BUS < 999 AND DIST_BUS >= 0
			THEN POP_TOT+emptot 
			ELSE NULL END)
		END AS DIST_BUS,
	CASE WHEN SUM(POP_TOT+emptot) = 0
			OR SUM(CASE WHEN DIST_LRT < 999 THEN POP_TOT ELSE NULL END) = 0 THEN -1 
		ELSE SUM(CASE WHEN DIST_LRT < 999 AND DIST_LRT >= 0
			THEN (POP_TOT+emptot) * DIST_LRT
			ELSE NULL END) / 
			SUM(CASE WHEN DIST_LRT < 999 AND DIST_LRT >= 0
			THEN POP_TOT+emptot
			ELSE NULL END)
		END AS DIST_LRT,
	CASE WHEN SUM(POP_TOT+emptot) = 0
			OR SUM(CASE WHEN DIST_MIN < 5 THEN POP_TOT ELSE NULL END) = 0 THEN -1 
		ELSE SUM(CASE WHEN DIST_MIN < 5 AND DIST_MIN >= 0
			THEN (POP_TOT+emptot) * DIST_MIN
			ELSE NULL END) / 
			SUM(CASE WHEN DIST_MIN < 5 AND DIST_MIN >= 0
			THEN POP_TOT+emptot 
			ELSE NULL END)
		END AS DIST_MIN,
	CASE WHEN SUM(POP_TOT+emptot) = 0 THEN -1 --case statement to avoide divide-by-zero error; if no pop then we can't know pop-weighted avearge
		ELSE SUM(CASE WHEN NODES1H = -1 THEN 0 ELSE (POP_TOT+emptot)*NODES1H END)/SUM(POP_TOT+emptot) END AS NODES1H, --population-weighted cul-de-sacs within half mile
	CASE WHEN SUM(POP_TOT+emptot) = 0 THEN -1 --if parcel lacks node data then it also lacks pop data, so we don't factor these in.
		ELSE SUM(CASE WHEN NODES3H = -1 THEN 0 ELSE (POP_TOT+emptot)*NODES3H END)/SUM(POP_TOT+emptot) END AS NODES3H,
	CASE WHEN SUM(POP_TOT+emptot) = 0 THEN -1
		ELSE SUM(CASE WHEN NODES4H = -1 THEN 0 ELSE (POP_TOT+emptot)*NODES4H END)/SUM(POP_TOT+emptot) END AS NODES4H,
	CASE WHEN SUM(POP_TOT+emptot) = 0 THEN -1
		ELSE SUM(CASE WHEN MIXINDEX = -1 THEN 0 ELSE (POP_TOT+emptot)*MIXINDEX END)/SUM(POP_TOT+emptot) END AS MIXINDEX,
	CASE WHEN SUM(POP_TOT+emptot) = 0 THEN -1
		ELSE SUM(CASE WHEN MIX_DENS = -1 THEN 0 ELSE (POP_TOT+emptot)*MIX_DENS END)/SUM(POP_TOT+emptot) END AS MIX_DENS, --pop-weighted average mix index, but should this be job weighted? or unweighted?
	CASE WHEN SUM(POP_TOT+emptot) = 0 THEN -1
		ELSE SUM((POP_TOT+emptot)*HH_BUF2)/SUM(POP_TOT+emptot) END AS HH_BUF2,
	CASE WHEN SUM(POP_TOT+emptot) = 0 THEN -1
		ELSE SUM((POP_TOT+emptot)*EMP_BUF2)/SUM(POP_TOT+emptot) END AS EMP_BUF2,
	SUM(PT_TOT_RES) AS PT_TOT_RES,
	SUM(PTO_TOT_RES) AS PTO_TOT_RES,
	SUM(VT_TOT_RES) AS VT_TOT_RES,
	SUM(PT_WRK_RES) AS PT_WRK_RES,
	SUM(PTO_WRK_RES) AS PTO_WRK_RES,
	SUM(VT_WRK_RES) AS VT_WRK_RES,
	SUM(SOV_TOT_RES) AS SOV_TOT_RES,
	SUM(HOV_TOT_RES) AS HOV_TOT_RES,
	SUM(TRN_TOT_RES) AS TRN_TOT_RES,
	SUM(BIK_TOT_RES) AS BIK_TOT_RES,
	SUM(WLK_TOT_RES) AS WLK_TOT_RES,
	SUM(SCB_TOT_RES) AS SCB_TOT_RES,
	SUM(TNC_TOT_RES) AS TNC_TOT_RES,
	SUM(SOV_WRK_RES) AS SOV_WRK_RES,
	SUM(HOV_WRK_RES) AS HOV_WRK_RES,
	SUM(TRN_WRK_RES) AS TRN_WRK_RES,
	SUM(BIK_WRK_RES) AS BIK_WRK_RES,
	SUM(WLK_WRK_RES) AS WLK_WRK_RES,
	SUM(TNC_WRK_RES) AS TNC_WRK_RES,
	SUM(PTOURSOV) AS PTOURSOV,
	SUM(PTOURHOV) AS PTOURHOV,
	SUM(PTOURTRN) AS PTOURTRN,
	SUM(PTOURBIK) AS PTOURBIK,
	SUM(PTOURWLK) AS PTOURWLK,
	SUM(PTOURSCB) AS PTOURSCB,
	SUM(PTOURTNC) AS PTOURTNC,
	SUM(WTOURSOV) AS WTOURSOV,
	SUM(WTOURHOV) AS WTOURHOV,
	SUM(WTOURTRN) AS WTOURTRN,
	SUM(WTOURBIK) AS WTOURBIK,
	SUM(WTOURWLK) AS WTOURWLK,
	SUM(WTOURTNC) AS WTOURTNC,
	SUM(II_VMT_RES) AS II_VMT_RES,
	SUM(VMT_WRK_RES) AS VMT_WRK_RES,
	SUM(II_CVMT_RES) AS II_CVMT_RES, --old column name: CVMT_TOT_RES; changed to II_CVMT_RES on 3/1/2019
	SUM(CVMT_WRK_RES) AS CVMT_WRK_RES,
	SUM(PHR_TOT_RES) AS PHR_TOT_RES,
	SUM(VHR_TOT_RES) AS VHR_TOT_RES,
	SUM(PHR_WRK_RES) AS PHR_WRK_RES,
	SUM(VHR_WRK_RES) AS VHR_WRK_RES,
	SUM(GMI_TOT_RES) AS GMI_TOT_RES,
	SUM(GMI_HH_E) AS GMI_HH_E,
	SUM(GMI_HH_C) AS GMI_HH_C,
	SUM(IX_VT_RES) AS IX_VT_RES,
	SUM(IX_VMT_RES) AS IX_VMT_RES,
	SUM(IX_CVMT_RES) AS IX_CVMT_RES,
	SUM(IX_VHT_RES) AS IX_VHT_RES,
	SUM(VMT_TOT_RES) AS VMT_TOT_RES,
	SUM(IX_VT) AS IX_VT,
	SUM(IX_VMT) AS IX_VMT,
	SUM(IX_CVMT) AS IX_CVMT,
	SUM(IX_VHT) AS IX_VHT,
	SUM(CV2_VT) AS CV2_VT,
	SUM(CV3_VT) AS CV3_VT,
	SUM(CV2_VMT) AS CV2_VMT,
	SUM(CV3_VMT) AS CV3_VMT,
	SUM(CV2_CVMT) AS CV2_CVMT,
	SUM(CV3_CVMT) AS CV3_CVMT,
	SUM(CV2_VHT) AS CV2_VHT,
	SUM(CV3_VHT) AS CV3_VHT,
	SUM(JOB_ExWorker) AS JOB_ExWorker,
	SUM(VMT_wrk_tourend) AS VMT_wrk_tourend,
	SUM(CVMT_wrk_tourend) AS CVMT_wrk_tourend,
	SUM(VT_wrk_tourend) AS VT_wrk_tourend,
	SUM(PT_wrk_tourend) AS PT_wrk_tourend,
	SUM(SOV_wrk_tourend) AS SOV_wrk_tourend,
	SUM(HOV_wrk_tourend) AS HOV_wrk_tourend,
	SUM(TRN_wrk_tourend) AS TRN_wrk_tourend,
	SUM(BIK_wrk_tourend) AS BIK_wrk_tourend,
	SUM(WLK_wrk_tourend) AS WLK_wrk_tourend,
	SUM(TNC_wrk_tourend) AS TNC_wrk_tourend,
	SUM(TRN_LBUS_RES) AS TRN_LBUS_RES,
	SUM(TRN_LRT_RES) AS TRN_LRT_RES,  
	SUM(TRN_EBUS_RES) AS TRN_EBUS_RES,
	sum(EMPTOT)+sum(HOMEEMP) as emtot_hb,
	sum(case when du_tot>0 then GISac else 0 end) as GISac_DU,
	sum(case when emptot>0 then GISac else 0 end) as GISac_emp
	--into mtpuser.ilut_combined2040_51_TAZ
FROM 
   --mtpuser.ilut_combined2016_50 -- base - adopted
	--mtpuser.ilut_combined2027_2 -- base
	--mtpuser.ilut_combined2035_130  -- base
	--mtpuser.ilut_combined2035_129 -- pricing
	--mtpuser.ilut_combined2035_201 -- pricing + goldGreen InterLine
	--mtpuser.ilut_combined2035_202 -- pricing + goldGreen InterLine + BRT
	--mtpuser.ilut_combined2040_51 -- base - adopted
	mtpuser.ilut_combined2040_50 -- pricing - adopted

	--mtpuser.ilut_combined2035_119
	--[mtpuser].[ilut_combined2012_1]
	--group by county
    --order by county
	--group by juris
	--order by juris
	--group by plan_area
	--order by plan_area
	--group by county,tpa_40
	--order by county,tpa_40
	--group by juri
	--order by juri
	--group by EJ_2018
	--order by EJ_2018
	group by county,tract10
	order by county,tract10

	--group by county,tpa_16
	--order by county,tpa_16
	--GROUP BY TAZ07
     --order by TAZ07
    --GROUP BY RAD07_new
   -- order by RAD07_new
	--group by comtype_bo
	--order by comtype_bo
    --group by PJOBC_NAME
    --order by PJOBC_NAME
    --group by tpa36_16
	--order by tpa36_16

	--select * from mtpuser.ilut_combined2035_129_TAZ
  
--  select 
   
--	SUM(EMPEDU) AS EMPEDU,
--	SUM(EMPFOOD) AS EMPFOOD,
--	SUM(EMPGOV) AS EMPGOV,
--	SUM(EMPIND) AS EMPIND,
--	SUM(EMPMED) AS EMPMED,
--	SUM(EMPOFC) AS EMPOFC,
--	SUM(EMPOTH) AS EMPOTH,
--	SUM(EMPRET) AS EMPRET,
--	SUM(EMPSVC) AS EMPSVC,
--	SUM(HOMEEMP) AS HOMEEMP,
--	SUM(EMPTOT) AS EMPTOt
--from mtpuser.ilut_combined2035_100


--select a.taz07,sum(a.pop_tot),sum(a.vmt_tot_res),sum(b.pop_tot),sum(b.vmt_tot_res)
--from mtpuser.ilut_combined2016_22 a
--inner join mtpuser.ilut_combined2040_37 b
--on a.parcelid=b.parcelid
--group by a.taz07
--order by a.taz07

--select a.rad07_new,sum(a.du_tot) as du16,sum(b.du_tot) as du40,sum(a.hh_tot_p) as hhp16,sum(b.hh_tot_p) as hhp40,
--sum(a.hh_hh) as hh16,sum(b.hh_hh) as hh40
--from mtpuser.ilut_combined2016_22 a
--inner join mtpuser.ilut_combined2040_37 b
--on a.parcelid=b.parcelid
--group by a.rad07_new
--order by a.rad07_new




