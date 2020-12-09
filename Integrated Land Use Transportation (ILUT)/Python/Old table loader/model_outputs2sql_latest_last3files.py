# -*- coding: utf-8 -*-
"""
Created on Wed May 30 08:07:20 2018

@author: dconly
Purpose: load model output tables into SQL server. This script does NOT load
the other, following tables that are necessary for ILUT creation:
    Envision Tomorrow parcel table
    PopGen population file
    
To-dos:
    10/13/2018 - add while loop to make sure user put in correct model year prefix (pa35, ds40, etc)
    
resources used in development of script:
    http://docs.sqlalchemy.org/en/latest/core/engines.html#microsoft-sql-server
    https://stackoverflow.com/questions/48154172/python-write-pandas-dataframe-to-mssql-database-error
    https://stackoverflow.com/questions/25661754/get-data-from-pandas-into-a-sql-server-with-pyodbc
    http://cmdlinetips.com/2018/01/how-to-load-a-massive-file-as-small-chunks-in-pandas/

"""

import os
import re
import urllib
import csv
import time
import sqlalchemy as sqla
from sqlalchemy.dialects.mssql import SMALLINT,INTEGER
import pandas as pd
from dbfread import DBF



def drop_table_if_exists(table_name,sql_engine):
    engine = sqla.create_engine("mssql+pyodbc:///?odbc_connect={}".format(conxn_info))
    conn = engine.connect()
    
    tables = list(engine.table_names())
    
    if table_name in tables:
        drop_tbl_sql = "DROP TABLE {};".format(table_name)
        conn.execute(drop_tbl_sql)
        
def dbf_to_csv(f_in,outcsv):
    """Export from DBF to CSV for large files"""
    table = DBF(f_in)

    with open(outcsv, 'w', newline='') as f_out:
        writer = csv.writer(f_out)
        writer.writerow(table.field_names)
        for record in table:
            writer.writerow(list(record.values()))
    
def create_table(sql_file,sql_table_name):
    engine = sqla.create_engine("mssql+pyodbc:///?odbc_connect={}".format(conxn_info))
    conn = engine.connect()
    conn.autocommit = True
    with open(os.path.join(maketbl_sqldir,sql_file),'r') as in_sql:
        raw_sql = in_sql.read()
        formatted_sql = raw_sql.format(sql_table_name)
        conn.execute(formatted_sql)

    conn.close()
    
def prefix_check(model_dir):
    check = True
    while check:
        prefix = prefix = input("Enter model run scenario prefix (e.g. pa35, pa27, 2016, etc.): ")
        prefix_match = '{}.*'.format(prefix)
        pref_list = [i for i in os.listdir(model_dir) if re.match(prefix_match,i)]
        if len(pref_list) == 0:
            check = True
            print("Wrong model prefix. Please check model run folder.")
            continue
        else:
            check = False
            break
    return prefix

def load2sql(model_dir,in_txt,delim,sql_tblname,headval,raw_pcl_tbl):
    engine = sqla.create_engine("mssql+pyodbc:///?odbc_connect={}".format(conxn_info))
    txt = os.path.join(model_dir,in_txt)
    
    #if table already exists, delete it
    drop_table_if_exists(sql_tblname,engine)
        
    
    #do in chunks of 100,000 rows to keep memory free
    for chunk in pd.read_csv(txt,delimiter = delim, header = headval, chunksize = 1000, iterator = True):

        #make into smallest workable data types
        for col in chunk.columns:
            if chunk[col].dtype == 'int64':
                chunk[col] = pd.to_numeric(chunk[col], downcast = 'integer')
            elif chunk[col].dtype == 'float64':
                chunk[col] = pd.to_numeric(chunk[col], downcast = 'float')
            else:
                pass
            
        #make small integer values import as such into sql server table, to save space
        smallint_dict = {col:SMALLINT for col in chunk.columns \
                         if chunk[col].dtype == 'int8'}
        
        if in_txt == raw_pcl_tbl: #upsize smallint values for some parcel table columns
            for col in pcl_coltype_corrdict.keys():
                smallint_dict[col] = pcl_coltype_corrdict[col]
          
        #pandas int16 won't fit into SQL Server smallint, so resize it to fit into sql server int data type
        for col in chunk.columns:
            if chunk[col].dtype == 'int16':
                chunk[col] = chunk[col].astype('int32')
            else:
                pass
        
        #only 2100 cells at a time can be loaded to sql server, so this ensures
        #that the table is imported in small enough pieces        
        colcnt = len(chunk.columns)
        chunk_size = int(2050/colcnt)-1
        
        #load to sql server -- in future may be able to increase chunk size
        chunk.to_sql(sql_tblname,engine,if_exists = 'append', 
                     index = False, chunksize = chunk_size, dtype = smallint_dict)
        
