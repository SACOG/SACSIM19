
"""
Title: pems_x_link_latest_StationLevelv5.py
Author: Kyle Shipley
Description:
 aggregate hourly PeMS traffic count for seasonal comparison and Replica updates
 aggregate counts to SACSIM19 links for validation, script base on 2016 MTP/SCS pems processing script - pems_x_link_latest.py.
Created: 8/22/19
Last Updated: 10/02/19
"""

import os
import re
import time
import datetime
import warnings
import pandas as pd
from functools import reduce
import numpy as np

now = datetime.datetime.now()
start_time = time.time()
print(now.strftime("%Y-%m-%d %H:%M"))
date_suf = time.strftime('%m%d%H%M')

#A_B = unique directional model lin, ID is PeMS sensors (HOV,ML,RP), S_ID is PeMS station
#Should add CountID & FreewayID
corr_columns = ['A_B','ID','S_ID','Dir','NAME','CAPCLASS16']

header_names = ['Timestamp','Station','District','Route','DirTravel','LaneType',
                'StationLen','Samples','PtcObsved','TotFlow','AvgOccpy',
                'AvgSpeed','Delay35','Delay40','Delay45','Delay50','Delay55',
                'Delay60','LaneNFlow','LaneNAvgOcc','LaneNAvgSpeed',
                'F22','F23','F24','F25','F26','F27','F28','F29','F30','F31',
                'F32','F33','F34','F35','F36','F37','F38','F39','F40','F41']


# PeMS summary dictionaries
#will only summarize based on user specified var "Prds"
ss19_prds = {'C16H07':[7],
             'C16H08':[8],
             'C16H09':[9],
             'C16MD5':[10,11,12,13,14],
             'C16H15':[15],
             'C16H16':[16],
             'C16H17':[17],
             'C16EV2':[18,19],
             'C16N11':[20,21,22,23,0,1,2,3,4,5,6]}

pems_hrly = {
            'H01':[1],
            'H02':[2],
            'H03':[3],
            'H04':[4],
            'H05':[5],
            'H06':[6],
            'H07':[7],
             'H08':[8],
             'H09':[9],
             'H10':[10],
             'H11': [11],
             'H12': [12],
             'H13': [13],
             'H14': [14],
             'H15':[15],
             'H16':[16],
             'H17':[17],
             'H18': [18],
             'H19': [19],
             'H20': [20],
             'H21': [21],
             'H22': [22],
             'H23': [23],
             'H24': [0]}

pems_4prds = {'AM3':[7,8,9],
             'MD5':[10,11,12,13,14],
             'PM3':[15,16,17],
             'NT13':[18,19,20,21,22,23,0,1,2,3,4,5,6]}

#columns set to variables because they're used a lot, should revise
link_col = 'A_B'
lanetype_col = 'LaneType'
stn = 'ID'
prd_col = 'ss19_prd'
vol_col = 'TotFlow'
dir_col = 'Dir'
capclass_col = 'CAPCLASS16'
S_ID_col = 'S_ID' #combines pems sensors of adjacent HOV and Mainline
#should add from Model into file
FWID = 'FWID'
COUNTID = 'COUNTID'
Lat = 'Longitude'
Long = 'Latitude'
County = 'County'
City = 'City'
PM = 'State_PM'
#defaults, user can adjust below
AggToVar = stn
Prds = pems_hrly

# days of week to consider. 0 = Monday, 6 = Sunday
# will only summarize varibles user specifies below in var "days_of_week"
wkday3 = [1, 2, 3]  # sacsim19 aadt
wknd2 = [5, 6]

wkday4 = [0, 1, 2, 3]  # hts18
wknd3 = [4, 5, 6]  # hts18

wk7 = [0, 1, 2, 3, 4, 5, 6]

# SWL week, weekday, weekend per Alexi 9/5/19
swl_wk7 = [0, 1, 2, 3, 4, 5, 6]
swl_wk4 = [0, 1, 2, 3]
swl_wknd1 = [5, ]

wkday5 = [0, 1, 2, 3, 4]
# individual days
mon = [0, ]
tue = [1, ]
wed = [2, ]
thr = [3, ]
fri = [4, ]
sat = [5, ]
sun = [6, ]

