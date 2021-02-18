#--------------------------------
# Name: PopGen_InputProcess_v2.py
# Purpose: To prepare the PopGen Input SAMPLE files based on PUMAs Household and Person data.
# Author: Kyle Shipley
# Created: 2/05/18
# Update - 7/7/2020
# converted minor syntax from 2.7 to 3.6
# Copyright:   (c) SACOG
# ArcGIS Pro
# Python Version:   3.6
#--------------------------------

import arcpy,traceback, sys, os, time, csv
from arcpy import env

start_time = time.time()

####################################################

###USER INPUTS
# Input PUMAs SACOG region tables
inhca = r'C:\Projects\LandUse\popgen\00_ScenarioTemplate\01_Input\popgen_inputProcess.gdb\ss16hca_sacog'
inpca = r'C:\Projects\LandUse\popgen\00_ScenarioTemplate\01_Input\popgen_inputProcess.gdb\ss16pca_sacog'
# output Names
outHHName = "HH_Sample"
outPPName = "PP_sample"
outGQName = "GQ_Sample"

####################################################

# set workspace
workspace = os.path.dirname(inhca)
env.workspace = workspace
env.overwriteOutput = True
parentfolder = os.path.dirname(workspace)
outCSVfolder = os.path.join(parentfolder,"02_Sample")
if not os.path.exists(outCSVfolder):
    os.makedirs(outCSVfolder)

# outputs
outHH = os.path.join(workspace,outHHName)
outPP = os.path.join(workspace,outPPName)
outGQ = os.path.join(workspace,outGQName)

outHHCSV = os.path.join(outCSVfolder,outHHName + ".csv")
outPPCSV = os.path.join(outCSVfolder,outPPName + ".csv")
outGQCSV = os.path.join(outCSVfolder,outGQName + ".csv")

# rename UID from input file,
#  DAYSIM cannot use orginal SEERIALNO format.
oUID = "SERIALNO"
nUID_2 = "SID_2"
nUID = "SID_Orig"

# required fields for output tables
OrderedoutHHFields = [
    "STATE","PUMANO","HHID",
    "SERIALNO","HSIZE","WORKER",
    "INCOME","HHER","UNIV",
    "NP","NWORKER","HINCP",
    "AGE_OWNER"
]

OrderedoutPPFields = [
    "STATE","PUMANO","HHID",
    "SERIALNO","PNUM","AGEC",
    "AGEP","ETHC"
]

OrderedoutGQFields = [
    "STATE","PUMANO","HHID",
    "SERIALNO","GQtype"
]

# Determine other working fields to keep. Then drop fields to reduce file size
# --Some 'working fields' kept for 'PopGen_To_Allocation.py' process.
# hca working fields
hcakeep = [
    "PUMA","SERIALNO","ST",
    "NP","VEH","HINCP",
    "ADJINC","TYPE","AGEP",
    "WKHP","WGTP","WGTP1",
    "UNI_STU","SENIOR","WIF"
    ,"VEH","TEN", "BLD",
    "NPF","NOC"
]
# pca working fields
pcakeep = ["SERIALNO",
           "AGEP","WKW","PWGTP",
           "RELP","SCHG","SPORDER",
           "WKHP","WKL","WRK",
           "PUMA","RAC1P","FHISP",
            "RELP","SEX","WKHP",
           "SCH"
]

#Check if fields already exist
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
        if  field_type == "TEXT":
            field_length = 50
        arcpy.AddMessage("Adding " + field_name + " as - " + field_type)
        arcpy.AddField_management(in_table, field_name, field_type, field_precision, field_scale,
                                  field_length,
                                  field_alias,
                                  field_is_nullable, field_is_required, field_domain)

# Rename Field
def renamefield(fc,oldf,newf):
    arcpy.AlterField_management(fc,oldf,newf,newf,
                                field_type="#",field_length="#",
                                field_is_nullable="#",clear_field_alias="#")

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
#  include of addional fields to add.
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

