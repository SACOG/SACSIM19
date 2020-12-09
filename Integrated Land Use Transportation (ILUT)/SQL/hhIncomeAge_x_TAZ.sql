/*
Author: Darren Conly

Purpose: Get median HH income and median person age for each TAZ
*/

USE MTP2020

GO

WITH pop_tbl AS (
	SELECT 
		hhtaz,
		SUM(hhsize) AS taz_pop
	FROM raw_hh2016_2
	GROUP BY hhtaz
)

SELECT DISTINCT  
	h.hhtaz as taz,
	pt.taz_pop,
	PERCENTILE_CONT(0.5)
		WITHIN GROUP (ORDER BY h.hhincome) 
		OVER (PARTITION BY h.hhtaz) AS med_taz_hhincome,
	PERCENTILE_CONT(0.5)
		WITHIN GROUP (ORDER BY p.pagey)
		OVER (PARTITION BY h.hhtaz) AS med_taz_persn_age
FROM raw_hh2016_2 h
	LEFT JOIN raw_person2016_2 p
		ON h.hhno = p.hhno
	LEFT JOIN pop_tbl pt
		ON h.hhtaz = pt.hhtaz