#initial dataframes
corr_df = pd.DataFrame()  # defining df outputs

#Functions
def ss19_time_range(in_hr):
    for k,v in Prds.items():
        if in_hr in v:
            return k

#if the link name string has a colon, then check the named direction against pems direction       
def direcn_chk(in_strs):
    namestr = str(in_strs[0])
    pemdirstr = str(in_strs[1])
    pems_dir = re.compile('.*:{}.*'.format(pemdirstr))
    
    if re.match(pems_dir,namestr):
        return 'ok'
    elif re.match('.*:.*',namestr) is None:
        return 'no dir in name'
    else:
        return 'check'

def buildrange(s,Mr,stp):
    Mdict = {}

    while s <= stp:
        Mlist = []
        Mlist.append(s)
        for i in range(Mr-1):
            v = s + 1
            #jump to next year january
            if v - round(s,-2) > 12:
                v = s + 100 - 11
            #Note: this will summarize less than the set range. e.g. 2 months insead of 3.
            if v <= stp:
                Mlist.append(v)
            s = v
        # jump to next year january
        if s - round(s, -2) >= 12:
            s = s + 100 - 11
        else:
            s = s+1

        if round(Mlist[0],-2) == round(Mlist[-1],-2):
            name = str(Mlist[0]) + "_" + str(Mlist[-1])[-2:]
        else:
            name = str(Mlist[0]) + "_" + str(Mlist[-1])

        Mdict[name] = Mlist
        #print("key: {}").format(name)
        print(Mdict[name])


    return Mdict

def multi_file_hourly(mdict,csvslist):
    multi_file_dict = {}
    for f in csvslist:
        year = os.path.basename(f).split('_')[4][2:]
        month = os.path.basename(f).split('_')[5][:2]
        ym = [year, month]
        cdate = ym[0] + ym[1]

        for key in mdict:
            if not key in multi_file_dict:
                multi_file_dict[key] = []

            if int(cdate) in mdict[key]:
                multi_file_dict[key].append(f)

    return multi_file_dict

def trim_table(data_dir,in_txt):
    df = pd.read_csv(os.path.join(data_dir,in_txt),
                     header = None, names = header_names,index_col = False)
    df = df[[i for i in df.columns if not re.match('F.*',i)]] #delete unused columns
    df = df[[i for i in df.columns if not re.match('Delay.*',i)]] #delete unused columns
    df = df.loc[df[lanetype_col].isin(['ML','HV'])] #only keep rows for HOV and mainline facilities
    
    df['Timestamp'] = pd.to_datetime(df['Timestamp']) #convert to timestamp data type
    
    #add columns
    #https://pandas.pydata.org/pandas-docs/stable/api.html#datetimelike-properties
    df['hour'] = df['Timestamp'].dt.hour
    df['month'] = df['Timestamp'].dt.month
    df['dow'] = df['Timestamp'].dt.dayofweek #0 = monday, 6 = sunday
    df[prd_col] = df['hour'].apply(lambda x: ss19_time_range(x))
    
    return df

def make_master_df(data_dir,in_files,corr_df,multi_file_agg,multidict=None,multikey=None):

    master = pd.DataFrame()  # defining df outputs

    #loop through all other raw input months and make one long table
    if multi_file_agg:
        print("reading in multiple files:")
        for f in multidict[multikey]:
            try:
                print("reading in {}...".format(f))
                df = trim_table(data_dir,f) #this function is taking too long...suggest revising for optimization.
                master = master.append(df)
            except Warning as e:
                print("Warning: error loading and merging csv: skipping, check input files.", e)


    else:
        #generate initial table
        print("reading in {}...".format(in_files))
        master = trim_table(data_dir,in_files)

    # left on stations from correspondance table, right is Pems Station sensor.
    master = corr_df.merge(master, how='inner', left_on=stn, right_on='Station')
    
    return master