def maketable(fc,outT,where_clause=None,flist=None):
    try:
        if arcpy.Exists(outT):
            arcpy.Delete_management(outT)
            arcpy.AddMessage("Remove previous table")
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
        arcpy.AddMessage("Table Created: " + name)

    except arcpy.ExecuteError:
        arcpy.AddMessage(arcpy.GetMessages(2))
    except Exception as e:
        arcpy.AddMessage(e.args[0])
        tb = sys.exc_info()[2]
        arcpy.AddMessage("An error occured on line %i" % tb.tb_lineno)
        arcpy.AddMessage(str(e))

# Fix CSV Table Formatting,
#  1. to remove OID created by arcpy table to table conversion.
#  2. Add "bigint" required row.
#  3. Lowercase all column headers
def fixOutputs(fixCSVTemp,fname_out,fillvalue=None):
    with open(fixCSVTemp, 'r') as fin, open(fixCSVTemp, 'r') as fint, open(fname_out, 'w', newline='') as fout:
        r1 = csv.reader(fint)
        reader = csv.reader(fin)
        writer = csv.writer(fout)

        columns = len(next(r1))
        del r1
        if fillvalue:
            #because we are removing the OID field..
            newcolumns = columns - 1
            fillrow = [fillvalue]*newcolumns

        i = 0
        for row in reader:
            if i == 0:
                row = [column.lower() for column in row]  # Lowercase the headings.
            elif (i == 1 and fillrow):
                # second line
                writer.writerow(fillrow)
            writer.writerow(row[1:])
            i = i+1
    os.remove(fixCSVTemp)
    arcpy.AddMessage("Output to CSV Fix: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

def CreateDic(UID, S=0):
    d = {}
    for ID in UID:
        S = S+1
        d.update({ID: S})
    return d

def unique_values(table, field):
    with arcpy.da.SearchCursor(table, [field]) as cursor:
        #return sorted({row[0] for row in cursor})
        #To remove nulls and blanks
        return sorted({row[0] for row in cursor if row[0]})

def merge_two_dicts(x, y):
    z = x.copy()   # start with x's keys and values
    z.update(y)    # modifies z with y's keys and values & returns None
    return z

#######
#START#
#######

hh_allf = hcakeep + OrderedoutHHFields + OrderedoutGQFields
pp_allf = pcakeep + OrderedoutPPFields

# Make working gdb tables
hh_tbl = os.path.join(workspace,"hh_tbl")
pp_tbl = os.path.join(workspace,"pp_tbl")

maketable(inhca, hh_tbl,"",hh_allf)
maketable(inpca, pp_tbl,"",pp_allf)

# set new key field
renamefield(hh_tbl,oUID,nUID)
renamefield(pp_tbl,oUID,nUID)

# rename existing fields
renamefield(hh_tbl,"NP","NP_Orig")
renamefield(hh_tbl,"HINCP","HINCP_Orig")
renamefield(pp_tbl,"AGEP","AGEP_Orig")

## Check if fields exists, else add new fields
# Name, Type
# HH
for f in OrderedoutHHFields:
    AddNewField(hh_tbl, f, "LONG")
AddNewField(hh_tbl,"HINC","LONG")
AddNewField(hh_tbl,"WORKER0","LONG")
AddNewField(hh_tbl,"WORKER1","LONG")
AddNewField(hh_tbl,"WORKER2","LONG")
AddNewField(hh_tbl,"WORKER3","LONG")
AddNewField(hh_tbl,"UNI_STU","LONG")
AddNewField(hh_tbl,"SENIOR","LONG")
AddNewField(hh_tbl,"HH_DUP","LONG") #households to duplicate in sample.

# GQ
for f in OrderedoutGQFields:
   AddNewField(hh_tbl, f, "LONG")
# PP
for f in OrderedoutPPFields:
    AddNewField(pp_tbl, f, "LONG")
AddNewField(pp_tbl,"ROWNO","LONG")
AddNewField(pp_tbl,"HH_only","LONG")
AddNewField(pp_tbl,"HH_Dup","LONG")
AddNewField(pp_tbl,"GR_only","LONG")
AddNewField(pp_tbl,"SR_only","LONG")

# Create Type 1 Table
hh_type = os.path.join(workspace,"hh_tbl_type")
wc_hh_type = ''' "TYPE" = 1 AND "NP_Orig" > 0 '''
maketable(hh_tbl,hh_type,wc_hh_type)

# Create Group Quarters Table
hh_gq_all = os.path.join(workspace,"hh_gq_all")
wc_hh_gq_all = ''' "TYPE" = 3 '''
maketable(hh_tbl,hh_gq_all,wc_hh_gq_all)

# Create Household Age Table from persons file. - Check only
hh_age = os.path.join(workspace,"hh_tbl_age")
wc_hh_age = ''' "RELP" = 0 '''
maketable(pp_tbl,hh_age,wc_hh_age)

###
# Find Senior Population
# shouldn't have to do this - instead load dic with stats np array? - update later...
pp_temp = os.path.join(workspace,"pp_temp")
stats = [["SPORDER","MAX"],["AGEP_Orig","MIN"]]
arcpy.Statistics_analysis(pp_tbl, pp_temp, stats, nUID)

#Create Senior Dictionary & Duplicate Households
senior_hh_temp = {}
hh_np56_temp = {}
Scursor, fieldlist = LoadSCursor(pp_temp)
for row in Scursor:
    key = row[fieldlist.index(nUID)]
    age = row[fieldlist.index('MIN_AGEP_Orig')]
    hhnum = row[fieldlist.index('MAX_SPORDER')]
    #Senior HHs
    if (age > 64 and hhnum <= 2):
        senior_hh_temp[key] = hhnum
    #duplicate households
    elif (hhnum >4):
        hh_np56_temp[key] = hhnum
# cleanup
del fieldlist, row, Scursor

# Create Demographic dictionarys from persons file.
Scursor, fieldlist = LoadSCursor(pp_tbl)
hh_age_dict = {}
wrker_wh_dict = {}
student_dict = {}
senior_dict = {}
np56_dict = {}

for row in Scursor:
    key = row[fieldlist.index(nUID)]

    # HH Owner by Age
    age = row[fieldlist.index('AGEP_Orig')]
    person = row[fieldlist.index('RELP')]
    if person == 0:
        hh_age_dict[key] = age

    # Workers by Age
    wrk = row[fieldlist.index('WRK')]
    agep = row[fieldlist.index('AGEP_Orig')]
    if (wrk == 1 and agep < 65):
        worker = 1
    else:
        worker = 0
    if key in wrker_wh_dict:
        wrker_wh_dict[key] = (wrker_wh_dict[key] + worker)
    else:
        wrker_wh_dict[key] = worker

    # University Students per Household
    schg = row[fieldlist.index('SCHG')]
    stud = 0
    per = 1
    if schg is None:
        schg = 0
    if (schg >= 15):
        stud = 1
    if key in student_dict:
        stud = stud + student_dict[key][0]
        HHpersons = per + student_dict[key][1]
        stuHHrt = round(float(stud)/float(HHpersons),2)
        student_dict[key] = [stud,HHpersons,stuHHrt]
    else:
        stuHHrt = round(float(stud)/float(per),2)
        student_dict[key] = [stud,per,stuHHrt]

    # Load Senior Population
    # Senior GQ Sample
    if key in senior_hh_temp:
        senior_dict[key] = [person,age,senior_hh_temp[key],6,0] #person number, age, number of people per household, state, puma (setting placeholder value)
    # Load expand person sample hhouseholds 5 & 6 persons
    if key in np56_dict:
        np56_dict[key] = [person,age,np56_dict[key]] #person number, age, number of people per household

# cleanup
del fieldlist, row, Scursor
arcpy.AddMessage("Create Person Dictionaries - Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

# Join Householder's age into HH Table
Ucursor, fieldlist = LoadUCursor(hh_type)
for row in Ucursor:
    key = row[fieldlist.index(nUID)]
    np = row[fieldlist.index("NP_Orig")]
    nworker = row[fieldlist.index("NWORKER")]

    hinc = (row[fieldlist.index('HINCP_Orig')] * (row[fieldlist.index('ADJINC')] / 1000000.00))
    row[fieldlist.index('HINC')] = hinc

    row[fieldlist.index('STATE')] = 6
    row[fieldlist.index('PUMANO')] = row[fieldlist.index('PUMA')]
    row[fieldlist.index('NP')] = row[fieldlist.index('NP_Orig')]
    row[fieldlist.index('HINCP')] = row[fieldlist.index('HINCP_Orig')]

    if key in hh_age_dict:
        age_owner = hh_age_dict[key]
        row[fieldlist.index('AGE_OWNER')] = age_owner
    else:
        age_owner = None
        row[fieldlist.index('AGE_OWNER')] = age_owner

    if key in wrker_wh_dict:
        HH_workers = wrker_wh_dict[key]
        row[fieldlist.index('NWORKER')] = HH_workers
        if HH_workers == 0:
            row[fieldlist.index('WORKER0')] = 1
        else:
            row[fieldlist.index('WORKER0')] = 0
        if HH_workers == 1:
            row[fieldlist.index('WORKER1')] = HH_workers
        else:
            row[fieldlist.index('WORKER1')] = 0
        if HH_workers == 2:
            row[fieldlist.index('WORKER2')] = HH_workers
        else:
            row[fieldlist.index('WORKER2')] = 0
        if HH_workers >= 3:
            row[fieldlist.index('WORKER3')] = HH_workers
        else:
            row[fieldlist.index('WORKER3')] = 0
    else:
        row[fieldlist.index('NWORKER')] = 0
        row[fieldlist.index('WORKER1')] = 0
        row[fieldlist.index('WORKER2')] = 0
        row[fieldlist.index('WORKER3')] = 0

    if np >= 4:
        row[fieldlist.index('HSIZE')] = 4
    elif np < 4:
        row[fieldlist.index('HSIZE')] = np

    if HH_workers == 0:
        row[fieldlist.index('WORKER')] = 1
    elif HH_workers == 1:
        row[fieldlist.index('WORKER')] = 2
    elif HH_workers == 2:
        row[fieldlist.index('WORKER')] = 3
    elif HH_workers >= 3:
        row[fieldlist.index('WORKER')] = 4

    if (hinc < 20000):
        row[fieldlist.index('INCOME')] = 1
    elif (hinc >= 20000 and hinc < 40000):
        row[fieldlist.index('INCOME')] = 2
    elif (hinc >= 40000 and hinc < 60000):
        row[fieldlist.index('INCOME')] = 3
    elif (hinc >= 60000 and hinc < 100000):
        row[fieldlist.index('INCOME')] = 4
    elif (hinc >= 100000):
        row[fieldlist.index('INCOME')] = 5

    if (age_owner < 35):
        row[fieldlist.index('HHER')] = 1
    elif (age_owner >= 35 and age_owner < 65):
        row[fieldlist.index('HHER')] = 2
    elif (age_owner >= 65):
        row[fieldlist.index('HHER')] = 3

    # Cluster University student Household
    if key in student_dict:
        uni_stu = student_dict[key][0]
        row[fieldlist.index('UNI_STU')] = uni_stu
        stud_hh_rate = student_dict[key][2]
        if stud_hh_rate > 0.66:
            row[fieldlist.index('UNIV')] = 2
        else:
            row[fieldlist.index('UNIV')] = 1
    else:
        print("Should not happen, check key: %s") % int(key)

    #Senior Facilities
    if key in senior_hh_temp:
        row[fieldlist.index('SENIOR')] = 1
        puma = row[fieldlist.index('PUMA')]
        senior_dict[key][4] = puma
    #Expand records
    if key in hh_np56_temp:
        row[fieldlist.index('HH_DUP')] = 1

    Ucursor.updateRow(row)
# cleanup
del fieldlist, row, Ucursor
arcpy.AddMessage("Update HH Table - Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

hh_dup = os.path.join(workspace,"hh_dup")
wc_hh_dup = ''' "HH_DUP" = 1 '''
maketable(hh_type,hh_dup,wc_hh_dup)

arcpy.AddMessage("Expand HH Table - Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

# Load Students and Persons into Group Quarters All Table
Ucursor, fieldlist = LoadUCursor(hh_gq_all)
for row in Ucursor:

    key = row[fieldlist.index(nUID)]

    row[fieldlist.index('STATE')] = 6
    row[fieldlist.index('PUMANO')] = row[fieldlist.index('PUMA')]

    # Cluster University student Household
    if key in student_dict:
        uni_stu = student_dict[key][0]
        row[fieldlist.index('UNI_STU')] = uni_stu
        np = student_dict[key][2]
        row[fieldlist.index('NP')] = np

    Ucursor.updateRow(row)
# cleanup
del fieldlist, row, Ucursor
arcpy.AddMessage("Update Group Quarters Table - Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

# Create Dorm Students Table
hh_gq = os.path.join(workspace,"hh_gq")
wc_hh_gr = ''' "TYPE" = 3 AND "NP_Orig" >= 1 AND "UNI_STU" >= 1 '''
maketable(hh_gq_all,hh_gq,wc_hh_gr)

# Create Group Quarter Senior Facility Table
hh_smple_seniors = os.path.join(workspace,"senior_sample")
wc_hh_seniors = ''' "SENIOR" >= 1'''
maketable(hh_type,hh_smple_seniors,wc_hh_seniors)
SeniorHHsCnt = arcpy.GetCount_management(hh_smple_seniors)
print('{} has {} records'.format(wc_hh_seniors, SeniorHHsCnt[0]))
#Insert records into group quarter table

fields1 = ["SID_Orig","STATE","PUMANO"]
fields2 = ["SID_Orig","STATE","PUMANO","GQtype"]

# Create cursors and insert new rows
# note, this assumes senior and dorm are different households
cnt = 0
with arcpy.da.SearchCursor(hh_smple_seniors,fields1) as sCur:
    with arcpy.da.InsertCursor(hh_gq,fields2) as iCur:
        for row in sCur:
            newrow = row + (2,)
            iCur.insertRow(newrow)
# cleanup
del fields1,fields2,row
arcpy.AddMessage("ADD Senior Facility HH to Group Quarters - Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

###
#Sorting and Creating HHID numbers from 1 - x
# 1. Normal Households
# 2. Duplicate Households
# 3. Dorms and Senior Facilities

# Create Sorted Unique Value Lists
print ("Create New HHIDs: Start: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

HH_type_Lsorted_norm = unique_values(hh_type, nUID) #This should now include normal
print ("HH_type list records: %s" % (len(HH_type_Lsorted_norm)))

HH_dup_Lsorted_dup = unique_values(hh_dup, nUID) #This should now include expanded
print ("HH_type Duplicate list records: %s" % (len(HH_dup_Lsorted_dup)))

HH_gr_Lsorted_gq_sf = unique_values(hh_gq, nUID) #Includes dorms and senior facilities
print ("hh_gq list records: %s" % (len(HH_gr_Lsorted_gq_sf)))

#Create Dicts with IDs
# Create HHID Dictionary
HH_t_dict = CreateDic(HH_type_Lsorted_norm)
HH_tdup_dict = CreateDic(HH_dup_Lsorted_dup,len(HH_type_Lsorted_norm))
lastnum = len(HH_type_Lsorted_norm) + len(HH_dup_Lsorted_dup)

HH_gr_dict = CreateDic(HH_gr_Lsorted_gq_sf,lastnum)

##
# Load back ordered HHID field - Normal
Ucursor, fieldlist = LoadUCursor(hh_type)
for row in Ucursor:
    key = row[fieldlist.index(nUID)]
    if key in HH_t_dict:
        HHID = HH_t_dict[key]
        row[fieldlist.index('HHID')] = HHID
        row[fieldlist.index('SERIALNO')] = HHID
    Ucursor.updateRow(row)
# cleanup
del fieldlist, row, Ucursor

# Load back ordered HHID field - Duplicates Only
Ucursor, fieldlist = LoadUCursor(hh_dup)
for row in Ucursor:
    key = row[fieldlist.index(nUID)]
    if key in HH_tdup_dict:
        HHID = HH_tdup_dict[key]
        row[fieldlist.index('HHID')] = HHID
        row[fieldlist.index('SERIALNO')] = HHID
    Ucursor.updateRow(row)
# cleanup
del fieldlist, row, Ucursor

# Load back ordered HHID field, add dorms as 1, senior facilities as 2
Ucursor, fieldlist = LoadUCursor(hh_gq)
for row in Ucursor:
    key = row[fieldlist.index(nUID)]
    if row[fieldlist.index("GQtype")] == None:
        row[fieldlist.index("GQtype")] = 1
    if key in HH_gr_dict:
        HHID = HH_gr_dict[key]
        row[fieldlist.index('HHID')] = HHID
        row[fieldlist.index('SERIALNO')] = HHID
        #if key in senior_dict:
            #senior_dict[key] = [person, age, senior_hh_temp[key], 6, 0]  # person number, age, number of people per household, state, puma (setting placeholder value)
    Ucursor.updateRow(row)
# cleanup
del fieldlist, row, Ucursor
arcpy.AddMessage("Add HHIDs to HH_Sample File : Complete")
arcpy.AddMessage("Add HHIDs to GQ_Sample File : Complete")

arcpy.AddMessage("Make Person Sample Table Start: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
# Update Person Table
#  - Note this is entire table, still need to query down to Person Sample
Ucursor, fieldlist = LoadUCursor(pp_tbl)
for row in Ucursor:
    key = row[fieldlist.index(nUID)]

    row[fieldlist.index('STATE')] = 6
    row[fieldlist.index('PUMANO')] = row[fieldlist.index('PUMA')]
    row[fieldlist.index('PNUM')] = row[fieldlist.index('SPORDER')]
    row[fieldlist.index('AGEP')] = row[fieldlist.index('AGEP_Orig')]

    agep = row[fieldlist.index('AGEP_Orig')]
    if agep < 15:
        row[fieldlist.index('AGEC')] = 1
    elif agep >= 15 and agep < 35:
        row[fieldlist.index('AGEC')] = 2
    elif agep >= 35 and agep < 65:
        row[fieldlist.index('AGEC')] = 3
    elif agep >= 65:
        row[fieldlist.index('AGEC')] = 4

    # Ethnicity Group - based on census 2010 questions.
    hisp = row[fieldlist.index('FHISP')]
    race = row[fieldlist.index('RAC1P')]
    if hisp == 1: # hispanic
        row[fieldlist.index('ETHC')] = 3
    else:
        if race == 1: # white, non-hispanic
            row[fieldlist.index('ETHC')] = 1
        elif race == 2: # black or aa, non-hispanic
            row[fieldlist.index('ETHC')] = 2
        else: # Asian alone & other
            row[fieldlist.index('ETHC')] = 4

    #only HH_TYPE
    if key in HH_t_dict:
        HH_t = HH_t_dict[key]
        row[fieldlist.index('HH_only')] = HH_t
        row[fieldlist.index('HHID')] = HH_t
        row[fieldlist.index('SERIALNO')] = HH_t


    # Add Dorms HHID,
    #  Senior Facilities and Duplicate records to be
    #  added separately.
    if key in HH_gr_dict:
        if key in senior_dict:
            HH_g = HH_gr_dict[key]
            row[fieldlist.index('SR_only')] = HH_g
        else:
            #dorms
            HH_dorm = HH_gr_dict[key]
            row[fieldlist.index('GR_only')] = HH_dorm
            row[fieldlist.index('HHID')] = HH_dorm
            row[fieldlist.index('SERIALNO')] = HH_dorm
    if key in HH_tdup_dict:
       HH_d = HH_tdup_dict[key]
       row[fieldlist.index('HH_Dup')] = HH_d

    Ucursor.updateRow(row)
# cleanup
del fieldlist, row, Ucursor

#ADD BACK IN DUPLICATE RECORDS WITH NEW HHID FOR SENIOR FACILITIES AND DUPLICATES (5-4 HH TYPE)
pp_dup_only = os.path.join(workspace,"pp_dup_only")
wc_pp_dup_only = ''' "HH_Dup" >= 0 OR "SR_only" >= 0'''
maketable(pp_tbl,pp_dup_only,wc_pp_dup_only)

# Update Person Sample Duplicates
Ucursor, fieldlist = LoadUCursor(pp_dup_only)
for row in Ucursor:
    key = row[fieldlist.index(nUID)]
    if key in HH_gr_dict:
            HH_g = HH_gr_dict[key]
            row[fieldlist.index('HHID')] = HH_g
            row[fieldlist.index('SERIALNO')] = HH_g
            row[fieldlist.index('GR_only')] = 2
    elif key in HH_tdup_dict:
        HH_g = HH_tdup_dict[key]
        row[fieldlist.index('HHID')] = HH_g
        row[fieldlist.index('SERIALNO')] = HH_g
        row[fieldlist.index('HH_Dup')] = 2

    Ucursor.updateRow(row)
# cleanup
del fieldlist, row, Ucursor

# Finalize Person Table
print("Finalize Tables: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
pp_tbl_mrg = os.path.join(workspace,"pp_tbl_mrg")
arcpy.Merge_management([pp_tbl,pp_dup_only],pp_tbl_mrg)
pp_sample_wc = ''' "HHID" > 0 '''
pp_sample = os.path.join(workspace,"pp_sample")
maketable(pp_tbl_mrg,pp_sample,pp_sample_wc)
pp_sample_sort = os.path.join(workspace,"pp_sample_sort")
arcpy.Sort_management(pp_sample,pp_sample_sort,[["HHID","ASCENDING"],["PNUM","ASCENDING"]])

# Finalize HH Table
hh_type_mrg = os.path.join(workspace,"hh_type_mrg")
hh_type_sort = os.path.join(workspace,"hh_type_mrg_sort")
arcpy.Merge_management([hh_type,hh_dup],hh_type_mrg)
arcpy.Sort_management(hh_type_mrg,hh_type_sort,[["HHID","ASCENDING"]])

# Finalize GQ Table
hh_gq_sort = os.path.join(workspace,"hh_gq_sort")
arcpy.Sort_management(hh_gq,hh_gq_sort,[["HHID","ASCENDING"]])

print("Finalize Tables - Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

#Output final csvs
arcpy.AddMessage("-----------------------------------")
arcpy.AddMessage("Create CSV Outputs: " + outCSVfolder)

outTemp_HHCSV = outHHCSV[:-4] + "_T.csv"
outTemp_PPCSV = outPPCSV[:-4] + "_T.csv"
outTemp_GQCSV = outGQCSV[:-4] + "_T.csv"

maketable(hh_type_sort,outTemp_HHCSV,"",OrderedoutHHFields)
maketable(pp_sample_sort,outTemp_PPCSV,"",OrderedoutPPFields)
maketable(hh_gq_sort,outTemp_GQCSV,"",OrderedoutGQFields)

fixOutputs(outTemp_HHCSV, outHHCSV, "bigint")
fixOutputs(outTemp_PPCSV, outPPCSV, "bigint")
fixOutputs(outTemp_GQCSV, outGQCSV, "bigint")

arcpy.AddMessage("Process Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))