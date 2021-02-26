;Attached Transit Skims to get Transit Travel Times

RUN PGM=MATRIX 
	FILEI ZDATI = popparctaz.txt, Z=#1,wkrs15k=#2, pop15k=#3, wkrs30k=#4, pop30k=#5,wkrs50k=#6, pop50k=#7,wkrs75k=#8, pop75k=#9,wkrs75mk=#10, pop75mk=#11,wkrsall=#12, popall=#13,
                               hhs=#14, jobs=#15, edu=#16, food=#17, gov=#18, ofc=#19, ret=#20, svc=#21, med=#22, ind=#23, oth=#24, stugrd=#25, stuhgh=#26, stuuni=#27;columns in matrix
							   
		  MATI[2] = skim.tran.am4.mat ;input transkt skim for AM
		  MATI[2] = skim.tran.am4.mat ;input transkt skim for AM		  
		  MATI[2] = skim.tran.am4.mat ;input transkt skim for AM
		  MATI[2] = skim.tran.am4.mat ;input transkt skim for AM