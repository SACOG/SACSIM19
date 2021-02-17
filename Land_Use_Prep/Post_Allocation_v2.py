#--------------------------------
# Name: Post_Allocation_v2.py
# Purpose: To finalize population file and bring population information back to the parcel file.
#       New version to improve performance, must use python 3+
# Author: Kyle Shipley
# Created: 7/20/18
# Update: 8/23/18
# Copyright:   (c) SACOG
# ArcGIS Version:   Pro
# Python Version:   3.6
#--------------------------------

import arcpy,traceback, sys, os, time, csv, datetime
import numpy as np
import pandas
from dbfread import DBF
from arcpy import env

now = datetime.datetime.now()
start_time = time.time()
print(now.strftime("%Y-%m-%d %H:%M"))

#######################################################
#Inputs
Parcel = r'Q:\SACSIM19\2020MTP\parcel\2035\ParcelData_2035_latest.gdb\DPS_2035_latest_less800k'
AllocationPop1 = r'Q:\SACSIM19\2020MTP\popgen\2035\04_2035_v2\03_PostProcess\02_Allocation\01_Split\pp_popgen_expandh1.dbf'
AllocationPop2 = r'Q:\SACSIM19\2020MTP\popgen\2035\04_2035_v2\03_PostProcess\02_Allocation\02_Split\pp_popgen_expandh2.dbf'

#ETO LU parcel File
ETO_parcel = r'Q:\SACSIM19\2020MTP\parcel\2035\ParcelData_2035_latest.gdb\DPS_2035_latest_less800k'

#Set to 03_Final folder plus gdb name
workspace = r'Q:\SACSIM19\2020MTP\popgen\2035\04_2035_v2\03_PostProcess\03_Final'
#Can use ETO file if already includes parking and school info.
CircuityParcel_Input = r'Q:\SACSIM19\2020MTP\parcel\2035\ParcelData_2035_latest.gdb\DPS_2035_latest_less800k'
#updates HH_P filed for Circuity Parcel file.
ExportforCircuity = True #only true if Create_parcel_wLU.py has been ran and all fields are already in parcel file. Else False
Scenario = "2035_v3_check"
#######################################################

outpp = Scenario + "_prec_pp"
outhh = Scenario + "_prec_hh"

gdbout = os.path.join(workspace,"Checks.gdb")
if not arcpy.Exists(gdbout):
    print("Create " + os.path.basename(gdbout))
    arcpy.CreateFileGDB_management(workspace,"Checks.gdb")

outfolder = os.path.join(workspace,"Post_Allocation_results")
if not os.path.exists(outfolder):
    print("Create Output Folder")
    os.makedirs(outfolder)

# set workspace
env.workspace = workspace
env.overwriteOutput = True

# Functions

def FieldExist(featureclass, fieldname):
    # Check if a field in a feature class field exists and return true it does, false if not.
    fieldList = arcpy.ListFields(featureclass, fieldname)
    fieldCount = len(fieldList)
    if (fieldCount >= 1):  # If there is one or more of this field return true
        return True
    else:
        return False

def AddNewField(in_table, field_name,field_type, field_precision="#", field_scale="#",
                field_length="#",
                field_alias="#", field_is_nullable="#", field_is_required="#", field_domain="#"):
    # Add a new field if it currently does not exist
    if FieldExist(in_table, field_name):
        arcpy.AddMessage(field_name + " Exists")
    else:
        if field_type == "TEXT":
            field_length = 50
        arcpy.AddMessage("Adding " + field_name + " as - " + field_type)
        arcpy.AddField_management(in_table, field_name, field_type, field_precision, field_scale,
                                  field_length,
                                  field_alias,
                                  field_is_nullable, field_is_required, field_domain)

def convert_to_pandas_df(table):
    # Get a list of field names to display
    field_names = [i.name for i in arcpy.ListFields(table) if i.type != 'OID']
    # Open a cursor to extract results from stats table
    cursor = arcpy.da.SearchCursor(table, field_names)
    # Create a pandas dataframe to display results
    df = pandas.DataFrame(data=[row for row in cursor],
                          columns=field_names)
    return df

