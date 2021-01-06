DECLARE @tnc_vmt_ratio FLOAT
SELECT @tnc_vmt_ratio = 
	CAST(SUM(CASE WHEN dorp IN (1,3) THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)
	FROM raw_trip_testscen
	WHERE mode = 9

CREATE TABLE #trip_temp (
	parcelid INT,
	hhno INT,
	hrestype INT,
	person_id INT,
	p_uworkpcl INT,
	tour_id INT,
	pdpurp INT,
	tmodetp INT,
	parent INT,
	trip_id INT,
	trip_mode INT,
	trip_travtime_hrs FLOAT,
	trip_timeau_hrs FLOAT,
	trip_travdist FLOAT,
	trip_distau FLOAT,
	trip_distcong FLOAT,
	trip_speed FLOAT,
	trip_dorp INT --1 = driver, normal veh; 3 = "main" passenger in AV
	)


INSERT INTO #trip_temp
	SELECT
		hh.hhparcel,
		hh.hhno,
		hh.hrestype,
		p.id,
		p.pwpcl,
		tour.id,
		tour.pdpurp,
		tour.tmodetp,
		tour.parent,
		trip.id,
		trip.mode,
		trip.travtime/60 AS trip_travtime_hrs, --NOTE: in some cases the total travel time is less than the in-auto TT--how?
		trip.timeau/60 AS trip_timeau_hrs, --do not sum this. it double counts. for unique veh trips sum the travtimeau_hrs in the #vehicle_trips_temp table
		trip.travdist,
		trip.distau,
		trip.distcong,
		CASE WHEN trip.mode IN (3,4,5) AND trip.timeau> 0 AND trip.distau > 0 THEN trip.distau/(trip.timeau/60) --auto speed
			WHEN trip.mode NOT IN (3,4,5) AND trip.travtime > 0 AND trip.travdist > 0 THEN trip.travdist/(trip.travtime/60) --non-auto speed
			ELSE 20 --default speed if travtime or travdist = 0
		END AS trip_speed,
		trip.dorp
	FROM raw_trip_testscen trip --RAW TABLE
		JOIN raw_tour_testscen tour --RAW TABLE
			ON trip.tour_id = tour.id
		JOIN raw_hh_testscen hh --RAW TABLE
			ON trip.hhno = hh.hhno
		JOIN raw_person_testscen p
			ON tour.person_id = p.id

CREATE TABLE #vehicle_trips_temp (
	trip_id BIGINT,
	tour_id INT,
	travtimeau_hrs FLOAT,
	distau2 FLOAT,
	distcong2 FLOAT
	)

INSERT INTO #vehicle_trips_temp
	SELECT
		trip.trip_id,
		trip.tour_id,
		CASE 
			WHEN trip.trip_mode = 3 --sov
				OR (trip.trip_mode IN (4,5) AND trip.hrestype = 0 AND trip.trip_dorp = 1) --driver in normal veh carpool
				OR (trip.trip_mode IN (4,5) AND trip.hrestype = 1 AND trip.trip_dorp = 3) --"main" passenger in AV carpool
			THEN trip.trip_timeau_hrs
			WHEN trip.trip_mode = 9 THEN trip.trip_timeau_hrs*@tnc_vmt_ratio --tnc, assuming an average TNC occupancy factor
			ELSE 0 
		END AS travtimeau_hrs,
		CASE 
			WHEN trip.trip_mode = 3 --sov
				OR (trip.trip_mode IN (4,5) AND trip.hrestype = 0 AND trip.trip_dorp = 1) --driver in normal veh carpool
				OR (trip.trip_mode IN (4,5) AND trip.hrestype = 1 AND trip.trip_dorp = 3) --"main" passenger in AV carpool
			THEN trip.trip_distau
			WHEN trip.trip_mode = 9 THEN trip.trip_distau*@tnc_vmt_ratio --tnc, assuming an average TNC occupancy factor
			ELSE 0 
		END AS distau2,
		CASE 
			WHEN trip.trip_mode = 3 --sov
				OR (trip.trip_mode IN (4,5) AND trip.hrestype = 0 AND trip.trip_dorp = 1) --driver in normal veh carpool
				OR (trip.trip_mode IN (4,5) AND trip.hrestype = 1 AND trip.trip_dorp = 3) --"main" passenger in AV carpool
			THEN trip.trip_distcong
			WHEN trip.trip_mode = 9 THEN trip.trip_distcong*@tnc_vmt_ratio --tnc, assuming an average TNC occupancy factor
			ELSE 0 
		END AS distcong2
	FROM #trip_temp trip

SELECT
	tour.tdpcl, --tour destination parcel
	SUM(vt.distau2) AS VMT_wrk_tourend,
	SUM(vt.distcong2) AS CVMT_wrk_tourend,
	0 AS VT_wrk_tourend, --need to add this in
	COUNT(trip.parcelid) AS PT_wrk_tourend,
	SUM(CASE WHEN trip.trip_mode = 3 THEN 1 ELSE 0 END) AS SOV_wrk_tourend,
	SUM(CASE WHEN trip.trip_mode IN (4,5) THEN 1 ELSE 0 END) AS HOV_wrk_tourend,
	SUM(CASE WHEN trip.trip_mode = 6 THEN 1 ELSE 0 END) AS TRN_wrk_tourend,
	SUM(CASE WHEN trip.trip_mode = 2 THEN 1 ELSE 0 END) AS BIK_wrk_tourend,
	SUM(CASE WHEN trip.trip_mode = 1 THEN 1 ELSE 0 END) AS WLK_wrk_tourend,
	SUM(CASE WHEN trip.trip_mode = 9 THEN 1 ELSE 0 END) AS TNC_wrk_tourend
FROM raw_tour_testscen tour 
	JOIN #trip_temp trip
		ON tour.id = trip.tour_id
	JOIN #vehicle_trips_temp vt
		ON trip.trip_id = vt.trip_id
WHERE (tour.pdpurp = 1 --work tours
	OR tour.parent > 0) --subtours
	AND tour.tdpcl = 61106967
GROUP BY tour.tdpcl


SELECT 
	vt.trip_id as vt_trip_id,
	vt.distau2,
	trip.trip_id,
	trip.trip_mode,
	tour.pdpurp,
	tour.parent,
	tour.tdpcl 
FROM #trip_temp trip
	join raw_tour_testscen tour
		ON trip.tour_id = tour.id
	JOIN #vehicle_trips_temp vt
		ON trip.trip_id = vt.trip_id
WHERE (tour.pdpurp = 1 --work tours
	OR tour.parent > 0) --subtours
	AND tour.tdpcl = 61106967
ORDER BY trip.trip_mode

--DROP TABLE #trip_temp 
--DROP TABLE #vehicle_trips_temp