def link_avg_x_prd(in_df, dow_list, obs_th):
    
    print("Summarizing ADTs by time period and link...")
    df = in_df[(in_df['dow'].isin(dow_list)) & (in_df['PtcObsved'] >= obs_th)] #selecting days of week to include and quality threshold

    #get count of all 1-hour time periods with observed data within each SS19 day period for each link
    piv_cols = [AggToVar,link_col,prd_col,vol_col]
    
    piv_prdcnt = pd.pivot_table(df[piv_cols], values = vol_col,
                                index = AggToVar, columns = prd_col,
                                aggfunc = 'count')

    #get count of all potential PeMS data
    df_all = in_df[(in_df['dow'].isin(dow_list))]
    piv_prdcnt_all = pd.pivot_table(df_all[piv_cols], values = vol_col,
                                index = AggToVar, columns = prd_col,
                                aggfunc = 'count')


    #get total flow within each time period for each link (sum of all flows at all stations on each <AggToVar>)
    piv_flowsum = pd.pivot_table(df[piv_cols],
                                values = vol_col, index = AggToVar,
                                columns = prd_col, 
                                aggfunc = 'sum')
    
    #divide total flow/total hour bins to get average hourly flow at each <AggToVar> in each time period
    piv_flowhr = piv_flowsum.divide(piv_prdcnt)
    piv_flowavg = piv_flowhr #preserve pflowhr if needed
    piv_flowavg_cols = list(piv_flowavg.columns)

    #for each time period, multiply the average per-hour flow by number of hours in that period to get that period's average flow
    for c in piv_flowavg_cols:
        prd_durn = len(Prds[c]) #duration in hours of period
        piv_flowavg[c] = piv_flowavg[c].apply(lambda x: x*prd_durn)

    # hr24, looks like a system wide issue where all sensors were reset at hr 24 for 2018, imputing
    # Note imputing the same day 1am & 11pm, should adjust to using next day 1am.
    if 'H24' in piv_flowavg.columns:
        bool_series = pd.isnull(piv_flowavg['H24'])
        if ('H01' in piv_flowavg.columns and 'H23' in piv_flowavg.columns):
            piv_flowavg.loc[pd.isnull(piv_flowavg['H24']),'H24'] = (piv_flowavg['H23'] + piv_flowavg['H01'])/2
            print('imputed some flows for hour 24')
    if not 'H24' in piv_flowavg.columns:
        if ('H01' in piv_flowavg.columns and 'H23' in piv_flowavg.columns):
            piv_flowavg['H24'] = (piv_flowavg['H23'] + piv_flowavg['H01'])/2
            print('imputed all hour 24 flows')

    piv_flowavg = piv_flowavg.reset_index()
    
    #average flow for each time period at each link (average of station flows for multi-station links)
    prds_flow_s = piv_flowavg.groupby(AggToVar).mean().reset_index()
    sumlist = list(Prds.keys())
    prds_flow_s['hasnull'] = prds_flow_s.isnull().any(axis = 1) #add tag indicating if any of the columns has a null value
    try:
        prds_flow_s['DAYVOL'] = np.where(prds_flow_s.isnull().any(axis = 1),None,prds_flow_s[sumlist].sum(axis = 1))
    except Exception as e:
        print(e)
        prds_flow_s['DAYVOL'] = None

    df_4dir = df[[AggToVar, dir_col, lanetype_col, capclass_col,S_ID_col]].drop_duplicates()

    # combine df for output
    piv_prdcnt.rename(columns = lambda c: c+"cnt",inplace=True)
    piv_prdcnt_all.rename(columns = lambda c: c+"cntall",inplace=True)

    dfs = [df_4dir,prds_flow_s,piv_prdcnt,piv_prdcnt_all]
    output = reduce(lambda left,right: pd.merge(left,right,how = 'inner',on = AggToVar),dfs)

    #output = output[output['hasnull'] == False] #get rid of rows where one of the columns has null count values
    print("output:")
    print(output.head(3))
    return output
    
def write2csv(in_df,outname_csv,index=False):
    in_df.to_csv(os.path.join(output_dir,outname_csv),index = index)

