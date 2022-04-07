"""
Name:model_topline_summary.py
Purpose: Get topline, region-totals summary of some of the most common metrics we like to pull
    from SACOG's Integrated Land Use-Transportation (ILUT) process. ILUT is great, but takes 10-20mins to set up and run,
    and has dependencies like SQL Server. this aims to be an alternative to make the process faster and easier.

    OUTPUTS
        o	Total trips by mode
    o	Trip share by mode
    o	Total person trips
    o	Residential VMT
    o	VMT/capita
    o	Population

        
          
Author: Darren Conly
Last Updated: Oct 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import os
import datetime

import arcpy
import pandas as pd
from dbfread import DBF
from pandas.core.arrays import categorical

from pandas_memory_optimization import memory_optimization
from get_unc_path import build_unc_path


class modelRunSummary:
    def __init__(self, model_run_dir, road_vmt_dbf=None, scenario_desc=""):
        
        self.model_run_dir = model_run_dir
        self.road_vmt_dbf = road_vmt_dbf
        self.scenario_year = self.get_year_from_prn()
        self.scenario_desc = scenario_desc

        # trip table attributes
        self.in_trip_file = '_trip_1_1.csv' #trip table name
        self.c_pno = 'pno'
        self.c_hhno = 'hhno'
        self.c_mode = 'mode'
        self.c_dorp = 'dorp'
        self.c_distau = 'distau'
        self.c_distcong = 'distcong'

        self.tripcols = [self.c_hhno, self.c_mode, self.c_dorp,
                        self.c_distau, self.c_distcong] #specify columns you want to import. This will save memory.
        
        self.df_trip = self.load_table(self.in_trip_file, self.tripcols)
        

        # hh table attributes
        self.in_hh_file = '_household.tsv'
        self.c_hhsize = 'hhsize'

        self.hhcols = [self.c_hhno, self.c_hhsize]

        self.df_hh = self.load_table(self.in_hh_file, self.hhcols, delim_char='\t')

    def load_table(self, in_table, use_cols, delim_char=','):
        tbl_path = os.path.join(self.model_run_dir, in_table)
        arcpy.AddMessage(f"reading {tbl_path} into dataframe...")
        df = pd.read_csv(tbl_path, usecols=use_cols, delimiter=delim_char)
        memory_optimization(df)
        return df

    def get_year_from_prn(self):
        prn_file = [f for f in os.listdir(self.model_run_dir) if os.path.splitext(f)[1].lower() == '.prn'][0]
        sc_year = prn_file[:4]
        return sc_year

    def calc_res_vmt_paxcnt(self, vmt_col):
        """
        'Normal' way of calculating total residential VMT: assumes VMT is halved for HOV2 trips,
        and a bit more than 70% reduced for HOV3+ trips.
        """

        mgrp = self.df_trip.groupby('mode')
        sumxmode = mgrp.sum()[vmt_col] #get sum of vmt grouped by mode
        sov_vmt =  sumxmode[3]  #sov vmt, or row where mode = 3, or sov
        hov2_vmt = sumxmode[4] * 0.5 #vmt/person-trip is half for 2-person carpool
        hov3plus_vmt = sumxmode[5] * 0.3 #averaging that 3+ carpool has 0.3 times the per-person vmt
        total_vmt = sov_vmt + hov2_vmt + hov3plus_vmt
        return total_vmt


    def calc_res_vmt_dorp(self, vmt_col):
        """
        'DORP' (driver or passenger) way of calculating total residential VMT: 
        Only count the VMT if the DORP flag = 1, indicating the trip maker is the driver.
        In theory this is a better way of estimating actual vehicle trips.

        NOTE - As of 1/4/2022, this method is not being used.
        """
        total_vmt = self.df_trip.loc[self.df_trip[self.c_dorp] == 1][vmt_col] \
                    .sum()

        return total_vmt

    def calc_hh_pop(self):
        tot_hh_pop = self.df_hh[self.c_hhsize].sum()
        return tot_hh_pop

    def get_trips_x_mode(self, mode_val):
        mode_trips = self.df_trip.loc[self.df_trip[self.c_mode] == mode_val].shape[0]
        return mode_trips

    def get_road_vmt(self):
        """Get total roadway VMT and CVMT
        Args:
            road_vmt_dbf (DBF): DBF file of model links with daynet data
        """
        arcpy.AddMessage(f"reading in roadway VMT data from {self.road_vmt_dbf}...")
        if len(self.road_vmt_dbf) > 1:
            self.fld_day_vmt = 'DAYVMT'
            self.fld_day_cvmt = 'DAYCVMT'
            fields_to_use = [self.fld_day_vmt, self.fld_day_cvmt]

            self.vmt_dbf_path = os.path.join(self.model_run_dir, self.road_vmt_dbf)

            dbf_obj = DBF(self.vmt_dbf_path)
            df = pd.DataFrame(iter(dbf_obj))[fields_to_use]

            tot_vmt = df[self.fld_day_vmt].sum()
            tot_cvmt = df[self.fld_day_cvmt].sum()
        else:
            tot_vmt = -1
            tot_cvmt = -1

        return (tot_vmt, tot_cvmt)

    def get_topline(self):
        disclaimer_msg = "Numbers reported in this summary may vary from those reported bySACOG published documents." \
            "\nEnd user assumes all risk associated with reporting numbers generated in this report."

        tot_pop = self.calc_hh_pop()
        tot_restrips = self.df_trip.shape[0]
        tot_vmt_fracmethod = self.calc_res_vmt_paxcnt(self.c_distau)
        vmt_cap_frac = tot_vmt_fracmethod / tot_pop
        
        roadway_data = self.get_road_vmt()
        road_vmt = roadway_data[0]
        road_cvmt = roadway_data[1]

        modes = {1: "walk", 2:"bike", 3:"sov", 4:"hov2", 5: "hov3", 6: "transit", 8: "schoolbus"}
        modenames = [f"{n}_trips" for n in modes.values()]

        trips_x_mode = [self.get_trips_x_mode(mode_id) for mode_id in modes.keys()]

        dict_trips_x_mode = dict(zip(modenames, trips_x_mode))
        
        # import pdb; pdb.set_trace()
        model_run_uncpath = build_unc_path(self.model_run_dir)

        out_dict = {"DISCLAIMER": disclaimer_msg,
            "model_run_folder": model_run_uncpath,
            "scenario_year": self.scenario_year, 
            "scenario_desc": self.scenario_desc,
            "tot_pop": tot_pop, 
            "tot_vmt_ii": tot_vmt_fracmethod,
            "tot_restrips": tot_restrips, 
            "tot_resvmt_percap": vmt_cap_frac,
            "roadway_vmt": road_vmt, 
            "roadway_cvmt": road_cvmt}

        out_dict.update(dict_trips_x_mode)
        
        df = pd.DataFrame.from_dict(out_dict, orient='index')

        csv_out = os.path.join(self.model_run_dir, f"{self.scenario_year}_toplinesummary.csv")
        df.to_csv(csv_out)

        return (df, csv_out)






if __name__ == '__main__':
    #=======================USER-DEFINED INPUT PARAMETERS=========================

    # IF RUNNING TOOL FROM PYTHON INTERPRETER, COMMENT THESE VALUES OUT
    in_dir_root = arcpy.GetParameterAsText(0)  
    roadway_data_dbf = arcpy.GetParameterAsText(1)  
    sc_desc = arcpy.GetParameterAsText(2)  


    # UNCOMMENT AND UPDATE THESE VALUES TO RUN FROM PYTHON INTERPRETER
    # in_dir_root = r'\\win10-you\E\SACSIM19\amendment_1\2040_baseline\run_2040_MTIP_Amd1_Baseline_v1'  
    # roadway_data_dbf = '' 
    # sc_desc = 'Test run for year 2040, MTIP amendment 1 run'

    #=========================WRITE OUT TO CSV===========================
    date_suffix = str(datetime.date.today().strftime('%Y%m%d'))

    # model_run_dir, road_vmt_dbf=None, scenario_year=None, scenario_desc="")
    sumobj = modelRunSummary(in_dir_root, road_vmt_dbf=roadway_data_dbf, scenario_desc=sc_desc)
    result = sumobj.get_topline()
    df = result[0]
    print(df)

    arcpy.SetParameterAsText(3, result[1]) # COMMENT OUT IF RUNNING FROM INTERPRETER