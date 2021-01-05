use mtp2020
go

UPDATE mtpuser.mixden_2040
set den = 0,
    per_hh=0,
	per_emp=0,
	cate=0

UPDATE mtpuser.mixden_2040
set den = (hh_tot_p+emptot)/160,
    per_hh=hh_tot_p/(hh_tot_p+emptot),
	per_emp=emptot/(hh_tot_p+emptot)

UPDATE mtpuser.mixden_2040
SET CATE = 1
FROM mtpuser.mixden_2040
WHERE PER_HH >= 0.8 and DEN <= 5

UPDATE mtpuser.mixden_2040
SET CATE = 2
FROM mtpuser.mixden_2040
WHERE PER_HH >= 0.8 and (DEN > 5 and DEN <= 10)

UPDATE mtpuser.mixden_2040
SET CATE = 3
FROM mtpuser.mixden_2040
WHERE PER_HH >= 0.8 and (DEN >10)

UPDATE mtpuser.mixden_2040
SET CATE = 4
FROM mtpuser.mixden_2040
WHERE PER_EMP >= 0.8 and DEN <= 5

UPDATE mtpuser.mixden_2040
SET CATE = 5
FROM mtpuser.mixden_2040
WHERE PER_EMP >= 0.8 and (DEN > 5 and DEN <= 10)

UPDATE mtpuser.mixden_2040
SET CATE = 6
FROM mtpuser.mixden_2040
WHERE PER_EMP >= 0.8 and (DEN > 10)

UPDATE mtpuser.mixden_2040
SET CATE = 7
FROM mtpuser.mixden_2040
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 0 and DEN <= 5)

UPDATE mtpuser.mixden_2040
SET CATE = 5
FROM mtpuser.mixden_2040
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 5 and DEN <= 10)

UPDATE mtpuser.mixden_2040
SET CATE = 9
FROM mtpuser.mixden_2040
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 10)

select cate,count(*)
from mtpuser.mixden_2040
group by cate
order by cate

select *
from mtpuser.mixden_2040
where cate=9