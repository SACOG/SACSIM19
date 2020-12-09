use mtp2020
go
drop table mtpuser.hex_2016_50_MixDen

SELECT a.grid_id, cast((SUM_DU_TOT_propl+SUM_EMPTOT_propl)/160 as numeric(18,2)) as DEN,
       cast(SUM_DU_TOT_propl/(SUM_DU_TOT_propl+SUM_EMPTOT_propl) as numeric(18,2)) as PER_HH,
       cast(SUM_EMPTOT_propl/(SUM_DU_TOT_propl+SUM_EMPTOT_propl) as numeric(18,2)) as PER_EMP,
       0 as "CATE"
INTO mtpuser.hex_2016_50_MixDen  
FROM mtpuser.hex_2016_50 a
WHERE SUM_DU_TOT_propl > 0 or SUM_EMPTOT_propl > 0



UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 1
FROM mtpuser.hex_2016_50_MixDen
WHERE PER_HH >= 0.8 and DEN <= 5

UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 2
FROM mtpuser.hex_2016_50_MixDen
WHERE PER_HH >= 0.8 and (DEN > 5 and DEN <= 10)

UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 3
FROM mtpuser.hex_2016_50_MixDen
WHERE PER_HH >= 0.8 and (DEN >10)

UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 4
FROM mtpuser.hex_2016_50_MixDen
WHERE PER_EMP >= 0.8 and DEN <= 5

UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 5
FROM mtpuser.hex_2016_50_MixDen
WHERE PER_EMP >= 0.8 and (DEN > 5 and DEN <= 10)

UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 6
FROM mtpuser.hex_2016_50_MixDen
WHERE PER_EMP >= 0.8 and (DEN > 10)

UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 7
FROM mtpuser.hex_2016_50_MixDen
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 0 and DEN <= 5)

UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 8
FROM mtpuser.hex_2016_50_MixDen
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 5 and DEN <= 10)

UPDATE mtpuser.hex_2016_50_MixDen
SET CATE = 9
FROM mtpuser.hex_2016_50_MixDen
WHERE (PER_HH < 0.8 and PER_EMP < 0.8) and (DEN > 10)

select cate,count(*)
from mtpuser.hex_2016_50_MixDen
group by cate
order by cate

select *
from mtpuser.hex_2016_50_MixDen
where cate=0

alter table  mtpuser.hex_2016_50
add mixDen16 int null


update mtpuser.hex_2016_50
set mixDen16 = b.cate
from mtpuser.hex_2016_50 a
inner join mtpuser.hex_2016_50_mixden b
on a.grid_id=b.grid_id

