USE MTP2020
GO

SELECT
	ic.parcelid,
	ic.MIXINDEX,
	ic.MIX_DENS,
	ic.HH_hh,
	ic.EMPTOT,
	ic.HH_BUF2,
	ic.EMP_BUF2,
	pm.GRID_ID AS HEX_ID
INTO ilut_mixdens2035_109_whex
FROM mtpuser.ilut_combined2035_109 ic
	JOIN mtpuser.PARCEL_MASTER pm
		ON ic.parcelid = pm.parcelid

SELECT TOP 100 *
FROM ilut_mixdens2035_109_whex

SELECT
	HEX_ID,
	SUM(HH_hh) AS HH_HEXPCLS,
	SUM(EMPTOT) AS EMP_HEXPCLS,
	AVG(MIX_DENS) AS AVG_MIXDENS,
	COUNT(PARCELID) AS CNT_PCL_CENTR
INTO ilut_mixdens_x_hex
FROM ilut_mixdens2035_109_whex
GROUP BY HEX_ID