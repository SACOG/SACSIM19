"""
Name: retrieve_modeled_project_year.py
Purpose: 
    •	Only for links that have a SACTRAK ID
    •	Where LANES, CAPCLASS, or BIKE value changed
    •	Flag which among lanes, capclass, and bike changed
    
    Example output table fields
    •	Link A/B values
    •	Lane change indicator
        o	If lanes changed, return each year that they changed and add it to a semicolon-separated list
        o	If they didn’t change in any years, return -1
        o	**For 2035/2040, only look at “DPS” version
    •	CAPC change indicator (same rules as lane change indicator)
    •	BIKE indicator (same rules as lane change indicator)
    
    
    With this table:
    •	Compare year changed to SACTRAK or latest official project list years, see where there’s a discrepancy, at the link level, using a VLOOKUP function with SACTRAK ID as key.

        
Author: Darren Conly
Last Updated: Oct 2020
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import os
import re

import pandas as pd
import dbfread


# ==========INPUTS=========================
# input DBF
dbf_in = r"Q:\SACSIM19\2020MTP\highway\network update\NetworkGIS\DBF\Link\masterSM19ProjCoding_latest_10152020.dbf"

csv_out = r'Q:\SACSIM19\2020MTP\highway\network update\Project Coding\QA\modeled_change_year_x_link.csv'

#2-digit year formats
base_year_2dig = 16 
horizon_year_2dig = 40

dps_years = [35, 40] # years that have special versions (e.g. "all projects version" vs "pref'd scenario verison")
keep_sc_flag = 'DPS' #scenario you want to keep if multiple scenarios for single year

# fields to use
col_sactrak = "SACTRAK"
col_phase2 = "PHASE2"
col_A = "A"
col_B = "B"

prefx_speed = "SPD"
prefx_capclass = "CAPC"
prefx_lanes = "LANE"
prefx_bike = "BIKE"

sufx_horizon = f"{horizon_year_2dig}_DPS"

# important field values
sactrak_none = '' # link has no SACTRAK


#==========INPUTS THAT DON'T CHANGE MUCH===============
# specify prefixes that indicate attributes that you want to check for change
std_cols = [col_A, col_B, col_sactrak ]
check_attribs = [prefx_speed, prefx_capclass, prefx_lanes, prefx_bike]

#=============MAIN SCRIPT====================

def make_4digit_year(in_2digit_year, years_to_add=2000):
    return in_2digit_year + years_to_add

def version_filter(in_str, check_str, yes_filter_val):
    if re.search(check_str, in_str):
        if re.search(yes_filter_val, in_str):
            return in_str
        else:
            pass
    else:
        return in_str

# read in master net DBF as pandas dataframe
print("reading in DBF into pandas dataframe...")
dbf = dbfread.DBF(dbf_in)
df = pd.DataFrame(iter(dbf))

# filter to only include rows where there's a SACTRAK ID
df = df.loc[(df[col_sactrak] != sactrak_none)]

# convert df to dict records (each row is a dict with headers as keys and row values as vals)
dfd = df.to_dict(orient='records') # list of dicts; each row is a dict; this is a list of dicts


# specify any years for which there are exceptions (e.g. for 2035 and 2040, you 
# only want the "_DPS" version of each attribute for that year)



# make list of all columns to use (all speed, capclass, lanes, bike columns for all years)

# regex to extract the year from each attribute (e.g. 'CAPC20' retrieve integer 2020)
re_year_extract = re.compile('[0-9]+')
re_prefx_extract = re.compile('[A-Za-z]*')

# set up an "output list" that will be a list of dicts
output_list = []

# for rowdict in the df-to-dict object:
print("Getting the first year that changes happened to link attributes, for links with projects...")
for rowdict in dfd:
    # set up an "output dict" that will be one item in the output list of dicts, called "outdict"
    # by default, add boilerplate data (A, B, SACTRAK)
    out_dict = {colname: rowdict[colname] for colname in std_cols}
    
    if rowdict[col_phase2] != '':
        out_dict[col_phase2] = rowdict[col_phase2]
    
    # identify base-year values for speed, capc, lanes, bike
    by_attribcolnames = [f"{colname}{base_year_2dig}" for colname in check_attribs]
    by_vals_dict = {colname: rowdict[colname] for colname in by_attribcolnames}
    
    # make a list of all the columns for which you'll be checking the values against base year
    check_cols_1 = [col for col in rowdict.keys() if re.search(re_year_extract, col) is not None]
    check_cols = []
    
    for col in check_cols_1:
        col2 = version_filter(col, '_', keep_sc_flag)
        if col2: 
            check_cols.append(col2)
        else: continue
    
    for colname in check_cols:
        re_prefx = re.search(re_prefx_extract, colname) #get attribute type (e.g. BIKE, CAPCLASS, etc.)
        re_sc_year = re.search(re_year_extract, colname) # get the year for the field
        if re_prefx is not None: prefx = re_prefx.group(0)
        if re_sc_year is not None: sc_year = re_sc_year.group(0)
        
        # rowdict[cname] is the value for that attribute for that year (e.g. the BIKE value for 2021)
        # compare that value against the base-year value for that attribute (e.g. the 2016 BIKE value)
        # if the values match, pass
    
        # if the attribute type is not within the types to check, then don't get its value from rowdict
        if prefx not in check_attribs or int(sc_year) < base_year_2dig or re_sc_year is None:
            continue
        else:
            sc_year_val = rowdict[colname]
            
            bydict_colname = f"{prefx}{base_year_2dig}"
            if sc_year_val == by_vals_dict[bydict_colname]: # skip if the base year value and scenario value are the same for the attribute
                continue
            else:
                # print(prefx, sc_year, '|{}'.format(sc_year_val))
                out_colname = f"{prefx}_changeyears"
                sc_year_int = int(sc_year)
                sc_year_4dig = make_4digit_year(sc_year_int)
                
                out_val = f"{sc_year_4dig}" # return year as string
                
                if out_dict.get(out_colname) is None:
                    out_dict[out_colname] = [out_val]
                else: 
                    out_dict[out_colname].append(out_val) # if multiple years of change, make semicolon-separated list of those changes.
                    out_dict[out_colname] = [min(out_dict[out_colname])]
    
    out_dict = {k: int(min(v)) if type(v) == list else v for k, v in out_dict.items()}
    output_list.append(out_dict)
    
df2 = pd.DataFrame(output_list)

df2.to_csv(csv_out, index=False)

print("Success! be careful to look for projects that have a PHASE2 value for them")


