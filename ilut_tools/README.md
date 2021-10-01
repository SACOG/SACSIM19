# SACSIM19 Integrated Land Use Transportation (ILUT) Summary Tool

## Contents
* [Version Info](#Version-Info)
* [What is the ILUT Tool?]()
* [Using the ILUT Tool](#Using-the-ILUT-Tool)
* [Software and Package Requirements](#Software-and-Package-Requirements)



## Version Info

Last update: Feb 2021

## What is the ILUT Tool?
The integrated land-use transportation (ILUT) tool takes in raw model input and output files and generates an output table that provides wide array of transportation and land use information for each parcel in the SACOG region. Among the dozens of variables, the resulting ILUT table provides the following information for each parcel::
* Travel behavior (VMT, mode split, etc.)
* Demographic and job data (total population, count of workers, school population, total jobs, etc.)
* Land use characteristics (total dwelling units, type of land use, etc.)

The ILUT table also contains fields like TAZ, census tract, county, and other characteristics that allow more aggregate "roll-ups" of the data to these and other geographies.

## Using the ILUT Tool

1.  Go to the 'ILUT' folder

2.  Open ilut.py script in interpreter (e.g. IDLE, PyCharm)

3.  Run the script, entering parameters as prompted

## Software and Package Requirements:

### Python packages

The ILUT Summary Tool requires the following packages be installed

-pyodbc

-dbfread

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
