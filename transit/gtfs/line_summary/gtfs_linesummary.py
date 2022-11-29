# -*- coding: utf-8 -*-
"""
Name: name_here.py
Purpose: 
    Name - agency id + route id + route direction
    Mode - initially set to zero, then explore ways to populate
        Will be stuff like LRT/Commuter/Local Bus/etc.
    For each of the 5 time periods:
        HeadwayX = count of trip departures/minutes in period X
        Head1X = time elapsed between first and second headways in time period X
        TrpCntX = count of trips in time period X
        Trip1stX = time of first trip in time period X
        Trip2ndX = time of 2nd trip in time period X

    Headway periods: 5am-9am, 9am-3pm, 3pm-6pm, 6pm-8pm, 8pm-11pm

    PREPARATION: 
    1. Set up a folder (out_dir) containing unzipped folders of each operator's GTFS data
    2. update the spec_file CSV, ideally kept inside the folder of GTFS data you set up,
        so that it points to the correct files within each operator's folder.
    3. If available, set up a lookup file so you can link between GTFS line names and old model line names

Author: Darren Conly
Last Updated: Mar 2022
Updated by: 
Copyright:   (c) SACOG
Python Version: 3.x
"""
import os

import pandas as pd
import datetime as dt
import arcpy
import math
import csv


#===============USER INPUTS==================================
in_dir = r'Q:\SACSIM19\2020MTP\transit\GTFS2016' # contains GTFS folders for all operators
out_dir = r'Q:\SACSIM19\2020MTP\transit\python\tranline_link_outputs' # where you want output CSV to go

#specifies which input files correspond to each operator. Some operators required modified versions to be made,
#these modified versions are listed out as value lists in agencies_dict
#read in from spec_file, this specifies which GTFS files get used
#for each operator. Change values in CSV as needed.
spec_file = r"\\data-svr\Modeling\SACSIM19\2020MTP\transit\python\GTFS\gtfs_input_spec.csv"

#specifies file that relates SACSIM15 (or SS19, for updating to SS23) line names to GTFS line names
lookup_old_line_names = False
lookup_xls = r'Q:\SACSIM19\2020MTP\transit\Line Naming Changes_latest.xlsx'
lookup_sheet = 'MasterLookup'

# if set to false, only a pandas dataframe will be made. 
make_csv = True # input('Make CSV output (y/n)? ')

#=================SELDOM-CHANGED INPUTS===============

#initially GTFS data are set as WGS1984 coord system
spatialref_wgs = arcpy.SpatialReference(4326) 

#SACOG's system: NAD_1983_StatePlane_California_II_FIPS_0402_Feet
projectnref = arcpy.SpatialReference(2226) 

#default input files. 
agencies_dict = {}

with open(spec_file, 'r') as sf_in:
    header = sf_in.readline().strip('\n').split(',')
    header.sort()
    header = header[1:]
    
    sf_in.seek(0)
    in_csv_dict = csv.DictReader(sf_in)

    
    for row in in_csv_dict:
        if agencies_dict.get(row['agency']) is None:
            agencies_dict[row['agency']] = []
        for col in header:
            agencies_dict[row['agency']].append(row[col])

agencies_list = list(agencies_dict.keys())

route_cols = ['agency_id', 'route_id','route_long_name']
trip_cols = ['route_id','trip_id','direction_id','service_id','shape_id']
stoptimes_cols = ['trip_id','departure_time','stop_id','stop_sequence']
svc_day_cols = ['service_id','monday','saturday','sunday'] #use to omit sat/sun service

#{period id: [start mins after 12am, end mins after 12am]}
periods = {1:[300,540], 2:[540,900], 3:[900,1080], 4:[1080,1200], 5:[1200,1380],
           6:[1380,1600]}

agency_rename_dict = {'ETran':'ETRN',
                      'SRTD':'SRTD',
                      'Roseville':'RSVL',
                      'Unitrans':'UTRN',
                      'YubaSutter':'YUSU',
                      'YoloBus':'YOLO',
                      'ElDorado':'ELDO',
                      'PCT':'PLAC'}

#============================FUNCTIONS=====================
#take agency's stop, trips, stoptimes tables and merge them into one

agency_files = ['calendar','routes','shapes','stop_times','stops','trips']
def merger(agency,input_file_list):
    routes = input_file_list[agency_files.index('routes')]
    trips = input_file_list[agency_files.index('trips')]
    stoptimes = input_file_list[agency_files.index('stop_times')]
    svc_days = input_file_list[agency_files.index('calendar')]
    direc = in_dir + '\\' + agency
    
    
    route_df = pd.DataFrame(pd.read_csv(direc + '\\' + routes,
                                        usecols = route_cols))
    
    trip_df = pd.DataFrame(pd.read_csv(direc + '\\' + trips,
                                        usecols = trip_cols))
    
    stoptime_df = pd.DataFrame(pd.read_csv(direc + '\\' + stoptimes,
                                        usecols = stoptimes_cols))
    
    svc_days_df = pd.DataFrame(pd.read_csv(direc + '\\' + svc_days,
                                        usecols = svc_day_cols))
    
    master = route_df.merge(trip_df,how = 'left', on = 'route_id') \
                    .merge(stoptime_df,how = 'left', on = 'trip_id') \
                    .merge(svc_days_df,how = 'left', on = 'service_id')
    return master

