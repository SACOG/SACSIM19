# SACSIM19 Integrated Land Use Transportation (ILUT) Summary Tool

## Contents
* [Version Info](#Version-Info)
* [What is the ILUT Tool?](#What-is-the-ilut-tool?)
* [Software and Package Requirements](#Software-and-Package-Requirements)
* [Preparing ILUT Inputs](#Preparing-ILUT-Inputs)
* [Running the ILUT Tool](#Running-the-ILUT-Tool)



## Version Info

Last update: Feb 2021

## What is the ILUT Tool?
The integrated land-use transportation (ILUT) tool takes in raw model input and output files and generates an output table that provides wide array of transportation and land use information for each parcel in the SACOG region. Among the dozens of variables, the resulting ILUT table provides the following information for each parcel::
* Travel behavior (VMT, mode split, etc.)
* Demographic and job data (total population, count of workers, school population, total jobs, etc.)
* Land use characteristics (total dwelling units, type of land use, etc.)

The ILUT table also contains fields like TAZ, census tract, county, and other characteristics that allow more aggregate "roll-ups" of the data to these and other geographies.

## Software and Package Requirements:

### Python packages

The ILUT Summary Tool requires the following packages be installed. **If you are using the ArcGIS toolbox version of the tool in ArcGIS Pro, you do not need to worry about installing these packages.**

* pyodbc
* dbfread
* sqlalchemy

At SACOG, we recommend installing these packages using Conda. For more information on how to do this, please refer to our [Conda reference](https://github.com/SACOG/SACOG-Intro/blob/main/using-envs/sacog-Python-Env-Reference.md#setting-up-your-python-environment)

### Other Software Requirements

**Microsoft SQL Server**

The ILUT tool is designed to work with Microsoft SQL Server. If you have
a different RDBMS (e.g. Postgres, MySQL, etc.) , you will need to update
the query syntax accordingly.


**SQL Server Bulk Copy Program (BCP)**

The ILUT tool relies on SQL Server's Bulk Copy Program (BCP) to quickly
and seamlessly load model output tables into SQL Server. Before running
the ILUT tool, you must [download the BCP utility from
Microsoft](https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver15).

*Note -- if this link does not work, simply search for "SQL Server BCP
utility"*

## Preparing ILUT Inputs

The steps below list the inputs the ILUT needs, grouped by the source of each input

1. Run the main SACSIM model script to get primary model outputs
   * `_household.tsv`
   * `_person.tsv`
   * `_tour.tsv`
   * `2016_raw_parcel.txt`
   * `worker_ixxifractions.dat`
2. Run the post-model script `sacsim19 attach skims to trips.s` to attach TAZ-TAZ skim values to the model's output trip table
   * `_trip_1_1.tsv` (different from `_trip.tsv`, which does not have skim values attached to each trip)
3. Run post-model script `sacsim19_ixxi_cveh_taz.s` to calculate commercial vehicle traffic by taz and external traffic
   * `cveh_taz.dbf`
   * `ixxi_taz.dbf`

## Running the ILUT Tool

If you have ArcGIS Pro available, we recommend running the toolbox version of the tool (ILUT_tbx) because it has a more user-friendly interface.

### From the Command Line

1.  Ensure you are in a python environment with all of the needed [dependencies](###Python-packages) installed.
2.  Go to the 'ILUT' folder
3.  Open run_ilut.py script in the interpreter of your choice
3.  Run the script, entering parameters as prompted

### From the ArcGIS Pro Toolbox

1. In ArcGIS Pro, go to Catalog > Toolboxes
2. Right-click "toolboxes" and add ilut_tool.tbx
3. Enter parameters accordingly and run tool.