def do_work(person_tf,hh_tf,raw_pcl_tf,trip_tf,tour_tf,ixxi_tf,commveh_tf,ixworker_tf):
    model_dir = input("Copy/paste model run folder path: ")
    sc_yr = input("Enter scenario year: ") #scenario year
    sc_code = input("Enter scenario number: ") #scenario ID code
    
    if raw_pcl_tf:
        scen_prefix = prefix_check(model_dir)
        raw_pcl_tbl = "{}_raw_parcel.txt".format(scen_prefix)
    else:
        raw_pcl_tbl = "not_used.txt" #if not loading parcel table, give it dummy value so that dict has a key for it.
        
    #convert ixxi and commercial vehicle DBFs to CSVs prior to uploading to SQL
    print("converting DBFs to CSVs...")
    if ixxi_tf:
        ixxi_tbl = ixxi_tbl_dbf.replace('.dbf','.csv')
        dbf_to_csv(os.path.join(model_dir,ixxi_tbl_dbf), os.path.join(model_dir,ixxi_tbl))
    else:
        ixxi_tbl = 'not_used.txt2'
        
    if commveh_tf:
        commveh_tbl = commveh_tbl_dbf.replace('.dbf','.csv')
        dbf_to_csv(os.path.join(model_dir,commveh_tbl_dbf), os.path.join(model_dir,commveh_tbl))
    else:
        commveh_tbl = 'not_used.txt3'
    
    
    
    #{<in txt file name>:[<true/false to include table>,<delimiter type>,<sql_table_name>,<indicate if false>}
    import_dict = {person_tbl:[person_tf,"\t","raw_person{}_{}".format(sc_yr,sc_code),'infer'],
                   hh_tbl:[hh_tf,"\t","raw_hh{}_{}".format(sc_yr,sc_code),'infer'],
                   raw_pcl_tbl:[raw_pcl_tf,",","raw_parcel{}_{}".format(sc_yr,sc_code),'infer'],
                   trip_tbl:[trip_tf,",","raw_trip{}_{}".format(sc_yr,sc_code),'infer'],
                   tour_tbl:[tour_tf,"\t","raw_tour{}_{}".format(sc_yr,sc_code),'infer'],
                   ixxi_tbl:[ixxi_tf,",","raw_ixxi{}_{}".format(sc_yr,sc_code),'infer'],
                   commveh_tbl:[commveh_tf,",","raw_cveh{}_{}".format(sc_yr,sc_code),'infer'],
                   ixworker_tbl:[ixworker_tf,",","raw_ixworker{}_{}".format(sc_yr,sc_code),None]}
    
    for in_txt in import_dict.keys():
        if import_dict[in_txt][0]:
            print("starting to load {}...".format(in_txt))
            start_time  = time.time()
            
            load2sql(model_dir,in_txt,
                     import_dict[in_txt][1],
                     import_dict[in_txt][2],
                     import_dict[in_txt][3],
                     raw_pcl_tbl)
            
            elapsed_time = elapsed_time = round((time.time() - start_time)/60,1)
            print("Loaded {} into SQL table {} in {} mins" \
                  .format(in_txt,import_dict[in_txt][2],elapsed_time))
            print("--"*20)
    
#============================MAIN SCRIPT===========================================

if __name__ == '__main__':
    driver = '{SQL Server}'
    server = 'SQL-SVR'
    database = 'MTP2020'
    trusted_connection = 'yes'
    conxn_info = urllib.parse.quote_plus("DRIVER={0}; SERVER={1}; DATABASE={2}; Trusted_Connection={3}" \
                                   .format(driver, server, database, trusted_connection))
    
    #model output files to put into SQL server
    person_tbl = "_person.tsv"
    hh_tbl = "_household.tsv"
    #raw_pcl_tbl = "2016_raw_parcel.txt" #created during script run to apply user-entered year.
    trip_tbl = "_trip_1_1.csv"
    tour_tbl = "_tour.tsv"
    ixworker_tbl = "worker_ixxifractions.dat" #no header
    
    ixxi_tbl_dbf = "ixxi_taz.dbf" #requires conversion from dbf
    commveh_tbl_dbf = "cveh_taz.dbf" #requires conversion from dbf
    
    #due to chunking, some columns must manually be set to integer.
    #if not they will be started as smallint, then throw an error when int value is passed in next chunk
    pcl_coltype_corrdict = {'aparks_1':INTEGER,'aparks_2':INTEGER}
    
    #specify which tables you want to load.
    do_work(person_tf = False,
            hh_tf = False,
            raw_pcl_tf = False,
            trip_tf = False,
            tour_tf = False,
            ixxi_tf = True,
            commveh_tf = True,
            ixworker_tf = True)
    
    
    
    
    
    