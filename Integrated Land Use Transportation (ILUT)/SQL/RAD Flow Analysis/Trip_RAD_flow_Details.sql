/*Does analyses of RAD-to-RAD flows
NOTE - requires that o_rad and d_rad columns be added to whichever input trip table you use.
These columns can be made with Q:\SACSIM19\Integration Data Summary\SACSIM19 Scripts\SQL\RAD Flow Analysis\Trip_RAD_flow_col_gen.sql

*/

USE MTP2020
GO

SELECT
	o_rad,
	d_rad,
	COUNT(id) AS total_ptrips,
	SUM(
		CASE WHEN mode = 1 THEN 1 ELSE 0 END) AS walk_trips,
	SUM(
		CASE WHEN mode = 2 THEN 1 ELSE 0 END) AS bike_trips,
	SUM(
		CASE WHEN mode = 3 THEN 1 ELSE 0 END) AS sov_trips,
	SUM(
		CASE WHEN mode = 4 THEN 1 ELSE 0 END) AS hov2_trips,
	SUM(
		CASE WHEN mode = 5 THEN 1 ELSE 0 END) AS hov3p_trips,
	SUM(
		CASE WHEN mode = 6 THEN 1 ELSE 0 END) AS transit_trips
FROM raw_trip2035_38
GROUP BY o_rad, d_rad
ORDER BY o_rad, d_rad

