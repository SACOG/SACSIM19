#--------------------------------
# Name: TAZupdate_SACSIM_inputs.py
# Purpose: Update all SACSIM input files with new TAZ's added.
#           Developed for conversion of SACSIM19 TAZ strucutre to SACSIM23
#           Updates files: tazrad07.txt, _raw_parcel.txt, _raw_household.txt, _taz.dbf, daysim/worker_ixxifractions.dat, daysim/sacog_taz_indexes.dat
#
# Issues: DBF file not generating in correct column order, needs to be updated before running SACSIM. (11/7)
#
# Author: Kyle Shipley
# Created: 11/7/2021 (v1)
# Version 1: Does not include Spaital work, done in GIS before running script.
# Update - TBD
# Copyright:   (c) SACOG
# ArcGIS Version:   Pro
# Python Version:   3.6
#--------------------------------

import os,sys, arcpy,fileinput,time,csv,datetime
import numpy as np
import pandas as pd
import geopandas as gpd
import fiona
fiona.supported_drivers
from shutil import copyfile

now = datetime.datetime.now()
start_time = time.time()
print(now.strftime("%Y-%m-%d %H:%M"))


 #Field Names
key_infile = "PARCELID"
key_joinfile = "PARCELID"
OldTAZ = "TAZ07"
NewTAZ = "TAZ21"


def convert_to_pandas_df(table):
    # Get a list of field names to display
    field_names = [i.name for i in arcpy.ListFields(table) if i.type != 'OID']
    # Open a cursor to extract results from stats table
    cursor = arcpy.da.SearchCursor(table, field_names)
    # Create a pandas dataframe to display results
    df = pd.DataFrame(data=[row for row in cursor],
                          columns=field_names)
    print("created pandas df")
    return df

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

#Insert Update DA Cursor with indexed fields,
#  include of addional fields to add.
def LoadUCursor(fc,flist=None):
    """Important note: Function creates two outputs, also only opens cursor,
     no "with" function to automatically close,
      remeber to delete cursor and fieldlist when finished"""
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

def build_index(filename, sort_col):
    index = []
    f = open(filename)
    while True:
        offset = f.tell()
        line = f.readline()
        if not line:
            break
        length = len(line)
        col = line.split('\t')[sort_col].strip()
        index.append((col, offset, length))
    f.close()
    index.sort()
    return index

def print_sorted(filename, col_sort):
    index = build_index(filename, col_sort)
    f = open(filename)
    for col, offset, length in index:
        f.seek(offset)
        print(f.read(length).rstrip('\n'))


def update_textfiles(text,replaceDict,columnkeynum,sort_colnum):

    for line in fileinput.input(text, inplace=True,backup='.bak'):
        line = line.rstrip()
        linelist = line.split(',')
        parc = -1
        tz = -1
        try:
            parc = int(linelist[columnkeynum])
            tz = int(linelist[sort_colnum])
            tzstr = ',' + str(tz) + ','
        except:
            pass
        if not line:
            continue
        if parc in replaceDict:
            newtzstr = (','+str(replaceDict[parc])+',')
            line = line.replace(tzstr,newtzstr)
        print(line)
    print("Updated: ")

    # Sort file remaining in text form
    """for now removed since no sorting need on parcel and hh files. May need if new hh or parcels are added"""
    #print_sorted(text, sort_col)
    #print("Sorted: ")

def new_textfile_RAD(outtxt,TAZL,D,G,k1,v3,v4):
    ZoneList = G + TAZL
    with open(outtxt, 'w') as f:
        for item in ZoneList:
            if item in G:
                f.write(str(item) + ' ' + '97' + ' ' + str(v3) + ' ' + str(v4) + '\n')
            else:
                f.write(str(item) + ' ' + str(D[item][k1]) + ' ' + str(v3) + ' ' + str(v4) + '\n')

    print("created new Rad file")

def new_textfile_ixfrac(outtxt,TAZL,D,G,k1,k2):
    ZoneList = TAZL
    with open(outtxt, 'w') as f:
        for item in ZoneList:
                f.write(str(item) + ' ' + str(D[item][k1]) + ' ' + str(D[item][k2]) + '\n')

    print("created new ixfrac file")

def new_textfile_tazindx(outtxt,TAZL,D,G):
    ZoneList = G + TAZL
    with open(outtxt, 'w') as f:
        f.write('Zone_id Zone_ordinal Dest_eligible External' + '\n')
        for item in ZoneList:
            if item in G:
                f.write(str(item) + ' ' + str(item) + ' ' + str(0) + ' ' + str(1) + '\n')
            else:
                f.write(str(item) + ' ' + str(item) + ' ' + str(1) + ' ' + str(0) + '\n')

    print("created new tazindx file")

