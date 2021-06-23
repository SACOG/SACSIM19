"""
Name:segtypes.py
Purpose: classifying types of inputs for process to conflate "stick-ball" lines to true-shape lines
        
          
Author: Darren Conly
Last Updated: Jun 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""
# %%
import os
import math
from time import perf_counter as perf

import arcpy
arcpy.overwriteOutput = True

import utils


def field_exists(fc, fieldname):
    fieldList = arcpy.ListFields(fc, fieldname)
    fieldCount = len(fieldList)
    if (fieldCount >= 1):  # If there is one or more of this field return true
        return True
    else:
        return False

class line_segs:
    """General class for all input line types"""
    def __init__(self, workspace, fc_in, fld_func_class=None, funclass_fwys=None, 
                funclass_arts=None, fld_rdname=None):
        self.fc_in = fc_in # file path for input feature class
        self.workspace = workspace
        arcpy.env.workspace = workspace

        self.fld_rdname = fld_rdname # field for road name

        self.fld_func_class = fld_func_class # field for functional class, used to define fwy vs. arterial
        self.funclass_fwys = funclass_fwys # func classes corresponding to freeways
        self.funclass_arts = funclass_arts # func classes corresponding to arterials

        self.fld_c_angle = "c_angle" # field for cardinal angle in degrees
        self.fld_c_textdirn = "c_textdirn" # field for cardinal angle as N/S/E/W string


        # make feature layer from input feature class
        # import pdb; pdb.set_trace()
        fl_in = os.path.splitext(os.path.basename(self.fc_in))[0]
        self.fl_in = f"fl_{fl_in}"

        if arcpy.Exists(self.fl_in): arcpy.Delete_management(self.fl_in)
        arcpy.MakeFeatureLayer_management(self.fc_in, self.fl_in)


    def add_angle_data(self):
        """add field containing the cardinal angle for the line, in degrees"""

        fld_text_dirn = ''

        if field_exists(self.fc_in, self.fld_c_angle):
            print("field {} already exists. Overwriting...".format(self.fld_c_angle))
        else:
            arcpy.AddField_management(self.fc_in, self.fld_c_angle, "FLOAT")
        
        if field_exists(self.fc_in, self.fld_c_textdirn):
            print("field {} already exists. Overwriting...".format(self.fld_c_textdirn))
        else:
            arcpy.AddField_management(self.fc_in, self.fld_c_textdirn, "TEXT", "", "", 10)
            
        fields = [field.name for field in arcpy.ListFields(self.fc_in)]
        shape_field = "SHAPE@"
        fields.append(shape_field)
        
        counter = 0
        print("adding directional fields to model network links...")
        with arcpy.da.UpdateCursor(self.fc_in,fields) as link_uc:
            for row in link_uc:
                counter += 1
                linegeom = row[fields.index(shape_field)]
                link_angle = utils.get_angle(linegeom)
                card_dir = self.get_card_dir(link_angle)
                row[fields.index(self.fld_c_angle)] = link_angle
                row[fields.index(self.fld_c_textdirn)] = card_dir
                
                link_uc.updateRow(row)
        
        print("Added directional data to {} model links.\n".format(counter))

    def get_card_dir(self, dir_angle): 
        """
        Given a line's cardinal angle in degrees, return N/S/E/W direction.
        0 degrees is straight east, not north.
        """
        
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




class stickBall(line_segs):
    """class specific to the input stick-ball network"""
    def __init__(self, workspace, fc_in, fld_func_class, funclass_fwys, funclass_arts, fld_rdname, 
                extra_fields=[], make_copy_w_projn=True, add_dirn_data=True):

        # inheriting stuff from parent class
        super().__init__(workspace, fc_in, fld_func_class, funclass_fwys, funclass_arts,
                fld_rdname='NAME') 
        self.fld_anode = 'A'
        self.fld_bnode = 'B'
        self.fld_join = 'A_B' # used for joining link centroids back to link lines
        
        self.usefields = [self.fld_anode, self.fld_bnode, self.fld_join,
                        self.fld_func_class, self.fld_rdname, self.fld_c_angle, 
                        self.fld_c_textdirn] + extra_fields

        # will be copy of input link file, but projected to specified CRS
        # Needed because Cube NET files usually don't have projection
        self.fc_link_prj = "TEMP_link_prj" 
        self.fc_link_centroids = "TEMP_link_centroids"

        # add angle data to stick-ball links
        if add_dirn_data:
            self.add_angle_data()

        self.sref = arcpy.SpatialReference(2226)

        
        if make_copy_w_projn:
            self.make_linkcopy_prj()
            

        self.make_link_centroids()

    def make_linkcopy_prj(self):
        """ Make make temporary copy of input links with desired fields using a projection,
        rather than "unknown" projection that Cube  spits out """
        arcpy.env.outputCoordinateSystem = self.sref

        utils.shp2fc_sel_fields(self.workspace, self.fc_in, self.usefields, self.fc_link_prj)

        # then make a feature layer out of it
        self.fl_link_prj = f"fl_{self.fc_link_prj}"
        if arcpy.Exists(self.fl_link_prj): arcpy.Delete_management(self.fl_link_prj)
        arcpy.MakeFeatureLayer_management(self.fc_link_prj, self.fl_link_prj)

    def make_link_centroids(self):
        """ Make temporary feature class of points
        representing center point of links """
        #convert model links to points that will be joined to TMCs based on closest distance, capclass, and direction
        if arcpy.Exists(self.fc_link_centroids): arcpy.Delete_management(self.fc_link_centroids)
        arcpy.FeatureToPoint_management(self.fc_link_prj, self.fc_link_centroids)
        self.fl_link_centroids = f"fl_{self.fc_link_centroids}"

        if arcpy.Exists(self.fl_link_centroids): arcpy.Delete_management(self.fl_link_centroids)
        arcpy.MakeFeatureLayer_management(self.fc_link_centroids, self.fl_link_centroids)


class trueShape(line_segs):
    """class specific to the input true-shape network"""
    def __init__(self, workspace, fc_in, fld_linkid, fld_dir_sign, fld_func_class, 
                funclass_fwys, funclass_arts, fld_rdname, fld_link_len,
                extra_fields=None):
         # inheriting stuff from parent class
        super().__init__(workspace, fc_in, fld_func_class, funclass_fwys, funclass_arts,
                fld_rdname)     
        
        self.fld_seg_len = fld_link_len
        self.fld_linkid = fld_linkid # unique ID for each true-shape segment (e.g. TMC code for Inrix files)
        self.fld_dir_sign = fld_dir_sign # field that has signed direction (eg. direction shown on road signs)
        self.fld_rdname = fld_rdname
        self.fld_func_class = fld_func_class

        self.usefields = [self.fld_linkid, self.fld_rdname, self.fld_func_class, self.fld_dir_sign,
        self.fld_seg_len] + extra_fields

        self.fl_trueshps = f"fl_trueshps"

        if arcpy.Exists(self.fl_trueshps): arcpy.Delete_management(self.fl_trueshps)
        arcpy.MakeFeatureLayer_management(self.fc_in, self.fl_trueshps)

        # if no directional data supplied with true-shape, then add it based on cardinal angle
        if self.fld_dir_sign is None:
            self.add_angle_data()
            self.fld_dir_sign = self.fld_c_textdirn



if __name__ == '__main__':
    pass
    # arcpy.env.workspace = r"Q:\SACSIM23\network_update\SACSIM23NetUpdate\SACSIM23NetUpdate.gdb"
    # test_model_lnk = r"Q:\SACSIM19\2020MTP\highway\network update\NetworkGIS\SHP\Link\masterSM19ProjCoding_10022020.shp"

    
    # sbt = stickBall(test_model_lnk, extra_fields=['SACTRAK','CAPC20'])
    # print(sbt.make_prj_link())


    # # %%
    # dir(sbt)
