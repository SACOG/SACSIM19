#python sqlserver_conxntest.py
#https://docs.microsoft.com/en-us/sql/connect/python/pyodbc/step-3-proof-of-concept-connecting-to-sql-using-pyodbc?view=sql-server-2017
#https://github.com/mkleehammer/pyodbc/wiki/Cursor

import os
import sys
import time
import pyodbc as pdb
#import pdb as pydebug



#===================================FUNCTIONS================================
def check_if_table_exists(table_name,conxn_info):
    conn = pdb.connect(conxn_info) 
    cursor = conn.cursor()
    tables = [i.table_name for i in cursor.tables()]
    return table_name in tables

def run_sql(sql_file,params_list):
    print("Running {}...".format(sql_file))
    conn = pdb.connect(conxn_info)
    conn.autocommit = True
    with open(os.path.join(sql_dir,sql_file),'r') as in_sql:
        raw_sql = in_sql.read()
        formatted_sql = raw_sql.format(*params_list)
#        if sql_file == 'ILUT_combine_tables.sql':
#            print(formatted_sql) #uncomment to see query
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
    
def log_run(sc_yr, sc_code, sc_desc, log_table, avtnc_desc):
    conn = pdb.connect(conxn_info)
    conn.autocommit = True
    cursor = conn.cursor()
    default_tbl_status = "created"
    
    sc_desc = r'{}'.format(sc_desc) #gets rid of pesky unicode escape errors if description has \N, \t, etc.
    
    sql = "INSERT INTO {3} VALUES ({0}, {1}, '{2}', GETDATE(),'{4}','{5}')" \
            .format(sc_yr, sc_code, sc_desc, log_table, avtnc_desc,default_tbl_status)
    
    cursor.execute(sql)
    
    cursor.commit()
    cursor.close()
    conn.close()

def make_tables(create_triptour_table = False,
                create_person_table = False,
                create_hh_table = False,
                create_cvixxi_table = False,
                create_comb_table = False):
    start_time = time.time()
    conn = pdb.connect(conxn_info)
    cursor = conn.cursor()
    
    avmode_dict = {1:["No AV, No TNC", triptour_sql_noAV, hh_sql_noAV],
                    2:["No AV, Yes TNC", triptour_sql_noAV, hh_sql_noAV],
                    3:["Both AV and TNC", triptour_sql_yesAV, hh_sql_yesAV]}
    
    #log info about each ILUT creation
    pop_table = input("Copy/paste population table name: ")
    sc_yr = input("Enter scenario year: ")
    sc_code = input("Enter scenario number: ")
    av_tnc_type = input("Enter '1' ({}), '2' ({}), or '3' ({}): " \
                        .format(avmode_dict[1][0],avmode_dict[2][0],avmode_dict[3][0]))
    av_tnc_type = int(av_tnc_type)
    sc_desc = input("Enter scenario description (255 char limit): ")
    
    scenario_extn = "{}_{}".format(sc_yr,sc_code)
    
    #scenario-dependent raw input table names
    raw_parcel = "raw_parcel{}".format(scenario_extn)
    raw_hh = "raw_hh{}".format(scenario_extn)
    raw_person = "raw_person{}".format(scenario_extn)
    raw_ixxi = "raw_ixxi{}".format(scenario_extn)
    raw_cveh = "raw_cveh{}".format(scenario_extn)
    raw_ixworkerfraxn = "raw_ixworker{}".format(scenario_extn)
    raw_tour = "raw_tour{}".format(scenario_extn)
    raw_trip = "raw_trip{}".format(scenario_extn)
    
    # these tables are temporary and will be deleted after script finishes.
    triptour_outtbl = "TEMP_ilut_triptour{}".format(scenario_extn)
    person_outtbl = "TEMP_ilut_person{}".format(scenario_extn)
    hh_outtbl = "TEMP_ilut_hh{}".format(scenario_extn)
    cvixxi_outtbl = "TEMP_ilut_ixxicveh{}".format(scenario_extn)
    
    if create_triptour_table:
        triptour_sql = avmode_dict[av_tnc_type][1]
        triptour_params = [raw_trip, raw_tour, raw_hh, raw_person, raw_parcel, 
                           raw_ixworkerfraxn, triptour_outtbl]
        run_sql(triptour_sql,triptour_params) 
        
    #Create person theme table
    if create_person_table:
        person_params = [pop_table, raw_person, raw_parcel, person_outtbl]
        run_sql(person_sql,person_params) 
    
    #create hh theme table
    if create_hh_table:
        hh_sql = avmode_dict[av_tnc_type][2]
        hh_params = [pop_table, raw_hh, raw_parcel,hh_outtbl]
        run_sql(hh_sql,hh_params)
        
    if create_cvixxi_table:
        cvixxi_params = [raw_parcel, raw_cveh, taz_rad_table, 
                         raw_hh, raw_ixxi, cvixxi_outtbl]
        run_sql(cvixxi_sql,cvixxi_params)
    
    tables_existing = [cursor.tables(table=t).fetchone()[2] for t in \
                       [triptour_outtbl, person_outtbl, hh_outtbl, cvixxi_outtbl] \
                       if cursor.tables(table=t).fetchone() is not None]
    
    if create_comb_table:
        if len(tables_existing) == 4: #check that all ilut tables exist before creating combo table
            col_str_yr = str(sc_yr)[-2:] #for columns in ETO table with year suffix in header name
            comb_outtbl = "mtpuser.ilut_combined{}".format(scenario_extn)
            comb_params = [master_parcel_table, raw_parcel, hh_outtbl, 
                           person_outtbl, triptour_outtbl, cvixxi_outtbl, 
                           comb_outtbl, envision_tomorrow_tbl, col_str_yr]
            
            run_sql(mix_density_sql1,[raw_parcel]) #calculate mixed-density column on parcel file
            run_sql(mix_density_sql2,[raw_parcel]) #calculate mixed-density column on parcel file
            run_sql(comb_sql,comb_params) #run script to combine all theme tables
            
            av_tnc_desc = avmode_dict[av_tnc_type][0]
            log_run(sc_yr, sc_code, sc_desc, scen_log_tbl, av_tnc_desc)
        else:
            print("Not all input ILUT tables exist. Make sure all theme ILUT tables exist then re-run.")
            sys.exit()
    
    cursor.close()
    conn.close()
    elapsed_time = round((time.time() - start_time)/60,1)
    print("Success! Elapsed time: {} minutes".format(elapsed_time))
    
