'''
Get trip data broken out by income quartile

To open in python command shell, open the shell and enter:
exec(open('Q:\SACSIM19\Sensitivity Tests\Darren\AutoCost\\table_loader2.py').read())

'Q:\SACSIM19\Sensitivity Tests\Darren\AutoCost'
'''

import pandas as pd
import datetime

#=======================USER-DEFINED INPUT PARAMETERS=========================
"BEFORE RUNNING MAKE SURE ALL PARAMETERS ARE CORRECT!!!"

in_dir_root = r'Y:\yanmei\SACSIM19\DAYSIM_2June17\run_08_v2_trn_6' #directory for input .tsv file
in_trip_file = '_trip_1_2.csv' #tsv file name
in_hh_file = '_household.tsv'
test_type = 'AOC'
sens_values = [''] #cents per mile, these append to end of in_dir_root
out_file_dir = r'Q:\SACSIM19\Sensitivity Tests\Darren\AutoCost\outputs' #where you want the output CSV to go

#=======================FUNCTIONS==============================================

def tripTableMake(sens_val):
    in_dir = in_dir_root + str(sens_val)
    trip = pd.DataFrame(pd.read_csv(in_dir + '\\' + in_trip_file,
                                    sep=',',
                                    usecols = tripcols,
                                    engine='python'))
    return trip
    
def hhTableMake(sens_val):
    in_dir = in_dir_root + str(sens_val)
    hh = pd.DataFrame(pd.read_csv(in_dir + '\\' + in_hh_file,
                                    sep='\\t',
                                    usecols = hhcols,
                                    engine='python'))
    return hh

def tblMerge(trip_tbl,hh_tbl):
    trip_hh_join = trip_tbl.merge(hh_tbl,on='hhno')
    return trip_hh_join
    
def tagger(in_amt): #makes applicable tag identifier from the ChangeAmt value
    return str(in_amt) + 'c'
    
def totPTrips(df):
	return df.shape[0]

def totPTours(df):
    return df['tour_id'].unique().shape[0]

def totVTrips(df):
	sov = df.loc[df['mode'] == 3].shape[0] #count of trips where mode = SOV (3)
	hov2 = df.loc[df['mode'] == 4].shape[0] * 0.5 #0.5 times the count of trips where mode = HOV2 (4)
	hov3plus = df.loc[df['mode'] == 5].shape[0] * 0.3
	vtrips = sov + hov2 + hov3plus
	return vtrips

def totVMT(df):
	mgrp = df.groupby('mode')
	sumxmode = mgrp.sum().distau #get sum of vmt grouped by mode
	sov_vmt =  sumxmode[3]  #sov vmt, or row where mode = 3, or sov
	hov2_vmt = sumxmode[4] * 0.5 #vmt/person-trip is half for 2-person carpool
	hov3plus_vmt = sumxmode[5] * 0.3 #averaging that 3+ carpool has 0.3 times the per-person vmt
	total_vmt = sov_vmt + hov2_vmt + hov3plus_vmt
	return total_vmt

def totCvmt(df):
	mGrp = df.groupby('mode')
	sumXMode = mGrp.sum().distcong #get sum of cvmt grouped by mode
	sovCvmt =  sumXMode[3]  #sov cvmt, or row where mode = 3, or sov
	hov2Cvmt = sumXMode[4] * 0.5 #cvmt/person-trip is half for 2-person carpool
	hov3PlusCvmt = sumXMode[5] * 0.3 #averaging that 3+ carpool has 0.3 times the per-person cvmt
	totCvmt = sovCvmt + hov2Cvmt + hov3PlusCvmt
	return totCvmt

def transitPTrips(df):
	return df.loc[df['mode'] == 6].shape[0]

def bikewalkPTrips(df):
	walktrips = df.loc[df['mode'] == 1].shape[0]
	biketrips = df.loc[df['mode'] == 2].shape[0]
	return biketrips + walktrips

#avg vmt per hh
def vmtXHH(df):
    return df.groupby('hhno')['distau'].sum().mean()

def outputProcessor(df): #calculate the metrics as a list
	outputList = []
	outputList.extend((totPTrips(df),
                    totPTours(df),
                    totVTrips(df),
                    totVMT(df),
                    totCvmt(df),
                    transitPTrips(df),
                    bikewalkPTrips(df),
                    #vmtXHH(df) #gets vmt per hh if desired
		))
	return outputList

def dict2DF(inDict):
    outlist_names = ['_1_PTrips',
                 '_2_PTours',
                 '_3_vehtrips',
                 '_4_vmt',
                 '_5_cvmt',
                 '_6_transit_trips',
                 '_7_bikewalk_trips',
                 #'_8_vmt_per_hh' #gets vmt per hh if desired
                 ]
    outDF = pd.DataFrame(inDict,index = outlist_names)
    return outDF
	
#=======================SUMMARIES================================
tripcols = ['tour_id','pno','hhno','mode','distau','distcong'] #specify columns you want to import. This will save memory.
hhcols = [0,13] #0 = hhno column, 13 = hhincome column

outDictAllIncome = {}
outDictTopIncome = {}
outDictBtmIncome = {}

for val in sens_values:
    print("Loading tables for " + str(val) + "-cent AOC...")
    trip = tripTableMake(val)
    hh = hhTableMake(val)
    trip_hh_join = tblMerge(trip,hh)
    
    btmqtile = hh['hhincome'].quantile(q=0.25)
    topqtile = hh['hhincome'].quantile(q=0.75)

    del trip,hh #free up some memory space

    # Tables filtered by income quartile
    btmqtiletable = trip_hh_join.loc[trip_hh_join['hhincome'] < btmqtile]
    topqtiletable = trip_hh_join.loc[trip_hh_join['hhincome'] > topqtile]
    
    all_income_vals = outputProcessor(trip_hh_join)
    btm_qtl_values = outputProcessor(btmqtiletable)
    top_qtl_values = outputProcessor(topqtiletable)
    
    outDictAllIncome[val] = all_income_vals
    outDictTopIncome[val] = top_qtl_values
    outDictBtmIncome[val] = btm_qtl_values
    
    print("Finished summarizing for " + str(val) + "-cent AOC")


col_headers = ['all_incomes','btm_quartile','top_quartile']

#LOOK AT FINAL AOC TABLES AND ADD CVMT

all_income = dict2DF(outDictAllIncome)
low_income = dict2DF(outDictBtmIncome)
hi_income = dict2DF(outDictTopIncome)


#outlist = dict(zip(outlist_names,list(zip(all_income_vals,btm_qtl_values,top_qtl_values))))

#out_df = pd.DataFrame(outlist,index=col_headers)

#out_df = out_df.T #transpose so that income categories are the column headers

#=========================WRITE OUT TO CSV===========================
date_suffix = str(datetime.date.today().strftime('%m%d%Y'))

writer = pd.ExcelWriter(out_file_dir + '\\' \
                                + test_type + 'SensSummaryBaseOnly' \
                                + '_' + date_suffix + '.xlsx')
    
all_income.to_excel(writer,sheet_name='all_incomes',startcol = 0,startrow = 0)
low_income.to_excel(writer,sheet_name='btm_qrtile',startcol = 0,startrow = 0)
hi_income.to_excel(writer,sheet_name='top_qrtile',startcol = 0,startrow = 0)

writer.save()

print("Success!")
