#--------------------------------
# Name: dbf_csv_largefile.py
# Purpose: Convert large dbf files to csv.
# Author: Kyle Shipley
# Created: 6/6/2018
# Update:
# Copyright:   (c) SACOG
# Python Version:   2 or 3
#--------------------------------

import sys
import csv
import time
import datetime
import arcpy
import os
from dbfread import DBF

#####INPUTS######
#input dbf full path
indbf = r"C:\Projects\Replica\scripts\cube\replica_combine_spring19_wSACSIMdist_v8.dbf"
out_csv = indbf[:-4] + ".csv"
###########################



def dbf_to_csv(fin,outcsv,Python=3):
    """Export from DBF to CSV for large files"""
    now = datetime.datetime.now()
    start_time = time.time()
    print(now.strftime("%Y-%m-%d %H:%M"))
    table = DBF(fin)
    print("DBF LOAD Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

    if Python==3:
        print("Python3")
        with open(outcsv, 'w', newline='') as fout:
            writer = csv.writer(fout)

            writer.writerow(table.field_names)
            for record in table:
                writer.writerow(list(record.values()))

    elif Python==2:
        print("Python2")
        with open(outcsv, 'wb') as fout:
            writer = csv.writer(fout)

            writer.writerow(table.field_names)
            for record in table:
                writer.writerow(list(record.values()))
    print("DBF to CSV Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
#
dbf_to_csv(indbf,out_csv,Python=3)