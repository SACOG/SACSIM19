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

class lineSegs:
    """General class for all input line types"""
    def __init__(self, workspace=None, fc_in=None, fld_func_class=None, funclass_fwys=None, 
                funclass_arts=None, fld_rdname=None, extra_fields=[]):
        self.fc_in = fc_in # file path for input feature class
        self.workspace = workspace
        arcpy.env.workspace = workspace

        self.fld_rdname = fld_rdname # field for road name

        self.fld_func_class = fld_func_class # field for functional class, used to define fwy vs. arterial



        self.funclass_fwys = tuple(funclass_fwys) # func classes corresponding to freeways; need to tuple-ize for SQL syntax
        self.funclass_arts = tuple(funclass_arts) # func classes corresponding to arterials; need to tuple-ize for SQL syntax

        self.extra_fields = extra_fields

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
        print(f"adding directional fields to {self.fc_in}...")
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




class stickBall(lineSegs):
    """class specific to the input stick-ball network"""
    def __init__(self, make_copy_w_projn=True, 
                add_dirn_data=True, **lineseg_args):

        # inheriting stuff from parent class
        super().__init__(**lineseg_args)

        self.fld_anode = 'A'
        self.fld_bnode = 'B'
        self.fld_join = 'A_B' # used for joining link centroids back to link lines
        
        self.usefields = [self.fld_anode, self.fld_bnode, self.fld_join,
                        self.fld_func_class, self.fld_rdname, self.fld_c_angle, 
                        self.fld_c_textdirn] + self.extra_fields

        self.sref = arcpy.SpatialReference(2226) # output will have spatial reference of SACOG region

        # will be copy of input link file, but projected to specified CRS
        # Needed because Cube NET files usually don't have projection
        self.fc_link_prj = "TEMP_link_prj" 
        self.fc_link_centroids = "TEMP_link_centroids"

        # add angle data to stick-ball links
        if add_dirn_data:
            self.add_angle_data()

        
        self.make_ab_joinfield() # if it doesn't exist, add A_B join field to enable joining between copies of link file based on concatenated A_B 
        
        if make_copy_w_projn:
            self.make_linkcopy_prj()
            

        self.make_link_centroids()

    
    def make_ab_joinfield(self):
        """ Checks if there's a join field, based on concatenating A and B nodes.
        If there is not, it adds one. 
        CONSIDER making this happen no matter what, since sometimes the A_B field will have duplicate values
        if user does not run field calculation in Cube
        """
        link_fields = [f.name for f in arcpy.ListFields(self.fc_in)]
        # import pdb;pdb.set_trace()
        if self.fld_join not in link_fields:
            print(f"{self.fld_join} does not exist, so it's being added to enable joining...")
            arcpy.AddField_management(self.fc_in, self.fld_join, "TEXT")
            
        with arcpy.da.UpdateCursor(self.fc_in, [self.fld_anode, self.fld_bnode, self.fld_join]) as ucur:
            for row in ucur:
                anode = row[0]
                bnode = row[1]
                jnkey = f"{anode}_{bnode}"

                row[2] = jnkey
                ucur.updateRow(row)

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


class trueShape(lineSegs):
    """class specific to the input true-shape network"""
    def __init__(self, fld_linkid=None, fld_dir_sign=None, 
                fld_link_len=None, **lineseg_args):

         # inheriting stuff from parent class
        super().__init__(**lineseg_args)  
        
        self.fld_seg_len = fld_link_len
        self.fld_linkid = fld_linkid # unique ID for each true-shape segment (e.g. TMC code for Inrix files)
        self.fld_dir_sign = fld_dir_sign # field that has signed direction (eg. direction shown on road signs)

        self.usefields = [self.fld_linkid, self.fld_rdname, self.fld_func_class, 
        self.fld_dir_sign, self.fld_seg_len] \
            + self.extra_fields

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
    # test_trueshapes = r'Q:\SACSIM23\network_update\SACSIM23NetUpdate\SACSIM23NetUpdate.gdb\HERE_Sugar_2019_pubROW_ctype_nearSSlinksNoRamp'
    
    # sbt = stickBall(workspace=arcpy.env.workspace, fc_in=test_model_lnk, fld_func_class='CAPC20',
    #     funclass_fwys=(1), extra_fields=['SACTRAK'])

    # tst = trueShape(workspace=arcpy.env.workspace, fc_in=test_trueshapes, fld_func_class='FRC',
    #     funclass_fwys=(1, 2), extra_fields=['ST_NAME', 'SPD_LIMIT'], fld_link_len='DISTANCE',
    #     fld_dir_sign=)

    # import pdb; pdb.set_trace()
