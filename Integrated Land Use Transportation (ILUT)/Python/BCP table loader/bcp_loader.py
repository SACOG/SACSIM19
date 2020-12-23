"""
Name:bcp_loader.py
Purpose: This is a python wrapper for MS SQL Server Bulk Copy Program (BCP) utility.
    It allows automating and scripting for loading tables into SQL server.
    
    Dependencies:
        -BCP needs to be downloaded as a separate EXE file, obtainable at:
            https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver15
            
            BCP is normally a command-line tool. Reference for all of its arguments is
            available at:
                https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver15
        -pyodbc python library, downloadable through conda and pip package managers
        
        
    
          
Author: Darren Conly
Last Updated: Nov 2020
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import os
import csv
import sys
import time
import subprocess

import pyodbc
from dbfread import DBF



class BCP():
    
    # establish connection to database you want to work in, and params for 
    # bcp command that normally do not change
    def __init__(self, svr_name, db_name, trusted_conn=True):
        
        
        self.svr_name = svr_name # server name
        self.db_name = db_name # database name
        self.db_system ="{SQL Server}" # will always be SQL Server, since BCP is specifically for MSSQL
        
        if trusted_conn:
            self.bcp_auth = '-T' 
            self.conn_auth = 'yes' # pyodbc auth if trusted connection
        else:
            self.username = input("Enter username: ")
            self.password = input("Enter password: ")
            
            self.conn_auth = f'-U {self.username} -P {self.password}'
        
        # NOTE 11/21/2020 - SQL ALCHEMY CONNECTION NOT SET UP TO HAVE NON-TRUSTED CONNECTION!
        self.str_conn_info = "Driver={0}; Server={1}; Database={2}; Trusted_Connection={3};" \
            .format(self.db_system, self.svr_name, self.db_name, self.conn_auth)
            
        # dict to ensure correct file delimiter character is used. User specifies
        # comma or tab type in methods that follow below, not in this __init__ method
        self.accepted_file_types= ['csv', 'tsv', 'txt', 'dat', 'dbf']
        self.delim_char_lookup = {"csv": ',', "tsv": '\\t', 'txt':','}
        

        self.use_quoted_identifiers = '-q' #allows loading to table name with spaces in it
        self.use_char_dtype = '-c'
        
        
    def dbf_to_csv(self, dbf_in,outcsv):
        """Export from DBF to CSV for large files"""
        table = DBF(dbf_in)
    
        with open(outcsv, 'w', newline='') as f_out:
            writer = csv.writer(f_out)
            writer.writerow(table.field_names)
            for record in table:
                writer.writerow(list(record.values()))
             
                
    def dat_to_csv(self, dat_in, out_csv, dat_delim):
        """Convert DAT file to CSV to allow loading via BCP utility"""
        with open(dat_in, 'r') as f_in:
            in_rows = f_in.readlines()
            with open(out_csv, 'w', newline='') as f_out:
                writer_out = csv.writer(f_out)
            
                for row in in_rows:
                    rstrip = row.strip('\n')
                    out_row = rstrip.split(dat_delim)
                    writer_out.writerow(out_row)
        
            
    def create_sql_table_from_file(self, file_in, str_create_table_sql, tbl_name,
                                   overwrite=True, data_start_row=2, delimiter=None):
        '''Loads data from a text file into a sql server table
        PARAMETERS:
            file_in = text or CSV input data file
            delim_name = name of character used for delimiting
            str_create_table_sql = string of SQL query, normally read from SQL file
            tbl_name = name of table to be created
            overwrite = True/False. If true will overwrite any tables that already exist with tbl_name
            data_start_row = row that data start on. If data file has header row, then start_row = 2
            delimiter = optional argument to specify delimiter. If none specified, the delimiter will
                be guessed based on the file extension. For TXT files a comma delimiter is assumed
        '''
        # return file format without period (e.g. 'csv', 'tsv')
        file_format = os.path.splitext(file_in)[1].strip('\.')
        
        if file_format not in self.accepted_file_types:
            print(f"{file_format} files not presently accepted by this loader. Exiting...")
            sys.exit()
        
        #-----convert, if needed, DAT or DBF into CSVs, which can be read by BCP
        format_dat = 'dat'
        format_dbf = 'dbf'
        format_csv = 'csv'
        
        in_file_rmextn = os.path.splitext(file_in)[0] # removes file extension from file path
        file_converted = f"{in_file_rmextn}.csv" # converts to CSV file extension. This will be path to converted file
        
        # convert DAT to CSV
        if file_format == format_dat:
            delim_spc = ' '
            self.dat_to_csv(file_in, file_converted, delim_spc)
            file_in = file_converted
            file_format = format_csv
        # convert DBF to CSV
        elif file_format == format_dbf:
            self.dbf_to_csv(file_in, file_converted)
            file_in = file_converted
            file_format = format_csv
        else:
            pass
            
        delim_char = self.delim_char_lookup[file_format]
        if delimiter: delim_char = delimiter
        
        #---------make SQL table with correct data types------------
        with pyodbc.connect(self.str_conn_info, autocommit=True) as conn:
            sql_cur = conn.cursor()
            str_data_start_row = str(data_start_row)
            
            # drop existing table if specified
            tables = [t[2] for t in sql_cur.tables()]
    
            if tbl_name in tables:
                if overwrite:
                    print(f"{tbl_name} already exists. Will be overwritten...")
                    drop_tbl_sql = "DROP TABLE {};".format(tbl_name)
                    sql_cur.execute(drop_tbl_sql)
                else:
                    print(f"{tbl_name} already exists. Exiting script...")
                    sys.exit()
                
            # create table that data will load to
            print(f"creating table {tbl_name}...")
            sql_cur.execute(str_create_table_sql)
            
            

        #------------load file's data to created table using BCP utility---------
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
                  "4 - Make sure you are specifying the correct delimiter type\n" \
                  "5 - If you loaded a TXT file with non-comma delimiters, you need to specify the delimiter type." \
                      "If no delimiter specified, a comma delimiter is assumed.")
            sys.exit(1)
        
        
        
    def append_from_file_to_sql_tbl():
        # placeholder for potential future method that appends from file to existing sql table
        pass
    
    def export_sqlresult_to_csv():
        # placeholder for potential future method that runs a sql query and exports to CSV
        pass


if __name__ == '__main__':
    
    #================INPUT PARAMETERS======================
    """BASIC PARAMETERS TO RUN AS STAND-ALONE TOOL:
        -File path to input data file (csv, tsv, etc)
        -NAME of input file field delimiter (presently accepts comma or tab)
        -Name of the SQL Server instance
        -Name of SQL Server database you are loading the table to
        -Name that the table in SQL Server will have
        -String representing SQL command for creating and/or loading to table,
            which can be entered manually as a string or loaded from a SQL
            query file.
    """
    
    #----------------TEST PARAMS---------------------
    sql_to_run = r"Q:\SACSIM19\Integration Data Summary\SACSIM19 Scripts\SQL\Python SQL\BCP table creation queries\create_ixworker_table.sql"
    
    # this chunk of params could also just be rewritten as one variable that is a file path
    test_tbl_type = "worker_ixxifractions" #household, trip, etc
    run_folder = r'D:\SACSIM19\MTP2020\Conformity_Runs\run_2035_MTIP_Amd1_Baseline_v1'
    txt_file_in = "worker_ixxifractions.dat"
    test_tbl_name = f"BCPtest_{test_tbl_type}_table"
    data_first_row = 1
    
    # server and database parameters
    server_name = 'SQL-SVR'
    database = 'MTP2020'
        
    #-----------------RUN TEST SCRIPT----------------  
    # load SQL create-table command from SQL file, formatting to insert user-specified
    # table name
    with open(sql_to_run, 'r') as f_sql_in:
        raw_sql = f_sql_in.read()
        formatted_sql_str = raw_sql.format(test_tbl_name)
    
    tbl_loader = BCP(svr_name=server_name, db_name=database)
    test_file_in = os.path.join(run_folder, txt_file_in)
    tbl_loader.create_sql_table_from_file(test_file_in, formatted_sql_str, test_tbl_name,
                                          overwrite=True, data_start_row=data_first_row)

