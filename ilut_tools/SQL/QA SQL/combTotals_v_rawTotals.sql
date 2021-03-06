USE MTP2020

--region-level check
SELECT
	SUM(c.PT_TOT_RES) AS COMB_PT_TOT_RES
FROM ilut_combined2016_2 c

SELECT
	COUNT(t.id) AS TRIP_PT_TOT
FROM raw_trip2016_2 t

--get parcels where combo pt_tot_res <> trips from that parcel
	
WITH trips_pcl AS (
	SELECT
		opcl,
		COUNT(*) AS trips
	FROM raw_trip2016_2
	GROUP BY opcl
)

SELECT
	c.PARCELID,
	c.PT_TOT_RES,
	o.trips AS triptbl_trpcnt
FROM ilut_combined2016_2 c
	LEFT JOIN trips_pcl o
	 ON c.PARCELID = o.opcl

--check for single parcel 17002831
SELECT
	hh.hhno,
	tour.id as tour_id,
	tour.pno as tour_pno,
	trip.id as trip_id
from 
