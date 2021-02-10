# -*- coding: utf-8 -*-
"""
Created on Tue Feb  9 10:31:04 2021

@author: dconly
"""

import os

script_dir = os.getcwd()

print(f"if nothing else specified, this script is running in {script_dir}")

# "subfolder" is a sub-folder of the folder in which the script is running
sd1 = "sql_bcp"

out_txt = os.path.join(sd1,"test.txt")
with open(out_txt, 'w') as f:
    f.write('this is a line')
    
    
print('\n------\n')
out_txt_fullpath = os.path.abspath(out_txt)
print(f"wrote line of text to newly created {out_txt_fullpath}")