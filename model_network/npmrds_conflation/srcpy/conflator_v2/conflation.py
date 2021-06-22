"""
Name:conflation.py
Purpose: creates "conflation" object for conflating true-shape data onto stick-ball links (e.g. SACSIM links)
        
          
Author: Darren Conly
Last Updated: Jun 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""
from time import perf_counter as perf
import datetime as dt

import pandas as pd
import arcpy

import segtypes
import utils


class conflation:
    def __init__(self, links_trueshp, links_stickball, workspace):
        self.links_stickball = links_stickball
        self.links_trueshp = links_trueshp

        arcpy.env.workspace = workspace
        self.workspace = workspace

        self.direcn_list = ["N","S","E","W"]
        self.searchdist_fwy = "500 Feet" #distance from model link midpoint that spatial join will use to search for matching TMCs.
        self.searchdist_art = "300 Feet" #distance from model link midpoint that spatial join will use to search for matching TMCs.

        self.outputph1_fc_fields = self.links_stickball.usefields
        self.output_ph1 = 'TEMP_outlinks_ph1' # will have conflation done for most links, but not for links that have "45s", like NE/SW/etc.
        self.fl_outout_ph1 = f'fl_{self.output_ph1}'
        
        
        self.sufx_tstamp = str(dt.datetime.now().strftime('%Y%m%d'))
        self.output_ph2 = f'conflation_sticktrue_{self.sufx_tstamp}' # name of final output



    def build_sql(self, fld_dirn, dirn, fld_funclass, funclasses):
        """ Build sql query to select links based on direction and whether its functional class corresponds to freeway or arterial """
        sql = f"{fld_dirn} = '{dirn}' AND {fld_funclass} IN {funclasses}"

        return sql

    def spatial_join_1(self, combined_link_pts_fc, fwy_tf, join_search_dist):
    
        temp_link_pts_fcs = []
        
        for direcn in self.direcn_list:  
            #define temporary outputs
            temp_output = "tempLinks_spJoin_{}".format(direcn)
            temp_link_pts_fcs.append(temp_output)
            
            #select model links in correct direction and capclasses; also make sure street model links don't accidentally match to freeway TMCs
            #NEED SYSTEM FOR IDENTIFYING "DIAGONALS", e.g., if TMC is N and model link is just barely different but tagged as W, still consider them a match.
            
            if fwy_tf:
                sql_tmcs = self.build_sql(self.links_trueshp.fld_dir_sign, direcn, 
                                        self.links_trueshp.fld_func_class, self.links_trueshp.funclass_fwys)
                sql_model_links = self.build_sql(self.links_stickball.fld_c_textdirn, direcn, 
                                        self.links_stickball.fld_func_class, self.links_stickball.funclass_fwys)
            else:
                sql_tmcs = self.build_sql(self.links_trueshp.fld_dir_sign, direcn, 
                                        self.links_trueshp.fld_func_class, self.links_trueshp.funclass_arts)
                sql_model_links = self.build_sql(self.links_stickball.fld_c_textdirn, direcn, 
                                        self.links_stickball.fld_func_class, self.links_stickball.funclass_arts) 
            
            print(sql_tmcs)
            print(sql_model_links)

            arcpy.SelectLayerByAttribute_management(self.links_stickball.fl_link_centroids, "NEW_SELECTION", sql_model_links)
            arcpy.SelectLayerByAttribute_management(self.links_trueshp.fl_in, "NEW_SELECTION", sql_tmcs)
            arcpy.SpatialJoin_analysis(self.links_stickball.fl_link_centroids, self.links_trueshp.fl_in, temp_output, "JOIN_ONE_TO_ONE",
                                    "KEEP_ALL","","CLOSEST", join_search_dist)
            
        arcpy.Merge_management(temp_link_pts_fcs, combined_link_pts_fc)

        for fc in temp_link_pts_fcs:
            arcpy.Delete_management(fc)

    def spatial_join_2(self):
        
        combined_linkpts_fwy = "temp_comb_fwy"
        combined_linkpts_art = "temp_comb_art"
        combined_linkpts_all = "temp_comb_pts"
        
        output_fc_pretrim = "TEMP_untrimmedLinkOutput"
        
        print("spatial joining for freeways...")
        self.spatial_join_1(combined_linkpts_fwy, fwy_tf=True, join_search_dist=self.searchdist_fwy)
        
        print("spatial joining for arterials...")
        self.spatial_join_1(combined_linkpts_art, fwy_tf=False, join_search_dist=self.searchdist_art)
        
        print("combining outputs...")
        arcpy.Merge_management([combined_linkpts_fwy, combined_linkpts_art], combined_linkpts_all)
        
        print("joining with links...")
        arcpy.AddJoin_management(self.links_stickball.fl_link_prj, self.links_stickball.fld_join, 
                                combined_linkpts_all, self.links_stickball.fld_join)
        #pdb.set_trace()
        arcpy.FeatureClassToFeatureClass_conversion(self.links_stickball.fl_link_prj, self.workspace, output_fc_pretrim)

        # after joining TMC attributes from stickball centroids to stickball links, export stickball links with selected fields rather than all fields.
        utils.shp2fc_sel_fields(output_fc_pretrim, self.output_fc_fields, self.output_ph1)
        
        
        
        for i in [combined_linkpts_fwy, combined_linkpts_art, combined_linkpts_all, output_fc_pretrim]:
            arcpy.Delete_management(i)

    def fix_diagonals(self):
        """ Initial conflated stick-ball network is lacking conflated data where the link is
        'between direction', e.g. NE, SW, etc.
        This function will identify and correct those segments. """

        angle_diff_tol = 10 # maximum number of degrees by which two links can differ to be considered going in same direction
        taggable_capclasses = self.links_stickball.funclass_fwys + self.links_stickball.funclass_arts
        
        # make feature layer from phase-1 output (output of spatial_join_2) so you can select and stuff with it.
        arcpy.MakeFeatureLayer_management(self.output_ph1, self.fl_outout_ph1)
        
        # Select all model links, that have stick-ball func classes that should've been tagged with true-shape data but weren't
        sql_diag_modlinks = f"{self.links_trueshp.fld_linkid} IS NULL AND {self.links_stickball.fld_func_class} IN {taggable_capclasses}"
        arcpy.SelectLayerByAttribute_management(self.fl_outout_ph1, "NEW_SELECTION", sql_diag_modlinks)
        
        fld_geom = "SHAPE@" # arcpy geometry class
        modlink_ucur_fields = [self.links_stickball.fld_func_class, self.links_stickball.fld_join,
                                self.links_stickball.fld_c_angle, self.links_trueshp.fld_linkid,
                                fld_geom]
        
        # return list of true/false flags indicating if each of the fields is in the output feature class from spatial_join_2()
        missing_fields = [fname for fname in modlink_ucur_fields if not utils.field_in_fc(fname, self.fl_outout_ph1)]

        if len(missing_fields) > 0:
            raise Exception(f"following fields are missing from the stick-ball layer: {missing_fields}")
        # import pdb; pdb.set_trace()
        
        
        with arcpy.da.UpdateCursor(self.fl_outout_ph1, modlink_ucur_fields, sql_diag_modlinks) as ucur:
            
            for row in ucur:
                st = perf()
                
                # Get link direction and road cat
                capc = row[modlink_ucur_fields.index(self.links_stickball.fld_func_class)]
                modlink_angle = row[modlink_ucur_fields.index(self.links_stickball.fld_c_angle)]
                modlink_geom = row[modlink_ucur_fields.index(fld_geom)]
                modlink_a_b = row[modlink_ucur_fields.index(self.links_stickball.fld_join)]
                
                # Get the centroid of the model link
                modlink_centr = modlink_geom.centroid
                centr_geom = arcpy.Geometry('point', modlink_centr, self.links_stickball.sref) # need to convert to geometry to allow select-by-location

                # check if the direction of the link is ambiguous (e.g. between north and east, between south and west, etc.)
                not_ambiguous_dir = modlink_angle < 40 and modlink_angle > 50 \
                                    and modlink_angle > -140 and modlink_angle < -130 \
                                    and modlink_angle > -40 and modlink_angle < -30 \
                                    and modlink_angle < 130 and modlink_angle > 140
                if not_ambiguous_dir: continue
                
                # Select all true shapes that are within search distance of stickball link's centroid,
                if capc in self.links_stickball.funclass_fwys: # if the stickball link is a freeway link, select all freeway true shapes within distance
                    arcpy.SelectLayerByLocation_management(self.links_trueshp.fl_trueshps, "WITHIN_A_DISTANCE", 
                                                        centr_geom, self.searchdist_fwy,
                                                        "NEW_SELECTION")
                    sql_fwytype = f"{self.links_trueshp.fld_func_class} IN {self.links_trueshp.funclass_fwys}"
                    arcpy.SelectLayerByAttribute_management(self.links_trueshp.fl_trueshps, "SUBSET_SELECTION", sql_fwytype)
                elif capc in self.links_stickball.funclass_arts:
                    arcpy.SelectLayerByLocation_management(self.links_trueshp.fl_trueshps, "WITHIN_A_DISTANCE", 
                                                        centr_geom, self.searchdist_art,
                                                        "NEW_SELECTION")
                    sql_notfwytype = f"{self.links_trueshp.fld_func_class} IN {self.links_trueshp.funclass_arts}"
                    arcpy.SelectLayerByAttribute_management(self.links_trueshp.fl_trueshps, "SUBSET_SELECTION", sql_notfwytype)    
                else:
                    continue # if the stickball link's func class (capclass for model links) is not a freeway or arterial, then we don't want to conflate.
                            # So move on to next link           
                    
                # Then subselect again for TMC that has cardinal angle that is < X degrees different from the model link's angle
                
                trueshp_samedir = [] # list of TMCs that have close direction to the model link being considered.
                flds_trueshp = [self.links_trueshp.fld_linkid, self.links_trueshp.fld_rdname, self.links_trueshp.fld_dir_sign, 
                            self.links_trueshp.fld_func_class, self.links_trueshp.seg_len, fld_geom]

                with arcpy.da.SearchCursor(self.links_trueshp.fl_trueshps, flds_trueshp) as cur:
                    for trueshp_row in cur:
                        
                        trueshp = trueshp_row[flds_trueshp.index(self.links_trueshp.fld_linkid)]
                        trueshplen = trueshp_row[flds_trueshp.index(self.links_trueshp.seg_len)]
                        
                        trueshp_geom = trueshp_row[flds_trueshp.index(fld_geom)]
                        trueshp_angle = utils.get_angle(trueshp_geom)
                        
                        dist_to_linkcentr =  trueshp_geom.distanceTo(centr_geom) # distance from model link centroid to closest point of TMC
                        # dist_to_linkcentr2 = get_nearest_distance(tmc_geom, centr_geom)
                        
                        if abs(modlink_angle - trueshp_angle) < angle_diff_tol:
                            trueshp_samedir.append((trueshp, trueshplen, dist_to_linkcentr))
                
                # for testing only
                # if len(tmcs_samedir) > 1:
                #     import pdb; pdb.set_trace()
                # else: continue
            
                # if no TMCs are nearby, same direction, and same road type, then skip and go to the next row in the model link file
                if len(trueshp_samedir) < 1:
                    continue
                
                
                # make dataframe of TMCs that are nearby, same direction, and same road type
                df_col_dist = 'distance' # distance from TMC to the model link centroid
                
                # get TMC(s) that are closest to the model link's centroid
                df_himatch = pd.DataFrame.from_records(trueshp_samedir, columns=[self.links_trueshp.fld_linkid, self.links_trueshp.seg_len, df_col_dist])
                df_himatch = df_himatch.loc[df_himatch[df_col_dist] == df_himatch[df_col_dist].min()]
                
                # if more than 1 TMC ties for being closest to the model link centroid, then choose the one with longer length
                # sometimes you get > 1 because of overlapping TMCs.
                if df_himatch.shape[0] > 1:
                    df_himatch = df_himatch.loc[df_himatch[self.links_trueshp.seg_len] == df_himatch[self.links_trueshp.seg_len].max()]
                    
                # if still more than 1 TMC ties for being closest, and both TMCs are same length, then raise an error.
                if df_himatch.shape[0] > 1:
                    tmcs = [i for i in df_himatch[self.links_trueshp.fld_linkid]]
                    raise Exception(f"TMCs {tmcs} are same length and both match as being the closest to model link {modlink_a_b}." \
                                    f"\nYou must review the GIS layers and figure out which of these TMCs you want to match to the model link.")
                        
                # return the TMC id of the TMC that is same direction, same road type, and closest to the centroid of the model link.
                # this will be the TMC whose info you conflate to the model link.
                closest_tmc = df_himatch.iloc[0][self.links_trueshp.fld_linkid]
                
                # Set the model link's TMC value to be closest_tmc
                row[modlink_ucur_fields.index(self.links_trueshp.fld_linkid)] = closest_tmc
                ucur.updateRow(row)
                
                elapsed = perf() - st
                print(f"updated link {modlink_a_b} in {elapsed} seconds")

    