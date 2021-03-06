USE MTP2020

SELECT
	id,
	mode,
	CAST(deptm AS FLOAT)/60,
	CAST(arrtm AS FLOAT)/60,
	arrtm - deptm AS durn_mins
FROM raw_trip_testscenNoTNC
WHERE ROUND(deptm/60,0) = 7
	AND ROUND(arrtm/60,0) = 9
	AND mode = 3
	AND id = 792465101

--trip 792465101 starts ~7:30, ends ~9:30
--7am DA skim time value, zone 1061-903: 138.48
--8am DA skim time value, zone 1061-903: 130.65
--9am DA skim time value, zone 1061-903: 119.23
--time in 7am: 0.5 hr ( % of total time)
--8am: 1.0 hr ( % of total time)
--9am: .4833 hr

SELECT * FROM raw_trip_testscenNoTNC
WHERE id = 792465101