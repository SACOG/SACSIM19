/****** Script for SelectTopNRows command from SSMS  ******/
USE NPMRDS

SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'npmrds_2017_paxveh'