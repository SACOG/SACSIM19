use mtp2020
go
drop table mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den

SELECT a.grid_id, a.hh_tot_p, a.emptot,cast((hh_buf2+emp_buf2)/503 as numeric(18,2)) as DEN,
       cast(hh_buf2/(hh_buf2+emp_buf2) as numeric(18,2)) as PER_HH,
       cast(emp_buf2/(hh_buf2+emp_buf2) as numeric(18,2)) as PER_EMP,
       0 as "CATE"
INTO mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den  
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id a
WHERE a.hh_tot_p > 0 or a.emptot > 0



UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 1
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE PER_HH >= 0.8 and DEN <= 8

UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 2
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE PER_HH >= 0.8 and (DEN > 8 and DEN <= 16)

UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 3
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE PER_HH >= 0.8 and (DEN >16)

UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 4
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE PER_EMP >= 0.8 and DEN <= 8

UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 5
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE PER_EMP >= 0.8 and (DEN > 8 and DEN <= 16)

UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 6
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE PER_EMP >= 0.8 and (DEN > 16)

UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 7
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 0 and DEN <= 8)

UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 8
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 8 and DEN <= 16)

UPDATE mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
SET CATE = 9
FROM mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 16)

select cate,count(*)
from mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
group by cate
order by cate

select *
from mtpuser.ilut_combined2040_20_ppaMay19_grid_id_den
where cate=0