"""
Name: MakeCombinedILUT.py
Purpose: After model output tables have been loaded into SQL server, this script
    runs a series of queries that aggregate model outputs to give detailed population
    and travel data at the parcel level.
        
          
Author: Darren Conly
Last Updated: Jan 2020
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import os
import sys
import time
from pathlib import Path

# import arcpy
import pyodbc



#===================================FUNCTIONS================================
class ILUTReport():

    def __init__(self, model_run_dir, dbname, envision_tomorrow_tbl=None, pop_table=None, 
                taz_rad_tbl=None, master_pcl_tbl=None,
                sc_yr=None, sc_code=None, av_tnc_type=None, sc_desc=None,
                shared_ext=False):
        
        # ========parameters that are unlikely to change or are changed rarely======
        self.driver = '{SQL Server}'
        self.server = 'SQL-SVR'
        self.database = dbname
        self.trusted_connection = 'yes'
        self.conxn_info = "DRIVER={0}; SERVER={1}; DATABASE={2}; Trusted_Connection={3}" \
            .format(self.driver, self.server, self.database, self.trusted_connection)
        self.scen_log_tbl = "ilut_scenario_log" #logs each run made and asks user for scenario description
        
        #sql script directory
        os.chdir(os.path.dirname(__file__)) # ensure that you start in same folder as script
        self.sql_dir = os.path.abspath("sql_ilut_summary")
        
        #Tables that don't come from model-run folder
        self.master_parcel_table = master_pcl_tbl
        self.taz_rad_table = taz_rad_tbl
        self.envision_tomorrow_tbl = envision_tomorrow_tbl
        self.pop_table = pop_table
        
        # Specify theme table queries to execute
        self.person_sql = "theme_person.sql"
        self.hh_sql_yesAV = "theme_hh_yesAV.sql"
        self.hh_sql_noAV = "theme_hh_noAV.sql"
        self.triptour_sql_noAV = "theme_triptour_VMTConstants.sql" 
        self.triptour_sql_yesAV = "theme_triptour_VMTConstants.sql" #for now, AV/No AV is using the same trip tour script
        self.cvixxi_sql = "theme_cveh_ixxi.sql"
        
        self.mix_density_sql1 = "mix_density_pt1.sql"
        self.mix_density_sql2 = "mix_density_pt2.sql"
        
        self.comb_sql = "ILUT_combine_tables.sql"
        
        
        # Autonomous Vehicle (AV) and TNC (e.g. Uber/Lyft) assumptions used:
        self.avtnc_nn = "No AV, No TNC"
        self.avtnc_ny = "No AV, Yes TNC"
        self.avtnc_yy = "Both AV and TNC"

        self.avmode_dict = {
            self.avtnc_nn:[self.triptour_sql_noAV, self.hh_sql_noAV],
            self.avtnc_ny:[self.triptour_sql_noAV, self.hh_sql_noAV],
            self.avtnc_yy:[self.triptour_sql_yesAV, self.hh_sql_yesAV]
            }
        
        # model run folder
        self.model_run_dir = model_run_dir

        # confirm that needed input tables are in the database
        tbls_to_check = {self.envision_tomorrow_tbl: "Envision Tomorrow parcel table",
                        self.pop_table: "Population table", 
                        self.taz_rad_table: "TAZ-RAD table", 
                        self.master_parcel_table: "Master parcel table"}

        for tblname, tbl_desc in tbls_to_check.items():
            if tblname:
                if self.check_if_table_exists(tblname):
                    continue # if user specified a table, and the table is in the db, then all good and you can move on to check next table
                else: # if the user-specified table isn't found, let them know and give a chance to re-enter manually.
                    self.conditional_table_entry(f"Table {tblname} not found in database {self.database}. " \
                                                "Please manually enter name or press ctrl+c to exit")
            else: # if a table wasn't specified ahead of time, have user specify it.
                tblname = self.conditional_table_entry(f"Specify table you are using for {tbl_desc} or press ctrl+c to exit")

            
        # scenario year
        if sc_yr:
            self.sc_yr = sc_yr
        else: 
            self.sc_yr = input("Enter scenario year: ")  
            
        # scenario ID code
        if sc_code:   
            self.sc_code = sc_code
        else: 
            self.sc_code = input("Enter scenario number: ")   
           
        # AV/TNC flag
        if av_tnc_type:
            self.av_tnc_type = av_tnc_type
        else: 
            user_tnc_entry = input(f"Enter '1' ('{self.avtnc_nn}'), '2' ('{self.avtnc_ny}'), " \
                f"or '3' ('{self.avtnc_yy}'): ")
            av_tnc_lookup = {'1':self.avtnc_nn, '2':self.avtnc_ny, '3':self.avtnc_yy}

            self.av_tnc_type = av_tnc_lookup[user_tnc_entry]
                
        # additional scenario description
        if sc_desc:
            self.sc_desc = sc_desc
        else:
            self.sc_desc = input("Enter scenario description (255 char limit): ") 
        
        # self.av_tnc_type = int(self.av_tnc_type)
        self.scenario_extn = "{}_{}".format(self.sc_yr, self.sc_code)

        # 1/0 flag indicator if run is shared externally (e.g. for EIR, MTP, MTIP amendment, etc.)
        self.shared_ext = int(shared_ext) # convert True/False to 1/0 value
        

    def check_if_table_exists(self, table_name):
        '''Returns true/false value of whether a given table exists in database'''
        conn = pyodbc.connect(self.conxn_info) 
        cursor = conn.cursor()
        tables = [i.table_name for i in cursor.tables()]
        return table_name in tables

    def shared_externally(self):
        '''
        Checks if the indicated year and scenario ID correspond to an existing run that was
        shared publicly (e.g. MTIP, MTP, EIR run). If it is shared, do not let the user overwrite
        the table.
        '''
        
        conn = pyodbc.connect(self.conxn_info)
        conn.autocommit = True
        cursor = conn.cursor()
        
        sql = f"""
            SELECT * FROM {self.scen_log_tbl}
            WHERE scenario_year = {self.sc_yr}
                AND scenario_code = {self.sc_code}
                AND table_status = 'created'
            """
        
        cursor.execute(sql)
        results = cursor.fetchall()

        if len(results) > 0:
            fields = [i[0] for i in cursor.description]
            record = dict(zip(fields, results[0]))
            share_flag = record['shared_externally']

            output = True if share_flag == 1 else False
        else:
            output = False

        cursor.close()
        conn.close()       

        return output
    
    
    def run_sql(self, sql_file, params_list):
        '''Runs SQL file. params_list contains any formatters used in the SQL 
        file (e.g. to specify which table names to use in the SQL command).'''
        
        print("Running {}...".format(sql_file))
        conn = pyodbc.connect(self.conxn_info)
        conn.autocommit = True
        with open(os.path.join(self.sql_dir, sql_file),'r') as in_sql:
            raw_sql = in_sql.read()
            formatted_sql = raw_sql.format(*params_list)
            cursor = conn.cursor()
            cursor.execute(formatted_sql)
            cursor.commit()
            cursor.close()
        conn.close()
        
    def get_unc_path(self, in_path):
        
        # based on a network drive path, convert the letter to full machine name
        unc_path = str(Path(in_path).resolve())
        
        # if the model run folder is on the machine that this script is getting run on,
        # the full machine name path must be manually built.
        if unc_path == in_path:
            import socket
            machine = socket.gethostname()
            drive_letter = os.path.splitdrive(in_path)[0].strip(':')
            folderpath = os.path.splitdrive(in_path)[1]
            unc_path = f"\\\\{machine}\\{drive_letter}{folderpath}"
        
        return unc_path
        
    def log_run(self, av_tnc_flag):
        '''
        Logs information about the ILUT run performed, including scenario year,
        scenario ID, text description and notes of scenario, when the ILUT for the scenario was run,
        and what AV/TNC settings were used in the run.
        '''
        
        conn = pyodbc.connect(self.conxn_info)
        conn.autocommit = True
        cursor = conn.cursor()
        
        sc_desc_fmt = r'{}'.format(self.sc_desc) #gets rid of pesky unicode escape errors if description has \N, \t, etc.
        default_tbl_status = "created"
        run_folder = self.get_unc_path(self.model_run_dir)
        
        sql = f"""
            INSERT INTO {self.scen_log_tbl} VALUES (
            {self.sc_yr}, {self.sc_code}, '{sc_desc_fmt}', GETDATE(), 
            '{av_tnc_flag}', '{default_tbl_status}', '{run_folder}',
            {self.shared_ext})
            """
        
        cursor.execute(sql)
        cursor.commit()
        cursor.close()
        conn.close()
        
    def conditional_table_entry(self, input_prompt):
        '''If user needs to specify a table that already exists, this makes sure
        they specify a valid table name'''
        while True:
            tbl_name = input(f"{input_prompt}: ")  # Enter future parcel/ETO table name
            valid_tbl_name = self.check_if_table_exists(tbl_name)
            if valid_tbl_name:
                break
                print(tbl_name)
                
            else:
                print("Table {} does not exist. Please try a different table name." \
                      .format(tbl_name))
                continue
        
        return tbl_name

    def delete_tables(self, tables_to_delete):
        conn = pyodbc.connect(self.conxn_info)
        conn.autocommit = True

        for table in tables_to_delete:
            cursor = conn.cursor()

            sql = f"DROP TABLE {table}"
            cursor.execute(sql)

            cursor.commit()
            cursor.close()

        conn.close()
    
    def run_report(self, create_triptour_table=True,
                    create_person_table=True,
                    create_hh_table=True,
                    create_cvixxi_table=True,
                    create_comb_table=True,
                    delete_input_tables=False):
        
        '''Runs queries to generate parcel-level ILUT table.'''
        
        start_time = time.time()
        conn = pyodbc.connect(self.conxn_info)
        cursor = conn.cursor()
        
        
        #scenario-dependent raw input table names
        raw_parcel = "raw_parcel{}".format(self.scenario_extn)
        raw_hh = "raw_hh{}".format(self.scenario_extn)
        raw_person = "raw_person{}".format(self.scenario_extn)
        raw_ixxi = "raw_ixxi{}".format(self.scenario_extn)
        raw_cveh = "raw_cveh{}".format(self.scenario_extn)
        raw_ixworkerfraxn = "raw_ixworker{}".format(self.scenario_extn)
        raw_tour = "raw_tour{}".format(self.scenario_extn)
        raw_trip = "raw_trip{}".format(self.scenario_extn)
        
        # these tables are temporary and will be deleted after script finishes.
        triptour_outtbl = "TEMP_ilut_triptour{}".format(self.scenario_extn)
        person_outtbl = "TEMP_ilut_person{}".format(self.scenario_extn)
        hh_outtbl = "TEMP_ilut_hh{}".format(self.scenario_extn)
        cvixxi_outtbl = "TEMP_ilut_ixxicveh{}".format(self.scenario_extn)
        
        # create trip-tour theme table
        if create_triptour_table:
            triptour_sql = self.avmode_dict[self.av_tnc_type][0]
            triptour_params = [raw_trip, raw_tour, raw_hh, raw_person, raw_parcel, 
                               raw_ixworkerfraxn, triptour_outtbl]
            self.run_sql(triptour_sql,triptour_params) 
            
        #Create person theme table
        if create_person_table:
            person_params = [self.pop_table, raw_person, raw_parcel, person_outtbl]
            self.run_sql(self.person_sql, person_params) 
        
        #create hh theme table
        if create_hh_table:
            hh_sql = self.avmode_dict[self.av_tnc_type][1]
            hh_params = [self.pop_table, raw_hh, raw_parcel,hh_outtbl]
            self.run_sql(hh_sql,hh_params)
            
        # create comm veh ixxi table
        if create_cvixxi_table:
            cvixxi_params = [raw_parcel, raw_cveh, self.taz_rad_table, 
                             raw_hh, raw_ixxi, cvixxi_outtbl]
            self.run_sql(self.cvixxi_sql, cvixxi_params)
        
        tables_existing = [cursor.tables(table=t).fetchone()[2] for t in \
                           [triptour_outtbl, person_outtbl, hh_outtbl, cvixxi_outtbl] \
                           if cursor.tables(table=t).fetchone() is not None]
        
        if create_comb_table:
            if len(tables_existing) == 4: #check that all ilut tables exist before creating combo table
                col_str_yr = str(self.sc_yr)[-2:] #for columns in ETO table with year suffix in header name
                comb_outtbl = "ilut_combined{}".format(self.scenario_extn)
                comb_params = [self.master_parcel_table, raw_parcel, hh_outtbl, 
                               person_outtbl, triptour_outtbl, cvixxi_outtbl, 
                               comb_outtbl, self.envision_tomorrow_tbl, col_str_yr]
                
                self.run_sql(self.mix_density_sql1,[raw_parcel]) #calculate mixed-density column on parcel file
                self.run_sql(self.mix_density_sql2,[raw_parcel]) #calculate mixed-density column on parcel file
                self.run_sql(self.comb_sql, comb_params) #run script to combine all theme tables
                
                # av_tnc_desc = self.avmode_dict[self.av_tnc_type][0]
                self.log_run(self.av_tnc_type)
            else:
                print("Not all input ILUT tables exist. Make sure all theme ILUT tables exist then re-run.")
                sys.exit()

            if delete_input_tables:
                input_tables = [raw_parcel, raw_hh, raw_person, raw_ixxi, 
                                raw_cveh, raw_ixworkerfraxn, raw_tour, raw_trip]
                self.delete_tables(input_tables)
        
        cursor.close()
        conn.close()
        elapsed_time = round((time.time() - start_time)/60,1)
        print("Success! Elapsed time: {} minutes".format(elapsed_time))
    
#=========================SCRIPT ENTRY POINT===================================


if __name__ == '__main__':
    report_obj = ILUTReport(model_run_dir = r'D:\SACSIM19\MTP2020\2016_UpdatedAug2020\run_2016_baseline_AO13_V7_NetUpdate08202020',
        dbname='MTP2024', envision_tomorrow_tbl='raw_eto2016_latest', pop_table='raw_Pop2016_latest', sc_yr=2016,
                 sc_code=999, av_tnc_type=1, 
                 sc_desc='testing')

    check_if_exists = report_obj.shared_externally()
    print(check_if_exists)

    # report_obj.run_report(create_triptour_table = False,
    #                 create_person_table = False,
    #                 create_hh_table = False,
    #                 create_cvixxi_table = True,
    #                 create_comb_table = False)


