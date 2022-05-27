# Speed Data Conflation

## READ THIS FIRST

While we hope to provide more robust documentation in the future, please use the conflation scripts in this repository at your own risk. Even the best conflation tools usually require additional manual corrections and filling in of missing data after running the tool itself. SACOG assumes no responsibility for outcomes resulting from people using the conflation scripts in this repository.



## Overview

SACSIM19's model links are a "stick-ball" network. In comparison, many sources of observed speed data come in "true-shape" networks whose link shapes match the curves of real roads. Conflation is the process by which we take attributes from speed network links and tag, or "conflate" them to model links so we can do link-level validations such as comparing modeled free-flow speed to observed free-flow speeds.

## Scripts to Use

The primary scripts for running the conflation are in the [srcpy/conflator directory](https://github.com/SACOG/SACSIM19/tree/main/model_network/npmrds_conflation/srcpy/conflator) in this repository. A quick overview of the scripts:

* `run_conflation.py` - This is the main script that you specify all required input parameters in. After filling out all inputs parameters in the indicated `INPUT PARAMETERS` section you run the script to execute the conflation tool.
* `conflation.py` - used by `run_conflation`. Should not require any editing by end user.
* `segtypes.py` - used by `run_conflation`. Should not require any editing by end user.
* `utils.py` - used by `run_conflation`. Should not require any editing by end user.

## Dependencies

The [scripts](#Scripts-to-Use) described above will give a more complete list of needed dependencies, but notable dependencies include:

* [arcpy](https://pro.arcgis.com/en/pro-app/latest/arcpy/get-started/what-is-arcpy-.htm) library included with most ESRI licenses
* [pandas](https://pandas.pydata.org/)



