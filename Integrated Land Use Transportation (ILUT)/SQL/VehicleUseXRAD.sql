/*Get count of TNC trips, total vehicle trips, AV vehicle trips, AV additional passenger vehicle trips, average vehicle occupancy (all vehicles,
average AV occupancy
BY RAD
*/

USE MTP2020
GO

CREATE TABLE #temp_vdataxrad (
	trip_id INT,
	trip_mode SMALLINT,
	dorp SMALLINT,
	hhrestype SMALLINT,
	o_parcelid INT,
	o_rad_id INT,
	o_rad_name VARCHAR(50)
	)

INSERT INTO #temp_vdataxrad
	SELECT
		t.id,
		t.mode,
		t.dorp,
		h.hrestype,
		h.hhparcel,
		tr.RAD,
		tr.RADNAME
	FROM raw_trip2035_23 t --trip table
		JOIN raw_hh2035_23 h --hh table
			ON t.hhno = h.hhno
		JOIN TAZ07_RAD07 tr --tazrad table
			ON h.hhtaz = tr.TAZ
GO

WITH trip_x_rad_data AS (SELECT
	o_rad_id,
	o_rad_name,
	COUNT(trip_id) AS tot_trips,
	SUM(CASE WHEN trip_mode = 9 THEN 1 ELSE 0 END) AS tnc_trips,
	SUM(CASE
			WHEN trip_mode IN (3,4,5) AND hhrestype = 1 AND dorp = 3
			THEN 1 ELSE 0
		END) AS av_veh_trips,
	SUM(CASE
			WHEN trip_mode IN (3,4,5) AND hhrestype = 1 AND dorp = 4
			THEN 1 ELSE 0
		END) AS av_addlpax_trips, --trips of 2nd through Nth passenger of AVs
	SUM(CASE
			WHEN trip_mode IN (3,4,5) AND hhrestype = 1
			THEN 1 ELSE 0
		END) AS av_person_trips, --total AV person trips
	SUM(CASE
			WHEN trip_mode IN (3,4,5) AND hhrestype = 1
			THEN 1 ELSE 0
		END)*1.0 /
		SUM(CASE
				WHEN trip_mode IN (3,4,5) AND hhrestype = 1 AND dorp = 3
				THEN 1 ELSE 0
			END) AS avg_av_veh_occupancy --average AV vehicle occupancy (total person trips in AVs / AV vehicle trips
FROM #temp_vdataxrad tv
GROUP BY o_rad_id, o_rad_name
)

SELECT
	txr.o_rad_id,
	txr.o_rad_name,
	txr.tot_trips,
	txr.tnc_trips,
	txr.av_veh_trips,
	txr.av_addlpax_trips,
	txr.av_person_trips,
	txr.avg_av_veh_occupancy,
	SUM(ilut.POP_TOT) AS rad_pop,
	SUM(ilut.EMP_TOT) AS rad_emp
FROM trip_x_rad_data txr
	JOIN mtpuser.ilut_combined2035_23 ilut --ILUT table
		ON txr.o_rad_id = ilut.RAD07_NEW
GROUP BY o_rad_id,
		o_rad_name,
		tot_trips,
		tnc_trips,
		av_veh_trips,
		av_addlpax_trips,
		av_person_trips,
		avg_av_veh_occupancy
ORDER BY o_rad_id

DROP TABLE #temp_vdataxrad