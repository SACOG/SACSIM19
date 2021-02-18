#--------------------------------
# Name: PopGen_To_Allocation.py
# Purpose: To prepare the PopGen Outputs to final Population inputs for parcel Allocation process.
#          Assumes 'PopGen_InputProcess.py' script & PopGen have been ran.
#           V2 to improve performance, must run on Python 3+
#           v3 make "expand records" optional depending on PopGen exports
# Author: Kyle Shipley & Yanmei Ou
# Created: 2/22/18 (v1)
# Update - 10/13/2020
# Copyright:   (c) SACOG
# ArcGIS Version:   Pro
# Python Version:   3.6
#--------------------------------

import arcpy,traceback, sys, os, time, csv, datetime
import numpy as np
import pandas as pd
from dbfread import DBF
from arcpy import env

now = datetime.datetime.now()
start_time = time.time()
print(now.strftime("%Y-%m-%d %H:%M"))


####################################################
### USER INPUTS ###

# Input Folder: Specify PopGen Output Directory Path
input_dir = r'C:\Projects\regional forecasts\SACSIM19_ElkGrove_SportComplex\00_ElkGroveMultiComplx_2035_wfullRes\02_PopGen\02_PopGenOutputs'

# PopGen_InputProcess.py geodatabase workspace or where the PUMAs tables have been moved.
IP_gdb_dir = r'C:\Projects\regional forecasts\SACSIM19_ElkGrove_SportComplex\00_ElkGroveMultiComplx_2035_wfullRes\01_Input\popgen_inputProcess.gdb'
# set current workspace gdb - set file geodatabase path for working files.
# Note: if workspace doesn't exist, it will be created (must end with .gdb)
workspace = r'C:\Projects\regional forecasts\SACSIM19_ElkGrove_SportComplex\00_ElkGroveMultiComplx_2035_wfullRes\03_PostProcess\01_Inputs_to_Allocation_Process\Allocation_Workspace.gdb'

# Households files
meta_hh = os.path.join(input_dir,'housing_synthetic_data_meta.txt')
in_hh = os.path.join(input_dir,'housing_synthetic_data.csv')
exp_hh_name = 'hh_popgen_expand'

# Persons files
meta_pp = os.path.join(input_dir,'person_synthetic_data_meta.txt')
in_pp = os.path.join(input_dir,'person_synthetic_data.csv')
exp_pp_name = 'pp_popgen_expand'

#If exported as 'unique records' from PopGen set to False because records are already expanded.
exp_rec = False

#(optional) - use to update additional PopGen Runs to expand and append, else only leave = "" and comment out
in_pp2_appends = ""
in_hh2_appends = ""
#in_pp2_append1 = os.path.join(input_dir,'person_synthetic_data_append.csv')
#in_hh2_append1 = os.path.join(input_dir,'housing_synthetic_data_append.csv')
#in_pp2_append2 = os.path.join(input_dir,'person_synthetic_data_t10511.csv')
#in_hh2_append2 = os.path.join(input_dir,'housing_synthetic_data_t10511.csv')
#in_pp2_append3 = os.path.join(input_dir,'person_synthetic_data_append3.csv')
#in_hh2_append3 = os.path.join(input_dir,'housing_synthetic_data_append3.csv')

#in_pp2_appends = [in_pp2_append1,in_pp2_append2]
#in_hh2_appends = [in_hh2_append1,in_hh2_append2]
####################################################



# Check the order matches meta data files.
# list column number (starting with 0), required to call variables in expand records
rec_order_hh = [2,4,6] # tract, hhid, frequency
rec_order_pp = [2,4,7] # tract, hhid, frequency
inflat_adjrt = 0.7057  # 2016 to 2000 dollar converstion rate source: Weston Regional CPI - collected 7/18/18
# set file & path structures
if not arcpy.Exists(workspace):
    print("Create " + os.path.basename(workspace))
    arcpy.CreateFileGDB_management(os.path.dirname(workspace),os.path.basename(workspace))
env.workspace = workspace
env.overwriteOutput = True
parentfolder = os.path.dirname(workspace)
outfolder = os.path.join(parentfolder,"PopGen_to_Allocation_results")
if not os.path.exists(outfolder):
    print("Create Output Folder")
    os.makedirs(outfolder)

