"""
#--------------------------------
# Name: conflation_NPMRDS_to_model_latest.py
# Purpose: conflate TMC attributes on to model links. 
#          
#           
# Author: Darren Conly
# Last Updated: 7/30/2019
# Updated by: <name>
# Copyright:   (c) SACOG
# Python Version: 3+
#--------------------------------
"""
import os
import math
import arcpy
from datetime import datetime as dt

arcpy.env.overwriteOutput = True
arcpy.env.qualifiedFieldNames = False

time_stamp = dt.now().strftime("%m%d%Y_%H%M")

start_time = dt.now()

#takes in FC and copies to output with user-selected subset of fields
def shp2fc_sel_fields(in_shp, field_list, out_temp_fc):
    field_maps = arcpy.FieldMappings()
    
    for field in field_list:
        vars()[field] = arcpy.FieldMap() #vars() 
        vars()[field].addInputField(in_shp, field)
        field_maps.addFieldMap(vars()[field])
        
    arcpy.FeatureClassToFeatureClass_conversion(in_shp, workspace, out_temp_fc, "", field_maps)

# Check if a field in a feature class field exists and return true it does, false if not.
def field_exists(fc, fieldname):
    fieldList = arcpy.ListFields(fc, fieldname)
    fieldCount = len(fieldList)
    if (fieldCount >= 1):  # If there is one or more of this field return true
        return True
    else:
        return False

#given angle in degrees, categorize as cardinal N/S/E/W direction
def get_card_dir(dir_angle): #0 degrees is straight east, not north
    if dir_angle >= -45 and dir_angle < 45:
        link_angle = "E"
    elif dir_angle >= 45 and dir_angle < 135:
        link_angle = "N"
    elif dir_angle >= 135 or dir_angle < -135:
        link_angle = "W"
    elif dir_angle >= -135 and dir_angle < -45:
        link_angle = "S"
    else:
        link_angle = "unknown"
    
    return link_angle

#add angle and direction fields to input links
def add_angle_data(link_fc, link_angle_field):
    #add field for cardinal angle
    if field_exists(link_fc,link_angle_field):
        print("field {} already exists. Overwriting...".format(link_angle_field))
    else:
        arcpy.AddField_management(link_fc, link_angle_field, "FLOAT")
    
    if field_exists(link_fc,modl_dirn_field):
        print("field {} already exists. Overwriting...".format(modl_dirn_field))
    else:
        arcpy.AddField_management(link_fc, modl_dirn_field, "TEXT", "", "",10)
        
    fields = [field.name for field in arcpy.ListFields(link_fc)]
    shape_field = "SHAPE@"
    fields.append(shape_field)
    
    counter = 0
    print("adding directional fields to model network links...")
    with arcpy.da.UpdateCursor(link_fc,fields) as link_uc:
        for row in link_uc:
            counter += 1
            start_lat = row[fields.index("SHAPE@")].firstPoint.Y
            start_lon = row[fields.index("SHAPE@")].firstPoint.X
            end_lat = row[fields.index("SHAPE@")].lastPoint.Y
            end_lon = row[fields.index("SHAPE@")].lastPoint.X
            
            xdiff = end_lon - start_lon
            ydiff = end_lat - start_lat
            link_angle = math.degrees(math.atan2(ydiff,xdiff))
            card_dir = get_card_dir(link_angle)
            row[fields.index(link_angle_field)] = link_angle
            row[fields.index(modl_dirn_field)] = card_dir
            
            link_uc.updateRow(row)
    
    print("Added directional data to {} model links.\n".format(counter))
    
