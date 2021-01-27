# -*- coding: utf-8 -*-
"""
Single script that allows user to both load and analyze/summarize model outputs
into Integrated Land Use Transportation (ILUT) parcel table
"""

import os
import csv

from dbfread import DBF
 
from bcp_loader import BCP # bcp_loader script must be in same folder as this script to import it
from MakeCombinedILUT import ILUTReport



def dbf_to_csv(dbf_in,outcsv):
    """Export from DBF to CSV for large files"""
    table = DBF(dbf_in)

    with open(outcsv, 'w', newline='') as f_out:
        writer = csv.writer(f_out)
        writer.writerow(table.field_names)
        for record in table:
            writer.writerow(list(record.values()))
         
            
def dat_to_csv(dat_in, out_csv, dat_delim):
    """Convert DAT file to CSV to allow loading via BCP utility"""
    with open(dat_in, 'r') as f_in:
        in_rows = f_in.readlines()
        with open(out_csv, 'w', newline='') as f_out:
            writer_out = csv.writer(f_out)
        
            for row in in_rows:
                rstrip = row.strip('\n')
                out_row = rstrip.split(dat_delim)
                writer_out.writerow(out_row)
                
                



if __name__ == '__main__':
    
    #===============PARAMETERS SET AT EACH RUN========================
    print("Welcome to the SACSIM Integrated Land Use Transportation (ILUT) processor.\n" \
          "To run the ILUT process, please follow the prompts below:\n")
    
    model_run_folder = input("Enter model run folder path: ")# r'D:\SACSIM19\MTP2020\Conformity_Runs\run_2035_MTIP_Amd1_Baseline_v1'
    scenario_year = int(input("Enter scenario year: ")) # 2035
    scenario_id = int(input("Enter scenario ID number: ")) # 999
    run_ilut_combine = input("Do you want to run ILUT Combine script after loading tables (y/n)? ")
        

    #=============SELDOM-CHANGED PARAMETERS==========================
    # folder containing query files used to create tables
    script_dir = os.path.dirname(os.path.realpath(__file__))
    query_dir = os.path.join(script_dir, "BCP table creation queries")
    
    sql_server_name = 'SQL-SVR'
    ilut_db_name = 'MTP2020'
    
    # in table names, base year and earlier is usually written as 4-digit year, while for future years its
    # writted as "pa<two-digit year"
    base_year = 2016
    yeartag = "pa{}".format(str(scenario_year)[-2:]) if scenario_year > base_year else scenario_year
    
    # indicate which tables you want to load, if not all tables
    load_triptbl = True
    load_tourtbl = True
    load_persontbl = True
    load_hhtbl = True
    load_parceltbl = True
    load_ixxworkerfractbl = True
    load_cveh_taztbl = True
    load_ixxi_taztbl = True
    
    # population tables
    pop_y1 = 'raw_Pop2016_latest'
    pop_y2 = 'raw_pop2027_latest'
    pop_y3 = 'raw_Pop2035_latest'
    pop_y4 = 'raw_Pop2040_latest'
    
    # envision-tomorrow parcel tables
    env_tmrw_y1 = 'raw_eto2016_latest'
    env_tmrw_y2 = 'raw_eto2027_latest'
    env_tmrw_y3 = 'raw_eto2035_latest'
    env_tmrw_y4 = 'raw_eto2040_latest'
    
    # set envision-tomorrow and population sql tables for given run based on the scenario year
    yr1 = base_year
    yr2 = 2027
    yr3 = 2035
    yr4 = 2040
    
    pop_yr_dict = {yr1:pop_y1, yr2:pop_y2, yr3:pop_y3, yr4:pop_y4}
    env_tmrw_yr_dict = {yr1:env_tmrw_y1, yr2:env_tmrw_y2, yr3:env_tmrw_y3, yr4:env_tmrw_y4}
    
    
    # files to load that need to be converted to CSV
    dbf_cveh_taz = "cveh_taz.dbf"
    csv_cveh_taz = "cveh_taz.csv"
    dat_ixworker = "worker_ixxifractions.dat"
    csv_ixworker = "worker_ixxifractions.csv"
    
    
    k_sql_tbl_name = "sql_tbl_name"
    k_input_file = "in_file_name"
    k_file_format = "file_field_delimiter"
    k_sql_qry_file = "create_table_sql_file"
    k_data_start_row = "data_start_row"
    k_load_tbl = "load_table"
    
    
    ilut_tbl_specs = [{k_sql_tbl_name: "raw_parcel", 
                      k_input_file: f"{yeartag}_raw_parcel.txt",
                      k_sql_qry_file: 'create_parcel_table.sql',
                      k_data_start_row: 2,
                      k_load_tbl: load_parceltbl},
                     {k_sql_tbl_name: "raw_hh", 
                      k_input_file: "_household.tsv",
                      k_sql_qry_file: 'create_hh_table.sql',
                      k_data_start_row: 2,
                      k_load_tbl: load_hhtbl},
                     {k_sql_tbl_name: "raw_person", 
                      k_input_file: "_person.tsv",
                      k_sql_qry_file: 'create_person_table.sql',
                      k_data_start_row: 2,
                      k_load_tbl: load_persontbl},
                     {k_sql_tbl_name: "raw_tour", 
                      k_input_file: "_tour.tsv",
                      k_sql_qry_file: 'create_tour_table.sql',
                      k_data_start_row: 2,
                      k_load_tbl: load_tourtbl},
                     {k_sql_tbl_name: "raw_trip", 
                      k_input_file: "_trip_1_1.csv",
                      k_sql_qry_file: 'create_trip_table_wskimvals.sql',
                      k_data_start_row: 2,
                      k_load_tbl: load_triptbl},
                     {k_sql_tbl_name: "raw_cveh", 
                      k_input_file: "cveh_taz.dbf", 
                      k_sql_qry_file: 'create_cveh_taz.sql',
                      k_data_start_row: 2,
                      k_load_tbl: load_cveh_taztbl},
                     {k_sql_tbl_name: "raw_ixxi", 
                      k_input_file: "ixxi_taz.dbf",
                      k_sql_qry_file: 'create_ixxi_taz.sql',
                      k_data_start_row: 2,
                      k_load_tbl: load_ixxi_taztbl},
                     {k_sql_tbl_name: "raw_ixworker", 
                      k_input_file: "worker_ixxifractions.dat",
                      k_sql_qry_file: 'create_ixworker_table.sql',
                      k_data_start_row: 1,
                      k_load_tbl: load_ixxworkerfractbl},
                     ]
    
    #======================RUN SCRIPT=================================
    
    # create instance of ILUT combiner report; in so doing, ask for additional info required to do
    # the ILUT aggregation once the tables have loaded. By having this here, before the loading,
    # the user can have a "one and done" process, just setting parameters once, hitting "go",
    # and having the full ILUT process happen for them.
    if run_ilut_combine.lower() == 'y':
        eto_tbl = env_tmrw_yr_dict[scenario_year]
        popn_tbl = pop_yr_dict[scenario_year]
        comb_rpt = ILUTReport(model_run_dir=model_run_folder, sc_yr=scenario_year, 
                              sc_code=scenario_id, envision_tomorrow_tbl=eto_tbl,
                              pop_table=popn_tbl)
        
        # make sure population and envision tomorrow tables indicated above actually exist in DB
        eto_tbl_exists = comb_rpt.check_if_table_exists(eto_tbl)
        popn_tbl_exists = comb_rpt.check_if_table_exists(popn_tbl)
        
        if eto_tbl_exists and popn_tbl_exists:
            pass
        else:
            raise Exception("Envision Tomorrow and population tables not found. " \
                            "Confirm that the envision tomorrow table and population " \
                            "table names are spelled correctly and are in SQL Server.")
        
    else:
        pass
        print("Loading model output tables but will NOT run ILUT combination process...\n")
    
    # change workspace to model run folder
    os.chdir(model_run_folder)
    
    # pre-process DBF and DAT files to make them into loadable CSVs
    # print(f"converting{dbf_cveh_taz} and {dat_ixworker} to CSVs for loader compatibility...")
    # dbf_to_csv(dbf_cveh_taz,csv_cveh_taz)
    # dat_to_csv(dat_ixworker, csv_ixworker, ' ')
    
    tbl_loader = BCP(svr_name=sql_server_name, db_name=ilut_db_name)
    
    for tblspec in ilut_tbl_specs:
        if tblspec[k_load_tbl]:
            sql_tname = f"{tblspec[k_sql_tbl_name]}{scenario_year}_{scenario_id}"
            input_file = tblspec[k_input_file]
            qry_file = os.path.join(query_dir, tblspec[k_sql_qry_file])
            startrow = tblspec[k_data_start_row]
            
            # populate table creation query file with name of table to create
            with open(qry_file, 'r') as f_sql_in:
                raw_sql = f_sql_in.read()
                formatted_sql = raw_sql.format(sql_tname)
        
            tbl_loader.create_sql_table_from_file(input_file, formatted_sql, sql_tname,
                                              overwrite=True, data_start_row=startrow)
        else:
            print(f"Skipping loading of {tblspec[k_sql_tbl_name]} table...")
            continue
        
    print("All tables successfully loaded!\n")
    
    if run_ilut_combine.lower() == 'y':
        print("Starting ILUT combining/aggregation process...\n")
        comb_rpt.run_report()
    