# Files from PopGen_InputProcess.py: Households, Persons, General Quarters
ip_hh = os.path.join(IP_gdb_dir,"hh_type_mrg_sort") #was hh_tbl_type
ip_pp = os.path.join(IP_gdb_dir,"pp_sample_sort")
ip_gq = os.path.join(IP_gdb_dir,"hh_gq_sort") #was hh_gq_all

exp_hh_txt = os.path.join(outfolder,exp_hh_name+'.txt')
exp_pp_txt = os.path.join(outfolder,exp_pp_name+'.txt')

### Functions ###
def convert_to_pandas_df(table):
    # Get a list of field names to display
    field_names = [i.name for i in arcpy.ListFields(table) if i.type != 'OID']
    # Open a cursor to extract results from stats table
    cursor = arcpy.da.SearchCursor(table, field_names)
    # Create a pandas dataframe to display results
    df = pd.DataFrame(data=[row for row in cursor],
                          columns=field_names)
    return df

# Check if fields already exist
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
        print(field_name + " Exists")
    else:
        if  field_type == "TEXT":
            field_length = 50
        print("Adding " + field_name + " as - " + field_type)
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

def expandrecords(in_h,inf,outf,rec_order,expand,inf_appends=None):
    """ This function expands records,
        removes 'N/' values produced from PopGen,
        and assigns a new unique identifier """
    with open(in_h,'r') as in_header, open(inf,'r') as infile, open(outf,'w') as outfile:

        lines = in_header.readlines()
        head = ""
        total_rec = 0

        rec_tract = rec_order[0]
        rec_hhid = rec_order[1]
        rec_fre = rec_order[2]

        i = 1
        for aLine in lines:
            aLi = aLine.strip()
            aWord = aLi.split('-')
            aField = aWord[1]
            aField = aField.strip()
            if i == 1:
                head = aField
            else:
                head = head + "," + aField
            i = i + 1
        head = head + ",unique_id"

        #in_header.close()

        #outfile = open(outfile, 'w')
        outfile.write(head + "\n")
        print ("Create Header - Complete")

        #infile = open(infpath, 'r')
        lines = infile.readlines()
        cnt = 1
        for aLine in lines:
            aLi = aLine.strip()
            aLi = aLi.replace("\\N", "0")
            aWord = aLi.split(',')
            aTr = aWord[rec_tract]
            ahhid = aWord[rec_hhid]
            aFre = aWord[rec_fre]
            i = 1

            while i <= int(aFre):
                aID = str(aTr) + "_" + str(ahhid) + "_" + str(i)
                aNewLine = aLi + "," + aID
                # print aNewLine
                if cnt % 100000 == 0:
                    print("  %d: %s" % (cnt, aNewLine))
                outfile.write(aNewLine + "\n")
                total_rec = total_rec + 1
                i = i + 1
                cnt = cnt + 1
                if not expand:
                    break

        infile.close()

        try:
            for inf_append in inf_appends:
                with open(inf_append, 'r') as infile2:
                    print ("Appending Records")
                    lines = infile2.readlines()
                    for aLine in lines:
                        aLi = aLine.strip()
                        aLi = aLi.replace("\\N", "0")
                        aWord = aLi.split(',')
                        aTr = aWord[rec_tract]
                        ahhid = aWord[rec_hhid]
                        aFre = aWord[rec_fre]
                        i = 1
                        while i <= int(aFre):
                            aID = str(aTr) + "_" + str(ahhid) + "_" + str(i)
                            aNewLine = aLi + "," + aID
                            # print aNewLine
                            if cnt % 100000 == 0:
                                print("  %d: %s" % (cnt, aNewLine))
                            outfile.write(aNewLine + "\n")
                            total_rec = total_rec + 1
                            i = i + 1
                            cnt = cnt + 1
                            if not expand:
                                break
                    infile2.close()
        except:
            print("Warning: No Append File Exists: "+ str(inf_append))

        outfile.close()
        print("Total Records: " + str(total_rec))

def make_attribute_dict(fc, key_field, attr_list=['*']):
    ''' Create a dictionary of feature class/table attributes.
        Default of ['*'] for attr_list (instead of actual attribute names)
        will create a dictionary of all attributes. '''
    attr_dict = {}
    fcname = os.path.basename(fc)
    fc_field_objects = arcpy.ListFields(fc)
    fc_fields = [field.name for field in fc_field_objects if field.type != 'Geometry']
    if attr_list == ['*']:
        valid_fields = fc_fields
    else:
        valid_fields = [field for field in attr_list if field in fc_fields]
    # Ensure that key_field is always the first field in the field list
    cursor_fields = [key_field] + list(set(valid_fields) - set([key_field]))
    with arcpy.da.SearchCursor(fc, cursor_fields) as cursor:
        for row in cursor:
            attr_dict[row[0]] = dict(zip(cursor.fields, row))
    print ("Dictionary Loaded from: " + fcname)
    return attr_dict

