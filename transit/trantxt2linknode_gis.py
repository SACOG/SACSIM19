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
    def __init__(in_txt):
        self.in_txt = in_txt
        
        self.f_linename = 'LINE NAME'
        
        self.line_attrs = [self.f_linename,'TIMEFAC[1]','TIMEFAC[2]','TIMEFAC[3]',
                         'TIMEFAC[4]','TIMEFAC[5]','ONEWAY','MODE','OPERATOR',
                         'COLOR','CIRCULAR','HEADWAY[1]','HEADWAY[2]','HEADWAY[3]',
                         'HEADWAY[4]','HEADWAY[5]']
        
        self.line_attrs_outorder = [self.f_linename,'TIMEFAC[1]','ONEWAY','MODE','OPERATOR',
                         'COLOR','CIRCULAR','TIMEFAC[1]','TIMEFAC[2]','TIMEFAC[3]',
                         'TIMEFAC[4]','TIMEFAC[5]','HEADWAY[1]','HEADWAY[2]','HEADWAY[3]',
                         'HEADWAY[4]','HEADWAY[5]']
        
        self.f_node_attrname = 'N' #field name for node id
        
        self.f_tf_attrnames = ['TF','TIMEFAC'] # time factor field names
        
        self.val_stop = 'Y' # value for stop node
        self.val_notstop = 'N' # not a stop node
        
        self.data_rows = self.make_link_node_lists(in_txt)
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
        
        for attr in line_attrs_list: 
            attr_sp = attr.strip().split('=') # example: 'LINE NAME=LINE1' becomes ['LINE NAME', 'LINE1']
            
            if len(attr_sp) > 1: # if the attribute has a name to it as opposed to just being the value (most nodes don't have attrib names)
                attr_name = attr_sp[0] # attribute name
                attr_value = attr_sp[1].strip('"') # value of attribute
                
                # non-node line attributes (e.g. line name, color, headways...)
                if attr_name in self.line_attrs:
                    row_dict1[attr_name] = attr_value
        
                # for each line, the node values will be made into a list
                elif attr_name == self.f_node_attrname: 
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
    
    def ideal_type(self, in_str):
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

    def make_link_node_lists(self, in_file):
        try:
            print("Writing out line and node lists...")
            
            # {NAME:[NAME, TFs, HEADWAYs, node list, etc.]}
            lines_dict = get_line_attrs()

            link_rows = []
            node_rows = []

            for line_name in lines_dict.keys():
                line_attrs = lines_dict[line_name]
                node_lists = self.make_node_lists(line_attrs)
                
                node_ids = node_lists[0] # list of all node ids associated with line
                node_tfs = node_lists[1] # list of all node-level tf values associated with line

        
                # put values into correct order to insert into output gdb; ensure all fields needed for GDB included
                row_dict2 = {}
                for attrname in line_level_attrnames:
                    if row_dict1.get(attrname):
                        row_dict2[attrname] = row_dict1[attrname]
                    else:
                        row_dict2[attrname] = '0' # value if the key isn't found in input tranline file attribute names
        
                linkrow_reordered = []
                for attr in line_attrs_outorder:
                    if row_dict2.get(attr):
                        linkrow_reordered.append(row_dict2[attr])
                    else:
                        linkrow_reordered.append('0')

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
                  .format(LineName))
                
class textOutput:
    def __init__(self, in_file):
        self.in_file = in_file
        self.data = LinesNodes(self.in_file)
        
        self.line_rows = self.data.line_rows
        self.node_rows = self.data.node_rows
        
        self.out_link_fields = 'NAME,TIMEFAC,ONEWAY,MODE,OPERATOR,COLOR,CIRCULAR,' \
            'TF1,TF2,TF3,TF4,TF5,HEADWAY1,HEADWAY2,HEADWAY3,HEADWAY4,HEADWAY5'+"\n"
            
        self.out_node_fields = 'NAME,NODE,SEQ,STOP,TF'+"\n"
    
 
    def make_txt(self, out_link_txt, out_node_txt):
        
        with open(out_link_txt,'w') as f_out_link:
            f_out_link.write(out_link_fields)
            for row in self.line_rows:
                row = ','.join(str(i) for i in row) + '\n'
                f_out_link.write(row)
        
        with open(out_node_txt,'w') as f_out_node:
            f_out_node.write(self.out_node_fields)
            for row in self.node_rows:
                row = ','.join(str(i) for i in row) + '\n'
                f_out_node.write(row)
                
