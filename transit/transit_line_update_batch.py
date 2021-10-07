"""
Name: transit_line_update_batch.py.py
Purpose: Update multiple CUBE transit line files
        
INSTRUCTIONS:

          
Author: Kyle Shipley (based on CheckFit_PTLineHwyNet.py)
Created: Aug 2021
Last Updated: Aug 2021
Updated by: <name>
Copyright:   (c) SACOG
Python Version: 3.x
"""

import os
import re
import datetime as dt

import pandas as pd
from dbfread import DBF




#=============================FUNCTIONS==========================================
def make_link_node_lists(in_file):
    try:        
        aLinkDic = {}
        
        with open(in_file, 'r') as f_in:
            lines = f_in.readlines()
        
            for line in lines:
                if len(line) != 0: 
                    line = line.strip()
                    if line[0] != ';': #if line is not a cube commented-out line
                        if re.match('LINE NAME',line): #if it's the start of a new transit line feature
                            #line_attrs = ''
                            line_list = line.split(',') #make into comma-delimited list
                            line_name1 = line_list[0].split('=') # 'LINE NAME="AMTRCCB_A"' becomes list ['LINE NAME', '"AMTRCCB_A"']
                            line_name = line_name1[1].strip('"') #get the line name
                            line_attrs = line
                        elif line[-1] == ',': #if the line ends with a comma, it's part of the same route entry
                            line_attrs = line_attrs + line
                        else:
                            line_attrs = line_attrs + line
                            aLinkDic[line_name] = (line_attrs) #dict entry - {NAME:[NAME, TFs, HEADWAYs, node list, etc.]}
        
        link_rows = []
        node_rows = []
        
        for LineName in aLinkDic.keys():
            line_attrs = aLinkDic[LineName]
            aNodeList = []
            tfchg_list = [] #list of time factor (TF) changes
            
            tf_change = '0'
            line_level_attrnames = ['LINE NAME','TIMEFAC[1]','TIMEFAC[2]','TIMEFAC[3]',
                             'TIMEFAC[4]','TIMEFAC[5]','ONEWAY','MODE','OPERATOR',
                             'COLOR','CIRCULAR','HEADWAY[1]','HEADWAY[2]','HEADWAY[3]',
                             'HEADWAY[4]','HEADWAY[5]']
            
            line_attrs_outorder = ['LINE NAME','TIMEFAC[1]','ONEWAY','MODE','OPERATOR',
                             'COLOR','CIRCULAR','TIMEFAC[1]','TIMEFAC[2]','TIMEFAC[3]',
                             'TIMEFAC[4]','TIMEFAC[5]','HEADWAY[1]','HEADWAY[2]','HEADWAY[3]',
                             'HEADWAY[4]','HEADWAY[5]']
            
            node_attrname = 'N'
            tf_attrnames = ['TF','TIMEFAC']
            
            row_dict1 = {}
            for attr in line_attrs.split(','): #example: ['LINE NAME=LINE1','COLOR=2'...]
                attr_sp = attr.strip().split('=')
                
                if len(attr_sp) > 1:
                    attr_name = attr_sp[0]
                    attr_value = attr_sp[1].strip('"')
                    
                    if attr_name in line_level_attrnames:
                        # link_row.append(attr_value)
                        row_dict1[attr_name] = attr_value
            
                    elif attr_name == node_attrname: #for each line, the node values will be made into a list
                        firstNode = attr_value
                        aNodeList.append(firstNode)
                        tfchg_list.append(tf_change) #default aTF value is 0
                    elif attr_name in tf_attrnames: #if there's a time factor change along the route, set it to that TF value
                        #we don't want to append TF changes to the node list because they've nothing to do with route geometry???
                        tf_change = attr_value
                        tfchg_list.append(tf_change)
                else:
                    aNodeList.append(attr_sp[0])
                    tfchg_list.append(tf_change)
    
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
                    try:
                        i = int(i)
                    except ValueError:
                        try:
                            i = float(i)
                        except ValueError:
                            pass
                    finally:
                        linkrow_out.append(i)
            
                    
            link_rows.append(linkrow_out)
            
            # generate node-level table
            node_seq = 0
            for node in aNodeList:
                if node[0] == '-': #if node has negative value, it's not a stop
                    stop = 'N'
                    node = node.strip('-') #take minus symbol out of node id
                else:
                    stop = 'Y'
        		
                node_row = [LineName, node, node_seq, stop, tf_change]
                node_rows.append(node_row)
                tf_change = tfchg_list[node_seq]
                
                node_seq += 1 #node order for line (1st, 2nd, etc.)
        
        return link_rows, node_rows
    except KeyError:
        print("Key error. The line after {} may not have all of its line-level fields. Please check." \
              .format(LineName))
            