def adt_df(link_vol_TR,wktype,ym1,link_corrfile, corr_columns,df_adt_all,vol_hrsdf):

    dfcname = ym1 + wktype

    if not df_adt_all.empty:
        #join only new Daily Count by aggregation column
        link_vol_TR[dfcname] = link_vol_TR['DAYVOL']

        #loop through all periods to give all hours together
        clist = []
        clist.append(AggToVar)
        for c in Prds:
            try: #adding this in incase houlry has no volume, review exception errors...
                dfprdsname = dfcname + c
                link_vol_TR[dfprdsname] = link_vol_TR[c]
                clist.append(dfprdsname)
            except Exception as e:
                print(e)
        dfcnameADT = dfcname + "ADT"
        link_vol_TR[dfcnameADT] = link_vol_TR['DAYVOL']
        clist.append(dfcnameADT)

        df_adt_all = pd.merge(df_adt_all,link_vol_TR[[AggToVar,dfcname]],on=AggToVar,how='left')
        vol_hrsdf = pd.merge(vol_hrsdf, link_vol_TR[clist], on=AggToVar, how='left')
    else:
        df_adt_all = link_vol_TR
        df_adt_all[dfcname] = df_adt_all['DAYVOL']
        df_adt_all=df_adt_all[[AggToVar,dfcname]]

        vol_hrsdf = link_vol_TR
        clist = []
        clist.append(AggToVar)

        for c in Prds:
            try:
                dfprdsname = dfcname + c
                vol_hrsdf[dfprdsname] = vol_hrsdf[c]
                clist.append(dfprdsname)
            except Exception as e:
                print(e)

        dfcnameADT = dfcname + "ADT"
        vol_hrsdf[dfcnameADT] = vol_hrsdf['DAYVOL']
        clist.append(dfcnameADT)
        vol_hrsdf = vol_hrsdf[clist]


    return df_adt_all,vol_hrsdf

def exportSummary(df_out_all,days_of_week_name,a,sumby=AggToVar):
    df_out_all.set_index(sumby)
    for d in days_of_week_name:
        outname = "{}_{}.csv".format(a,d)
        df_out = df_out_all.filter(like=d)
        df_out = pd.merge(df_out_all[[sumby]],df_out, how='outer', left_index=True, right_index=True)
        write2csv(df_out,outname)
        print("output:{}".format(outname))
    outname = "{}_all.csv".format(a)
    write2csv(df_out_all,outname)
    print("output:full list as {}".format(outname))

def do_stuff(days_of_week,link_corrfile, corr_columns, obs_th,
                 ym1, CntWeekType, out, df_adt_full, vol_hrsdf_full,master):

    link_vol_TR = link_avg_x_prd(master,days_of_week, obs_th)
    write2csv(link_vol_TR,out)

    df_adt_all,vol_hrsdf = adt_df(link_vol_TR,CntWeekType,ym1,link_corrfile, corr_columns,df_adt_full,vol_hrsdf_full)

    return df_adt_all,vol_hrsdf

def do_analysis(days_of_week,days_of_week_name,obs_threshold,df_adt_full,vol_hrsdf_full,multi_file_agg,start,Mrange,stop):

    # loop through all other raw input months and make one long table
    if multi_file_agg:
        fileDict = buildrange(start,Mrange,stop)
        multihourly_dict = multi_file_hourly(fileDict,hourly_files)

        for key in multihourly_dict:
            cdate = key
            x = len(days_of_week)
            corr_df = pd.read_csv(link_corrfile, usecols=corr_columns)
            master = make_master_df(hourly_data_dir, hourly_files, corr_df, multi_file_agg, multihourly_dict, key)

            for sumwk in days_of_week:
                if x < len(days_of_week):
                    x = x+1
                else:
                    x = 0
                WeekTypeName = days_of_week_name[x]

                output_csv = 'PeMSxStation_ran{}_cnt{}_{}.csv'.format(date_suf,cdate,WeekTypeName)

                # main function, returns total and individual hourly summarized results.
                df_adt_all,vol_hrsdf = do_stuff(sumwk,
                                        link_corrfile, corr_columns, obs_threshold,
                                        cdate,
                                        WeekTypeName,output_csv,df_adt_full,vol_hrsdf_full,master)

                print("added {}".format(output_csv))
                df_adt_full = df_adt_all
                vol_hrsdf_full = vol_hrsdf

    #summarize each month individually
    else:
        for f in hourly_files:

            year = os.path.basename(f).split('_')[4][2:]
            month = os.path.basename(f).split('_')[5][:2]
            ym = [year,month]
            cdate = ym[0]+ym[1]

            x = len(days_of_week)

            corr_df = pd.read_csv(link_corrfile, usecols=corr_columns)
            master = make_master_df(hourly_data_dir, f, corr_df, multi_file_agg)

            for sumwk in days_of_week:
                if x < len(days_of_week):
                    x = x+1
                else:
                    x = 0
                WeekTypeName = days_of_week_name[x]

                output_csv = 'PeMSxStation_ran{}_cnt{}_{}.csv'.format(date_suf,cdate,WeekTypeName)
                #need to fix this, pulled master out of do stuff...
                df_adt_all,vol_hrsdf = do_stuff(sumwk,
                                        link_corrfile, corr_columns, obs_threshold,
                                        cdate,
                                        WeekTypeName,output_csv,df_adt_full,vol_hrsdf_full,master)

                print("added {}".format(output_csv))
                df_adt_full = df_adt_all
                vol_hrsdf_full = vol_hrsdf

    exportSummary(df_adt_all,days_of_week_name,"ADT")
    exportSummary(vol_hrsdf_full, days_of_week_name,"ADT_wPrds")

    #Note:
    # need to add summarize by S_ID aka groupby mainlines and HOV together, currently just post processed this in Excel...
    # check for duplicates or add drop_duplicate to dataframe.

    print("Complete: {} minutes {} ---".format(round((time.time() - start_time) / 60, 1),(now.strftime("%Y-%m-%d %H:%M"))))

