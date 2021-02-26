'''
author: Yanmei Ou/Darren Conly

Purpose: convert tranline.txt file to separate node and route GDB tables
execfile(r'Q:\SACSIM19\2020MTP\transit\python\Convert_PTline_to_LinkNode_latest.py')

Next steps to add:
    Find more concise, functionalizable way to do the line splitting in the main script (use dict or something?)
	Make tranline GIS FC
        Bring in Cube node dbf with X/Y attributes
        > join to the output node table
        > make feature layer from the joined node table
        > run nodes2lines grouping by line name and ordering by SEQ column
        > output will be line FC
    Make text outputs from link/node tables
	
	Then work on improving the reverse script (link-node-to-PTline)

'''

import os
import re
# import pdb
import datetime as dt
import arcpy

arcpy.env.overwriteOutput = True


#=============================FUNCTIONS==========================================
class LinesNodes:
    def __init__(self, in_txt):
        self.in_txt = in_txt
        
        self.f_linename = 'LINE NAME'
        self.f_node_attrname = 'N' #field name for node id
        
        self.line_attrs = [self.f_linename,'TIMEFAC[1]','TIMEFAC[2]','TIMEFAC[3]',
                         'TIMEFAC[4]','TIMEFAC[5]','ONEWAY','MODE','OPERATOR',
                         'COLOR','CIRCULAR','HEADWAY[1]','HEADWAY[2]','HEADWAY[3]',
                         'HEADWAY[4]','HEADWAY[5]']
        
        self.line_attrs_outorder = [self.f_linename,'TIMEFAC[1]','ONEWAY','MODE','OPERATOR',
                         'COLOR','CIRCULAR','TIMEFAC[1]','TIMEFAC[2]','TIMEFAC[3]',
                         'TIMEFAC[4]','TIMEFAC[5]','HEADWAY[1]','HEADWAY[2]','HEADWAY[3]',
                         'HEADWAY[4]','HEADWAY[5]']
        
        self.node_attrs_out_order = [self.f_linename, self.f_node_attrname, 'SEQ',
                                     'STOP', 'TF']
        
        self.f_tf_attrnames = ['TF','TIMEFAC'] # time factor field names
        
        self.val_stop = 'Y' # value for stop node
        self.val_notstop = 'N' # not a stop node
        
        self.data_rows = self.make_link_node_outputs(in_txt)
        self.line_rows = self.data_rows[0] # each row contains line-level data
        self.node_rows = self.data_rows[1] # each row contains data for each node on each line
        


    def get_line_attrs(self):  
        """
        Generates dictionary of line-level attributes, e.g.:
            {<line name>: <list of line attributes>}

        """
        line_dict_out = {}
        
        with open(self.in_txt, 'r') as f_in:
            lines = f_in.readlines()
        
            for line in lines:
                if len(line) != 0: 
                    line = line.strip() # removes any leading or trailing spaces
                    if line[0] != ';': #if line is not a cube commented-out line
                        if re.match(self.f_linename, line): #if it's the start of a new transit line feature
                            #line_attrs = ''
                            line_list = line.split(',') #make into comma-delimited list
                            line_name1 = line_list[0].split('=') # 'LINE NAME="AMTRCCB_A"' becomes list ['LINE NAME', '"AMTRCCB_A"']
                            line_name = line_name1[1].strip('"') #get the line name
                            line_attrs = line
                        elif line[-1] == ',': #if the line ends with a comma, it's part of the same route entry
                            line_attrs = line_attrs + line
                        else:
                            line_attrs = line_attrs + line
                            line_dict_out[line_name] = (line_attrs) #dict entry - {NAME:[NAME, TFs, HEADWAYs, node list, etc.]}
                            
        return line_dict_out
    
    def make_node_lists(self, line_attrs_str):
        tf_change = '0' # default value for time factor
        
        
        # example of line_attrs_str: ['LINE NAME=LINE1','COLOR=2'...]
        line_attrs_list = line_attrs_str.split(',')
        
        node_list = [] # list of nodes corresponding to the line
        tfchg_list = [] # list of time factor (TF) changes at each node, default = 0
        # lineattrs_dict = {} # {<line attribute name>: <line attribute value>} includes line name, headway vals, color, etc.
        
        for attr in line_attrs_list: 
            attr_sp = attr.strip().split('=') # example: 'LINE NAME=LINE1' becomes ['LINE NAME', 'LINE1']
            
            if len(attr_sp) > 1: # if the attribute has a name to it as opposed to just being the value (most nodes don't have attrib names)
                attr_name = attr_sp[0] # attribute name
                attr_value = attr_sp[1].strip('"') # value of attribute
                
                # # non-node line attributes (e.g. line name, color, headways...)
                # if attr_name in self.line_attrs:
                #     lineattrs_dict[attr_name] = attr_value
        
                # for each line, the node values will be made into a list
                if attr_name == self.f_node_attrname: 
                    first_node = attr_value
                    node_list.append(first_node)
                    tfchg_list.append(tf_change) #default aTF value is 0
                    
                # if there's a time factor change along the route, set it to that TF value
                elif attr_name in self.f_tf_attrnames: 
                    #we don't want to append TF changes to the node list because they've nothing to do with route geometry???
                    tf_change = attr_value
                    tfchg_list.append(tf_change)
            else: # if the attribute doesn't have a name, then it's a node id
                node_list.append(attr_sp[0])
                tfchg_list.append(tf_change)    
                
        return (node_list, tfchg_list)
    
    def get_line_attr_dict(self, line_attrs_str):
        
        line_attrs_dict = {}
        
        for attr in line_attrs_str.split(','): 
            attr_sp = attr.strip().split('=') # example: 'LINE NAME=LINE1' becomes ['LINE NAME', 'LINE1']
            
            if len(attr_sp) > 1: # if the attribute has a name to it as opposed to just being the value (most nodes don't have attrib names)
                attr_name = attr_sp[0] # attribute name
                attr_value = attr_sp[1].strip('"') # value of attribute
                
                # non-node line attributes (e.g. line name, color, headways...)
                if attr_name in self.line_attrs:
                    line_attrs_dict[attr_name] = attr_value
            
        
        return line_attrs_dict
        
    
    def ideal_type(self, in_str):
        '''
        Takes string as input and, if possible, converts either to integer or float data type.
        '''
        
        try:
            re_az = re.compile('.*[a-zA-Z]+.*')
            re_decimal = re.compile('.*\..*')
            
            if re.match(re_az, in_str): # if has letters, is string
                out = in_str
            elif re.match(re_decimal, in_str): # if no letter but periods, is float
                out = float(in_str)
            else: # if no letter and no periods, then is integer
                out = int(in_str)
                
        except ValueError:
            out = in_str # if all else fails, output will be same as input (string)
            
        return out

    def make_link_node_outputs(self, in_file):
        try:
            print("Writing out line and node lists...")
            
            # {NAME:[NAME, TFs, HEADWAYs, node list, etc.]}
            lines_dict = self.get_line_attrs()

            link_rows = []
            node_rows = []

            for line_name in lines_dict.keys():
                line_attrs = lines_dict[line_name]
                line_attrs_dict = self.get_line_attr_dict(line_attrs)
                
                node_lists = self.make_node_lists(line_attrs)
                node_ids = node_lists[0] # list of all node ids associated with line
                node_tfs = node_lists[1] # list of all node-level tf values associated with line

        
                # put values into correct order to insert into output gdb; ensure all fields needed for GDB included
                # if an attribute name is not found int he file, then make it's value = '0'
                row_dict2 = {attrname: line_attrs_dict[attrname] if line_attrs_dict.get(attrname) else '0' \
                             for attrname in self.line_attrs} 
        
                # put attributes into correct output order        
                linkrow_reordered = [row_dict2[attr] if row_dict2.get(attr) else '0' \
                                     for attr in self.line_attrs_outorder]
                
                # make values into field data types compatible with the feature class created.
                linkrow_out =[]
                for idx, i in enumerate(linkrow_reordered):
                    if idx == 0:
                        linkrow_out.append(i) #but line name is always text, even if it's a number value
                    else: 
                        ideal_i = self.ideal_type(i)
                        linkrow_out.append(ideal_i)
                
                link_rows.append(linkrow_out) # output link_row has line-level route info
                
                # generate node-level table
                for node_seq, node in enumerate(node_ids):
                    if node[0] == '-': #if node has negative value, it's not a stop
                        stop = self.val_notstop
                        node = node.strip('-') #take minus symbol out of node id
                    else:
                        stop = self.val_stop
            		
                    tf = node_tfs[node_seq]
                    node_row = [line_name, node, node_seq, stop, tf]
                    node_rows.append(node_row)
            
            return (link_rows, node_rows)
        except KeyError:
            print("Key error. The line after {} may not have all of its line-level fields. Please check." \
                  .format(line_name))
                