def get_hwynet_nodepairs(in_hwylink_dbf):
    fld_node_a = 'A'
    fld_node_b = 'B'
    
    linkdbfobj = DBF(in_hwylink_dbf)
    
    linkdbfobj.load()
    
    # output will be list of node pairs
    out_pair_list = [[row[fld_node_a], row[fld_node_b]] for row in linkdbfobj.records]
    
    return out_pair_list


def pair_check(in_node_pair, master_list):
    '''checks to see if either (A, B) or (B, A) is in the highway network'''
    pair_raw = in_node_pair # (a, b)
    pair_rev = [in_node_pair[1], in_node_pair[0]] # (b, a)
    
    raw_in_net = pair_raw in master_list
    rev_in_net = pair_rev in master_list

    if raw_in_net:
        result = "OK" # can skip, no missing links or instances of going wrong way
    elif raw_in_net is False and rev_in_net is True:
        result = "CHECK_DIR" # reverse link exists, so either transit line is coded as 2-way or it is going wrong way on the link
    elif raw_in_net + rev_in_net == 0:
        result = "LINK_MISSING" # link doesn't exist and needs to fixed
    else:
        raise Exception("Execution error in pair_check function")
        
    # if pair_raw == (9295, 9293): import pdb; pdb.set_trace()
    
    return result


def check_tranlinks(tranline_txt_file, hwylink_dbf, check_for_wrongways=False):
    #linkrows = list of lists; each list containing line-level attributes for transit routes
    #noderows = list of lists; each list is a node within each line with some line-level attributes
    linkrows, noderows = make_link_node_lists(tranline_txt_file)
    hwy_nodepairs = get_hwynet_nodepairs(hwylink_dbf)

    # {line name: line mode (1=rail, 2=exp bus, 3=local bus)}
    line_mode_dict = {row[0]: int(row[3]) for row in linkrows}
    
    # {line name: [list of nodes] if line mode != 1}
    line_nodes_dict = {}
    
    for row in noderows:
        line_name = row[0]
        node_id = abs(int(row[1])) # must be positive number since all hwy node IDs are positive
        if line_mode_dict[line_name] > 1: # only check transit node pairs that are on bus lines, which use hwy net
            if line_nodes_dict.get(line_name) is None:
                line_nodes_dict[line_name] = [node_id]
            else:
                line_nodes_dict[line_name].append(node_id)
        else:
            continue
        
    output_data_list = []
    output_df_headers = ["NAME", "A", "B", "LINK_HWYNET_STATUS"]
    for line_name, node_list in line_nodes_dict.items():
        # list of lists containing node pairs: [[1, 2], [3, 4]...]
        line_pair_list = [[node_list[i], node_list[i + 1]] for i, v in enumerate(node_list) \
                     if (i + 1) <= (len(node_list)-1)]

        for trn_node_pair in line_pair_list:
                        # 1 = okay, 2 = may be wrong way, 3 = no link between nodes in pair
            try:
                pair_status = pair_check(trn_node_pair, hwy_nodepairs)
            except:
                import pdb; pdb.set_trace()

            if pair_status != "OK":
                tnode_a = trn_node_pair[0]
                tnode_b  = trn_node_pair[1]
                pair_data_list = [line_name, tnode_a, tnode_b, pair_status] # [line_name, anode, bnode, status]
                output_data_list.append(pair_data_list)

    df_outputs = pd.DataFrame(output_data_list, columns=output_df_headers)
    return df_outputs        

#======================RUN SCRIPT============================================

if __name__ == '__main__':
    tranline_in = r"Q:\SACSIM23\Network\Cube\TransitLIN\pa35_tranline.lin"
    network_links_dbf = r"Q:\SACSIM23\Network\SM23GIS\DBF\masterLINK08172021.dbf"

    output_csv_dir = r"Q:\SACSIM23\Network\Temp"

    flag_wrong_ways = False
    
    # ===================BEGIN SCRIPT=================================
    date_sufx = str(dt.date.today().strftime('%m%d%Y_%H%M'))
    out_csv = os.path.join(output_csv_dir, f"TrnNodePairCheck{date_sufx}.csv")
    
    df_out = check_tranlinks(tranline_in, network_links_dbf, check_for_wrongways=flag_wrong_ways)
    df_out.to_csv(out_csv, index=False)

    print(f"""Success! Output CSV is {out_csv}.
        \n Note that Amtrak rail lines, due to having the mode tag of commute buses,
        will erroneously show up as having links in the highway network. You can IGNORE
        these flags as they are not actually missing. Rail links are stored in the transit_links.csv file.""")
    # import pdb; pdb.set_trace()
