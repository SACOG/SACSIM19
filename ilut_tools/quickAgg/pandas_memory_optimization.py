"""
Name:pandas_memory_optimize.py
Purpose: Takes pandas dataframe as input and updates column data types to the most
efficient data type possible.
        
          
Author: Darren Conly
Last Updated: <date>
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import pandas as pd

def memory_optimization(in_df):
    '''Takes in a pandas dataframe and converts it to have optimized, low-memory
    data types'''
    # common default data types that can be reduced to more memory-efficient type
    dtype_obj = 'object'
    dtypes_int = ['int64', 'uint64']
    dtypes_float = ['float64']
    
    # category dtype is far more efficient way to store strings if not many unique string values.
    dtype_category = 'category'
    downcast_float = 'float'
    downcast_int = 'integer'
    
    for col in in_df.columns:
        start_dtype = in_df[col].dtype
        if start_dtype in dtypes_int:
            in_df[col] = pd.to_numeric(in_df[col], downcast=downcast_int) # sets to biggest size necessary, not biggest size possible
        elif start_dtype in dtypes_float:
            in_df[col] = pd.to_numeric(in_df[col], downcast=downcast_float)
        elif start_dtype == dtype_obj:
            # if number of unique string vals is less than 40% of the total number of vals in column,
            # then recode as category instead of string, which will save significant memory
            if len(in_df[col].unique()) / len(in_df[col]) < 0.4:
                in_df[col] = in_df[col].astype(dtype_category)
            else:
                continue
        else:
            continue