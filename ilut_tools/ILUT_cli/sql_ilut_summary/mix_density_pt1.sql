--Mix-density step 1: Create the mix density column
--Must be done in separate script because you cannot both add and update a column in same transaction without the GO
--command, which is not recognized through pyodbc connection

IF EXISTS (SELECT * FROM sys.columns WHERE Name = N'MIX_DENS' and Object_ID = Object_ID(N'{0}')) --{0} = raw model input parcel table
ALTER TABLE {0} DROP COLUMN MIX_DENS
;

ALTER TABLE {0}
ADD MIX_DENS FLOAT
;