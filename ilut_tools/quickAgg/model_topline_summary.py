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
import pandas as pd
from pandas.core.arrays import categorical

from pandas_memory_optimization import memory_optimization


class modelRunSummary:
    def __init__(self, model_run_dir):
        
        self.model_run_dir = model_run_dir

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
        print(f"reading {tbl_path} into dataframe...")
        df = pd.read_csv(tbl_path, usecols=use_cols, delimiter=delim_char)
        memory_optimization(df)
        return df

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
        """

        total_vmt = self.df_trip.loc[self.df_trip[self.c_dorp] == 1].shape[0]

        return total_vmt

    def calc_hh_pop(self):
        tot_hh_pop = self.df_hh[self.c_hhsize].sum()
        return tot_hh_pop

    def get_mode_trip_shares(self, mode_val):
        
        mode_trips = self.df_trip.loc[self.df_trip[self.c_mode] == mode_val].shape[0]
                     
        return mode_trips

    def get_topline(self):
        tot_pop = self.calc_hh_pop()
        tot_restrips = self.df_trip.shape[0]
        tot_vmt_fracmethod = self.calc_res_vmt_paxcnt(self.c_distau)
        tot_vmt_dorp = self.calc_res_vmt_dorp(self.c_distau)
        vmt_cap_frac = tot_vmt_fracmethod / tot_pop
        vmt_cap_dorp = tot_vmt_dorp / tot_pop

        modes = {1: "walk", 2:"bike", 3:"sov", 4:"hov2", 5: "hov3", 6: "transit", 8: "schoolbus"}
        modenames = [n for n in modes.values()]

        trips_x_mode = [self.get_mode_trip_shares(mode_id) for mode_id in modes.keys()]

        dict_trips_x_mode = dict(zip(modenames, trips_x_mode))
         

        out_dict = {"tot_pop": tot_pop, "tot_vmt_fracmethod": tot_vmt_fracmethod,
                    "tot_restrips": tot_restrips, "tot_vmt_dorp": tot_vmt_dorp,
                    "vmt_cap_frac": vmt_cap_frac, "vmt_cap_dorp": vmt_cap_dorp}

        out_dict2 = out_dict.update(dict_trips_x_mode)

        for k, v in out_dict.items():
            print(f"{k}: {v}")




if __name__ == '__main__':
    #=======================USER-DEFINED INPUT PARAMETERS=========================

    in_dir_root = r'\\Win10-Model-1\Model-1-Data\SACSIM19\MTP2020\amendment_1\afterMeterFix\2016\run_2016_fixDelCurv' # input('Enter path to model run folder: ')


    #=========================WRITE OUT TO CSV===========================
    date_suffix = str(datetime.date.today().strftime('%Y%m%d'))

    sumobj = modelRunSummary(in_dir_root)
    sumobj.get_topline()


    print("\nSuccess!")
