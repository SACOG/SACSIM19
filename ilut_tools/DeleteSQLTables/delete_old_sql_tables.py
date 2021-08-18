# -*- coding: utf-8 -*-
"""
Created on Thu Jul 19 15:41:46 2018

@author: dconly

Purposes:
    Clean out old ILUT tables, including intermediate tables, raw model output
    tables.
    
"""

import os 
import pyodbc as pdb



def run_sql(sql_file,params_list):
    conn = pdb.connect(conxn_info)
    conn.autocommit = True
    with open(os.path.join(sql_dir,sql_file),'r') as in_sql:
        raw_sql = in_sql.read()
        formatted_sql = raw_sql.format(*params_list)
        #print(formatted_sql) #uncomment to see query
        cursor = conn.cursor()
        cursor.execute(formatted_sql)
        # =============================================================================
                # use this to get rows of data if needed
        #         rows = cursor.fetchall()
        #         for row in rows:
        #             print(row)
        # =============================================================================
        cursor.commit()
        cursor.close()
    conn.close()
    
def update_table_status(log_table, status_column, status_value, year, sc_id):
    conn = pdb.connect(conxn_info)
    conn.autocommit = True
    cursor = conn.cursor()
        
    year_column = 'scenario_year'
    sc_id_col = 'scenario_code'
    
    sql = "UPDATE {} SET {} = '{}' WHERE {} = {} AND {} = {}" \
            .format(log_table, status_column, status_value, year_column, year, sc_id_col, sc_id)
    
    cursor.execute(sql)
    
    cursor.commit()
    cursor.close()
    conn.close()
    
def delete_old_tables(sc_yr,sc_id,drop_comb):
    
    #option to include combined output tables.
    table_prefixes = ['raw_person','raw_hh','raw_parcel','raw_trip','raw_tour',
                      'raw_ixxi','raw_cveh','raw_ixworker','ilut_triptour',
                      'ilut_person','ilut_hh','ilut_ixxicveh','mtpuser.ilut_combined']

    if drop_comb.lower() == 'y':
        tables = ["{}{}_{}".format(prefix,sc_yr,sc_id) for prefix in table_prefixes]
        update_table_status(scen_log_tbl, 'table_status', table_status_delall, sc_yr, sc_id)
    elif drop_comb.lower() == 'n':
        tbl_prefixes_nocomb = ['na' if prefix == 'mtpuser.ilut_combined' \
                               else prefix for prefix in table_prefixes]
        tables = ["{}{}_{}".format(prefix,sc_yr,sc_id) \
                  for prefix in tbl_prefixes_nocomb]
        update_table_status(scen_log_tbl, 'table_status', table_status_keepcomb, sc_yr, sc_id)
    else:
        quit()
    
    run_sql(drop_table_sql,tables)
    
    
#============================MAIN SCRIPT=======================================


if __name__ == '__main__':
    # Database connection
    driver = '{SQL Server}'
    server = 'SQL-SVR'
    database = 'MTP2020'
    trusted_connection = 'yes'
    conxn_info = "DRIVER={0}; SERVER={1}; DATABASE={2}; Trusted_Connection={3}".format(driver, server, database, trusted_connection)
    
    scen_log_tbl = "ilut_scenario_log" #logs each run made and asks user for scenario description
    table_status_delall = "deleted all tables"
    table_status_keepcomb = "deleted raw/theme tables, kept combined table"
    
    #sql script directory
    sql_dir = r"Q:\SACSIM19\Integration Data Summary\SACSIM19 Scripts\SQL\Python SQL"
    
    drop_table_sql = 'delete_old_tablesSQL.sql'
    
    year = 2040
    scenario_ids = [1, 2, 3, 6, 7, 8, 9, 10, 11, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 37, 38, 39, 40, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 60, 62, 63, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 78, 79, 80, 81, 82, 83, 84, 85, 86, 89, 91, 92, 95, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 124, 125, 126, 127, 128, 129, 130, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 999]
    
    drop_comb = input("Deleting year {}, scenarios {}. Also drop combined output tables too (y/n)? ".format(year,scenario_ids))
    
    
    for sc_id in scenario_ids:
        delete_old_tables(year,sc_id,drop_comb) 
        print("Deleted tables for year {}, scenario {}".format(year, sc_id))
    print("--"*20)
    print("Finished. Note that raw population and Envision Tomorrow parcel files will require manual removal.")

