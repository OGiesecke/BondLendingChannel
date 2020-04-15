###############################################################################
### Import Python packages ###
import os
import subprocess
import logging
import sys
import pathlib

###############################################################################


## Set the working directory
directory=str(pathlib.Path().absolute())
print(f"The script is executed on path: {directory}")
push = 1

## Create folders if not present
if not os.path.isdir("../data/"):
    os.mkdir("../data/")
    print("data folder created")
if not os.path.isdir("../output/"):
    os.mkdir("../output/")
    print("output folder created")
if not os.path.isdir("../log_file/"):
    os.mkdir("../log_file/")
    print("log_file folder created")

## Clear old files and push the data from the Int_Data folder
if push ==1:
    os.system('rm  ../data/*')
    print("Data and outputs cleared")
    os.system('cp ../../Int_Data/data/Firm_Return_WS_Bond_Duration_Data_Default_Sample.dta ../data')
    print('Default sample data pushed')
    os.system('cp ../../Int_Data/data/Firm_Return_WS_Bond_Duration_Data_US_Sample.dta ../data')
    print('US sample data pushed')

## Clear output and old version of the data
try:
    os.system('rm ../output/*')
except:
    print('No outputs available')

## Run the analysis with the master data
dofile = 'DoAnalysis_Default.do'
cmd = ["stata-se", '-b', "do", dofile, directory, "&"]
subprocess.run(cmd)
print('Default Analysis is done')

dofile = 'DoAnalysis_US.do'
cmd = ["stata-se", '-b', "do", dofile, directory, "&"]
subprocess.run(cmd)
print('US Analysis is done')

# =============================================================================
# dofile = 'Rating_Downgrades.do'
# cmd = ["stata-se", '-b', "do", dofile, directory, "&"]
# subprocess.run(cmd)
# print('Rating downgrades is done')
#
# =============================================================================

dofile = 'DoLP_Default.do'
cmd = ["stata-se", '-b', "do", dofile, directory, "&"]
subprocess.run(cmd)
print('Local projection is done')

dofile = 'Do_lp_bloombergbond.do'
cmd = ["stata-se", '-b', "do", dofile, directory, "&"]
subprocess.run(cmd)
print('Bond LP is done')

dofile = 'Do_MacroTimeSeries.do'
cmd = ["stata-se", '-b', "do", dofile, directory, "&"]
subprocess.run(cmd)
print('Macro time series is done')

## Move the log files
try:
    os.system('mv *.log ../log_file/')
except:
    print('No log file')