class GISOutput:
    def __init__(self, in_txt, in_node_dbf):
        
        # data from transit line txt file (node-level and line-level rows)
        self.line_node_data = LinesNodes(in_txt)
        self.line_rows = self.line_node_data.line_rows
        self.node_rows = self.line_node_data.node_rows

def create_link_file(outDir, outLink_tbl, in_link_rows):
    print("writing link table...")
    outLinkPath = os.path.join(outDir,outLink_tbl)
    
    arcpy.CreateTable_management(outDir, outLink_tbl,"","")
    
    print("adding fields to link table...")
    arcpy.AddField_management(outLinkPath,"NAME" , "TEXT", "", "", 20)
    arcpy.AddField_management(outLinkPath,"TIMEFAC" , "TEXT", "", "", 5)
    arcpy.AddField_management(outLinkPath,"ONEWAY" , "TEXT", "", "", 2)
    arcpy.AddField_management(outLinkPath,"MODE" , "SHORT")
    arcpy.AddField_management(outLinkPath,"OPERATOR" , "SHORT")
    arcpy.AddField_management(outLinkPath,"COLOR" , "SHORT")
    arcpy.AddField_management(outLinkPath,"CIRCULAR" , "TEXT", "", "", 2)
    
    arcpy.AddField_management(outLinkPath,"TF1" , "FLOAT", "", "", 5)
    arcpy.AddField_management(outLinkPath,"TF2" , "FLOAT", "", "", 5)
    arcpy.AddField_management(outLinkPath,"TF3" , "FLOAT", "", "", 5)
    arcpy.AddField_management(outLinkPath,"TF4" , "FLOAT", "", "", 5)
    arcpy.AddField_management(outLinkPath,"TF5" , "FLOAT", "", "", 5)
    
    arcpy.AddField_management(outLinkPath,"HEADWAY1" , "SHORT")
    arcpy.AddField_management(outLinkPath,"HEADWAY2" , "SHORT")
    arcpy.AddField_management(outLinkPath,"HEADWAY3" , "SHORT")
    arcpy.AddField_management(outLinkPath,"HEADWAY4" , "SHORT")
    arcpy.AddField_management(outLinkPath,"HEADWAY5" , "SHORT")
    
    	
    link_fields = [i.name for i in arcpy.ListFields(outLink_tbl)]
    link_fields = link_fields[1:] #omit the OBJECTID field
    	
    	
    linkCursor = arcpy.da.InsertCursor(outLink_tbl,link_fields)
    i = 1
    for row in in_link_rows:
        linkCursor.insertRow(row)
        i += 1
    
    del linkCursor

