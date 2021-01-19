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
import re
import csv
import sys
import time
import subprocess

import pyodbc
from dbfread import DBF


# Traceback in case the script breaks, especially for BCP loading step
def trace():
    import traceback, inspect
    tb = sys.exc_info()[2]
    tbinfo = traceback.format_tb(tb)[0]
    # script name + line number
    line = tbinfo.split(", ")[1]
    filename = inspect.getfile(inspect.currentframe())
    # Get Python syntax error
    synerror = traceback.format_exc().splitlines()[-1]
    return line, filename, synerror


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
                    

                    
    def add_quotes_to_tstamps(self, in_file, tstamp_cols, re_dt_format=None):
        '''BCP cannot load some tstamp columns. A workaround is to add single
        quotes to make the timestamp into a string, then convert to timestamp
        once in SQL Server
        
        PARAMETERS:
            in_file (str file path) = path to data file to be loaded to SQL
            tstamp_cols (list) = list of names of columns with a datetime field
            re_dt_format (str) = regular expression to extract desired time stamp format
        
        
        Returns a copy of the file you want to load that has quotes added to timestamp column.
        ISSUE - this at least temporarily could consume significant drive space.
        '''
        
        print(f"\tquoting timestamp cols {tstamp_cols} so it can be read into SQL Server...")
        import csv
        
        def clean_tstamp_format(in_tstamp_str, re_expn=None):
            if re_dt_format:
                str_len = len(in_tstamp_str)
                
                if str_len < 5: # shortest time stamp possible would be '00:00' or 'mm/dd'
                    out_str = None
                else:
                    re_dt = re.compile(re_expn)
                    out_str = re.search(re_dt, in_tstamp_str).group(1)
                    out_str = f"'{out_str}'"
                
                return out_str
            else:
                return f"'{in_tstamp_str}'"
        
        try:
            temp_output_file = f"{os.path.splitext(os.path.basename(in_file))[0]}_str_ts.csv"
            output_dir = os.path.dirname(in_file)
            temp_output_fpath = os.path.join(output_dir, temp_output_file)
            
            f_out = open(temp_output_fpath, 'w', newline='')
            writer_out = csv.writer(f_out, delimiter=',')
            
            with open(in_file, 'r') as f_in:
                reader = csv.DictReader(f_in)
                for i, row in enumerate(reader):
                    for tstamp_col in tstamp_cols:
                        tstamp_val = row[tstamp_col]
                        tstamp_val2 = clean_tstamp_format(tstamp_val, re_dt_format) 
                        row[tstamp_col] = tstamp_val2
                    
                    if i == 0:
                        writer_out.writerow(list(row.keys()))
                        writer_out.writerow(list(row.values()))
                    else:
                        writer_out.writerow(list(row.values()))
                        
                    if i % 1000000 == 0: print(f"{i} datetime rows pre-processed...")

            return temp_output_fpath
            
            writer_out.close()
        except:
            trace()
            
        

    def create_sql_table_from_file(self, file_in, str_create_table_sql, tbl_name,
                                   overwrite=True, data_start_row=2, delimiter=None, dt_cols=None,
                                   str_load2final_sql=None, re_dt_format=None):
        '''Loads data from a text file into a sql server table
        PARAMETERS:
            file_in (str file path)= text or CSV input data file
            str_create_table_sql (string) = string of SQL query, normally read from SQL file
            tbl_name (string)= name of table to be created
            overwrite (boolean) = True/False. If true will overwrite any tables that already exist with tbl_name
            data_start_row (int) = row that data start on. If data file has header row, then start_row = 2
            delimiter (string) = optional argument to specify delimiter. If none specified, the delimiter will
                be guessed based on the file extension. For TXT files a comma delimiter is assumed
            dt_cols (list)= optional argument specifying field(s) that have a date or timestamp. BCP cannot directly
                load timestamp data to SQL Server, so need to let it know if there is such a field.
            str_load2final_sql (string) = optional argument for query that, after data have loaded into a staging table
                in SQL Server, they are then transferred (using this sql file) to a final table, and during the 
                transfer have their timestamp field converted to SQL Server datetime format
            re_dt_format (regex string) = regular expression describing the datetime format.
                Example: 01-01-2020 14:58:00 would have a regex format of '(\d+-\d+-\d+ \d+:\d+:\d+).*'
                ***ISSUE: this should be improved in future so it is more intuitive to someone unfamiliar with regex
         '''
         
        start_time = time.perf_counter()
         
        if dt_cols and not str_load2final_sql:
            raise Exception("You specified a datetime column (dt_cols). If loading a timestamp column, " \
                            " you must also provide a SQL string to convert" \
                            "it from a string to a SQL Server datetime type, filling out the " \
                            "str_load2final_sql parameter")
         
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
        
        
        #------------if necessary, pre-processing to load tables with datetime column
        if dt_cols:
            in_file_dt_str = self.add_quotes_to_tstamps(file_in, dt_cols, re_dt_format)
            file_in = in_file_dt_str
            tbl_name_final = tbl_name
            tbl_name = f"{tbl_name}_staging"
            
            str_create_table_sql = str_create_table_sql.format(tbl_name, tbl_name_final)
        else:
            str_create_table_sql = str_create_table_sql.format(tbl_name)

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
        try:
            subprocess.check_output(bcp_new_tbl_from_file)
            
            # import pdb; pdb.set_trace()
            if dt_cols:
                print("loading from staging table into final table for conversion to tstamp...")
                str_load2final_sql = str_load2final_sql.format(tbl_name, tbl_name_final)
                with pyodbc.connect(self.str_conn_info, autocommit=True) as conn:
                    sql_cur = conn.cursor()
                    sql_cur.execute(str_load2final_sql)

                os.remove(in_file_dt_str) # delete to free up space
            
            elapsed_time = round((time.perf_counter() - start_time)/60,1)
            print(("Successfully loaded table in {}mins!\n".format(elapsed_time)))
        except:
            print("BCP load fail. Things to try or check:\n" \
                  "1 - Make sure you are calling the correct SQL file to create the table\n" \
                  "2 - Make sure your SQL script is specifying correct columns and data types\n" \
                  "3 - Stop or shut off any SQL Server processes you have running\n" \
                  "4 - Confirm that the file you are trying to load is not open in another program\n" \
                  "4 - Make sure you are specifying the correct delimiter type\n" \
                  "5 - If you loaded a TXT file with non-comma delimiters, you need to specify the delimiter type." \
                      "If no delimiter specified, a comma delimiter is assumed.\n\n")
            
            trace()
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
    data_folder = r"D:\SACSIM19\MTP2020\Conformity_Runs\run_2035_MTIP_Amd1_Baseline_v1"
    test_file_in = os.path.join(data_folder, "_household.tsv" ) # r"P:\NPMRDS data\Raw Downloads\DynamicData_15Min\2020\test_trucks_Dec1_2020_yuba\test_trucks_Dec1_2020_yuba.csv"  # r"P:\NPMRDS data\Python\Data Prep\LoadRawData\samplett.csv"
    sql_to_run = r"C:\Users\dconly\GitRepos\SACSIM\ILUT Tools\Python\ILUT\BCP table creation queries\create_hh_table.sql"  # r"P:\NPMRDS data\Python\Data Prep\LoadRawData\qry\create_tt_table_no_tstamp.sql"  # r"P:\NPMRDS data\Python\Data Prep\LoadRawData\qry\create_tt_table.sql" # create_tt_table_chartime
    data_first_row = 2
    test_tbl_name = "TEST_load_hh01192020"
    
    # stuff you need if you are loading a table with datetime columns
    tstamp_cols = None # ['measurement_tstamp']
    load2final_sql = None # r"P:\NPMRDS data\Python\Data Prep\LoadRawData\qry\tt_tbl_load2final.sql"
    
    # server and database parameters
    server_name = 'SQL-SVR'
    database = 'MTP2020'
        
    #-----------------RUN TEST SCRIPT----------------  
    # load SQL create-table command from SQL file, formatting to insert user-specified
    # table name
    
    
    with open(sql_to_run, 'r') as f_sql_in:
        raw_sql_maketbls = f_sql_in.read()
        # formatted_sql_str = raw_sql.format(test_tbl_name)
    
    if load2final_sql:
        with open(load2final_sql, 'r') as f_sql_in:
            raw_sql_load2final = f_sql_in.read()
    else:
        raw_sql_load2final = None
    
    tbl_loader = BCP(svr_name=server_name, db_name=database)
    tbl_loader.create_sql_table_from_file(test_file_in, raw_sql_maketbls, test_tbl_name,
                                          overwrite=True, data_start_row=data_first_row,
                                          dt_cols=tstamp_cols, str_load2final_sql=raw_sql_load2final)
    

