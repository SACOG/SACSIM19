
select vmt40r_c,count(*) as hex,sum(du40) as du,sum(pop40) as pop,sum(vmt40_res) as vmt,min(vmt40r_p) as minn,max(vmt40r_p) as maxx
from mtpuser.HEX_VMT_16_40
group by vmt40r_c
order by vmt40r_c

select vmt16r_c,vmt40r_c,count(*) as hex,sum(du16) as du,sum(pop16) as pop,sum(du40) as du,sum(pop40) as pop
from mtpuser.HEX_VMT_16_40
group by vmt16r_c,vmt40r_c
order by vmt16r_c,vmt40r_c

select sum(du16)
from mtpuser.HEX_VMT_16_40

select count(*) from mtpuser.PARCEL_EJAREA_1AUG19

select *
from mtpuser.parcel_master a
inner join mtpuser.PARCEL_EJAREA_1AUG19 b
on a.parcelid=b.parcelid
where ej_2018 = 0

update mtpuser.parcel_master 
set ej_2018 = 0

update mtpuser.parcel_master 
set ej_2018 = 1
from mtpuser.parcel_master a
inner join mtpuser.PARCEL_EJAREA_1AUG19 b
on a.parcelid=b.parcelid

update mtpuser.ilut_combined2016_22
set ej_2018 = b.ej_2018
from mtpuser.ilut_combined2016_22 a
inner join mtpuser.parcel_master b
on a.parcelid=b.parcelid

update mtpuser.ilut_combined2040_37
set ej_2018 = b.ej_2018
from mtpuser.ilut_combined2040_37 a
inner join mtpuser.parcel_master b
on a.parcelid=b.parcelid