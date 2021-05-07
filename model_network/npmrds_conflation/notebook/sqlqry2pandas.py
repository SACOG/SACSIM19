"""
Name: pandas2sqltable.py
Purpose: Make dataframe from SQL Server query results
    https://docs.microsoft.com/en-us/sql/machine-learning/data-exploration/python-dataframe-sql-server?view=sql-server-ver15
        
          
Author: Darren Conly
Last Updated: Apr 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""
from time import perf_counter as perf

import pandas as pd
import urllib

import sqlalchemy as sqla # needed to run pandas df.to_sql() function
    
# extract SQL Server query results into a pandas dataframe   
def sqlqry_to_df(query_str, dbname, servername='SQL-SVR', trustedconn='yes', if_tbl_exists='replace'):     

    conn_str = "DRIVER={ODBC Driver 17 for SQL Server};" \
        f"SERVER={servername};" \
        f"DATABASE={dbname};" \
        f"Trusted_Connection={trustedconn}"
        
    conn_str = urllib.parse.quote_plus(conn_str)
    engine = sqla.create_engine(f"mssql+pyodbc:///?odbc_connect={conn_str}")
       
    start_time = perf()

    # create SQL table from the dataframe
    print("Executing query. Results loading into dataframe...")
    df = pd.read_sql_query(sql=query_str, con=engine)
    rowcnt = df.shape[0]
    
    et_mins = round((perf() - start_time) / 60, 2)
    print(f"Successfully executed query in {et_mins} minutes. {rowcnt} rows loaded into dataframe.")
    
    return df
    



if __name__ == '__main__':
    
    #==========Make dataframe from SQL Server query========
    db = 'NPMRDS'
    qry = 'SELECT TOP 10 * FROM npmrds_2017_alltmc_trucks'
    
    tdf = sqlqry_to_df(qry, db)
    
    
    
        
    
    