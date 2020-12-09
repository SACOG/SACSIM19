SELECT 
	y35.parcelid,
	y35.RAD07_NEW,
	y35.DIST_BUS AS DISTBUS_35,
	y35.DIST_LRT AS DISTLRT_35,
	y40.DIST_BUS AS DISTBUS_40,
	y40.DIST_LRT AS DISTLRT_40,
	y40.DIST_BUS - y35.DIST_BUS AS DISTBUS_CHG,
	y40.DIST_LRT - y35.DIST_LRT AS DISTLRT_CHG,
	y35.TRN_TOT_RES AS TRNTRIPS_35,
	y40.TRN_TOT_RES AS TRNTRIPS_40,
	y40.TRN_TOT_RES - y35.TRN_TOT_RES AS TRNTRIPS_CHG
FROM mtpuser.ilut_combined2035_26 y35
	JOIN mtpuser.ilut_combined2040_7 y40
		ON y35.parcelid = y40.parcelid

WHERE y35.DIST_LRT = -1 AND y40.DIST_LRT > -1
ORDER BY DISTLRT_CHG, DISTBUS_CHG


select * from raw_parcel2035_36
where parcelid = 61068978

select * from raw_parcel2040_6
where parcelid = 61068978

select count(*) from raw_parcel2040_6
where parcelid not in
	(select parcelid from raw_parcel2035_36)