def spatial_join_1(in_link_pts_fc, in_tmc_fc, combined_link_pts_fc, modl_dirn_field, tmc_dir_field, direcn_list, 
                       fwy_tf, capclass_field, tmc_class_field, join_search_dist):
    
    temp_link_pts_fcs = []
    
    for direcn in direcn_list:  
        
        in_linkpts_fl = "in_linkpts_fl"
        in_tmc_fl = "in_tmc_fl"
        
        arcpy.MakeFeatureLayer_management(in_link_pts_fc, in_linkpts_fl)
        arcpy.MakeFeatureLayer_management(in_tmc_fc, in_tmc_fl)
        
        #define temporary outputs
        temp_output = "tempLinks_spJoin_{}".format(direcn)
        temp_link_pts_fcs.append(temp_output)
        
        #select model links in correct direction and capclasses; also make sure street model links don't accidentally snap to freeway TMCs
        if fwy_tf:
            sql_tmcs = "{} = '{}' AND {} IN {}".format(tmc_dir_field, direcn, tmc_class_field, tmc_fwys)
            sql_model_links = "{} IN {} AND {} = '{}'".format(capclass_field, capclasses_fwy, modl_dirn_field, direcn)
        else:
            sql_tmcs = "{} = '{}' AND {} NOT IN {}".format(tmc_dir_field, direcn, tmc_class_field, tmc_fwys)
            sql_model_links = "{} IN {} AND {} = '{}'".format(capclass_field, capclasses_art, modl_dirn_field, direcn)   
        
        arcpy.SelectLayerByAttribute_management(in_linkpts_fl, "NEW_SELECTION", sql_model_links)
        arcpy.SelectLayerByAttribute_management(in_tmc_fl, "NEW_SELECTION", sql_tmcs)
        arcpy.SpatialJoin_analysis(in_linkpts_fl, in_tmc_fl, temp_output, "JOIN_ONE_TO_ONE",
                                   "KEEP_ALL","","CLOSEST", join_search_dist)
        
    arcpy.Merge_management(temp_link_pts_fcs, combined_link_pts_fc)
    
    for fc in temp_link_pts_fcs:
        arcpy.Delete_management(fc)
        
def spatial_join_2(link_pts_fc_in, link_fc_in, final_output_fc):
    link_fl_in = "link_fl_in"
    arcpy.MakeFeatureLayer_management(link_fc_in, link_fl_in)
    
    combined_linkpts_fwy = "temp_comb_fwy"
    combined_linkpts_art = "temp_comb_art"
    combined_linkpts_all = "temp_comb_pts"
    
    output_fc_pretrim = "TEMP_untrimmedLinkOutput"
    
    direcn_list = ["N","S","E","W"]
    
    print("spatial joining for freeways...")
    spatial_join_1(link_pts_fc_in, tmc_fc_in, combined_linkpts_fwy, modl_dirn_field, tmc_dir_field, direcn_list, 
                       True, capclass_field, tmc_class_field, join_search_dist_fwy)
    
    print("spatial joining for arterials...")
    spatial_join_1(link_pts_fc_in, tmc_fc_in, combined_linkpts_art, modl_dirn_field, tmc_dir_field, direcn_list, 
                       False, capclass_field, tmc_class_field, join_search_dist_art)
    
    print("combining outputs...")
    arcpy.Merge_management([combined_linkpts_fwy, combined_linkpts_art], combined_linkpts_all)
    
    print("joining with links...")
    arcpy.AddJoin_management(link_fl_in, link_join_field, combined_linkpts_all, link_join_field)
    #pdb.set_trace()
    arcpy.FeatureClassToFeatureClass_conversion(link_fl_in, workspace, output_fc_pretrim)
    shp2fc_sel_fields(output_fc_pretrim, output_field_list, final_output_fc)
    
    for i in [combined_linkpts_fwy, combined_linkpts_art, combined_linkpts_all, output_fc_pretrim]:
        arcpy.Delete_management(i)
    
