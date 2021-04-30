"""
Name: fix_diagonals.py
Purpose: The main conflation script, conflation_NPMRDS_to_model.py, has trouble
    tagging TMC attributes on "diagonal" roads that travel NE, SE, NW, SW, because
    in many cases, the angle for the model link will, by a small margin, for example, be N
    but the TMC angle will be W. 
    
    This script aims to correct those instances by comparing the angles of the TMC and model link
    If the angle is less than X degrees (need to test to see what good threshold is),
    then say they are the same direction even if their N/S/E/W tags do not match.
        
          
Author: Darren Conly
Last Updated: May 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import math
import json

import arcpy
    

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
    
    with arcpy.da.UpdateCursor(fl_modlinks, modlink_ucur_fields, sql_diag_modlinks) as ucur:
        for row in ucur:
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
            
            # Select all TMCs that are within search distance,
            if capc in capcs_fwy:
                arcpy.SelectLayerByLocation_management(fl_tmcs, "WITHIN_A_DISTANCE", 
                                                       centr_geom, search_dist_fwy,
                                                       "NEW_SELECTION")
                sql_fwytype = f"{fld_fsys} IN {fsys_fwys}"
                arcpy.SelectLayerByAttribute_management(fl_tmcs, "SUBSET_SELECTION")
            else:
                arcpy.SelectLayerByLocation_management(fl_tmcs, "WITHIN_A_DISTANCE", 
                                                       centr_geom, search_dist_art,
                                                       "NEW_SELECTION")
                sql_fwytype = f"{fld_fsys} NOT IN {fsys_fwys}"
                arcpy.SelectLayerByAttribute_management(fl_tmcs, "SUBSET_SELECTION")               
                
                
                
            # Then subselect again for TMC that has cardinal angle that is < X degrees different from the model link's angle
            
            tmcs_samedir = [] # list of TMCs that have close direction to the model link being considered.
            flds_tmc = [fld_tmc, fld_rte_num, fld_dir, fld_fsys, fld_geom]
            with arcpy.da.SearchCursor(fl_tmcs, flds_tmc) as cur:
                for tmcrow in cur:
                    
                    tmc = tmcrow[flds_tmc.index(fld_tmc)]
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
                        tmcs_samedir.append({tmc: dist_to_linkcentr})
                    
                    # tmc_info = {fld_tmc: tmc, fld_rte_num: rtnum, fld_dir: tmcdir,
                    #             fld_fsys: tmc_fsys, }
            
            if len(tmcs_samedir) > 1:
                import pdb; pdb.set_trace()
            else: continue
            # if no TMCs are nearby, same direction, and same road type, then skip and go to the next row in the model link file
            if len(tmcs_samedir) < 1:
                continue
            
            # re-run selection on the TMC layer to only fetch TMCs that are nearby, same direction, and same road type
            tmcs_hi_match = tuple(tmcs_samedir)
            sql_get_match_tmcs = f"{fld_tmc} IN {tmcs_hi_match}"
            arcpy.SelectLayerByAttribute_management(fl_tmcs, "NEW_SELECTION", tmcs_hi_match)
            
            # Then subselect, if necessary, to get the TMC closes to the centroid point
            # if more than 1 TMC ties for closest, choose the TMC where IsPrimary = 1
            if int(arcpy.GetCount_management(fl_tmcs)[0]) > 1:
                   arcpy.Near_analysis(centr_geom, "CLOSEST",
                                                          "SUBSET_SELECTION",
                                                          )
                
            

            
            
    
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