#indicate direction with A/B indicator
def direcn_tag(idstr):
    if idstr[-3:] == '0.0':
        return idstr[:-3] + 'A'
    elif idstr[-3:] == '1.0':
        return idstr[:-3] + 'B'
    else:
        return idstr
    
def time_prd_tagger(in_df,time_col,prd_key):
    in_df.loc[(in_df[time_col] >= periods[prd_key][0]) 
               & (in_df[time_col] < periods[prd_key][1]) 
               ,'time_prd_id'] = prd_key
    return in_df

def time_str_converter(in_int):
    hours_dec = in_int / 60
    hours_whole = int(math.floor(hours_dec))
    mins = str(int(round((hours_dec - hours_whole)*60)))
    mins = mins.zfill(2)
    
    return str(hours_whole) + ':' + mins

#============================LOAD AND PREP MASTER TABLE=====================


#for each agency, load its tables, merge them, then append them to single,
#multi-agency table

for agency in agencies_list:
    print('loading data for ' + agency + '...')
    if agency == agencies_list[0]:
        master = merger(agency,agencies_dict[agency])
    else:
        next_agency = merger(agency,agencies_dict[agency])
        master = pd.concat([master, next_agency])
    
#filter out saturday-sunday service
master = master.loc[(master['saturday'] == 0) \
                    & (master['sunday'] == 0) \
                    & (master['monday'] == 1)]

#convert time to metric format (minutes after midnight)

#get rid of null values
master.loc[pd.isnull(master['departure_time']),'departure_time'] = '00:00:00'

#add minutes-after-midnight time column,
master['dep_time2'] = master['departure_time'].str.extract('(\d+)', 
                             expand=False) \
                            .astype(int) * 60 \
                    + master['departure_time'].str.extract('.*:(\d+):.*', 
                            expand=False) \
                            .astype(int)
                            
#create unique line name from agency_id + route_id + direction_id
master['agency_id_short'] = master['agency_id'].apply(lambda x:
                                                       agency_rename_dict[x])

master['uniq_rte_name'] = master['agency_id_short'] \
                            + master['route_id'].map(str) \
                            + '_' \
                            + master['direction_id'].map(str)
                          
master['uniq_rte_name'] = master['uniq_rte_name'].apply(direcn_tag)

#make unique trip id column
master['trip_uid'] = master['uniq_rte_name'] + master['trip_id'].map(str)

master['shape_uid'] = master.apply(lambda x: x['agency_id_short'] \
                                  + str(x['shape_id']),axis=1)

#regex to remove the ".0" that mysteriously gets appended to shape_uid
master['shape_uid'] = master['shape_uid'].str.replace('\.0$','')
              
#--------------------STOP COUNT INFO-------------------------------------
#get count of stops in each trip
trip_grp = master.groupby('trip_uid')
trip_stop_cnt = trip_grp['stop_id'].count()

master = master.join(trip_stop_cnt,
                     on = 'trip_uid',
                     how = 'right',
                     rsuffix = '_stpcnt')

#get max number of stops on single trip for each route
rte_fullgrp = master.groupby('uniq_rte_name')
max_stops = rte_fullgrp['stop_id_stpcnt'].max()

master = master.join(max_stops,
                     on = 'uniq_rte_name',
                     how = 'right',
                     rsuffix = '_maxstpcnt')

#--------------------------TIME PERIOD INFO-----------------------------

#add time periods column
#if the dep_time2 was zero, then the time period was set to 99
master['time_prd_id'] = 99
for prd in periods.keys():
    master = time_prd_tagger(master,'dep_time2',prd)

                       
#add time period duration (mins) column
master['prd_duratn'] = 0
master = master.merge(pd.DataFrame(periods).T,
                      how = 'left',
                      left_on = 'time_prd_id',
                      right_index=True)
master['prd_duratn'] = master[1] - master[0]

#del the columns indicating period start and end time
del master[1],master[0]

#-------------------------GET ROUTE SHAPE FOR EACH TRIP-------------

shapes_pnt_dic = {}


