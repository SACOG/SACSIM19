import arcpy

# Work Order 
NumberworkOrder = "1103612"
# 
# # Name the Append and Target Layer (target layer is named in the ArcGIS Pro Map)
append_layer="T:/GIS/Projects/GIS/WorkOrderTools/MapDocuments/WorkOrderTesting/Default.gdb/WO" \
    +workOrder+"/point"target_layer="Consumer_SQL02"fieldmappings = arcpy.FieldMappings()
    
# Like when you manually choose a layer in the toolbox and it adds the fields to gridfieldmappings.addTable(target_layer)fieldmappings.addTable(append_layer)
# 
# # Lets map fields that have different names!
list_of_fields_we_will_map = []

list_of_fields_we_will_map.append(( append layer field name, target layer field name)list_of_fields_we_will_map.append(('esMapName', 'WMMAPNAME'))list_of_fields_we_will_map.append(('esPhasing', 'WMPHASING'))list_of_fields_we_will_map.append(('esUplineFeeder', 'FEEDER'))for field_map in list_of_fields_we_will_map:    
# Find the fields index by name.    
# field_to_map_index = fieldmappings.findFieldMapIndex(field_map[0])    
# # Grab "A copy" of the current field map object for this particular field    
# field_to_map = fieldmappings.getFieldMap(field_to_map_index)    
# # Update its data source to add the input from the the append layer    
# field_to_map.addInputField(append_layer, field_map[1])    # 
# We edited a copy, update our data grid object with it    
# fieldmappings.replaceFieldMap(field_to_map_index, field_to_map)
# Create a list of append datasets and run the the tool - the "1" at the end is for the subtype.inData = [append_layer]arcpy.Append_management(inData, target_layer, "NO_TEST", fieldmappings, "1")‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍‍