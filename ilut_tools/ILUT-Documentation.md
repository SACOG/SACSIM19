# SACSIM19 Integrated Land Use Transportation (ILUT) Summary Tool

## Version info

Last update: Feb 2021

# Using the ILUT Tool

1.  Go to the 'ILUT' folder

2.  Open ilut.py script in interpreter (e.g. IDLE, PyCharm)

3.  Run the script, entering parameters as prompted

# Software and Package Requirements:

## Python packages

The ILUT Summary Tool requires the following packages be installed

-pyodbc

-dbfread

## Other Software Requirements

### Microsoft SQL Server

The ILUT tool is designed to work with Microsoft SQL Server. If you have
a different RDBMS (e.g. Postgres, MySQL, etc.) , you will need to update
the query syntax accordingly.

### 

### SQL Server Bulk Copy Program (BCP)

The ILUT tool relies on SQL Server's Bulk Copy Program (BCP) to quickly
and seamlessly load model output tables into SQL Server. Before running
the ILUT tool, you must [download the BCP utility from
Microsoft](https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver15).

*Note -- if this link does not work, simply search for "SQL Server BCP
utility"*