#dict with shape_uid:[list of points in that shape]
print("getting line shape data for trips...")
for agency in agencies_list:
    with open(in_dir + '\\' + agency + '\\' + \
              agencies_dict[agency][agency_files.index('shapes')],'r') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            lat = row['shape_pt_lat']
            lon = row['shape_pt_lon']
            pnt_shp = arcpy.Point(lon,lat)
            shape_uid = agency_rename_dict[agency] + row['shape_id']
            if shapes_pnt_dic.get(shape_uid) is None:
                shapes_pnt_dic[shape_uid] = []
            shapes_pnt_dic[shape_uid].append(pnt_shp)
            
#make a line out of points for each shape_uid
shape_len_dic = {}

for shp_uid in shapes_pnt_dic.keys():
    pnt_list = shapes_pnt_dic[shp_uid]
    array = arcpy.Array()
    for point in pnt_list:
        array.add(point)
    tripshp = arcpy.Polyline(array,spatialref_wgs)
    triplength = tripshp.getLength("PRESERVE_SHAPE","MILES")
    if shape_len_dic.get(shp_uid) is None:
       shape_len_dic[shp_uid] = triplength
       
       

triplen_df = pd.DataFrame.from_dict(shape_len_dic,orient = 'index')

triplen_df['sid'] = triplen_df.index.astype(str)

master = master.merge(triplen_df,left_on = 'shape_uid', right_on = 'sid',
                      how = 'left',
                      right_index = True)
master = master.rename(columns = {0:'trip_len_mi'})

#-------------------------------------------------------------------

#get time period during which each trip left the first stop
trip_grp = master.groupby('trip_uid')
tgmin = trip_grp['time_prd_id'].min()

master = master.join(tgmin,on = 'trip_uid',how = 'left',rsuffix = '_startprd')
master = master.rename(columns = {'time_prd_id_startprd':'start_time_prd'})

#get start time of first trip

#simple 'minimum' not sufficient because blank stop times are set to zero.
#need to set start time as being time where stop_sequence == 1
trip_grp_sq1 = master[master['stop_sequence'] == 1].groupby('trip_uid')

tripstart = trip_grp_sq1['dep_time2'].min()
master = master.join(tripstart,on = 'trip_uid',how = 'left',rsuffix = '_1stStpDep')
master = master.rename(columns = {'dep_time2_1stStpDep':'dep_1ststop'})

#if start time is before 3am, set start_time_prd = 99
master.loc[master['dep_1ststop'] < 300, 'start_time_prd'] = 99

#remove trips whose start period is 6 or 99
master = master.loc[master['start_time_prd'] < 6]
            

#--------------Get duration of each trip, including partial trips--------------
#only for trips that departed first stop during model hours
trip_grp = master.groupby('trip_uid') #to get arrival time at last stop

#to get departure time from first stop without accidentally counting zeroes
trip_grp_sq1 = master[master['stop_sequence'] == 1].groupby('trip_uid')

#trip_tbl = master[['trip_uid','agency_id','uniq_rte_name',
#                   'trip_id','start_time_prd','stop_id_stpcnt',
#                   'stop_id_stpcnt_maxstpcnt']].drop_duplicates() 


#trip departure time from first stop, last stop, and trip duration
#will this exclude "zeroes"?
tripstart = pd.DataFrame(trip_grp_sq1['dep_time2'].min())
tripend = pd.DataFrame(trip_grp['dep_time2'].max())

duration_df = tripstart.merge(tripend, left_index = True, right_index = True,
                              suffixes = ('_start','_end'))

duration_df['duration'] = duration_df['dep_time2_end'] \
                        - duration_df['dep_time2_start']
                        
#del duration_df['dep_time2_end'], duration_df['dep_time2_start']


#add trip duration to master table via a merge
master = master.merge(duration_df, how = 'left', left_on = 'trip_uid', 
                          right_on = 'trip_uid', right_index = True,
                          suffixes=('_x', '_y'))

del duration_df
                  
#==================ROUTE-LEVEL SUMMARIZING=============================
#version of master table that only includes full runs;
#will be used to calculate average end-to-end route travel time
master_fulltrips = master[master['stop_id_stpcnt'] \
                              == master['stop_id_stpcnt_maxstpcnt']]

#make master list of all unique routes
print('calculating headway and trip count columns...')
mroutes = master[['uniq_rte_name','agency_id',
                  'route_long_name']].drop_duplicates()

#append SACSIM15 names
if lookup_old_line_names:
    lookup_df = pd.DataFrame(pd.read_excel(lookup_xls,sheet_name = lookup_sheet))
    lookup_df = lookup_df[['uniq_rte_name','ss15name']]
    mroutes = mroutes.merge(lookup_df,how = 'left', on = 'uniq_rte_name',
                suffixes = ('_x','_y'))
                        