class textOutput:
    def __init__(self, in_file):
        self.in_file = in_file
        self.data = LinesNodes(self.in_file)
        
        self.line_rows = self.data.line_rows
        self.node_rows = self.data.node_rows
        
        self.out_linktxt_header = ','.join(self.data.line_attrs_outorder) + '\n'
        self.out_nodetxt_header = ','.join(self.data.node_attrs_out_order) + '\n'
        
        # converts ".../filename.txt" to "file"
        self.in_txt_fname = os.path.splitext(os.path.basename(self.in_file))[0]
        
        # if output folder not specified by user, default will be to make a new subfolder within
        # the folder containing the transit line file, and separated line and node files
        # will be put into the subfolder.
        self.default_output_dir = os.path.join(os.path.dirname(in_file), "transit_linenode")
    
 
    def make_txt(self, output_dir=None):
        
        if output_dir is None:
            output_dir = self.default_output_dir
            if not os.path.exists(output_dir):
                os.mkdir(output_dir)
                
        
        out_lines_txt = f"{self.in_txt_fname}_lines.txt"
        out_nodes_txt = f"{self.in_txt_fname}_nodes.txt"
        
        output_lines_fpath = os.path.join(output_dir, out_lines_txt)
        output_nodes_fpath = os.path.join(output_dir, out_nodes_txt)
        
        
        with open(output_lines_fpath, 'w') as f_out_link:
            f_out_link.write(self.out_linktxt_header)
            for row in self.line_rows:
                row = ','.join(str(i) for i in row) + '\n'
                f_out_link.write(row)
        
        with open(output_nodes_fpath, 'w') as f_out_node:
            f_out_node.write(self.out_nodetxt_header)
            for row in self.node_rows:
                row = ','.join(str(i) for i in row) + '\n'
                f_out_node.write(row)
                
        print(f"Success! Output files are in {output_dir}")        
        
