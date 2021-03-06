USE MTP2020

SELECT * FROM ilut_combined2016_1
--where person tours are null and work end tours are null--why?

SELECT 
	i.parcelid,
	lutype_p,
	POP_TOT,
	HH_TOT_P,
	HH_hh,
	EMP_TOT,
	PTO_TOT_RES,
	VMT_TOT_RES,
	VMT_wrk_tourend,
	IX_VMT,
	CV2_VMT,
	CV3_VMT
FROM ilut_combined2016_1 i
	JOIN raw_parcel2016_1 p
		ON i.parcelid = p.parcelid
WHERE POP_TOT = 0
	AND EMP_TOT = 0
	AND PTO_TOT_RES > 0
	AND VMT_wrk_tourend > 0

--why is pop_tot null and emp_tot = 0?
--no rows with these parcels in the person ilut table
--check the 'person' theme script
SELECT *
FROM ilut_combined2016_1
WHERE parcelid IN (113033939,113033940)



--or are there maybe parcels with a hhno but no people in the hh?
SELECT
	p.parcelid,
	p.hh_p,
	h.hhsize,
	COUNT(pop.pno) AS persons_in_hh
FROM raw_parcel2016_1 p
	LEFT JOIN raw_hh2016_1 h
		ON p.parcelid = h.hhparcel
	LEFT JOIN raw_person2016_1 pop
		ON h.hhno = pop.hhno
WHERE hh_p > 0
	--AND hhsize IS NULL
	AND pop.pno IS NULL
GROUP BY p.parcelid, p.hh_p, h.hhsize
HAVING hhsize <> COUNT(pop.pno)



--how is pop_tot > 0 but PTO_TOT_RES null? Did they not take any trips? Or is there a joining problem?
SELECT DISTINCT
	p.parcelid,
	pop.hhcel,
	pop.serialno,
	h.hhno
FROM raw_parcel2016_1 p
	LEFT JOIN mtpuser.POPULATION2016 pop
		ON pop.hhcel = p.parcelid
	LEFT JOIN raw_hh2016_1 h
		ON p.parcelid = h.hhparcel

--hhs in pop file = hhs in hh file?
--NO; 882580 in hh file, 864846 in pop file
SELECT
	COUNT (DISTINCT serialno) AS pop_file_hhs
FROM population2016_1

SELECT
	COUNT(hhno) AS hh_file_hhs
FROM raw_hh2016_1

--people in pop file = people in person file?
--NO; pop file has 2296208 people, person file has 2312724 people
SELECT
	COUNT (*) AS pop_file_popn
FROM population2016_1

SELECT
	COUNT(*) AS persn_file_popn
FROM raw_person2016_1

SELECT
	pop.serialno + pop.pnum as pop_uid,
	per.hhno + per.pno as person_uid
FROM population2016_1 pop
	FULL OUTER JOIN raw_person2016_1 per
		ON pop.serialno = per.hhno
		AND pop.pnum = per.pno
WHERE pop.serialno + pop.pnum IS NULL
	OR per.hhno + per.pno IS NULL

--hhs with no people in hh table?
--NO, all HHs in hh file have at least 1 person in them
SELECT hhno,
	hhsize
--ISSUE: there are more people and hhs in the model output table than in the population file, so at best there'd be many people
--whose population-file attributes would be null (e.g., ethnicity, head of HH, etc)
FROM raw_hh2016_1
WHERE hhsize < 1


SELECT sum(pop_tot) AS ilut_person_pop from ilut_person2016_1
SELECT count(*) as raw_person_pop from raw_person2016_1
SELECT SUM(POP_TOT) as combined_ilut_pop FROM ilut_combined2016_1
SELECT * FROM ilut_person2016_1 where

--check if hhs per parcel is same in both parcel file and population file
--It is same in both files.
SELECT
	p.parcelid,
	COUNT(pop.serialno) AS popfile_hhs,
	COUNT(p.hh_p) AS parcelfile_hhs
FROM raw_parcel2016_1 p
	JOIN population2016_1 pop
		ON p.parcelid = pop.hhcel
GROUP BY p.parcelid
HAVING COUNT(pop.serialno) <> COUNT(p.hh_p)

--ensure hh_p in parcel file = count(hhno) group by hhparcel in hh file
SELECT
	parcelid,
	hhparcel,
	hh_p,
	COUNT(hhno) as hhs_hhfile
from raw_parcel2016_1 p
	left join raw_hh2016_1 h
		on p.parcelid = h.hhparcel
group by parcelid, hh_p, hhparcel
having hh_p <> COUNT(hhno)
OR count(hhno) = 0