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
        self.sufx_tstamp = str(dt.datetime.now().strftime('%Y%m%d'))
        self.fc_output_final = f'conflation_sticktrue_{self.sufx_tstamp}' # name of final output
        self.fl_output_final = f'fl_{self.fc_output_final}'


        # road types
        self.fwys = 'freeways'
        self.arterials = 'arterials'
        self.ramps = 'ramps'

    def build_sql(self, fld_dirn, dirn, fld_funclass, funclasses):
        """ Build sql query to select links based on direction and whether its functional class corresponds to freeway or arterial """
        sql = f"{fld_dirn} = '{dirn}' AND {fld_funclass} IN {funclasses}"

        return sql

    def spatial_join_1(self, combined_link_pts_fc, road_type, join_search_dist):
    
        temp_link_pts_fcs = []
        
        for direcn in self.direcn_list:  
            #define temporary outputs
            temp_output = "tempLinks_spJoin_{}".format(direcn)

            if arcpy.Exists(temp_output): arcpy.Delete_management(temp_output)

            temp_link_pts_fcs.append(temp_output)
            
            #select model links in correct direction and capclasses; also make sure street model links don't accidentally match to freeway TMCs
            #NEED SYSTEM FOR IDENTIFYING "DIAGONALS", e.g., if TMC is N and model link is just barely different but tagged as W, still consider them a match.
            
            if road_type == self.fwys:
                sql_trueshps = self.build_sql(self.links_trueshp.fld_dir_sign, direcn, 
                                        self.links_trueshp.fld_func_class, self.links_trueshp.funclass_fwys)
                sql_model_links = self.build_sql(self.links_stickball.fld_c_textdirn, direcn, 
                                        self.links_stickball.fld_func_class, self.links_stickball.funclass_fwys)
            elif road_type == self.arterials:
                sql_trueshps = self.build_sql(self.links_trueshp.fld_dir_sign, direcn, 
                                        self.links_trueshp.fld_func_class, self.links_trueshp.funclass_arts)
                sql_model_links = self.build_sql(self.links_stickball.fld_c_textdirn, direcn, 
                                        self.links_stickball.fld_func_class, self.links_stickball.funclass_arts) 
            elif road_type == self.ramps:
                pass # need to add decision point for handling ramps. Would be good to get conflation at least for on ramps, if not freeway ramps as well.
            else:
                pass

            # import pdb; pdb.set_trace()

            arcpy.SelectLayerByAttribute_management(self.links_stickball.fl_link_centroids, "NEW_SELECTION", sql_model_links)
            arcpy.SelectLayerByAttribute_management(self.links_trueshp.fl_in, "NEW_SELECTION", sql_trueshps)
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

        for lyr in [combined_linkpts_fwy, combined_linkpts_art, 
        combined_linkpts_all, output_fc_pretrim]:
            if arcpy.Exists(lyr): arcpy.Delete_management(lyr)
        
        print("spatial joining for freeways...")
        self.spatial_join_1(combined_linkpts_fwy, road_type=self.fwys, join_search_dist=self.searchdist_fwy)
        
        print("spatial joining for arterials...")
        self.spatial_join_1(combined_linkpts_art, road_type=self.arterials, join_search_dist=self.searchdist_art)
        
        print("combining outputs...")
        arcpy.Merge_management([combined_linkpts_fwy, combined_linkpts_art], combined_linkpts_all)
        
        print("joining with links...")
        
        arcpy.AddJoin_management(self.links_stickball.fl_link_prj, self.links_stickball.fld_join, 
                                combined_linkpts_all, self.links_stickball.fld_join)
        
        arcpy.FeatureClassToFeatureClass_conversion(self.links_stickball.fl_link_prj, self.workspace, output_fc_pretrim)

        # after joining TMC attributes from stickball centroids to stickball links, export stickball links with selected fields rather than all fields.
        trimmed_out_fields = self.links_stickball.usefields + self.links_trueshp.usefields
        # temp_out_fields = [f.name for f in arcpy.ListFields(output_fc_pretrim) if f.name != 'Shape']
        utils.shp2fc_sel_fields(self.workspace, output_fc_pretrim, trimmed_out_fields, self.fc_output_final)
        
        
        for i in [combined_linkpts_fwy, combined_linkpts_art, combined_linkpts_all, output_fc_pretrim]:
            arcpy.Delete_management(i)

    def fix_diagonals(self):
        """ Initial conflated stick-ball network is lacking conflated data where the link is
        'between direction', e.g. NE, SW, etc.
        This function will identify and correct those segments by checking direction based on cardinal angle, rather
        than by coarser N/S/E/W flag.
        
        This process is meant to run AFTER doing flag-based tagging, because it is significantly slower and we want to limit how
        many rows it must run on. Takes about 0.4sec per row."""

        print("filling in data for ambiguous angles")

        angle_diff_tol = 10 # maximum number of degrees by which two links can differ to be considered going in same direction
        self.taggable_capclasses = self.links_stickball.funclass_fwys + self.links_stickball.funclass_arts

        # make feature layer from phase-1 output (output of spatial_join_2) so you can select and stuff with it.
        if arcpy.Exists(self.fl_output_final): arcpy.Delete_management(self.fl_output_final)
        arcpy.MakeFeatureLayer_management(self.fc_output_final, self.fl_output_final)
        
        # Select all model links, that have stick-ball func classes that should've been tagged with true-shape data but weren't
        sql_taggable_sblinks = f"{self.links_trueshp.fld_linkid} IS NULL AND {self.links_stickball.fld_func_class} IN {self.taggable_capclasses}"
        arcpy.SelectLayerByAttribute_management(self.fl_output_final, "NEW_SELECTION", sql_taggable_sblinks)
        
        
        modlink_ucur_fields = [self.links_stickball.fld_func_class, self.links_stickball.fld_join,
                                self.links_stickball.fld_c_angle, self.links_trueshp.fld_linkid]
        
        # return list of true/false flags indicating if each of the fields is in the output feature class from spatial_join_2()
        missing_fields = [fname for fname in modlink_ucur_fields if not utils.field_in_fc(fname, self.fl_output_final)]

        if len(missing_fields) > 0:
            raise Exception(f"following fields are missing from the stick-ball layer: {missing_fields}")
        

        fld_geom = "SHAPE@" # arcpy geometry class
        modlink_ucur_fields.append(fld_geom)
        
        st = perf()
        link_cnt = 0 # counter for how many links get data added to them
        links_to_process = arcpy.GetCount_management(self.fl_output_final)
        with arcpy.da.UpdateCursor(self.fl_output_final, modlink_ucur_fields, sql_taggable_sblinks) as ucur:
            
            for row in ucur:
                # Get link direction and road cat
                capc = row[modlink_ucur_fields.index(self.links_stickball.fld_func_class)]
                modlink_angle = row[modlink_ucur_fields.index(self.links_stickball.fld_c_angle)]
                modlink_geom = row[modlink_ucur_fields.index(fld_geom)]
                modlink_a_b = row[modlink_ucur_fields.index(self.links_stickball.fld_join)]
                
                # Get the centroid of the model link
                modlink_centr = modlink_geom.centroid
                centr_geom = arcpy.Geometry('point', modlink_centr, self.links_stickball.sref) # need to convert to geometry to allow select-by-location

                # FROM VERSION 2 AND TRYING TO OMIT IN VERSION 3
                # check if the direction of the link is ambiguous (e.g. between north and east, between south and west, etc.)
                # must not near 45 degrees (NW) and not near -135 degrees (SW) and not near -45 degrees (SE) and not near 135 degrees (NE)
                # not_ambiguous_dir = (modlink_angle < 40 or modlink_angle > 50) \
                #                     and (modlink_angle < -140 or modlink_angle > -130) \
                #                     and (modlink_angle < -50 or modlink_angle > -40) \
                #                     and (modlink_angle < 130 or modlink_angle > 140) 
                
                # if not_ambiguous_dir: continue # FOR CONFLATOR VERSION 3 consdier NOT limiting the filling in to "ambiguous" directions and check ALL links without TMC data

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
                            self.links_trueshp.fld_func_class, self.links_trueshp.fld_seg_len, fld_geom]

                with arcpy.da.SearchCursor(self.links_trueshp.fl_trueshps, flds_trueshp) as cur:
                    for trueshp_row in cur:
                        
                        trueshp = trueshp_row[flds_trueshp.index(self.links_trueshp.fld_linkid)]
                        trueshplen = trueshp_row[flds_trueshp.index(self.links_trueshp.fld_seg_len)]
                        
                        trueshp_geom = trueshp_row[flds_trueshp.index(fld_geom)]
                        trueshp_angle = utils.get_angle(trueshp_geom)
                        
                        dist_to_linkcentr =  trueshp_geom.distanceTo(centr_geom) # distance from model link centroid to closest point of TMC
                        # dist_to_linkcentr2 = get_nearest_distance(tmc_geom, centr_geom)
                        
                        if abs(modlink_angle - trueshp_angle) < angle_diff_tol:
                            trueshp_samedir.append((trueshp, trueshplen, dist_to_linkcentr))
            
                # if no TMCs are nearby, same direction, and same road type, then skip and go to the next row in the model link file
                if len(trueshp_samedir) < 1:
                    continue
                
                # make dataframe of TMCs that are nearby, same direction, and same road type
                df_col_dist = 'distance' # distance from TMC to the model link centroid
                
                # get TMC(s) that are closest to the model link's centroid
                df_himatch = pd.DataFrame.from_records(trueshp_samedir, columns=[self.links_trueshp.fld_linkid, self.links_trueshp.fld_seg_len, df_col_dist])
                df_himatch = df_himatch.loc[df_himatch[df_col_dist] == df_himatch[df_col_dist].min()]
                
                # if more than 1 TMC ties for being closest to the model link centroid, then choose the one with longer length
                # sometimes you get > 1 because of overlapping TMCs.
                if df_himatch.shape[0] > 1:
                    df_himatch = df_himatch.loc[df_himatch[self.links_trueshp.fld_seg_len] == df_himatch[self.links_trueshp.fld_seg_len].max()]
                    
                # if still more than 1 TMC ties for being closest, and both TMCs are same length, then raise an error.
                if df_himatch.shape[0] > 1:
                    trueshps = [i for i in df_himatch[self.links_trueshp.fld_linkid]]
                    raise Exception(f"TMCs {trueshps} are same length and both match as being the closest to model link {modlink_a_b}." \
                                    f"\nYou must review the GIS layers and figure out which of these TMCs you want to match to the model link.")
                        
                # return the TMC id of the TMC that is same direction, same road type, and closest to the centroid of the model link.
                # this will be the TMC whose info you conflate to the model link.
                closest_trueshp = df_himatch.iloc[0][self.links_trueshp.fld_linkid]
                
                # Set the model link's TMC value to be closest_trueshp
                row[modlink_ucur_fields.index(self.links_trueshp.fld_linkid)] = closest_trueshp
                ucur.updateRow(row)

                link_cnt += 1

                if link_cnt % 1000 == 0:
                    print(f"\t{link_cnt} of {links_to_process} leftover links tagged with true-shape data")
        elapsed = round((perf() - st) / 60, 2)
        print(f"successfully added true-shape data to {link_cnt} links with ambiguous directions (e.g. NE) in {elapsed} mins." \
            f"\nOutput feature class is {self.fc_output_final}")

    def conflate_curvy_sections(self):
        """ Placeholder method for conflating where there is a stick-ball link that is not going the same direction
        as a true shape but should still be tagged to it, because the true-shap is curvy and the stick-ball link
        only traverses part of the curve (e.g. parts along River Rd. south of Sacramento). """
        pass

    def conflation_cleanup(self):
        """ Clean out unneeded feature classes """
        stuff_to_delete = [self.links_stickball.fc_link_centroids, self.links_stickball.fc_link_prj,
                            ]
        print(f"Deleting temp files {stuff_to_delete}...")
        for fc in stuff_to_delete:
            arcpy.Delete_management(fc)


    def conflation_summary(self):
        """ Provide user with printed summary of outputs """
        arcpy.SelectLayerByAttribute_management(self.fl_output_final, "CLEAR_SELECTION")
        total_links = int(arcpy.GetCount_management(self.fl_output_final)[0])

        sql_tot_taggable_links = f"{self.links_stickball.fld_func_class} IN {self.taggable_capclasses}"
        sql_tagged_links = f"{self.links_trueshp.fld_linkid} IS NOT NULL AND {self.links_stickball.fld_func_class} IN {self.taggable_capclasses}"

        arcpy.SelectLayerByAttribute_management(self.fl_output_final, "NEW_SELECTION", sql_tot_taggable_links)
        taggable_links = int(arcpy.GetCount_management(self.fl_output_final)[0])

        arcpy.SelectLayerByAttribute_management(self.fl_output_final, "SUBSET_SELECTION", sql_tagged_links)
        tagged_links = int(arcpy.GetCount_management(self.fl_output_final)[0])

        pct_tagged = round((tagged_links / taggable_links) * 100)

        summary_msg = f"""
        OUTPUT SUMMARY:\n
        * Output file location: {self.workspace}
        * Output feature class name: {self.fc_output_final}
        * Total stick-ball network links in output: {total_links}
        * Stick-ball network links eligible for true-shape tag (i.e., real roads): {taggable_links}
        * Stick-ball network links with true-shape data tagged to them: {tagged_links} 
        * Share of taggable links tagged: {pct_tagged}%
        """

        print(summary_msg)

    