class GISOutput:
    def __init__(self, in_txt, in_node_dbf, output_dir, str_scen_yr):
        
        # data from transit line txt file (node-level and line-level rows)
        self.line_node_data = LinesNodes(in_txt)
        self.line_rows = self.line_node_data.line_rows
        self.node_rows = self.line_node_data.node_rows
        
        self.hwynode_dbf = in_node_dbf
        
        # workspace and locations
        self.scratch_gdb = arcpy.env.scratchGDB
        self.output_dir = output_dir # for now must be a GDB; in future should allow using folder (for SHP/DBF export too)
        
        # output file names
        self.date_sufx = str(dt.date.today().strftime('%m%d%Y'))
        self.str_scen_yr = str_scen_yr
        self.link_tbl = "PT_link{}_{}".format(self.str_scen_yr, self.date_sufx)
        self.node_tbl = "PT_node{}_{}".format(self.str_scen_yr, self.date_sufx)
        self.link_fc = "PT_linkFC{}_{}".format(self.str_scen_yr, self.date_sufx) # name of output feature class of transit link feature class
        
        
        # column naming
        self.colname_lookup = {} # ideally this should be synced up/connected to header names on input txt file
        
        self.spatial_ref = arcpy.SpatialReference(2226)

    # create gdb table of link-level data
    def create_link_tbl(self):
        print("writing link table...")
        link_tbl_fpath = os.path.join(self.output_dir, self.link_tbl)
        
        arcpy.CreateTable_management(self.output_dir, self.link_tbl,"","")

        arcpy.AddField_management(link_tbl_fpath,"NAME" , "TEXT", "", "", 20)
        arcpy.AddField_management(link_tbl_fpath,"TIMEFAC" , "TEXT", "", "", 5)
        arcpy.AddField_management(link_tbl_fpath,"ONEWAY" , "TEXT", "", "", 2)
        arcpy.AddField_management(link_tbl_fpath,"MODE" , "SHORT")
        arcpy.AddField_management(link_tbl_fpath,"OPERATOR" , "SHORT")
        arcpy.AddField_management(link_tbl_fpath,"COLOR" , "SHORT")
        arcpy.AddField_management(link_tbl_fpath,"CIRCULAR" , "TEXT", "", "", 2)
        
        arcpy.AddField_management(link_tbl_fpath,"TF1" , "FLOAT", "", "", 5)
        arcpy.AddField_management(link_tbl_fpath,"TF2" , "FLOAT", "", "", 5)
        arcpy.AddField_management(link_tbl_fpath,"TF3" , "FLOAT", "", "", 5)
        arcpy.AddField_management(link_tbl_fpath,"TF4" , "FLOAT", "", "", 5)
        arcpy.AddField_management(link_tbl_fpath,"TF5" , "FLOAT", "", "", 5)
        
        arcpy.AddField_management(link_tbl_fpath,"HEADWAY1" , "SHORT")
        arcpy.AddField_management(link_tbl_fpath,"HEADWAY2" , "SHORT")
        arcpy.AddField_management(link_tbl_fpath,"HEADWAY3" , "SHORT")
        arcpy.AddField_management(link_tbl_fpath,"HEADWAY4" , "SHORT")
        arcpy.AddField_management(link_tbl_fpath,"HEADWAY5" , "SHORT")
        
        	
        link_fields = [i.name for i in arcpy.ListFields(link_tbl_fpath)]
        link_fields = link_fields[1:] #omit the OBJECTID field
        	
        	
        link_inscur = arcpy.da.InsertCursor(link_tbl_fpath, link_fields)

        for i, row in enumerate(self.line_rows):
            link_inscur.insertRow(row)
        
        del link_inscur
    
    #create route node gdb table
    def create_node_tbl(self):
        print("writing node table...")
        
        temp_nodetbl = "TEMP_nodetbl"
        temp_nodetbl_fpath = os.path.join(self.scratch_gdb, temp_nodetbl) # temp table, prior to adding x/y values to nodes
        node_tbl_fpath = os.path.join(self.output_dir, self.node_tbl) # final output node table
        
        # import pdb; pdb.set_trace()
        arcpy.CreateTable_management(self.scratch_gdb, temp_nodetbl,"","")
        arcpy.AddField_management(temp_nodetbl_fpath,"NAME" , "TEXT", "", "", 20)
        arcpy.AddField_management(temp_nodetbl_fpath,"NODE" ,"LONG")
        arcpy.AddField_management(temp_nodetbl_fpath,"SEQ" ,"LONG")
        arcpy.AddField_management(temp_nodetbl_fpath,"STOP" ,"TEXT", "", "", 2)
        arcpy.AddField_management(temp_nodetbl_fpath,"TF" ,"TEXT", "", "", 5)
        
        node_fields = [i.name for i in arcpy.ListFields(temp_nodetbl_fpath)]
        node_fields = node_fields[1:] #omit the OBJECTID field
        	
        with arcpy.da.InsertCursor(temp_nodetbl_fpath, node_fields) as node_cursor:
            for row in self.node_rows:
                node_cursor.insertRow(row)
        
        #make fls of the all-network node table and the list of transit nodes  
        tv_allnetnodes = "tv_allnetnodes"
        tv_trannodes = "tv_trannodes"
        
        arcpy.MakeTableView_management(temp_nodetbl_fpath, tv_trannodes)
        arcpy.MakeTableView_management(self.hwynode_dbf, tv_allnetnodes)
        
        #add XY data to transit nodes via join with all-network nodes DBF
        net_fields = ["N", "X", "Y"] # fields in network to include in join operation
        arcpy.JoinField_management(tv_trannodes, "NODE", tv_allnetnodes,"N", net_fields)
        
        # convert the table view, now with all node attribs and X/Y info, to a GDB table
        arcpy.TableToTable_conversion(tv_trannodes, self.output_dir, self.node_tbl)
        
        arcpy.DeleteField_management(node_tbl_fpath, "N")
        arcpy.Delete_management(temp_nodetbl_fpath)
        
        
    #make SHP/FC of transit lines
    def make_line_fc(self):
        
        arcpy.env.qualifiedFieldNames = False
        arcpy.env.workspace = self.output_dir
        
        # create line and transit node tables
        self.create_link_tbl()
        self.create_node_tbl()
        
        print("making line FC...")
        
        temp_line_fc = os.path.join(self.scratch_gdb, "temp_line_fc")
        temp_trannode_fc = os.path.join(self.scratch_gdb, "tran_nodes_fl_copy")
        temp_nodejoin_tbl = "temp_nodejoin_tbl"
        temp_nodejoin_fpath = os.path.join(self.scratch_gdb, temp_nodejoin_tbl)
        
        #parameters to join model network fc nodes to table of nodes from tranline file
        fl_node_field = "N"
        tbl_node_field = "NODE"
        join_type = "KEEP_COMMON" #inner join
        
        #parameters for joining points into transit lines
        x_field = "X" #from full network node dbf's table 
        y_field = "Y"
        line_field = "NAME"
        sort_field = "SEQ"
        
        #feature layer/table view names
        node_xy_tv = "node_xy_tv" #model net nodes to fl
        node_tblvw = "node_tblvw" #transit node list table to fl
        line_tblvw = "line_tblvw" #transit line table to fl
        line_fc_fl = "line_fc_fl" #output line fc to fl
        tran_nodes_fl = "tran_node_fl" #will be output of MakeXYEventLayer
        
        #make qualified field names ('table.field')
        arcpy.MakeTableView_management(self.hwynode_dbf, node_xy_tv) #make model node SHP into feature layer
        shp_name_prefix = arcpy.Describe(node_xy_tv).name
        shp_name_prefix = re.search('(.*)\..*',shp_name_prefix).group(1) #from 'xxx.shp' return 'xxx'

        arcpy.MakeTableView_management(self.node_tbl, node_tblvw)
        arcpy.MakeTableView_management(self.link_tbl, line_tblvw)
        
        #join transit node list to SHP of network nodes, keeping only nodes that are in transit file
        arcpy.AddJoin_management(node_tblvw, tbl_node_field, node_xy_tv, fl_node_field, join_type)

        #copy to temporary GDB in order to eliminate field prefixes
        arcpy.TableToTable_conversion(node_tblvw, self.scratch_gdb, temp_nodejoin_tbl)
        
        #make spatial FL of XY data
        arcpy.MakeXYEventLayer_management(temp_nodejoin_fpath, x_field, y_field, tran_nodes_fl, self.spatial_ref)
        
        #make FC of model transit lines from points
        arcpy.PointsToLine_management(tran_nodes_fl, temp_line_fc, line_field, sort_field)
        arcpy.MakeFeatureLayer_management(temp_line_fc, line_fc_fl)
        
        #join with link-level attributes, making sure column names are correct (not truncated join name columns)
        arcpy.AddJoin_management(line_fc_fl, line_field, line_tblvw, line_field, join_type)
        
        #output line feature layer to feature class, overwriting original fc
        arcpy.FeatureClassToFeatureClass_conversion(line_fc_fl, self.output_dir, self.link_fc) #arcpy.FeatureClassToFeatureClass_conversion(line_fc_fl,scratch_gdb,output_line_fc)
        
        #delete unneeded columns
        #arcpy.DeleteField_management(output_line_fc,["PRKCOST_08","PRKCOST_35","PRKCOST_20"])
        arcpy.Delete_management(temp_line_fc)
        arcpy.Delete_management(temp_trannode_fc)
        
        print(f"Success! Created line feature class {os.path.join(self.output_dir, self.link_fc)}")
    