if __name__ == '__main__':
    
    ########## input files ###################################

    #Raw PeMS data folder path
    # downloaded from http://pems.dot.ca.gov/?dnode=Clearinghouse&type=station_hour&district_id=3&submit=Submit
    hourly_data_dir = r'Q:\Big_Data_Pilot_Project\TrafficCounts\Data Collection\PEMS\Raw\Hourly\Seasonal_2009_2011'
    # threshold for data quality, for percent of PeMS data that's observed at a station
    obs_threshold = 90

    # preprossed correspondance between model links and PeMS stations using meta data station download, SACSIM AB IDs & create unique ID to join HOV and ML together as "S_ID"
    link_corrfile = r'Q:\Big_Data_Pilot_Project\TrafficCounts\Data Collection\PEMS\Model_w_Dir_Counts_from2020MTP.csv'
    #columns to include at top of script
    columnskeep = ['ID', 'S_ID', 'Fwy', 'Dir', 'Type_', 'Lanes', 'Name', 'County', 'City', 'State_PM', 'Abs_PM']

    # specify variable to aggregate to ex: A_B,ID,S_ID
    AggToVar = stn
    # specify period aggregation dictionary
    Prds = pems_hrly
    #list weekly summaries and names (must be the same order and length)
    days_of_week = [swl_wk7,swl_wk4,swl_wknd1,wknd3,mon,tue,wed,thr,fri,sat,sun]
    days_of_week_name = ['swl_wk7','swl_wk4','swl_wknd1','wknd3','mon','tue','wed','thr','fri','sat','sun']
    #days_of_week = [wkday5]
    #days_of_week_name = ['wkday5']
    # for testing
    #days_of_week = [swl_wk7,sun]
    #days_of_week_name = ['swl_wk7','sun']

    #combine and average monthly data, will need for seasonal aggregation
    multi_file_agg = True
    # if True, else ignore.
    # start = int(input("Enter start date in PeMS Database format e.g. 1601 equals 2016 January: "))
    # Mrange = int(input("Enter number of months in season: "))
    # stop = int(input("Enter last file to summarize e.g. 1907 equals 2019 July: "))
    start = 1909
    Mrange = 6
    stop = 2002

    # output directory and table names
    output_dir = r'Q:\Big_Data_Pilot_Project\TrafficCounts\Data Collection\PEMS\ProcessedPeMS\pems_SACSIM19_Seasonal_2009_2011'
    output_csv = 'PeMSxStation{}.csv'.format(date_suf)
    ###################################################

    # check inputs.
    hourly_files = [f for f in os.listdir(hourly_data_dir) if re.match('d03.*',f)]
    df_adt_full = pd.read_csv(link_corrfile, usecols=columnskeep)
    vol_hrsdf_full = df_adt_full.copy(deep=True)

    # Start
    do_analysis(days_of_week,days_of_week_name,obs_threshold,df_adt_full,vol_hrsdf_full,multi_file_agg,start,Mrange,stop)