def CalcGrade(Schg):
    """Grade level attending
    bb .N/A (not attending school)
    01 .Nursery school/preschool
    40
    02 .Kindergarten
    03 .Grade 1
    04 .Grade 2
    05 .Grade 3
    06 .Grade 4
    07 .Grade 5
    08 .Grade 6
    09 .Grade 7
    10 .Grade 8
    11 .Grade 9
    12 .Grade 10
    13 .Grade 11
    14 .Grade 12
    15 .College undergraduate years (freshman to senior)
    16 .Graduate or professional school beyond a bachelor's"""
    g = 0
    if Schg:
        g = Schg
    return g

########################
# Start Analysis
# Main Script
if __name__ == '__main__':

    # Step 1: Expand Households file
    print("Expand Records - Start at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    expandrecords(meta_hh,in_hh,exp_hh_txt,rec_order_hh,exp_rec,in_hh2_appends)
    print("STEP 1 Expanding records and unique ID for HH - Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print("-----------------------------------")
    # Step 2: Expand Population file
    expandrecords(meta_pp,in_pp,exp_pp_txt,rec_order_pp,exp_rec,in_pp2_appends)
    print("STEP 2 Expanding records and unique ID for PP Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print("-----------------------------------")
    # Step 3: <add description>
    # Copy Features into new workplace
    # Make working gdb tables
    hh_exp = os.path.join(workspace,exp_hh_name)
    pp_exp = os.path.join(workspace,exp_pp_name)
    hh_sample = os.path.join(workspace,"hh_sample")
    pp_sample = os.path.join(workspace,"pp_sample")
    gq_sample = os.path.join(workspace,"gq_sample")

    print("Loading working tables into GDB: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    maketable(exp_hh_txt,hh_exp)
    maketable(exp_pp_txt,pp_exp)
    maketable(ip_hh, hh_sample)
    maketable(ip_pp, pp_sample)
    maketable(ip_gq, gq_sample)
    print("Loaded Tables Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

    # Final Fields for Pop Gen Expanded Person File
    OrderedoutPPFields = [
        "serialno","pnum","HHTAZ",
        "HHCEL", "PERSONS", "TENURE",
        "BLDGSZ", "P65", "P18",
        "NPF", "NOC", "HINC",
        "VEHICL", "RELATE", "SEX",
        "AGE", "GRADE", "HOURS",
        "WORKER", "STUDENT", "NWORKERS",
        "NSTUDENT", "EXFAC", "dorm",
        "tr", "co", "ETHC"
    ]

    ## Check if fields exists, else add new fields
    # Name, Type
    # PP Expanded PopGen

    # rename existing fields
    try:
        renamefield(pp_exp,"serialno","serialno_old")
        renamefield(pp_exp,"pnum","pnum_old")
        renamefield(pp_exp,"ETHC","ETHC_old")
    except:
        print("did not alter fields")
        pass

    # PP Pop Gen
    for f in OrderedoutPPFields:
        ftype = "LONG"
        AddNewField(pp_exp, f, "LONG")
    AddNewField(pp_exp, "SERI_PNUM", "TEXT",field_length=30)

    AddNewField(pp_exp, "hhid_uni", "LONG")
    AddNewField(pp_exp, "hhinc_noadj","Long")
    # HH Pop Gen
    AddNewField(hh_exp, "hhid_uni", "LONG")

    # PP Sample
    AddNewField(pp_sample, "SERI_PNUM", "TEXT", field_length=30)

    # Specify Summary Dictionaries
    student_dict = {}
    hhworkers_dict = {}
    hhage_dict18 = {}
    hhage_dict65 = {}
    hh_newuid = {}

    # PP Sample
    # Create unique identifier, load summary dictionaries from PP Sample
    Ucursor, fieldlist = LoadUCursor(pp_sample)
    for row in Ucursor:
        # Create new serial / parcel number id
        seri = row[fieldlist.index('SERIALNO')]
        pnum = row[fieldlist.index('PNUM')]
        hhid = row[fieldlist.index('HHID')]

        SERI_PNUM = str(seri) + "_" + str(pnum)
        row[fieldlist.index('SERI_PNUM')] = SERI_PNUM

        # Load Household Summary Dictionaries
        # Define Student
        SchV = row[fieldlist.index('SCH')] if row[fieldlist.index('SCH')] is not None else 0
        Student = 1 if SchV > 1 else 0

        # SUM Total Students per Household
        if (hhid in student_dict and Student == 1):
            Student = Student + student_dict[hhid]
            student_dict[hhid] = Student
        elif Student == 1:
            student_dict[hhid] = Student

        # Define Worker
        # AGE & worked last week
        age = row[fieldlist.index('AGEP')]
        wrk = row[fieldlist.index('WRK')]
        Worker = 1 if (wrk == 1 and age < 65) else 0

        # Count Workers per Household
        if (hhid in hhworkers_dict and Worker == 1):
            Worker = Worker + hhworkers_dict[hhid]
            hhworkers_dict[hhid] = Worker
        elif Worker == 1:
            hhworkers_dict[hhid] = Worker

        # SUM household age under 18 and 65 or greater
        age18 = 1 if age < 18 else 0
        age65 = 1 if age > 64 else 0

        if (hhid in hhage_dict18 and age18 == 1):
            age18 = age18 + hhage_dict18[hhid]
        elif age18 == 1:
            hhage_dict18[hhid] = age18

        if (hhid in hhage_dict65 and age65 == 1):
            age65 = age65 + hhage_dict65[hhid]
        elif age65 == 1:
            hhage_dict65[hhid] = age65

        Ucursor.updateRow(row)
        # cleanup
    del fieldlist, row, Ucursor, seri, pnum, SERI_PNUM
    print("Created PP Sample UID - Complete at: %s minutes ---" % (
    round((time.time() - start_time) / 60, 1)))

    # Load Sample Tables into Dictionary <table,key>
    hh_tab_dict = make_attribute_dict(hh_sample,'HHID')
    senior_tab_dict = make_attribute_dict(hh_sample,'SID_Orig')
    gq_tab_dict = make_attribute_dict(gq_sample,'HHID')
    pp_tab_dict = make_attribute_dict(pp_sample,'SERI_PNUM')

    # Update Expanded Household table with new UID,
    #  load dictionary to join to Expanded Person File
    Ucursor, fieldlist = LoadUCursor(hh_exp)
    for row in Ucursor:
        hhid_uni = row[fieldlist.index('OBJECTID')]
        uid = row[fieldlist.index('unique_id')]

        row[fieldlist.index('hhid_uni')] = hhid_uni
        hh_newuid[uid] = hhid_uni

        Ucursor.updateRow(row)
        # cleanup
    del fieldlist, row, Ucursor
    print("Created Household UID - Complete at: %s minutes ---" % (
    round((time.time() - start_time) / 60, 1)))


    # Update Expanded Person Table with PP, HH & GQ Dictionaries
    print("Update Person Table - Start at: %s minutes ---" % (
    round((time.time() - start_time) / 60, 1)))
    Ucursor, fieldlist = LoadUCursor(pp_exp)
    checkcnt = 0
    listrecordids = []
    for row in Ucursor:
        key = row[fieldlist.index('serialno_old')]
        hhid = row[fieldlist.index('hhid')]
        SERI_PNUM = None
        unique_id = row[fieldlist.index('unique_id')]

        row[fieldlist.index('pnum')] = row[fieldlist.index('pnum_old')]

        #Create new Unique Household ID as serialno
        if unique_id in hh_newuid:
            new_serialno = hh_newuid[unique_id]
            row[fieldlist.index('serialno')] = new_serialno
            row[fieldlist.index('hhid_uni')] = new_serialno

        #defaults to be updated
        row[fieldlist.index('P18')] = 0
        row[fieldlist.index('P65')] = 0
        row[fieldlist.index('NSTUDENT')] = 0
        row[fieldlist.index('STUDENT')] = 0
        row[fieldlist.index('NWORKERS')] = 0
        row[fieldlist.index('NPF')] = 0
        row[fieldlist.index('HOURS')] = 0

        if key in hh_tab_dict:
            #Create new serial / parcel number id
            seri = hh_tab_dict[key]['SERIALNO']
            pnum = row[fieldlist.index('pnum')]
            SERI_PNUM = str(seri) + "_" + str(pnum)
            row[fieldlist.index('SERI_PNUM')] = SERI_PNUM

            #Set Household Values to Person file
            row[fieldlist.index('PERSONS')] = hh_tab_dict[key]['NP']
            row[fieldlist.index('TENURE')] = hh_tab_dict[key]['TEN']
            row[fieldlist.index('BLDGSZ')] = hh_tab_dict[key]['BLD']
            row[fieldlist.index('NPF')] = hh_tab_dict[key]['NPF']
            row[fieldlist.index('NOC')] = hh_tab_dict[key]['NOC']
            # Applying a cost of living conflation adjustment back to year 2000 dollars
            #  using converstion rate source: Weston Regional CPI - collected 7/18/18
            row[fieldlist.index('HINC')] = (((hh_tab_dict[key]['ADJINC'] * hh_tab_dict[key]['HINCP'])/1000000.0)*inflat_adjrt)
            # household income without conflation adjustment, for check only, field is not in final output.
            row[fieldlist.index('hhinc_noadj')] = (hh_tab_dict[key]['ADJINC'] * hh_tab_dict[key]['HINCP'])/1000000.0
            row[fieldlist.index('VEHICL')] = hh_tab_dict[key]['VEH']

        elif key in gq_tab_dict:
            #Create new serial / parcel number id
            seri = gq_tab_dict[key]['SERIALNO']
            pnum = row[fieldlist.index('pnum')]
            SERI_PNUM = str(seri) + "_" + str(pnum)
            row[fieldlist.index('SERI_PNUM')] = SERI_PNUM
            GQtype = gq_tab_dict[key]['GQtype']
            # Dorms
            if GQtype == 1:
                #Set Household Values to Person file
                row[fieldlist.index('PERSONS')] = 1
                row[fieldlist.index('TENURE')] = 0 #None for GQ
                row[fieldlist.index('BLDGSZ')] = 0 #None for GQ
                row[fieldlist.index('NPF')] = 0 #None for GQ
                row[fieldlist.index('NOC')] = 0 #None for GQ
                row[fieldlist.index('HINC')] = 0 #HINCP None for GQ
                row[fieldlist.index('VEHICL')] = 0 #None for GQ
            # Senior Facilities
            if GQtype == 2:
                #find original pums sample serial number
                SF_Key = gq_tab_dict[key]['SID_Orig']
                # Senior Facilities Persons, not taken from Group Quarters
                row[fieldlist.index('PERSONS')] = senior_tab_dict[SF_Key]['NP']   # 1 person hh avg = 1,      2 person hh avg = 2       Both = 1.572521
                row[fieldlist.index('TENURE')] = senior_tab_dict[SF_Key]['TEN']    # 1 person hh avg = 2,      2 person hh avg = 2       Both = 2
                row[fieldlist.index('BLDGSZ')] = senior_tab_dict[SF_Key]['BLD']    # 1 person hh avg = 3,      2 person hh avg = 2       Both = 3
                row[fieldlist.index('NPF')] = senior_tab_dict[SF_Key]['BLD']       # 1 person hh avg = 0,      2 person hh avg = 2       Both = 2
                row[fieldlist.index('NOC')] = senior_tab_dict[SF_Key]['BLD']       # 1 person hh avg = 0,      2 person hh avg = 0       Both = 0
                row[fieldlist.index('HINC')] = (((senior_tab_dict[SF_Key]['ADJINC'] * senior_tab_dict[SF_Key]['HINCP'])/1000000.0)*inflat_adjrt)  # 1 person hh avg = 45,483, 2 person hh avg = 89,040  Both = 71,724
                row[fieldlist.index('VEHICL')] = senior_tab_dict[SF_Key]['VEH']    # 1 person hh avg =     1,  2 person hh avg = 2       Both = 2

        else:
            checkcnt = checkcnt + 1
            listrecordids.append(key)

        row[fieldlist.index('EXFAC')] = 1
        row[fieldlist.index('co')] = row[fieldlist.index('county')]
        row[fieldlist.index('tr')] = row[fieldlist.index('tract')]

        if SERI_PNUM in pp_tab_dict:
            #Set Person Sample Values to Person file
            row[fieldlist.index('SEX')] = pp_tab_dict[SERI_PNUM]['SEX']

            # Populate Relationship
            RelV = pp_tab_dict[SERI_PNUM]['RELP']

            # Relate
            # 00 = .Reference person
            # 17 = .Noninstitutionalized group quarters population
            RelateV = RelV
            row[fieldlist.index('RELATE')] = RelateV

            # AGE & Hours
            age = pp_tab_dict[SERI_PNUM]['AGEP']
            hours = pp_tab_dict[SERI_PNUM]['WKHP'] if pp_tab_dict[SERI_PNUM]['WKHP'] is not None else 0
            row[fieldlist.index('AGE')] = age

            # Ethnicity - already categorized in Input PopGen Process
            # 1= ,2= ,3= ,4=
            ethnic = pp_tab_dict[SERI_PNUM]['ETHC']
            row[fieldlist.index('ETHC')] = ethnic

            # Populate Grade
            SchgV = pp_tab_dict[SERI_PNUM]['SCHG']
            GradeV = CalcGrade(SchgV)
            row[fieldlist.index('GRADE')] = GradeV

            # Populate hours, modify max college student work hours to 'part-time'
            if ((GradeV == 15 or GradeV == 16) and hours > 31):
                row[fieldlist.index('HOURS')] = 31
            else:
                row[fieldlist.index('HOURS')] = hours

            SchV = pp_tab_dict[SERI_PNUM]['SCH'] if pp_tab_dict[SERI_PNUM]['SCH'] is not None else 0
            Student = 1 if SchV > 1 else 0
            row[fieldlist.index('STUDENT')] = Student

            # Worker
            wrk = pp_tab_dict[SERI_PNUM]['WRK']
            Worker = 1 if (wrk == 1 and age < 65) else 0

            row[fieldlist.index('WORKER')] = Worker

        # Unload HH Summary Stats
        if hhid in student_dict:
            stud_sum = student_dict[hhid]
        else:
            stud_sum = 0
        if hhid in hhworkers_dict:
            wrkr_sum = hhworkers_dict[hhid]
        else:
            wrkr_sum = 0
        if hhid in hhage_dict18:
            ag18_sum = hhage_dict18[hhid]
        else:
            ag18_sum = 0
        if hhid in hhage_dict65:
            ag65_sum = hhage_dict65[hhid]
        else:
            ag65_sum = 0

        row[fieldlist.index('NSTUDENT')] = stud_sum
        row[fieldlist.index('NWORKERS')] = wrkr_sum
        row[fieldlist.index('P18')] = ag18_sum
        row[fieldlist.index('P65')] = ag65_sum

        # Populate Dorm Students
        dorm_student = 1 if key in gq_tab_dict else 0
        row[fieldlist.index('dorm')] = dorm_student

        Ucursor.updateRow(row)
    # cleanup
    del fieldlist, row, Ucursor
    print("Update PP Table from HH, PP & GQ Samples - Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    if checkcnt > 0:
        print("!!!WARNING!!!: %s records did not update in the PP Table" % checkcnt)
        print(listrecordids[0])
        print(listrecordids[-1])
        del listrecordids

    # Create output tables
    # Reorder, remove fields, & sort table
    print("Reorder Person Table")
    pp_exp_sort = os.path.join(workspace,"pp_exp_sort")
    arcpy.Sort_management(pp_exp,pp_exp_sort,[["hhid_uni","ASCENDING"],["pnum","ASCENDING"]])

    print("Create DBF Outputs: " + outfolder)
    pp_dbf = os.path.join(outfolder,exp_pp_name+'.dbf')
    hh_dbf = os.path.join(outfolder,exp_hh_name+'.dbf')
    #maketable(pp_exp_sort,pp_dbf,"",OrderedoutPPFields)
    maketable(pp_exp_sort, pp_dbf, "", "")
    maketable(hh_exp,hh_dbf)

    # This step is due to a maximum amount of records hard coded
    #  in the Allocation executable
    print("Create partial Pop files for Allocation Tool")
    pp_dbfh1 = os.path.join(outfolder,exp_pp_name+'h1.dbf')
    pp_dbfh2 = os.path.join(outfolder,exp_pp_name+'h2.dbf')
    wc_pp_h1 = ''' "tr" < 9105 '''
    wc_pp_h2 = ''' "tr" >= 9105 '''
    maketable(pp_exp_sort,pp_dbfh1,wc_pp_h1,OrderedoutPPFields)
    maketable(pp_exp_sort,pp_dbfh2,wc_pp_h2,OrderedoutPPFields)

    print("STEP 3 Process Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print("-----------------------------------")

    # Step 4: Run Allocation Tool
