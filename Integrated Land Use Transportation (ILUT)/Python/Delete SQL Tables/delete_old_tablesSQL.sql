--Purpose: delete unwanted ILUT tables, including raw tables, 
--Notes:
--	This script is meant to run from a python script call. Hence formatters instead of table names.


--Drop raw input tables
IF OBJECT_ID('{0}', 'U') IS NOT NULL DROP TABLE {0}; --raw_person
IF OBJECT_ID('{1}', 'U') IS NOT NULL DROP TABLE {1}; --raw_hh
IF OBJECT_ID('{2}', 'U') IS NOT NULL DROP TABLE {2}; --raw_parcel
IF OBJECT_ID('{3}', 'U') IS NOT NULL DROP TABLE {3}; --raw_trip
IF OBJECT_ID('{4}', 'U') IS NOT NULL DROP TABLE {4}; --raw_tour
IF OBJECT_ID('{5}', 'U') IS NOT NULL DROP TABLE {5}; --raw_ixxi
IF OBJECT_ID('{6}', 'U') IS NOT NULL DROP TABLE {6}; --raw_cveh
IF OBJECT_ID('{7}', 'U') IS NOT NULL DROP TABLE {7}; --raw_ixworker

--Drop theme tables
IF OBJECT_ID('{8}', 'U') IS NOT NULL DROP TABLE {8};	--ilut_triptour
IF OBJECT_ID('{9}', 'U') IS NOT NULL DROP TABLE {9};	--ilut_person
IF OBJECT_ID('{10}', 'U') IS NOT NULL DROP TABLE {10};	--ilut_hh
IF OBJECT_ID('{11}', 'U') IS NOT NULL DROP TABLE {11};	--ilut_ixxcveh

--Drop combined output tables (has MTPUSER schema)
IF OBJECT_ID('{12}', 'U') IS NOT NULL DROP TABLE {12};	--combined ilut table