def CalcStats(intable,casefield,NumStats = [],NumFields=None,StrStats = [],StrFields=None):
    # Correct formatting of stats [["Field1", "Sum"], ["Field2", "Sum"], ...]
    print("Calculate Summary Statistics: Start")
    if os.path.dirname(intable)[-3:] == "gdb":
        outtableName = intable + "_Statsby_" + casefield
    else:
        outtableName = intable[:-4] + "_Statsby_" + casefield + ".dbf"
    stats = []
    outtable = os.path.join(workspace, outtableName)
    # Loop through all fields in the Input Table
    for field in arcpy.ListFields(intable):
        if NumStats:
            for s in NumStats:
                if field.type in ("Double", "Integer", "Single", "SmallInteger"):
                    if NumFields:
                        if str(field.name) in NumFields:
                            stats.append([field.name,s])
                        else:
                            pass
                    else:
                        stats.append([field.name, s])
        elif StrStats:
            for s in StrStats:
                if (field.type not in ("Double", "Integer", "Single", "SmallInteger") and field.name in StrFields):
                    stats.append([field.name in StrFields, s])
    arcpy.Statistics_analysis(intable, outtable, stats, casefield)
    print("Calculate Summary Statistics as Table %s Complete" %outtableName)
    return outtable

#Insert Update DA Cursor with indexed fields,
#  include of addional fields to add.
def LoadUCursor(fc,flist=None):
    """Important note: Function creates two outputs, also only opens cursor,
     no "with" function to automatically close,
      remember to delete cursor and fieldlist when finished"""
    fields = [field.name for field in arcpy.ListFields(fc)]
    if flist:
        for f in flist:
            fields.append(f)
    cursor = arcpy.da.UpdateCursor(fc,fields)
    flist = cursor.fields
    return cursor, flist

#Insert Search DA Cursor with indexed fields,
#  include of additional fields to add.
def LoadSCursor(fc,flist=None):
    """Important note: Function creates two outputs, also only opens cursor,
     no "with" function to automatically close,
      remember to delete cursor and fieldlist when finished"""
    fields = [field.name for field in arcpy.ListFields(fc)]
    if flist:
        for f in flist:
            fields.append(f)
    cursor = arcpy.da.SearchCursor(fc,fields)
    flist = cursor.fields
    return cursor, flist

