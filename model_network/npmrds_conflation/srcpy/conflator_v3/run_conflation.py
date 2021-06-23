"""
Name: run_conflation.py
Purpose: enter parameters for and run conflation process to get true-shape attributes onto stick-ball links

    This package was developed to conflate INRIX TMC data onto SACSIM19 stick-ball model links.
        
          
Author: Darren Conly
Last Updated: Jun 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""
# #%%
import os
from datetime import datetime as dt

import pandas as pd

import segtypes
from conflation import conflation

# #%%
if __name__ == '__main__':
    # =============INPUT PARAMETERS=========================
    output_fgdb = r"Q:\SACSIM23\network_update\SACSIM23NetUpdate\SACSIM23NetUpdate.gdb"

    #stick-ball input parameters
    sacsim_links = r"Q:\SACSIM19\2020MTP\highway\network update\NetworkGIS\SHP\Link\masterSM19ProjCoding_10022020.shp"
    sacsim_capc = 'CAPC20'
    sacsim_fwys = (1, 16) # 1 = mainline freeways; 8 = HOV lanes, 16 = freeway-to-freeway connectors
    sacsim_arterials = (2, 3, 4, 5, 12, 22, 24)
    sacsim_ramps = (6) # arterial-to-freeway on-off ramps
    sacsim_roadname = "NAME"


    #true-shape input parameters
    # trueshp_links = r"Q:\SACSIM23\network_update\SACSIM23NetUpdate\SACSIM23NetUpdate.gdb\INRIX_SHP_2020_2021_noRamps"
    trueshp_links = r"Q:\SACSIM23\network_update\SACSIM23NetUpdate\SACSIM23NetUpdate.gdb\SAMPLE_HERE_Sugar_2019_pubROW_ctype" 
    trueshp_linkid = 'LINK_ID' # 'Tmc'
    trueshp_dirn_field = 'DirectionAbb'
    trueshp_funcclass = 'FRC'
    trueshp_fwys = (1, 2) 
    trueshp_arterials = (3, 4, 5, 6, 99)
    trueshp_roadnam = "RoadName"
    trueshp_len = 'Miles'

    # variables not being used, but may be useful in future if making capability to conflate ramps too.
    trueshp_rampflag_col = 'Type'
    trueshp_rampflag_val = 'P4.0' # links with this Type value are ramps (both street-freeway and freeway-freeway ramps)



    # =============RUN SCRIPT=========================
    start_time = dt.now()
    stickball_links = segtypes.stickBall(workspace=output_fgdb, fc_in=sacsim_links, fld_func_class=sacsim_capc, funclass_fwys=sacsim_fwys, 
                                        funclass_arts=sacsim_arterials, fld_rdname=sacsim_roadname, extra_fields=[], make_copy_w_projn=True)
    
    # # %%
    print("loading true-shape data...")
    true_shapes = segtypes.trueShape(workspace=output_fgdb, fc_in=trueshp_links, fld_linkid=trueshp_linkid, fld_dir_sign=trueshp_dirn_field,
                                    fld_func_class=trueshp_funcclass, funclass_fwys=trueshp_fwys, funclass_arts=trueshp_arterials, 
                                    fld_rdname=trueshp_roadnam, fld_link_len=trueshp_len, extra_fields=[])
    print("loaded true-shape data.")

    # #%%
    conflated = conflation(links_trueshp=true_shapes, links_stickball=stickball_links, workspace=output_fgdb)

    # #%%
    conflated.spatial_join_2()

    print("initial conflation complete. Now running supplemental process to fix ambiguous angles...")
    conflated.fix_diagonals()
    conflated.conflation_cleanup()
    conflated.conflation_summary()


    time_elapsed = dt.now() - start_time
    run_time_mins = round(time_elapsed.total_seconds()/60,1)
    
    # Idea for future feature: have output msg that gives status on conflation (e.g. % of links that conflated)
    
    print("""
        \nScript successfully completed in {} mins! \n\n
          Be sure to manually inspect conflation and check for errors. In particular: \n
          *Model links whose midpoint is outside the search distance from TMCs \n
          *Model links whose calculated cardinal direction doesn't match TMC direction \n
          *Model links with capacity class of 2, which get counted as freeways even if they are arterials \n
          *Model links with significant (>20mph or so) free-flow speed difference from NPMRDS free-flow
          *This script did NOT consider conflation for RAMPS or HOV facilities. These will need to be conflated manually.

          """.format(run_time_mins))




# %%
