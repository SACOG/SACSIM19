"""
Name: ILUT2SQL_bcp.py
Purpose: Uses python wrapper for BCP to use Microsoft BCP (bulk copy program) command-line utility
to load TSV and CSV ILUT tables into SQL server.

NOTE - using this script requires the following installations:
    -BCP utility, downloadable from https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver15
    -pyodbc, available through conda and pip package managers
    -Microsoft SQL Server connection info
        
          
Author: Darren Conly
Last Updated: Dec 2020
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import os
import csv

from .bcp_loader import BCP # bcp_loader script must be in same folder as this script to import it
from dbfread import DBF





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
    model_run_folder = input("Enter model run folder path: ")# r'D:\SACSIM19\MTP2020\Conformity_Runs\run_2035_MTIP_Amd1_Baseline_v1'
    scenario_year = int(input("Enter scenario year: ")) # 2035
    scenario_id = int(input("Enter scenario ID number: ")) # 999
    
    
    
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