#create route node gdb table
def create_node_file(outDir, outNode_tbl, in_node_rows, hwynode_dbf):
    print("writing node table...")
    
    #arcpy.env.workspace = scratch_gdb
    workspace = arcpy.env.workspace
    
    temp_nodetbl = "TEMP_nodetbl"
    outNodes_wPath = os.path.join(outDir, outNode_tbl)
    
    arcpy.CreateTable_management(workspace, temp_nodetbl,"","")
    arcpy.AddField_management(temp_nodetbl,"NAME" , "TEXT", "", "", 20)
    arcpy.AddField_management(temp_nodetbl,"NODE" ,"LONG")
    arcpy.AddField_management(temp_nodetbl,"SEQ" ,"LONG")
    arcpy.AddField_management(temp_nodetbl,"STOP" ,"TEXT", "", "", 2)
    arcpy.AddField_management(temp_nodetbl,"TF" ,"TEXT", "", "", 5)
    
    node_fields = [i.name for i in arcpy.ListFields(temp_nodetbl)]
    node_fields = node_fields[1:] #omit the OBJECTID field
    	
    with arcpy.da.InsertCursor(temp_nodetbl,node_fields) as node_cursor:
        for row in in_node_rows:
            node_cursor.insertRow(row)
    
    #make fls of the all-network node table and the list of transit nodes  
    tv_allnetnodes = "tv_allnetnodes"
    tv_trannodes = "tv_trannodes"
    
    arcpy.MakeTableView_management(temp_nodetbl,tv_trannodes)
    arcpy.MakeTableView_management(hwynode_dbf,tv_allnetnodes)
    
    #add XY data to transit nodes via join with all-network nodes DBF
    net_fields = ["N", "X", "Y"]
    arcpy.JoinField_management(tv_trannodes, "NODE", tv_allnetnodes,"N", net_fields)
    
    arcpy.TableToTable_conversion(tv_trannodes, outDir, outNode_tbl)
    
    arcpy.DeleteField_management(outNodes_wPath, "N")
    arcpy.Delete_management(temp_nodetbl)
    
    
def make_linknode_gdbs(in_file, hwynode_dbf, output_dir, outLink_tbl, outNode_tbl):
    data = LinesNodes(in_file)
    link_rows = data.line_rows
    node_rows = data.node_rows

    create_link_file(output_dir, outLink_tbl, link_rows)
    create_node_file(output_dir, outNode_tbl, node_rows, hwynode_dbf)
    
#make SHP/FC of transit lines
def make_line_fc(outDir, line_tbl, trn_node_tbl, hwynodes_dbf, output_line_fc):
    print("making line FC...")
    arcpy.env.qualifiedFieldNames = False
    arcpy.env.workspace = outDir
    
    temp_line_fc = r"{}\temp_line_fc".format(scratch_gdb)
    temp_trannode_fc = "tran_nodes_fl_copy"
    temp_nodejoin_tbl = "temp_nodejoin_tbl"
    nodejoin_w_path = r"{}\{}".format(scratch_gdb,temp_nodejoin_tbl)
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
    arcpy.MakeTableView_management(hwynodes_dbf, node_xy_tv) #make model node SHP into feature layer
    shp_name_prefix = arcpy.Describe(node_xy_tv).name
    shp_name_prefix = re.search('(.*)\..*',shp_name_prefix).group(1) #from 'xxx.shp' return 'xxx'

    
    
    arcpy.MakeTableView_management(trn_node_tbl, node_tblvw)
    
    arcpy.MakeTableView_management(line_tbl, line_tblvw)
    
    #join transit node list to SHP of network nodes, keeping only nodes that are in transit file
    #AddJoin_management(in_layer_or_view, in_field, join_table, join_field, {join_type})
    arcpy.AddJoin_management(node_tblvw,tbl_node_field,node_xy_tv,fl_node_field,join_type)
    #JoinField_management (in_data, in_field, join_table, join_field, {fields})
    
    
    #copy to temporary GDB in order to eliminate field prefixes
    arcpy.TableToTable_conversion(node_tblvw, scratch_gdb, temp_nodejoin_tbl)
    
    #make spatial FL of XY data
    arcpy.MakeXYEventLayer_management(nodejoin_w_path,x_field,y_field,tran_nodes_fl,spatial_ref)
    #arcpy.FeatureClassToFeatureClass_conversion(tran_nodes_fl,scratch_gdb,temp_trannode_fc) 
    
    #make FC of model transit lines from points
    arcpy.PointsToLine_management(tran_nodes_fl, temp_line_fc,line_field,sort_field)
    arcpy.MakeFeatureLayer_management(temp_line_fc, line_fc_fl)
    
    #join with link-level attributes, making sure column names are correct (not truncated join name columns)
    arcpy.AddJoin_management(line_fc_fl,line_field,line_tblvw,line_field,join_type)
    
    #output line feature layer to feature class, overwriting original fc
    arcpy.FeatureClassToFeatureClass_conversion(line_fc_fl,outDir,output_line_fc) #arcpy.FeatureClassToFeatureClass_conversion(line_fc_fl,scratch_gdb,output_line_fc)
    
    #delete unneeded columns
    #arcpy.DeleteField_management(output_line_fc,["PRKCOST_08","PRKCOST_35","PRKCOST_20"])
    arcpy.Delete_management(temp_line_fc)
    arcpy.Delete_management(temp_trannode_fc)

    
