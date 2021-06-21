"""
Name: fix_diagonals.py
Purpose: The main conflation script, conflation_NPMRDS_to_model.py, has trouble
    tagging TMC attributes on "diagonal" roads that travel NE, SE, NW, SW, because
    in many cases, the angle for the model link will, by a small margin, for example, be N
    but the TMC angle will be W. 
    
    This script aims to correct those instances by comparing the angles of the TMC and model link
    If the angle is less than X degrees (need to test to see what good threshold is),
    then say they are the same direction even if their N/S/E/W tags do not match.
    
    OPTION for speeding stuff up: just select links whose angles are in the "ranges of ambiguity"i.e., the c_angle is:
        * >40 and <50 (N v. E)
        * >-140 and <-130 (S v. W)
        * >-40 and <-30 (S v. E)
        * >130 and <140 (N v. W)
        
          
Author: Darren Conly
Last Updated: May 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import math
import json
from time import perf_counter as perf

import arcpy
import pandas as pd

    

def field_in_fc(fname, fc_to_check):
    fc_fields = [f.name for f in arcpy.ListFields(fc_to_check)]
    
    return fname in fc_fields

def get_nearest_distance(line_geom, pt_geom):
    '''returns distance between a point feature and the point on a line that is 
    closest to the point feature
    
    line_geom = ESRI line geometry object
    pt_geom = ESRI point geometry object
    
    '''
    
    line_json = json.loads(line_geom.JSON)
    line_ptlist = line_json['paths'][0] # list of [x, y pairs]
    
    
    pt_json = json.loads(pt_geom.JSON)
    
    pt_x = pt_json['x']
    pt_y = pt_json['y']
    
    dists = [] # list of distances between the reference point and each point within the line
    
    for linept in line_ptlist:
        lpx = linept[0]
        lpy = linept[1]
        
        # pythagorean distance ((x1 - x2)^2 + (y1 - y2)^2)^0.5
        dist = ((lpx - pt_x)**2 + (lpy - pt_y)**2)**0.5
        dists.append(dist)
        
    mindist = min(dists)
    
    return mindist



def fix_diagonals(in_modlink_fc, in_tmc_fc):
    
    sref_modlinks = arcpy.Describe(in_modlink_fc).spatialReference
    
    fl_modlinks = 'fl_modlinks'
    fl_tmcs = 'fl_tmcs'
    
    if not arcpy.Exists(fl_modlinks): arcpy.MakeFeatureLayer_management(in_modlink_fc, fl_modlinks)
    if not arcpy.Exists(fl_tmcs): arcpy.MakeFeatureLayer_management(in_tmc_fc, fl_tmcs)
    
    # model link fc fields to use
    fld_cangle_modlink = 'c_angle'
    fld_a_b = 'A_B'
    fld_capc = 'CAPC17'
    taggable_capclasses = (1,2,3,4,5,12,22,24)
    capcs_fwy = (1,2)
    
    # tmc fc fields to use
    fld_tmc = 'tmc'
    fld_rte_num = 'route_numb'
    fld_dir = 'direction_card'
    fld_fsys = 'f_system'
    fld_tmclen = 'miles'
    
    fsys_fwys = (1,2)
    
    search_dist_fwy = "500 Feet"
    search_dist_art = "300 Feet"
    angle_diff_tol = 10 # maximum number of degrees by which two links can differ to be considered going in same direction
    
    
    # Select all model links, that have capclass that should've been tagged but did not get TMC tag
    sql_diag_modlinks = f"{fld_tmc} IS NULL AND {fld_capc} IN {taggable_capclasses}"
    # arcpy.SelectLayerByAttribute_management(fl_modlinks, "NEW_SELECTION", sql_diag_modlinks)
    
    fld_geom = "SHAPE@" # https://pro.arcgis.com/en/pro-app/latest/arcpy/classes/geometry.htm
    
    
    modlink_ucur_fields = [fld_capc, fld_a_b, fld_cangle_modlink, fld_tmc, fld_rte_num,
                           fld_dir, fld_fsys, fld_geom]
    
    field_check = [field_in_fc(fname, in_modlink_fc) for fname in modlink_ucur_fields]
    # import pdb; pdb.set_trace()
    
    
    with arcpy.da.UpdateCursor(fl_modlinks, modlink_ucur_fields, sql_diag_modlinks) as ucur:
        
        for row in ucur:
            st = perf()
            
            # Get link direction and road cat
            capc = row[modlink_ucur_fields.index(fld_capc)]
            modlink_angle = row[modlink_ucur_fields.index(fld_cangle_modlink)]
            modlink_geom = row[modlink_ucur_fields.index(fld_geom)]
            modlink_a_b = row[modlink_ucur_fields.index(fld_a_b)]
            
            # Get the centroid of the model link
            modlink_centr = modlink_geom.centroid
            centr_geom = arcpy.Geometry('point', modlink_centr, sref_modlinks) # need to convert to geometry to allow select-by-location
            centr_x = modlink_centr.X
            centr_y = modlink_centr.Y
            
            # if there is no ambig
            is_ambiguous_dir =  modlink_angle > 40 and modlink_angle < 50 \
                                and modlink_angle > -140 and modlink_angle < -130 \
                                and modlink_angle > -40 and modlink_angle < -30 \
                                and modlink_angle > 130 and modlink_angle < 140
            if is_ambiguous_dir: continue
            
            # Select all TMCs that are within search distance,
            if capc in capcs_fwy:
                arcpy.SelectLayerByLocation_management(fl_tmcs, "WITHIN_A_DISTANCE", 
                                                       centr_geom, search_dist_fwy,
                                                       "NEW_SELECTION")
                sql_fwytype = f"{fld_fsys} IN {fsys_fwys}"
                arcpy.SelectLayerByAttribute_management(fl_tmcs, "SUBSET_SELECTION", sql_fwytype)
            else:
                arcpy.SelectLayerByLocation_management(fl_tmcs, "WITHIN_A_DISTANCE", 
                                                       centr_geom, search_dist_art,
                                                       "NEW_SELECTION")
                sql_notfwytype = f"{fld_fsys} NOT IN {fsys_fwys}"
                arcpy.SelectLayerByAttribute_management(fl_tmcs, "SUBSET_SELECTION", sql_notfwytype)               
                
                
                
            # Then subselect again for TMC that has cardinal angle that is < X degrees different from the model link's angle
            
            tmcs_samedir = [] # list of TMCs that have close direction to the model link being considered.
            flds_tmc = [fld_tmc, fld_rte_num, fld_dir, fld_fsys, fld_tmclen, fld_geom]
            with arcpy.da.SearchCursor(fl_tmcs, flds_tmc) as cur:
                for tmcrow in cur:
                    
                    tmc = tmcrow[flds_tmc.index(fld_tmc)]
                    tmclen = tmcrow[flds_tmc.index(fld_tmclen)]
                    rtnum = tmcrow[flds_tmc.index(fld_rte_num)]
                    tmcdir = tmcrow[flds_tmc.index(fld_dir)]
                    tmc_fsys = tmcrow[flds_tmc.index(fld_fsys)]
                    
                    tmc_geom = tmcrow[flds_tmc.index(fld_geom)]
                    start_lat = tmc_geom.firstPoint.Y
                    start_lon = tmc_geom.firstPoint.X
                    end_lat = tmc_geom.lastPoint.Y
                    end_lon = tmc_geom.lastPoint.X
                    #print(start_lat, start_lon, end_lat, end_lon)
                    
                    xdiff = end_lon - start_lon
                    ydiff = end_lat - start_lat
                    tmc_angle = math.degrees(math.atan2(ydiff,xdiff))   
                    
                    dist_to_linkcentr =  tmc_geom.distanceTo(centr_geom) # distance from model link centroid to closest point of TMC
                    # dist_to_linkcentr2 = get_nearest_distance(tmc_geom, centr_geom)
                    
                    if abs(modlink_angle - tmc_angle) < angle_diff_tol:
                        tmcs_samedir.append((tmc, tmclen, dist_to_linkcentr))
                    
                    # tmc_info = {fld_tmc: tmc, fld_rte_num: rtnum, fld_dir: tmcdir,
                    #             fld_fsys: tmc_fsys, }
            
            # for testing only
            # if len(tmcs_samedir) > 1:
            #     import pdb; pdb.set_trace()
            # else: continue
        
            # if no TMCs are nearby, same direction, and same road type, then skip and go to the next row in the model link file
            if len(tmcs_samedir) < 1:
                continue
            
            
            # make dataframe of TMCs that are nearby, same direction, and same road type
            df_col_tmc = 'tmc'
            df_col_tmclen = 'tmcmi' # length of TMC
            df_col_dist = 'distance' # distance from TMC to the model link centroid
            
            # get TMC(s) that are closest to the model link's centroid
            df_himatch = pd.DataFrame.from_records(tmcs_samedir, columns=[df_col_tmc, df_col_tmclen, df_col_dist])
            df_himatch = df_himatch.loc[df_himatch[df_col_dist] == df_himatch[df_col_dist].min()]
            
            # if more than 1 TMC ties for being closest to the model link centroid, then choose the one with longer length
            # sometimes you get > 1 because of overlapping TMCs.
            if df_himatch.shape[0] > 1:
                df_himatch = df_himatch.loc[df_himatch[df_col_tmclen] == df_himatch[df_col_tmclen].max()]
                
            # if still more than 1 TMC ties for being closest, and both TMCs are same length, then raise an error.
            if df_himatch.shape[0] > 1:
                tmcs = [i for i in df_himatch[df_col_tmc]]
                raise Exception(f"TMCs {tmcs} are same length and both match as being the closest to model link {modlink_a_b}." \
                                f"\nYou must review the GIS layers and figure out which of these TMCs you want to match to the model link.")
                    
            # return the TMC id of the TMC that is same direction, same road type, and closest to the centroid of the model link.
            # this will be the TMC whose info you conflate to the model link.
            closest_tmc = df_himatch.iloc[0][df_col_tmc]
            
            # Set the model link's TMC value to be closest_tmc
            row[modlink_ucur_fields.index(fld_tmc)] = closest_tmc
            ucur.updateRow(row)
            
            elapsed = perf() - st
            print(f"updated link {modlink_a_b} in {elapsed} seconds")


            
            
    
"""
Possible "post process" to fix diagonals		
1	Select all model links, in the resulting output file, that have capclass that should've been tagged but did not get TMC tag	
2	Run updateCursor on them. For each untagged link:	
	Get link direction and road cat	
	Get the centroid of the model link	
	Select all TMCs that meet following criteria:	
		Are within max search distance of the centroid
		Have same road cat as the model link
		Have a cardinal angle that is < X degrees different from the model link's angle
	If no TMCs match this criteria, return None and continue to next link--means there's no TMC match.	
	If there are TMCs that meet the matching criteria, get the TMC that is also closest to the centroid (this is the TMC you want to tag)	
	Update the record for the model link to reflect all of the needed TMC attributes.	
"""




if __name__ == '__main__':
    # feature class of model links created by conflation_NPMRDS_to_model.py. Many links conflated okay but diagonals did not.
    in_fc = r'P:\NPMRDS data\NPMRDS_GIS\scratch.gdb\model_2018TMC_confl20210429_0904'
    
    # TMC feature class whose attributes you want to tag
    input_tmc_fc = r'P:\NPMRDS data\NPMRDS_GIS\scratch.gdb\TMCs_AllRegn_2018'
    
    
    fix_diagonals(in_fc, input_tmc_fc)