# Title: CalcFieldsFast.py
# Author: Kyle Shipley
# Last Modified: 7/26/18

import arcpy, time, sys

#Insert Update DA Cursor with indexed fields,
#  include of addional fields to add.
def LoadUCursor(fc,flist=None):
    """Important note: Function creates two outputs, also only opens cursor,
     no "with" function to automatically close,
      remeber to delete cursor and fieldlist when finished"""
    fields = [field.name for field in arcpy.ListFields(fc)]
    if flist:
        for f in flist:
            fields.append(f)
    cursor = arcpy.da.UpdateCursor(fc,fields)
    flist = cursor.fields
    return cursor, flist

############################################


def do_count_analysis(inFile,UpdateL=None):
    try:
        #start
        start_time = time.time()
        arcpy.AddMessage("Start 'Calc' Process: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
        UCursor, fieldlist = LoadUCursor(inFile)
        print(fieldlist)

        for row in UCursor:
            if UpdateL:
                for L in UpdateL:
                    row[fieldlist.index(L[0])] = row[fieldlist.index(L[1])]

            #row[fieldlist.index('fieldname')] = 'Value'
            #row[fieldlist.index('fieldname')] = row[fieldlist.index('othervalue')]

            UCursor.updateRow(row)

        arcpy.AddMessage("Process Complete at: %s minutes ---" % (round((time.time() - start_time) / 60, 1)))
        #cleanup
        del fieldlist, row, UCursor

    except arcpy.ExecuteError:
        arcpy.AddMessage(arcpy.GetMessages(2))
    except Exception as e:
        arcpy.AddMessage(e.args[0])
        tb = sys.exc_info()[2]
        arcpy.AddMessage("An error occured on line %i" % tb.tb_lineno)
        arcpy.AddMessage(str(e))

# Main Script
if __name__ == '__main__':

    inFile = r"Q:\SACSIM19\Integration Data Summary\ILUT GIS\ILUT GIS.gdb\parcel_master05092019newTPA"
    UpdateList = [
        ['TPA_40Name', 'TPA']
    ]

    do_count_analysis(inFile,UpdateList)