def do_work():
    tranline_txt = input('Enter file path for transit line txt file: ')
    tranline_txt_dir = os.path.dirname(tranline_txt)

    output_format = input("Specify desired output format('GDB' or 'text'): ")
    
    
    if output_format.lower() == 'text':
        textOutput(tranline_txt).make_txt()
    elif output_format.lower() == 'gdb':
        hwy_node_dbf = input('Enter file path for hwy node DBF whose X/Y coordinates you will use: ')
        output_gdb = input("Enter the file path for the ESRI file geodatabase you want your outputs to be in: ")
        sc_yr = input("Enter the scenario year: ")
        
        gis_obj = GISOutput(tranline_txt, hwy_node_dbf, output_gdb, sc_yr)
        gis_obj.make_line_fc()
    else:
        raise ValueError("Output format must be either 'GDB' or 'text'. Please try again using either 'GDB' or 'text' for the output format.")
        
            
            

#======================RUN SCRIPT============================================

if __name__ == '__main__':
    do_work()
    
    # testing path for tranline file
    # D:\SACSIM19\MTP2020\Conformity_Runs\run_2035_MTIP_Amd1_Baseline_v1\pa35_tranline.txt
    
    # testing arguments for txt out
    # D:\SACSIM19\MTP2020\Conformity_Runs\run_2035_MTIP_Amd1_Baseline_v1\transit_linenode
    
    # testing args for gdb output
    # Q:\SACSIM19\2020MTP\transit\Transit GIS\TransitGIS.gdb
    # hwy nodes = D:\SACSIM19\MTP2020\Conformity_Runs\run_2035_MTIP_Amd1_Baseline_v1\pa35_base_nodes.dbf
    # scenario year = PA35