def fastjoin_Calc(inFile,joinFile,key_infile,key_joinfile,UpdateFromF,UpdateToF):
    try:
        #start
        start_time = time.time()
        arcpy.AddMessage("Start 'Join' Process: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
        #Create Dictionary from join feature
        JoinDict = {}

        SCursor, fieldlist = LoadSCursor(joinFile)
        for row in SCursor:
            key = row[fieldlist.index(key_joinfile)]
            UpdateValue = row[fieldlist.index(UpdateFromF)]
            JoinDict[key] = UpdateValue

        # cleanup
        del fieldlist, row, SCursor

        arcpy.AddMessage("Start 'Update New Field' Process: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
        UCursor, fieldlist = LoadUCursor(inFile)

        for row in UCursor:
            if row[fieldlist.index(key_infile)] in JoinDict:
                joinkey = row[fieldlist.index(key_infile)]
                row[fieldlist.index(UpdateToF)] = JoinDict[joinkey]
            UCursor.updateRow(row)

        arcpy.AddMessage("Process Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
        #cleanup
        del fieldlist, row, UCursor
        del JoinDict

    except arcpy.ExecuteError:
        arcpy.AddMessage(arcpy.GetMessages(2))
    except Exception as e:
        arcpy.AddMessage(e.args[0])
        tb = sys.exc_info()[2]
        arcpy.AddMessage("An error occured on line %i" % tb.tb_lineno)
        arcpy.AddMessage(str(e))

def maketable(fc,outT,where_clause=None,flist=None):
    try:
        if arcpy.Exists(outT):
            arcpy.Delete_management(outT)
            print("Remove previous table")
        if flist:
                FMapping = arcpy.FieldMappings()
                FMapping.addTable(fc)
                for field in FMapping.fields:
                    if field.name not in flist:
                        FMapping.removeFieldMap(FMapping.findFieldMapIndex(field.name))

        else:
            arcpy.AddWarning("No Field Mapping Specified")
            FMapping = ""

        folder = os.path.dirname(outT)
        name = os.path.basename(outT)
        arcpy.TableToTable_conversion(fc, folder, name, where_clause, FMapping)
        print("Table Created: " + name)

    except arcpy.ExecuteError:
        print(arcpy.GetMessages(2))
    except Exception as e:
        print(e.args[0])
        tb = sys.exc_info()[2]
        print("An error occured on line %i" % tb.tb_lineno)
        print(str(e))

def dbf_to_csv(fin,outcsv,Python=3):
    """Export from DBF to CSV for large files"""
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

# Rename Field
def renamefield(fc,oldf,newf):
    arcpy.AlterField_management(fc,oldf,newf,newf,
                                field_type="#",field_length="#",
                                field_is_nullable="#",clear_field_alias="#")
    arcpy.AddMessage("Rename Field " + oldf + "as : " + newf)

# Fix CSV Tables, to remove OID created by arcpy table to table conversion. Add "bigint" required row.
def fixOutputs(fixCSVTemp,fname_out,fillvalue=None):
    with open(fixCSVTemp, 'r') as fin, open(fixCSVTemp, 'r') as fint, open(fname_out, 'w',newline='') as fout:
        r1 = csv.reader(fint)
        reader = csv.reader(fin)
        writer = csv.writer(fout)

        columns = len(next(r1))
        del r1
        fillrow = None
        if fillvalue:
            #because we are removing the OID field..
            newcolumns = columns - 1
            fillrow = [fillvalue]*newcolumns

        i = 0
        for row in reader:
            if (i == 1 and fillrow):
                # second line
                writer.writerow(fillrow)
            writer.writerow(row[1:])
            i = i+1
    os.remove(fixCSVTemp)
    arcpy.AddMessage("Output to CSV Fix: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

def PersonTypeCalc_2(age,worker,hours,student,grade,pptyp):

    conditions = [
        (df[age]<= 4),
        (df[age] >= 5) & (df[age] <= 15),
        (df[age] >= 16) & (df[worker] == 1) & (df[hours] >= 32),
        (df[age] >= 16) & (df[student] == 1) & (df[grade] <=14),
        (df[age] >= 16) & (df[student] == 1) & (df[grade] > 14),
        (df[age] >= 16) & (df[worker] == 1) & (df[hours] < 32),
        (df[age] >= 65)]
    ptype_l = [8,7,1,6,5,2,3]
    df[pptyp] = np.select(conditions,ptype_l,default=4)
    return df[pptyp]

def pptypfun(ptype,value,newVar):
    df[newVar] = np.where(df[ptype]==value, 1, 0)
    return df[newVar]

### Start ###
# Main Script
if __name__ == '__main__':

    # STEP 1. Merge & Sort
    print("STEP 1 Merge & Sort allocated population file")
    dfpop1 = convert_to_pandas_df(AllocationPop1)
    dfpop2 = convert_to_pandas_df(AllocationPop2)
    print("Load Pop Table to Pandas: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    df = dfpop1.append(dfpop2,ignore_index=True)
    df['serialno'] = pandas.to_numeric(df['serialno'],errors='coerce')
    df = df.sort_values(by=['serialno', 'pnum'])
    print(df.head(3))
    outT_pop = os.path.join(outfolder, 'Pop.csv')
    df.to_csv(outT_pop)
    print("Process Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print("---------------------------------------")

    # STEP 2. Calculate Households per Parcel
    print("STEP 2. Calculate Households & Persons per Parcel")
    df['persons_p'] = df.groupby('HHCEL')['HHCEL'].transform('count')
    df_persons = df.groupby(['HHCEL'],as_index=False).agg({'persons_p':'max'})

    dfhhp = df.groupby(['serialno'],as_index=False).agg({'HHCEL':'max'})
    dfhhp['hh_p'] = dfhhp.groupby('HHCEL')['serialno'].transform('count')
    hh_parcel = dfhhp.groupby(['HHCEL'],as_index=False).agg({'hh_p':'max'})

    outT_hh_parcel = os.path.join(outfolder, 'Check_hh_parcel.csv')
    outT_pers_parcel = os.path.join(outfolder, 'Check_per_parcel.csv')

    hh_parcel.to_csv(outT_hh_parcel)
    df_persons.to_csv(outT_pers_parcel)

    #LoadDicts
    hhp_dict = hh_parcel.set_index('HHCEL')['hh_p'].to_dict() #households per parcel
    pphh_dict = df_persons.set_index('HHCEL')['persons_p'].to_dict() #persons per household
    print("Calculations Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

    #Load Households per Parcel & Persons Per Households back into the Circuity Parcel File
    Copybkup_CircuityParcel_Input = os.path.join(CircuityParcel_Input[:-4] + "_Old_HH_P")
    #arcpy.CopyRows_management(CircuityParcel_Input, Copybkup_CircuityParcel_Input)
    #print("Created Backup")
    #arcpy.CalculateField_management(CircuityParcel_Input, "HH_P", 0)
    AddNewField(CircuityParcel_Input,"Per_HH","DOUBLE")
    Ucursor, fieldlist = LoadUCursor(CircuityParcel_Input)
    for row in Ucursor:
        row[fieldlist.index('HH_P')] = 0
        row[fieldlist.index('Per_HH')] = 0

        pid = row[fieldlist.index('PARCELID')]
        if pid in hhp_dict:
            row[fieldlist.index('HH_P')] = hhp_dict[pid]
        if pid in pphh_dict:
            row[fieldlist.index('Per_HH')] = pphh_dict[pid]
        Ucursor.updateRow(row)
    # cleanup
    del fieldlist, row, Ucursor
    print("Updated HH_P & Persons_P for Circuity Buffer - Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    # Export to dbf
    if ExportforCircuity:
        arcpy.AddMessage("Create New Circuity Parcel Buffer File with new HH_P:")
        CircuityFile = os.path.join(outfolder,"sacog_parcel_" + Scenario + ".dbf" )
        print(CircuityFile)
        OrderedoutParcelFields = [
            "PARCELID", "X_COORD", "Y_COORD",
            "AREA_SQF", "TAZ", "LUSECODE",
            "HH_P", "STUGRD_P", "STUHGH_P",
            "STUUNI_P", "EMPEDU_P", "EMPFOO_P",
            "EMPGOV_P", "EMPIND_P", "EMPMED_P",
            "EMPOFC_P", "EMPRET_P", "EMPSVC_P",
            "EMPOTH_P", "EMPTOT_P", "PARKDY_P",
            "PARKHR_P", "PPRICDYP", "PPRICHRP"
        ]
        temptable = "in_memory\sacog_parcel_" + Scenario
        Sorted_Circuity = arcpy.Sort_management(CircuityParcel_Input,temptable,[["PARCELID", "ASCENDING"]])
        maketable(Sorted_Circuity, CircuityFile,"", OrderedoutParcelFields)

    print("Process Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print("---------------------------------------")

    #df = convert_to_pandas_df(Pop)
    #
    # Add Fields (note we may want to make a copy)
    ppfields = ["hhno","pno", "pptyp",
                 "pagey","pgend","pwtyp",
                 "pwpcl","pwtaz","pwautime",
                 "pwaudist", "pstyp","pspcl",
                 "pstaz", "psautime", "psaudist",
                 "puwmode","puwarrp", "puwdepp",
                 "ptpass","ppaidprk", "pdiary",
                 "pproxy","psexpfac"
                 ]


    # Update Fields
    print("STEP 3 Add Person Type and Update Population File: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

    df['hhno'] = df['serialno']
    df['pno'] = df['pnum']
    df['pptyp'] = PersonTypeCalc_2('AGE', 'WORKER', 'HOURS', 'STUDENT', 'GRADE', 'pptyp')
    df['pagey'] = df['AGE']
    df['pgend'] = df['SEX']
    df['pwtyp'] = df['WORKER']
    df['pwpcl'] = -1
    df['pwtaz'] = -1
    df['pwautime'] = -1
    df['pwaudist'] = -1
    df['pstyp'] = df['STUDENT']
    df['pspcl'] = -1
    df['pstaz'] = -1
    df['psautime'] = -1
    df['psaudist'] = -1
    df['puwmode'] = -1
    df['puwarrp'] = -1
    df['puwdepp'] = -1
    df['ptpass'] = -1
    df['ppaidprk'] = -1
    df['pdiary'] = -1
    df['pproxy'] = -1
    df['psexpfac'] = 1.0000
    df['hhftw'] = pptypfun('pptyp',1,'hhftw')
    df['hhptw'] = pptypfun('pptyp',2, 'hhptw')
    df['hhret'] = pptypfun('pptyp',3, 'hhret')
    df['hhoad'] = pptypfun('pptyp',4, 'hhoad')
    df['hhuni'] = pptypfun('pptyp',5, 'hhuni')
    df['hhhsc'] = pptypfun('pptyp',6, 'hhhsc')
    df['hh515'] = pptypfun('pptyp',7, 'hh515')
    df['hhcu5'] = pptypfun('pptyp',8, 'hhcu5')

    print("Person Types Summary:")
    print(df.groupby(['pptyp'])['pptyp'].count())
    print("Person Type Calculated: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

    df = df.sort_values(by=['serialno', 'pnum'])
    print("Sort Person Table Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    outT_ppcsv = os.path.join(outfolder, outpp + 'T.csv')
    df.to_csv(outT_ppcsv,columns=ppfields)
    out_ppcsv = os.path.join(outfolder, outpp + '.csv') #may want to change this to txt out...
    fixOutputs(outT_ppcsv,out_ppcsv)
    print("Export to CSV Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print("Process Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print("-----------------------------------")

    # Calc Stats by household
    stats = {
        "hhno":"count", # hhsize
        "hhftw":"sum", # hhftw
        "hhptw": "sum",  # hhptw
        "hhret": "sum",  # hhret
        "hhoad": "sum",  # hhoad
        "hhuni": "sum",  # hhuni
        "hhhsc": "sum",  # hhhsc
        "hh515": "sum",  # hh515
        "hhcu5": "sum",  # hhcu5
        "VEHICL":"max", # hhvehs
        "NWORKERS":"max",  # hhwkrs
        "HINC":"max", # hhincome as int
        "TENURE": "max",  # hownrent
        "BLDGSZ": "max",  # hrestype
        "HHCEL": "max",  # hhparcel numeric(10,0))
        "HHTAZ": "max"  # hhtaz as int
         }

    print("STEP 4 Create Household Table")
    df_hh_stats = pandas.DataFrame(df.groupby(['serialno'],as_index=False).agg(stats))

    hhfields = [
        "hhno","hhsize","hhvehs",
        "hhwkrs", "hhftw", "hhptw",
        "hhret", "hhoad", "hhuni",
        "hhhsc", "hh515", "hhcu5",
        "hhincome", "hownrent", "hrestype",
        "hhparcel", "hhtaz", "hhexpfac",
        "samptype"
    ]

    # create final Household pandas table
    df_hh = df_hh_stats
    # rename columns
    renamedict = {
        'serialno': 'hhno',
        'hhno': 'hhsize',
        'VEHICL': 'hhvehs',
        'NWORKERS': 'hhwkrs',

        'HINC': 'hhincome',
        'TENURE': 'hownrent',
        'BLDGSZ': 'hrestype',
        'HHCEL': 'hhparcel',
        'HHTAZ': 'hhtaz'
    }
    df_hh.rename(columns=renamedict,inplace=True)

    df_hh['hhexpfac'] = 1
    df_hh['samptype'] = 1

    df_hh = df_hh.sort_values(by='hhno')
    print("Sort Table Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    outT_hhcsv = os.path.join(outfolder, outhh + 'T.csv')
    # Export to CSV
    df_hh.to_csv(outT_hhcsv)
    out_hhcsv = os.path.join(outfolder, outhh + '.csv')
    fixOutputs(outT_hhcsv,out_hhcsv)
    print("Export HH Table")
    print("-----------------------------------")
    print("Final Outputs: " + outfolder)
    arcpy.Delete_management("in_memory")
    print("Process Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print("-----------------------------------")
