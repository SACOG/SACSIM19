"""
Name: utils.py
Purpose: various functions for conflation that don't neatly fit in elsewhere
        
          
Author: Darren Conly
Last Updated: June 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""
import  os
import math
import arcpy



def field_in_fc(fname, fc_to_check):
    # returns True/False to flag if fname appears in the fields of fc_to_check
    fc_fields = [f.name for f in arcpy.ListFields(fc_to_check)]
    
    return fname in fc_fields

def shp2fc_sel_fields(workspace, in_fc, field_list, out_fc):
    arcpy.overwriteOutput = True
    """ Takes in_fc and makes out_fc, which only contains fields
    specified in field_list. """

    field_maps = arcpy.FieldMappings()
    
    in_fc_fields = [f.name for f in arcpy.ListFields(in_fc)]

    if arcpy.Exists(out_fc): arcpy.Delete_management(out_fc)
    
    for field in field_list:
        
        try:
            if field in in_fc_fields:
                vars()[field] = arcpy.FieldMap() #vars() 
                vars()[field].addInputField(in_fc, field)
                field_maps.addFieldMap(vars()[field])
            else:
                print(f"'{field}' field is not in {in_fc}, so won't be in output either.")
        except:
            print("ERROR IN TRYING TO SET FIELDS")
            import pdb; pdb.set_trace()
        
    # This snippet should not be necessary since overwriteOutput = True, FYI
    if arcpy.Exists(os.path.join(workspace, out_fc)):
        arcpy.Delete_management(os.path.join(workspace, out_fc))
        
    arcpy.FeatureClassToFeatureClass_conversion(in_fc, workspace, out_fc, field_mapping=field_maps)

def get_angle(in_line_geom):
    """Takes in ESRI line geometry object and retrieves its angle.
    Meant to be used within search or update cursors"""
    start_lat = in_line_geom.firstPoint.Y
    start_lon = in_line_geom.firstPoint.X
    end_lat = in_line_geom.lastPoint.Y
    end_lon = in_line_geom.lastPoint.X
    
    xdiff = end_lon - start_lon
    ydiff = end_lat - start_lat
    link_angle = math.degrees(math.atan2(ydiff, xdiff))
    return link_angle

# in feature layer fl, set field to value set_val
def set_field_value(fl, field, set_val, srch_qry=None):
    with arcpy.da.UpdateCursor(fl, field, srch_qry) as ucur:
        for row in ucur:
            row[0] = set_val
            ucur.updateRow(row)

# def update_model_ab_field(fc_in, a_fld, b_fld, ab_fld):
#     with arcpy.da.UpdateCursor(fc_in, [a_fld, b_fld, ab_fld]) as ucur:
#         for row in ucur:
#             node_a = row[0]
#             node_b = row[1]
#             a_b = f"{node_a}_{node_b}"
#             row[2] = a_b
#             ucur.updateRow(row)