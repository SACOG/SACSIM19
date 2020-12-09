USE MTP2020
--are there parcels with no jobs or people generating commercial vehicle trips?
SELECT 
	ix.* 
from ilut_ixxcveh2016_1 ix
	JOIN raw_parcel2016_1 p
		ON p.parcelid = ix.parcelid
WHERE CV2_VT > 0 AND pcl_tot_user = 0 AND p.hh_p = 0

----parcels with most IX residential vehicle trips
SELECT TOP 5 *
FROM [MTP2020].[dbo].ilut_ixxcveh2016_1
ORDER BY IX_VT_RES DESC

--parcels with fewest IX residential vehicle trips
SELECT TOP 5 *
FROM [MTP2020].[dbo].ilut_ixxcveh2016_1
ORDER BY IX_VT_RES