#def make_stop_fc #make SHP/FC of transit model stops
    
# make separate classes for text output and GIS output types

            
def make_gis(in_file, net_nodes_dbf, output_dir, out_link, out_node, link_fc):
    make_linknode_gdbs(in_file, net_nodes_dbf, output_dir, out_link, out_node)
    make_line_fc(output_dir, out_link, out_node, net_nodes_dbf, link_fc)
    print("Success!")

#======================RUN SCRIPT============================================

if __name__ == '__main__':
    tranline_in = r"Q:\SACSIM19\2020MTP\transit\Transit Model Inputs\2027\TranInputs2027_latest_reduced_streetcar\pa27_tranline.txt" # r"Q:\SACSIM19\2020MTP\transit\Transit Model Inputs\2027\TranInputs2027_latest\pa27_tranline.txt"
    network_nodes_dbf = r"Q:\SACSIM19\2020MTP\highway\network update\NetworkGIS\DBF\Node\masterSM19nodes_10152020.dbf"
    
    #specify model version and scenario year
    sc_yr_string = 'PA27'
    
    #GDB outputs
    outDir_gis = r"Q:\SACSIM19\2020MTP\transit\Transit GIS\TransitGIS.gdb" #r'Q:\SACSIM19\2020MTP\transit\Transit GIS\Transit2016.gdb'
    scratch_gdb = r"Q:\SACSIM19\2020MTP\transit\Transit GIS\scratch.gdb" #to store temporary files
    spatial_ref = arcpy.SpatialReference(2226) #spatial_ref = arcpy.SpatialReference(102642) # 102642 = SACOG NAD 83 CA State Plane Zone 2
    
    #text outputs
    txt_out_dir = r'Q:\SACSIM19\2020MTP\transit\Transit Model Inputs\2035\TranInputs2035_latest\transit_linknode'

    
    # BEGIN SCRIPT
    date_sufx = str(dt.date.today().strftime('%m%d%Y'))
    arcpy.env.workspace = outDir_gis
    outLink_tbl = "PT_link{}_{}".format(sc_yr_string,date_sufx)
    outNode_tbl = "PT_node{}_{}".format(sc_yr_string,date_sufx)
    outLink_fc = "PT_linkFC{}_{}".format(sc_yr_string,date_sufx)
    
    outlink_txt = os.path.join(txt_out_dir,"{}PT_link{}.txt".format(sc_yr_string,date_sufx)) #nodeline_dir + '\\' + "2016PT_link" + date_sufx + ".txt"
    outnode_txt = os.path.join(txt_out_dir,"{}PT_node{}.txt".format(sc_yr_string,date_sufx))
    
    output_format = input("Specify desired output format('GDB' or 'text'): ")
    
    if output_format.lower() == 'gdb':
        make_gis(tranline_in, network_nodes_dbf, outDir_gis, outLink_tbl, outNode_tbl, outLink_fc)
    elif output_format.lower() == 'text':
        make_txt(tranline_in, outlink_txt, outnode_txt)
        print("Sucessfully written to line and point text files!")
    else:
        quit()
        
    
#arcpy.FeatureClassToFeatureClass_conversion(tran_nodes_fl,scratch_gdb,"tran_nodes_fl_copy")