def new_dbffile_taz(fc,outpathfile,fckey):
    TAZ_shp = outpathfile + '.dbf'
    TAZ_shp2 = outpathfile + '2.shp'
    TAZ_csv = outpathfile + '.csv'
    KeepFields = [fckey,]
    maketable(fc, TAZ_shp, "", KeepFields)

    OrderedoutParcelFields = [
    'TAZ21',	'AUTACC',
     'AUTEGR',	'PRKCOST',
     'DAVIS',	'PEDENV',
     'PUMA',	'RAD',
     'XCORD',	'YCORD',
     'PKNRCOST',	'SQFT_Z',
     'XPRKCOST']
    #fckey: 'TAZ'
    dffull = convert_to_pandas_df(fc)
    print(dffull.head(3))
    dffull.rename(columns={
                            'PUMA_1': 'PUMA',
                         'NewRADNum': 'RAD',
                         'SQFT_ZTAZ21': 'SQFT_Z'
                         }, inplace=True)
    print("renamed")
    dfout = dffull[OrderedoutParcelFields]
    #dfout = dfout.reindex(columns=OrderedoutParcelFields)

    #Join to existing shapefile
    gdf_ex = gpd.read_file((TAZ_shp))
    print(gdf_ex.columns)
    print(gdf_ex.head(3))
    #gdf_ex = gdf_ex[[fckey]]
    print("Load Existing Shapefile: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print(gdf_ex.columns)
    print(gdf_ex.head(3))
    print(dfout.columns)
    print(dfout.head(3))

    dfout.to_csv(TAZ_csv)

    gdf_ex2 = gdf_ex.merge(dfout,how='left',on=fckey)
    print(gdf_ex2.columns)
    print(gdf_ex2.head(3))
    #use projection from input shapefile
    #prj_file = TAZ_shp.replace(".shp", ".prj")
    #prj = [l.strip() for l in open(prj_file, 'r')][0]

    #https://stackoverflow.com/questions/51688660/geopandas-to-file-gives-wrong-column
    #gdf_ex.to_file(driver='ESRI Shapefile', filename=TAZ_shp) #, crs_wkt=prj
    schema = gpd.io.file.infer_schema(gdf_ex2)
    schema['properties']['TAZ21'] = 'int:18'
    schema['properties']['XCORD'] = 'int:18'
    schema['properties']['YCORD'] = 'int:18'

    gdf_ex2.to_file(filename=TAZ_shp2,schema=schema)

    print("Append to Shapefile: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
    print('dbf complete!')

############################################


def do_analysis(TAZinfc,scn_parcelfc,key_pcl,oldTAZ,newTAZ,Gateways,inScenario,p,
                UpdateParcel,UpdateHH,Update_TAZRad,Update_IXFrac,Update_TAZIndx,Update_TAZDBF):

    try:
        start_time = time.time()

        #build input paths
        modelpath = os.path.dirname(inScenario)
        daysimpath = os.path.join(modelpath, 'daysim')
        out_d = 'new_scenario'

        # names
        hhfname = p + '_raw_household.txt'
        parcelfname = p + '_raw_parcel.txt'
        # raw file parcel and hh hearders
        hhcol = 0 #[0]
        parcol = 0 #[0]
        tazfname = p + '_taz'
        tazradfname = 'tazrad07.txt'

        taz_indexfname = 'sacog_taz_indexes.dat'
        workerixxifname = 'worker_ixxifractions.dat'

        # relative input paths
        hhpathfile = os.path.join(inScenario, hhfname)
        parcelpathfile = os.path.join(inScenario, parcelfname)

        tazpathfile = os.path.join(inScenario, tazfname)
        tazradpathfile = os.path.join(inScenario, tazradfname)

        taz_indexpathfile = os.path.join(daysimpath, taz_indexfname)
        workerixxpathfile = os.path.join(daysimpath, workerixxifname)

        #make copies of inputs to new directory

        out_dpath = os.path.join(modelpath, out_d)
        try:
            os.makedirs(out_dpath,exist_ok = True)
            print("Directory '%s' created successfully" % out_d)
        except OSError as error:
            print("Directory '%s' can not be created" % out_d)

        outhhpathfile = os.path.join(out_dpath, hhfname)
        outparcelpathfile = os.path.join(out_dpath, parcelfname)

        outtazpathfile = os.path.join(out_dpath, tazfname)
        outtazradpathfile = os.path.join(out_dpath, tazradfname)

        outtaz_indexpathfile = os.path.join(out_dpath, taz_indexfname)
        outworkerixxpathfile = os.path.join(out_dpath, workerixxifname)

        #copy files
        hh_new = copyfile(hhpathfile, outhhpathfile)
        parcel_new = copyfile(parcelpathfile, outparcelpathfile)
        arcpy.AddMessage("Copied Files Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

        #build correspondence dictionary between old & new TAZ
            #for now feature class (potentially build in spatial steps here later on)

        arcpy.AddMessage("Start 'lookup' Process: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
        #Create Dictionary from join feature
        #1 Create dictionary between old and new TAZ using parcel id
        ParcelJoinDict = {}
        SCursor, fieldlist = LoadSCursor(scn_parcelfc)
        for row in SCursor:
            key = row[fieldlist.index(key_pcl)]
            UpdateValue = row[fieldlist.index(newTAZ)]
            ParcelJoinDict[key] = UpdateValue
        del fieldlist, row, SCursor
        arcpy.AddMessage("Lookup Process 1 Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

        #2 Create list and dictionary of new TAZ and necessary gis associated fields
        NewTAZList = []
        NewTAZDict = {}

        #fields - may add as user specified input
        F_RAD = 'NewRADNum'
        F_Worker_IXFrac = 'Worker_IXFrac'
        F_Jobs_XIFrac = 'Jobs_XIFrac'

        #Create Dictionary from join feature
        SCursor, fieldlist = LoadSCursor(TAZinfc)
        for row in SCursor:
            key = row[fieldlist.index(newTAZ)]

            #list all new values needed for TAZ update into SACSIM?
            RADVal = row[fieldlist.index(F_RAD)]
            Worker_IXFracVal = row[fieldlist.index(F_Worker_IXFrac)]
            Jobs_XIFracVal =  row[fieldlist.index(F_Jobs_XIFrac)]

            NewTAZDict[key] = [RADVal,Worker_IXFracVal,Jobs_XIFracVal]

            NewTAZList.append(key)

        del fieldlist, row, SCursor
        arcpy.AddMessage("Lookup Process 2 Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
        NewTAZList.sort()
        print("TAZlist sorted")

        #update user input files
        #update using parcel ID lookup
        if UpdateParcel:
            update_textfiles(parcel_new, ParcelJoinDict,0,4)
            arcpy.AddMessage("Update parcel file with new TAZ Complete: %s minutes ---" % (
                round((time.time() - start_time) / 60, 1)))

        if UpdateHH:
            update_textfiles(hh_new, ParcelJoinDict,15,16)
            arcpy.AddMessage("Update household file with new TAZ Complete: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

        if Update_TAZRad:
            new_textfile_RAD(outtazradpathfile,NewTAZList,NewTAZDict,Gateways,0,100,100)

        if Update_IXFrac:
            new_textfile_ixfrac(outworkerixxpathfile,NewTAZList,NewTAZDict,Gateways,1,2)

        if Update_TAZIndx:
            new_textfile_tazindx(outtaz_indexpathfile,NewTAZList,NewTAZDict,Gateways)

        if Update_TAZDBF:
            new_dbffile_taz(TAZinfc,outtazpathfile,newTAZ)

        arcpy.AddMessage("Done!: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))

    except arcpy.ExecuteError:
        arcpy.AddMessage(arcpy.GetMessages(2))
    except Exception as e:
        arcpy.AddMessage(e.args[0])
        tb = sys.exc_info()[2]
        arcpy.AddMessage("An error occured on line %i" % tb.tb_lineno)
        arcpy.AddMessage(str(e))


# Main Script
if __name__ == '__main__':
    """
    Goal is to update all SACSIM input files for TAZ update

    # Inputs:
    1. User inputs model run folder directory
    2. User inputs New TAZ's boundary file
        must include:
    3. User inputs parcel file with TAZ correspondence
        must include:
    # Outputs:
        new_scenario folder with new files:
         tazrad07.txt, _raw_parcel.txt, _raw_household.txt, _taz.dbf, daysim/worker_ixxifractions.dat, daysi
    """

    # Arguments are optional
    #argv = tuple(arcpy.GetParameterAsText(i)
    #    for i in range(arcpy.GetArgumentCount()))
    #do_count_analysis(*argv)

    #New TAZ boundary file
    """
    Note: Currently assumes user has created the following fields:
    
    
    """
    NewTAZ_lkupfc = r'Q:\SACSIM23\TAZ updates\Update_SACSIM_input_files\working.gdb\TAZ21_v3_3_w07WrkFracIX_wpuma'

    #Parcel file with old and new TAZs
    """
    Note: currently assumes spatial join to add new TAZ number at parcel level is done and the following fields exist:
    
    """
    scenario_parcelfc = r'Q:\SACSIM23\TAZ updates\Update_SACSIM_input_files\working.gdb\PARCEL_MTP2020_wnewTAZ_int'

    newTAZ = "TAZ21"
    oldTAZ = "TAZ07"
    scn_key_parcel_id = "PARCELID" #parcel ID
    GatewayList = [1,2,3,4,5,6,7,8,9,13,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30] #will need to update if adding new gateways

    #path of existing scearnio folder, a new folder will be created with outputs in directory
    UserModelScenario = r'Q:\SACSIM23\TAZ updates\Update_SACSIM_input_files\SACSIM19_35\SACSIM19.02.01_2035_baseline_newScript\scenario_runfolder'
    prefix = '2016'

    #change to false if update is not needed
    UpdateParcel = True
    UpdateHH = True
    Update_TAZRad = True
    Update_IXFrac = True
    Update_TAZIndx = True
    Update_TAZDBF = True

    do_analysis(NewTAZ_lkupfc,scenario_parcelfc,scn_key_parcel_id,oldTAZ,newTAZ,GatewayList,UserModelScenario,prefix,
                UpdateParcel,UpdateHH,Update_TAZRad,Update_IXFrac,Update_TAZIndx,Update_TAZDBF)

