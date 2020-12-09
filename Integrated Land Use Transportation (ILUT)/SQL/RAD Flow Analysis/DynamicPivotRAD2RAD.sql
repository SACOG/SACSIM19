/*
Pivot of RAD-to-RAD worker flows.
Rows are HH RADs and columns are usual workplace RADs

BEFORE running this script, need to update person table with RADs by running
"Q:\SACSIM19\Calibration_Validation\DAYSIM Calibration\SQL - final\worker_flow_RAD_mtp2020db.sql"
*/

USE MTP2020

DECLARE @SQLStatement NVARCHAR(MAX) = N'' --Variable to hold t-sql query; the N prefix makes it unicode nvarchar, which is more flexible and less likely to have conversion errors.

DECLARE @UniqueRowsToPivot NVARCHAR(MAX) = N'' --Variable to hold unique rows to be used in PIVOT clause

DECLARE @PivotColumnsToSelect NVARCHAR(MAX) = N'' --Variable to hold pivot column names with alias to be used in SELECT clause



--FOR XML PATH creates a list from table column, separated by the characters in the preceeding and following quotes
--STUFF: STUFF(<string>,<string position to start at>,<number of characters to replace>,<character to replace them with>)
SELECT @PivotColumnsToSelect = STUFF(
								(SELECT DISTINCT ',[' + CAST(w_RAD AS NVARCHAR) + ']'
								FROM dbo.raw_person2016_3 
								FOR XML PATH ('')
								),1,1,'')

SELECT @UniqueRowsToPivot = STUFF(
								(SELECT DISTINCT ',ISNULL([' + CAST(h_RAD AS NVARCHAR) + '],0)'
								FROM dbo.raw_person2016_3 
								FOR XML PATH ('')
								),1,1,'')

SELECT @UniqueRowsToPivot 

--@PivotColumnsToSelect + ', ['  + COALESCE(county, '') + ']'
--FROM (SELECT DISTINCT county FROM dbo.raw_person2016_3) dcountyname
--SELECT @PivotColumnsToSelect = LTRIM(STUFF(@PivotColumnsToSelect, 1, 1, ''))

--Generate dynamic PIVOT query here
SET @SQLStatement =
N'
SELECT ' + @UniqueRowsToPivot +
'FROM dbo.raw_person2016_3
PIVOT (
	COUNT(pno) FOR w_RAD 
	IN (' + @PivotColumnsToSelect + ')
	) AS PVT
ORDER BY h_RAD
'
--Execute the dynamic t-sql PIVOT query below

SELECT @SQLStatement
--EXEC (@SQLStatement)
