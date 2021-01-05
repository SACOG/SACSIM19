/*
Purpose: Calculate mix/density value for each parcel. Is 9-level index measuring jobs/hh balance and 
		total density (jobs + hhs) within "half mile" buffer of each parcel.

HOW TO USE
1 - update raw parcel table name
2 - update name of combined ILUT table that you want to add the updated mixed density column to.

NOTE: Density is based on area of 125 acres within a quarter-mile buffer of the parcel.
	This is only an APPROXIMATE estimate of density because half-mile job/hh counts are based on a decay factor (e.g., hhs and jobs
	that are further away from the parcel will "decay away"). On the one hand the decay
	method looks farther away than a half-mile from the parcel, but also decays.

*/
USE MTP2020
GO


IF EXISTS (SELECT * FROM sys.columns WHERE Name = N'MIX_DENS_B1' and Object_ID = Object_ID(N'raw_parcel2040_16')) 
ALTER TABLE raw_parcel2040_16 DROP COLUMN MIX_DENS_B1
GO


ALTER TABLE raw_parcel2040_16
ADD MIX_DENS_B1 FLOAT

GO

DECLARE @buffer_acres INT
SET @buffer_acres = 125

CREATE TABLE #MIX_DENS_B1_temp (
	PARCELID INT,
	TOT_DENS FLOAT,
	PCT_HH FLOAT,
	PCT_EMP FLOAT
	)
;

INSERT INTO #MIX_DENS_B1_temp
	SELECT
		pcl.parcelid,
		CAST((pcl.hh_1+pcl.emptot_1)/@buffer_acres AS FLOAT), --total hh + emp per acre
		CASE WHEN (pcl.hh_1+pcl.emptot_1) = 0 THEN 0
			ELSE CAST(pcl.hh_1/(pcl.hh_1+pcl.emptot_1) AS FLOAT)
			END,
		CASE WHEN (pcl.hh_1+pcl.emptot_1) = 0 THEN 0
			ELSE CAST(pcl.emptot_1/(pcl.hh_1+pcl.emptot_1) AS FLOAT)--do hh/emp values need to be divided by 100?
			END
	FROM raw_parcel2040_16 pcl --raw model input parcel table

UPDATE raw_parcel2040_16
SET MIX_DENS_B1 = 0


UPDATE raw_parcel2040_16
SET MIX_DENS_B1 = 
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
	FROM raw_parcel2040_16 pcl --raw model input parcel table
		JOIN #MIX_DENS_B1_temp m
			ON pcl.parcelid = m.PARCELID

DROP TABLE #MIX_DENS_B1_temp


ALTER TABLE mtpuser.ilut_combined2040_16
ADD MIX_DENS_B1 FLOAT

UPDATE mtpuser.ilut_combined2040_16
SET MIX_DENS_B1 = 
	CASE WHEN pr.MIX_DENS_B1 IS NULL THEN -1 ELSE pr.MIX_DENS_B1 END
	FROM mtpuser.ilut_combined2040_16 ic
		LEFT JOIN raw_parcel2040_16 pr
			ON ic.PARCELID = pr.parcelid

--ALTER TABLE mtpuser.ilut_combined2040_16 DROP COLUMN MIX_DENS_B1