print('summarizing at line level...')
for prd in list(periods.keys())[:-1]: #
    
    #return only stop times at first stop on route, in the specified time
    #period, then sort by route and departure time
    temp = master.loc[(master['time_prd_id'] == prd) \
                      & (master['stop_sequence'] == 1.0)]
    temp = temp.sort_values(['uniq_rte_name','dep_time2'])
    
    #same thing, but just for full trips; to be used for average end-end TTs
    temp_fulltrp = master_fulltrips.loc[(master_fulltrips['time_prd_id'] == prd) \
                      & (master_fulltrips['stop_sequence'] == 1.0)]
    temp_fulltrp = temp_fulltrp.sort_values(['uniq_rte_name','dep_time2'])

    
    t_grp = temp.groupby('uniq_rte_name') #unique routes groupby, incl. partials
    t_grp_full = temp_fulltrp.groupby('uniq_rte_name') #unique rtes gpby, only full trips
    
    uniq_trips = t_grp['trip_id'].nunique() #count of unique trips
    trip_1 = t_grp['dep_time2'].nth(0) #dep_time2 of 1st trip
    
    trip_2 = t_grp['dep_time2'].nth(1) #dep_time2 of 2nd trip
    
    for i in [uniq_trips,trip_1,trip_2]:
        mroutes = mroutes.join(i,on = 'uniq_rte_name',how = 'left',
                           rsuffix = '_2')
    
    mroutes = mroutes.rename(columns = {'trip_id':'tripcnt_' + str(prd),
                                        'dep_time2':'first_dep' + str(prd),
                                        'dep_time2_2':'second_dep' + str(prd)})
    
    #calc avg headway by period: (total period duration) / (count of trips in period)
    mroutes['avgheadway_' + str(prd)] = (periods[prd][1] \
                                    - periods[prd][0]) \
                                    / mroutes['tripcnt_' + str(prd)]
                                    
    #calc headway between 1st and 2nd trip of period
    #note this may calculate zero if the first two trips depart at the same
    #time but from separate locations
    mroutes['iheadway_' + str(prd)] = mroutes['second_dep' + str(prd)] \
                                      -  mroutes['first_dep' + str(prd)]
                                      
    #vehicle service hours in period, including partial trips
    #theoretically unique trips are given in temp, so if grouping by route name,
    #you just take the simple sum of the 'duration' values
    vsh = t_grp['duration'].sum()/60  
    mroutes = mroutes.join(vsh, on = 'uniq_rte_name', how = 'left',
                           rsuffix = '_sum')
    
    #estimate average time to travel route for FULL trips, not partials
    avg_duration = t_grp_full['duration'].mean()
    
    #if no full runs in time period, then avg duration will be all-run avge
    avg_duration2 = t_grp['duration'].mean()
                            
    
    mroutes = mroutes.join(avg_duration, on = 'uniq_rte_name', how = 'left',
                           rsuffix = '_rte') \
                     .join(avg_duration2, on = 'uniq_rte_name', how = 'left',
                           rsuffix = '_rte2')

    mroutes['duration_rte'] = mroutes['duration_rte'] \
                            .fillna(mroutes['duration_rte2'])
    
    del mroutes['duration_rte2']
    
    mroutes = mroutes.rename(columns = {'duration_rte':'avg_trpdur' + str(prd),
                                        'duration':'vsh_' + str(prd)})
    
    #get harmonic avg speed (sum trip dists/sum trip durations) 
    #for all trips, incl. partials
    tot_dist = t_grp['trip_len_mi'].sum()
    harm_avg_speed = tot_dist/vsh
    
    mroutes = mroutes.merge(harm_avg_speed.to_frame(),
                            how = 'left',
                            left_on = 'uniq_rte_name',
                            right_index = True) 
    
    mroutes = mroutes.rename(columns = {0:'avg_speed' + str(prd)})
    
    #get route vsm
    avg_fulltrp_dist = t_grp['trip_len_mi'].sum()
    mroutes = mroutes.merge(avg_fulltrp_dist.to_frame(), 
                            how = 'left',
                            left_on = 'uniq_rte_name',
                            right_index = True) 
    
    mroutes = mroutes.rename(columns = {'trip_len_mi':'vsm' + str(prd)})
                                                      

                                     
#===================EXPORT TO CSV========================================
if make_csv:
    
    sufx = str(dt.datetime.now().strftime('%Y%m%d_%H%M'))
    out_csv = f"gtfs_linesummary{sufx}.csv"
    out_path = os.path.join(out_dir, out_csv)
    print(f'writing to {out_path}')
    mroutes.to_csv(out_path,index = False)
    
print('-'*30)
print('Success! Output summary:')
print('Latest trip end time: ' + time_str_converter(master.dep_time2.max()))
print('Earliest trip start time: ' + time_str_converter(master.dep_time2.min()))
print('Latest trip start time: ' + time_str_converter(master.dep_1ststop.max()))
