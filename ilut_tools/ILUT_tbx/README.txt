ILUT TOOLBOX


INSTRUCTIONS FOR RUNNING IN ARCGIS PRO (UPDATED DECEMBER 2021)
1. In ArcGIS Pro, go to Catalog > Toolboxes
2. Right-click "toolboxes" and add ilut_tool.tbx
3. Enter parameters accordingly and run tool.


DEPENDENCIES:
- Microsoft Bulk Copy Program (BCP), which must be downloaded from https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver15
- pyodbc python package, which is normally included in the ArcGIS Pro default environment
- sqlalchemy, whose source code is included with this ZIP file and should not require any further action on the user's part
- dbfread, whose source code is included with this ZIP file and should not require any further action on the user's part