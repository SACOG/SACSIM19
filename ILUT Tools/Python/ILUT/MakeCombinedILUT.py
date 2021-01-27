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
import pyodbc



#===================================FUNCTIONS================================
class ILUTReport():

    def __init__(self, envision_tomorrow_tbl=None, pop_table=None, sc_yr=None,
                 sc_code=None, av_tnc_type=None, sc_desc=None):
        
        # ========parameters that are unlikely to change or are changed rarely======
        self.driver = '{SQL Server}'
        self.server = 'SQL-SVR'
        self.database = 'MTP2020'
        self.trusted_connection = 'yes'
        self.conxn_info = "DRIVER={0}; SERVER={1}; DATABASE={2}; Trusted_Connection={3}" \
            .format(self.driver, self.server, self.database, self.trusted_connection)
        self.scen_log_tbl = "ilut_scenario_log" #logs each run made and asks user for scenario description
        
        #sql script directory
        self.script_dir = os.path.dirname(os.path.realpath(__file__))
        self.sql_dir = os.path.join(self.script_dir, "MakeILUTCombinedTableSQL")
        
        #Tables that aren't scenario-dependent
        self.master_parcel_table = "mtpuser.PARCEL_MASTER"
        self.taz_rad_table = "TAZ07_RAD07"
        
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
        self.avmode_dict = {1:["No AV, No TNC", self.triptour_sql_noAV, self.hh_sql_noAV],
            2:["No AV, Yes TNC", self.triptour_sql_noAV, self.hh_sql_noAV],
            3:["Both AV and TNC", self.triptour_sql_yesAV, self.hh_sql_yesAV]}
        
        
        # =========parameters that change with every run================= 
        if envision_tomorrow_tbl:
            self.envision_tomorrow_tbl = envision_tomorrow_tbl
        else: 
            self.envision_tomorrow_tbl = self.conditional_table_entry("Enter future parcel/ETO table name")
            
        if pop_table:
            self.pop_table = pop_table
        else:
            self.pop_table = self.conditional_table_entry("Copy/paste population table name")  
            
        if sc_yr:
            self.sc_yr = sc_yr
        else: 
            self.sc_yr = input("Enter scenario year: ")  
            
        if sc_code:   
            self.sc_code = sc_code
        else: 
            self.sc_code = input("Enter scenario number: ")   
           
        if av_tnc_type:
            self.av_tnc_type = av_tnc_type
        else: 
            self.av_tnc_type = input("Enter '1' ({}), '2' ({}), or '3' ({}): " \
                            .format(self.avmode_dict[1][0], self.avmode_dict[2][0],
                                    self.avmode_dict[3][0]))
        
        if sc_desc:
            self.sc_desc = sc_desc
        else:
            self.sc_desc = input("Enter scenario description (255 char limit): ") 
        
        self.av_tnc_type = int(self.av_tnc_type)
        self.scenario_extn = "{}_{}".format(self.sc_yr, self.sc_code)
        # import pdb; pdb.set_trace()
        

    def check_if_table_exists(self, table_name):
        '''Returns true/false value of whether a given table exists in database'''
        conn = pyodbc.connect(self.conxn_info) 
        cursor = conn.cursor()
        tables = [i.table_name for i in cursor.tables()]
        return table_name in tables
    
    
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
        
    def log_run(self, avtnc_desc):
        '''
        Logs information about the ILUT run performed, including scenario year,
        scenario ID, text description and notes of scenario, when the ILUT for the scenario was run,
        and what AV/TNC settings were used in the run.
        '''
        
        conn = pyodbc.connect(self.conxn_info)
        conn.autocommit = True
        cursor = conn.cursor()
        default_tbl_status = "created"
        
        sc_desc = r'{}'.format(sc_desc) #gets rid of pesky unicode escape errors if description has \N, \t, etc.
        
        sql = "INSERT INTO {3} VALUES ({0}, {1}, '{2}', GETDATE(),'{4}','{5}')" \
                .format(self.sc_yr, self.sc_code, self.sc_desc, self.scen_log_tbl, avtnc_desc, default_tbl_status)
        
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
    
    def run_report(self, create_triptour_table = True,
                    create_person_table = True,
                    create_hh_table = True,
                    create_cvixxi_table = True,
                    create_comb_table = True):
        
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
            triptour_sql = self.avmode_dict[self.av_tnc_type][1]
            triptour_params = [raw_trip, raw_tour, raw_hh, raw_person, raw_parcel, 
                               raw_ixworkerfraxn, triptour_outtbl]
            self.run_sql(triptour_sql,triptour_params) 
            
        #Create person theme table
        if create_person_table:
            person_params = [self.pop_table, raw_person, raw_parcel, person_outtbl]
            self.run_sql(self.person_sql, person_params) 
        
        #create hh theme table
        if create_hh_table:
            hh_sql = self.avmode_dict[self.av_tnc_type][2]
            hh_params = [self.pop_table, raw_hh, raw_parcel,hh_outtbl]
            self.run_sql(hh_sql,hh_params)
            
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
                comb_outtbl = "mtpuser.ilut_combined{}".format(self.scenario_extn)
                comb_params = [self.master_parcel_table, raw_parcel, hh_outtbl, 
                               person_outtbl, triptour_outtbl, cvixxi_outtbl, 
                               comb_outtbl, self.envision_tomorrow_tbl, col_str_yr]
                
                self.run_sql(self.mix_density_sql1,[raw_parcel]) #calculate mixed-density column on parcel file
                self.run_sql(self.mix_density_sql2,[raw_parcel]) #calculate mixed-density column on parcel file
                self.run_sql(self.comb_sql, comb_params) #run script to combine all theme tables
                
                av_tnc_desc = self.avmode_dict[self.av_tnc_type][0]
                self.log_run(self.sc_yr, self.sc_code, self.sc_desc, self.scen_log_tbl, av_tnc_desc)
            else:
                print("Not all input ILUT tables exist. Make sure all theme ILUT tables exist then re-run.")
                sys.exit()
        
        cursor.close()
        conn.close()
        elapsed_time = round((time.time() - start_time)/60,1)
        print("Success! Elapsed time: {} minutes".format(elapsed_time))
    
#=========================SCRIPT ENTRY POINT===================================


if __name__ == '__main__':
    report_obj = ILUTReport(envision_tomorrow_tbl='raw_eto2035_latest', pop_table='raw_Pop2035_latest', sc_yr=2035,
                 sc_code=999, av_tnc_type=1, sc_desc='test to see if full ILUT process loads correctly')
    report_obj.run_report(create_triptour_table = False)


