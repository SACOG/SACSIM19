--compare the TMCs between two years of INRIX TMC data


DROP TABLE #tmc_compare_table

SELECT
	tmc1.tmc AS tmc_y1,
	tmc2.tmc AS tmc_y2,
	tmc1.Miles AS len_y1,
	tmc2.Miles AS len_y2,
	tmc2.Miles - tmc1.Miles AS lenchg_y1_y2
INTO #tmc_compare_table
FROM npmrds_2019_all_tmcs_txt tmc1
	FULL OUTER JOIN npmrds_2020_alltmc_txt tmc2
		ON tmc1.tmc = tmc2.tmc

SELECT * FROM #tmc_compare_table
--WHERE tmc_y1 = tmc_y2
	
