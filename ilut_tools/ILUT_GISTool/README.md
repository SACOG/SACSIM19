# ILUT GIS Toolbox

## Software Requirements

While this toolbox's ZIP file contains all of the python dependencies required to run the ILUT process, you must also have:

* Microsoft SQL Server
* ArcGIS Pro
* Microsoft BCP loader
* For a full description of dependencies, refer to the [ILUT README on GitHub](https://github.com/SACOG/SACSIM23-internal/blob/main/ilut_tools/README.md)

## Tool Setup

1. Unzip ILUT_GISToolfiles.zip. This contains the toolbox TBX file and all python dependencies.
2. Open ArcGIS Pro
3. In ArcGIS Pro, add the ilut_tool.tbx toolbox. [ESRI's documentation](https://pro.arcgis.com/en/pro-app/2.8/help/analysis/geoprocessing/basics/use-a-custom-geoprocessing-tool.htm) explains how to add a toolbox to a project.

## Input File Requirements

The ILUT tool takes several model run outputs as its inputs. In addition to the standard outputs created during a SACSIM model run, you must run the following post-model-run processes **prior** to running the ILUT tool:

* [Attach-skims script](https://github.com/SACOG/SACSIM23-internal/tree/main/model_scripts/post_processing/attach_skims)
* [IXXI and commercial vehicle trip summary script](https://github.com/SACOG/SACSIM23-internal/blob/main/model_scripts/post_processing/sacsim19_ixxi_cveh_taz.s)

## Running the ILUT GIS tool

### Basic Run Process

1. Open the toolbox in ArcGIS Pro
2. Fill out the fields. Each field's information bubble (hover the cursor to the immediate left of the entry field name to see the bubble) gives more information about what to enter in each field.
3. Click "Run"

### Advanced Usage

*Changing the output database*

To specify the output database for the ILUT tables, open the `run_ilut.py` script and enter the database name for the `ilut_db_name` variable. Please note that the output database you specify must also have an approprate `ilut_scenario_log` table within it.
