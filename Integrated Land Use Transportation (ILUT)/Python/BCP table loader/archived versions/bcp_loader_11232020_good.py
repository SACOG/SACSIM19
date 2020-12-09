"""
Name:bcp_loader.py
Purpose: This is a python wrapper for MS SQL Server Bulk Copy Program (BCP) utility.
    It allows automating and scripting for loading tables into SQL server.
    
    
    BCP needs to be downloaded as a separate EXE file, obtainable at:
        https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver15
        
    BCP is normally a command-line tool. Reference for all of its arguments is
    available at:
        https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver15
        
          
Author: Darren Conly
Last Updated: Nov 2020
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import os
import time
import subprocess

import pyodbc



class BCP():
    
    # establish connection to database you want to work in, and params for 
    # bcp command that normally do not change
    def __init__(self, svr_name, db_name, trusted_conn=True):
        
        
        self.svr_name = svr_name
        self.db_name = db_name
        self.db_system ="{SQL Server}" 
        
        if trusted_conn:
            self.bcp_auth = '-T' 
            self.sqla_auth = 'yes' # sql alchemy auth if trusted connection
        else:
            self.username = input("Enter username: ")
            self.password = input("Enter password: ")
            
            self.conn_auth = f'-U {self.username} -P {self.password}'
        
        # NOTE 11/21/2020 - SQL ALCHEMY CONNECTION NOT SET UP TO HAVE NON-TRUSTED CONNECTION!
        self.str_conn_info = "Driver={0}; Server={1}; Database={2}; Trusted_Connection={3};" \
            .format(self.db_system, self.svr_name, self.db_name, self.sqla_auth)
            
        self.delim_char_lookup = {"comma": ',', "tab": '\\t'}

        self.use_quoted_identifiers = '-q' #allows loading to table name with spaces in it
        self.use_char_dtype = '-c'
        
        
            
    def create_sql_table_from_file(self, file_in, delim_name, str_create_table_sql, tbl_name,
                                   overwrite=True, data_start_row=2):
        '''Loads data from a text file into a sql server table'''
        
        delim_char = self.delim_char_lookup[delim_name]
        
        with pyodbc.connect(self.str_conn_info, autocommit=True) as conn:
            sql_cur = conn.cursor()
            
            str_data_start_row = str(data_start_row)
            
            # drop existing table if specified
            tables = [t[2] for t in sql_cur.tables()]
            # import pdb; pdb.set_trace()
    
            if tbl_name in tables:
                if overwrite:
                    drop_tbl_sql = "DROP TABLE {};".format(tbl_name)
                    sql_cur.execute(drop_tbl_sql)
                else:
                    print("{} already exists. Will append to existing table")
                    # sys.exit()
                
            # create table that data will load to
            print(f"creating table {tbl_name}...")
            
            sql_cur.execute(str_create_table_sql)
            
        sql_cur.close()
        conn.close()
        
        
    
        # import pdb; pdb.set_trace()
        # generate bcp command
        loading_dir = 'in' # in = load from file into sql server; out = from server to file
        bcp_new_tbl_from_file = ['bcp', tbl_name, loading_dir, file_in,
                                 '-S', self.svr_name, # -S <server name>
                                 '-d', self.db_name, # -d <database name>
                                 self.bcp_auth, self.use_quoted_identifiers,
                                 self.use_char_dtype,
                                 '-t', delim_char, # -t <field delimiter char to use>
                                 '-F', str_data_start_row] # -F indicates row data starts on (default = 2nd row if file has headers)
        
        # run bcp command
        print(f"loading data from {file_in} into {tbl_name}...")
        # import pdb; pdb.set_trace()
        try:
            start_time = time.clock()
            
            subprocess.check_output(bcp_new_tbl_from_file)
            
            elapsed_time = round((time.clock() - start_time)/60,1)
            print(("Successfully loaded table in {}mins!\n".format(elapsed_time)))
        except:
            print("BCP load fail. Things to try or check:\n" \
                  "1 - Make sure you are calling the correct SQL file to create the table\n" \
                  "2 - Make sure your SQL script is specifying correct columns and data types\n" \
                  "3 - Stop or shut off any SQL Server processes you have running\n" \
                  "4 - Make sure you are specifying the correct delimiter type")
        
        
        
    def append_from_file_to_sql_tbl():
        # placeholder for potential future method that appends from file to existing sql table
        pass


if __name__ == '__main__':
    
    #================TEST ZONE======================
    #----------------TEST PARAMS---------------------
    test_tbl_sql = r"C:\Users\dconly\GitRepos\CodeSnippets\SQL\bulk_loader\create_trip_table_wskimvals.sql"
    test_tbl_type = "trip" #household, trip, etc
    run_folder = r'D:\SACSIM19\MTP2020\Conformity_Runs\run_2035_MTIP_Amd1_Baseline_v1'
    txt_file_in = "_trip_1_1.csv"
    delimiter_name = "comma" # acceptable values "comma", "tab"
    test_tbl_name = f"BCPtest_{test_tbl_type}_table"
    # test_tbl_name = "BCP_hh_TEST"
        
    #-----------------RUN TEST SCRIPT----------------    
    with open(test_tbl_sql, 'r') as f_sql_in:
        raw_sql = f_sql_in.read()
        formatted_sql = raw_sql.format(test_tbl_name)
    
    tbl_loader = BCP(svr_name='SQL-SVR', db_name='MTP2020')
    test_file_in = os.path.join(run_folder, txt_file_in)
    tbl_loader.create_sql_table_from_file(test_file_in, delimiter_name, formatted_sql, test_tbl_name,
                                          overwrite=True)