def conflation_process(link_shp_in, tmc_fc_in, output_link_fc, link_angle_field, link_field_list):
    
    link_fc_in = "TEMP_modelLink{}".format(time_stamp)
    temp_link_pts = "TEMP_modelLinkPoints{}".format(time_stamp)
    temp_link_pts_trimmed = "TEMP_modelLinkPointsTrim{}".format(time_stamp)
    
    #convert lines to centroid points
    arcpy.CopyFeatures_management(link_shp_in, link_fc_in)
    
    #add cardinal direction data to links
    add_angle_data(link_fc_in, link_angle_field)
    
    #convert model links to points that will be joined to TMCs based on closest distance, capclass, and direction
    arcpy.FeatureToPoint_management(link_fc_in, temp_link_pts)

    #trim down the points so that they don't have all the master net columns
    shp2fc_sel_fields(temp_link_pts, link_field_list, temp_link_pts_trimmed)
    
    #free up space
    arcpy.Delete_management(temp_link_pts)
    
    #spatial join TMC attributes to temporary points representing model link centroids,
    #then use A_B key to join those points back to model link line features, then
    #output as final output_link_fc
    spatial_join_2(temp_link_pts_trimmed, link_fc_in, output_link_fc)
    
    #clean up
    for i in [link_fc_in, temp_link_pts_trimmed]:
        arcpy.Delete_management(i)                

#============================SCRIPT ENTRY POINT=================================
if __name__=='__main__':
    workspace = r'P:\NPMRDS data\NPMRDS_GIS\scratch.gdb'
    arcpy.env.workspace = workspace
    
    sref = arcpy.SpatialReference(2226) #SACOG CRS
    arcpy.env.outputCoordinateSystem = sref
    
    #model network link parameters--get model link as SHP from Cube export
    link_shp_dir = r"Q:\SACSIM19\2020MTP\highway\network update\NetworkGIS\SHP\Link"
    link_shp_in = "masterSM19ProjCoding_Link08122019.shp" #must have same projection/CRS as source layer--NEXT STEP IS TO SPECIFY FIELD MAPPINGS
    node_a_field = "A"
    node_b_field = "B"
    capclass_field = "CAPC17" #in theory, the capclass year should sync with the TMC issue year
    ff_speed_field = "SPD17"
    capclasses_fwy = (1,2) 
    capclasses_art = (3,4,5,12,22,24) #includes all arterials and rural roads; excludes ramps
    
    #cardinal angle for model net links
    modl_dirn_field = "ModelTxtDir"
    link_angle_field = "c_angle"
    link_join_field = "{}_{}".format(node_a_field, node_b_field)
    
    link_field_list = [node_a_field, node_b_field, link_join_field, "NAME", 
                       "DISTANCE", "RAD", ff_speed_field, capclass_field, modl_dirn_field,
                       link_angle_field] #model link fields to include


    #TMC network parameters
    tmc_fc_in = "TMCs_2017" #initially TMCs_conflBase_2017_2
    tmc_year = 2017
    #tmc_incl_fields = ["Tmc","RoadNumber","RoadName","Direction","County"] #only used if somehow Transfer Attributes becomes useable.
    tmc_dir_field = "Direction"
    tmc_class_field = "F_System"
    tmc_fwys = (1,2) #based on TMC F_System value. need to specify so arterial model links don't tag to freeway TMCs, and vice-versa
    
    
    join_search_dist_fwy = "500 Feet" #distance from model link midpoint that spatial join will use to search for matching TMCs.
    join_search_dist_art = "300 Feet" #distance from model link midpoint that spatial join will use to search for matching TMCs.


    output_field_list = link_field_list + ['Tmc', 'RoadNumber', 'County', 'Direction', 'F_System']
    output_link_fc = "model_{}TMC_confl{}".format(tmc_year,time_stamp)
    
    link_shp_in = os.path.join(link_shp_dir, link_shp_in)
    
    conflation_process(link_shp_in, tmc_fc_in, output_link_fc, link_angle_field, link_field_list)
    
    
    time_elapsed = dt.now() - start_time
    run_time_mins = round(time_elapsed.total_seconds()/60,1)
    
    print("\nScript successfully completed in {} mins! \n\n" \
          "Be sure to manually inspect conflation and check for errors. In particular: \n" \
          "*Model links whose midpoint is outside the search distance from TMCs \n" \
          "*Model links whose calculated cardinal direction doesn't match TMC direction \n" \
          "*Model links with capacity class of 2, which get counted as freeways even if they are arterials \n" \
          "*Model links with significantly (>20mph or so) free-flow speed difference from NPMRDS free-flow".format(run_time_mins))
    
    