#=========================SCRIPT ENTRY POINT===================================


if __name__ == '__main__':
    # Database connection
    driver = '{SQL Server}'
    server = 'SQL-SVR'
    database = 'MTP2020'
    trusted_connection = 'yes'
    conxn_info = "DRIVER={0}; SERVER={1}; DATABASE={2}; Trusted_Connection={3}".format(driver, server, database, trusted_connection)
    scen_log_tbl = "ilut_scenario_log" #logs each run made and asks user for scenario description
    
    #sql script directory
    script_dir = os.path.dirname(os.path.realpath(__file__))
    sql_dir = os.path.join(script_dir, "MakeILUTCombinedTableSQL")
    
    #Tables that aren't scenario-dependent
    master_parcel_table = "mtpuser.PARCEL_MASTER"
    taz_rad_table = "TAZ07_RAD07"
    
    # Specify theme table queries to execute
    person_sql = "theme_person.sql"
    hh_sql_yesAV = "theme_hh_yesAV.sql"
    hh_sql_noAV = "theme_hh_noAV.sql"
    triptour_sql_noAV = "theme_triptour_VMTConstants.sql" 
    triptour_sql_yesAV = "theme_triptour_VMTConstants.sql" #for now, AV/No AV is using the same trip tour script
    
    cvixxi_sql = "theme_cveh_ixxi.sql"
    
    mix_density_sql1 = "mix_density_pt1.sql"
    mix_density_sql2 = "mix_density_pt2.sql"
    
    comb_sql = "ILUT_combine_tables.sql"
    
    #Enter and confirm the envision tomorrow parcel table to use
    while True:
        envision_tomorrow_tbl = input("Enter future parcel/ETO table name: ")
        correct_env_tmrw_table = check_if_table_exists(envision_tomorrow_tbl,conxn_info)
        if correct_env_tmrw_table:
            break
        else:
            print("Table {} does not exist. Please try a different table name." \
                  .format(envision_tomorrow_tbl))
            continue
    
    #Specify tables you want made. For a full ILUT table update set all to True
    if correct_env_tmrw_table:
        make_tables(create_triptour_table = True,
                    create_person_table = True,
                    create_hh_table = True,
                    create_cvixxi_table = True,
                    create_comb_table = True)
    else:
        print("Parcel table you entered does not exist. Please enter a different table name.")
        exit()


