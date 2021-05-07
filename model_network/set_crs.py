"""
Name:set_crs.py
Purpose: Set coordinate reference system (CRS) of a SHP. 

This was originally developed for setting the CRS for Cube Network SHP files.
By default, Cube will export NET to SHP without defining a CRS.
        
          
Author: Darren Conly
Last Updated: <date>
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

# Set CRS of SHP outputted from Cube. By default, Cube will export NET to SHP without defining a CRS

import os

import arcpy


def set_sref(in_file, out_dir, out_file, output_sref):
    arcpy.env.outputCoordinateSystem = output_sref
    arcpy.conversion.FeatureClassToFeatureClass(in_file, out_dir, out_file)

if __name__ == '__main__':
    # input SHP, from Cube NET and without spatial ref system
    shp_dir = r"Q:\SACSIM19\2020MTP\highway\network update\NetworkGIS\ModelNetGISProjects\MTP_MTIP_DataReleaseComparison\SHP\2040Pricing"
    in_shp = "MTP_MTIPAm2_2040Pricing.shp"

    # output location
    output_dir = r'\\data-svr\Modeling\SACSIM19\2020MTP\highway\network update\NetworkGIS\ModelNetGISProjects\MTP_MTIP_DataReleaseComparison\NetworkReleaseComparison.gdb'
    
    # set spatial reference you want to output it as
    sr_sacog = arcpy.SpatialReference(2226) # 2226 = SACOG CRS ID (CA NAD83 ZONE 5); 4326 = WGS84

    #==============================================================
    in_shp = os.path.join(shp_dir, in_shp)
    out_fc = f"compare{os.path.splitext(os.path.basename(in_shp))[0]}"
    
    set_sref(in_shp, output_dir, out_fc, sr_sacog)