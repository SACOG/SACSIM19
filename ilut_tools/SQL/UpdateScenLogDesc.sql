/****** Script for SelectTopNRows command from SSMS  ******/
USE MTP2020
UPDATE ilut_scenario_log
	SET scenario_desc = 'D:\SACSIM19\2020MTP\NoTNC\run_2035_AO17_noTNC_DS_3, toll function OFF'
	WHERE scenario_code = 10 AND scenario_year = 2035