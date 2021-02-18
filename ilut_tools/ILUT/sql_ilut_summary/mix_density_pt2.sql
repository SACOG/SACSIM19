/*
Part 2 of 2 for mix density calculation. Part 1 creates the mixdens column;
this part calculates it. Need to split into two scripts because cannot terminate batch command
(add column) in single script.

Purpose: Calculate mix/density value for each parcel. Is 9-level index measuring jobs/hh balance and 
		total density (jobs + hhs) within "half mile" buffer of each parcel.

NOTE: Density is based on area of 503 acres within a half-mile buffer of the parcel.
	This is only an APPROXIMATE estimate of density because half-mile job/hh counts are based on a decay factor (e.g., hhs and jobs
	that are further away from the parcel will "decay away"). On the one hand the decay
	method looks farther away than a half-mile from the parcel, but also decays.

*/

CREATE TABLE #mix_dens_temp (
	PARCELID INT,
	TOT_DENS FLOAT,
	PCT_HH FLOAT,
	PCT_EMP FLOAT
	)
;

INSERT INTO #mix_dens_temp
	SELECT
		pcl.parcelid,
		CAST((pcl.hh_2+pcl.emptot_2)/503 AS FLOAT), --total hh + emp per acre
		CASE WHEN (pcl.hh_2+pcl.emptot_2) = 0 THEN 0
			ELSE CAST(pcl.hh_2/(pcl.hh_2+pcl.emptot_2) AS FLOAT)
			END,
		CASE WHEN (pcl.hh_2+pcl.emptot_2) = 0 THEN 0
			ELSE CAST(pcl.emptot_2/(pcl.hh_2+pcl.emptot_2) AS FLOAT)--do hh/emp values need to be divided by 100?
			END
	FROM {0} pcl --raw model input parcel table

UPDATE {0}
SET MIX_DENS = 0
;

UPDATE {0}
SET MIX_DENS = 
	CASE WHEN m.PCT_HH >= 0.8 and m.TOT_DENS <= 8 THEN 1 -- >low density residential
		WHEN m.PCT_HH >= 0.8 and (m.TOT_DENS > 8 and m.TOT_DENS <= 16) THEN 2 --moderate density residential
		WHEN m.PCT_HH >= 0.8 and (m.TOT_DENS > 16) THEN 3 --high-density residential
		WHEN m.PCT_EMP >= 0.8 and m.TOT_DENS <= 8 THEN 4 --low-density non-residential
		WHEN m.PCT_EMP >= 0.8 and (m.TOT_DENS > 8 and m.TOT_DENS <= 16) THEN 5 --med-density non-residential
		WHEN m.PCT_EMP >= 0.8 and (m.TOT_DENS > 16) THEN 6 --high-density non-residential
		WHEN (m.PCT_HH < 0.8 and m.PCT_EMP < 0.8) and (m.TOT_DENS > 0 and m.TOT_DENS <= 8) THEN 7 --low-density mixed
		WHEN (m.PCT_HH < 0.8 and m.PCT_EMP < 0.8) and (m.TOT_DENS > 8 and m.TOT_DENS <= 16) THEN 8 --med-density mixed
		WHEN (m.PCT_HH < 0.8 and m.PCT_EMP < 0.8) and (m.TOT_DENS > 16) THEN 9 --hi-density mixed
		ELSE 0 --zero density, no jobs or hhs within half mile of buffer
		END
	FROM {0} pcl --raw model input parcel table
		JOIN #mix_dens_temp m
			ON pcl.parcelid = m.PARCELID

DROP TABLE #mix_dens_temp
