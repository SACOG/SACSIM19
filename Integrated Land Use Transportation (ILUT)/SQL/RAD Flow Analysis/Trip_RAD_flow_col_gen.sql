/*Adds o_rad and d_rad columns to trip table to enable pivots showing O-D flow of trips

Resources:
	https://www.techonthenet.com/sql_server/tables/alter_table.php
	https://stackoverflow.com/questions/1293330/how-can-i-do-an-update-statement-with-join-in-sql

*/

USE MTP2020
GO

ALTER TABLE raw_trip2035_54
	ADD o_rad INT,
		d_rad INT
GO
--population o_rad column with origin RAD
UPDATE raw_trip2035_54
	SET o_rad = trad.RAD
	FROM raw_trip2035_54 rt
		JOIN TAZ07_RAD07 trad
			ON rt.otaz = trad.TAZ
GO
--population d_rad column with destination RAD
UPDATE raw_trip2035_54
	SET d_rad = trad.RAD
	FROM raw_trip2035_54 rt
		JOIN TAZ07_RAD07 trad
			ON rt.dtaz = trad.TAZ

SELECT
	o_rad,
	d_rad,
	COUNT(id) AS trip_flow
FROM raw_trip2035_54
GROUP BY o_rad, d_rad

