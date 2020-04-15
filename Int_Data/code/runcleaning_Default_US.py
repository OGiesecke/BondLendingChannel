
###############################################################################
### Import Python packages ###
import os
import subprocess
import logging
import time
from time import strptime, strftime
import pathlib

###############################################################################

def run_stata(dofile,directory):
    cmd = ["stata-se", '-b', "do", dofile, f"\"{directory}\"", "&"]
    subprocess.run(cmd)
    
### Set the working directory ###
directory=str(pathlib.Path().absolute())
print(f"The script is executed on path: {directory}")

dtd=1

## Setup the log file
tot_time  = time.time()
logging.basicConfig(filename='log_Default.log',format='%(asctime)s %(message)s',level=logging.DEBUG)
logging.info('start bash')

## Create folders if not present
if not os.path.isdir("../data/"):
    os.mkdir("../data/")
    print("data folder created")
if not os.path.isdir("../log_file/"):
    os.mkdir("../log_file/")
    print("log_file folder created")

## Clear output and the intermediary files
os.system('rm -r ../log_file/*')
os.system('rm -r ../data/*')
print("All data and log files deleted")

os.system('cp ../../Raw_Data/data/* ../data/')
print("Raw data pushed")

## Generate the market data from the rawdata
dofile = 'Define_MarketData'
run_stata(dofile,directory)

dofile = 'MergeMarketData'
run_stata(dofile,directory)

dofile = 'Clean_MarketData'
run_stata(dofile,directory)
print("Market data created")

## Generate the Default sample data from the rawdata
dofile = 'DefineOutput_Default'
run_stata(dofile,directory)
print("Default data defined")

## Generate the US sample data from the rawdata
dofile = 'DefineOutput_US'
run_stata(dofile,directory)
print("US data defined")

# Generate the rolling beta regressions
start_time = time.time()
dofile = 'Default_beta_regressions'
run_stata(dofile,directory)
print("Rolling betas created. It took {} min".format(str((time.time() - start_time)/60)))

if dtd==1:
    # Generate the distance to default data
    start_time = time.time()
    dofile = 'Distance_to_Default_Default'
    run_stata(dofile,directory)
    print("D-t-D created. It took {} min".format(str((time.time() - start_time)/60) ))
else:
    os.system('cp ../Default_defprobability.dta ../data/')

# Generate the duration
dofile = 'Duration_measure_totsample'
run_stata(dofile,directory)
print("Duration created")

dofile = 'MergeData_Default'
run_stata(dofile,directory)

dofile = 'CleanData_Default'
run_stata(dofile,directory)
print("Default data created")

dofile = 'MergeData_US'
run_stata(dofile,directory)

dofile = 'CleanData_US'
run_stata(dofile,directory)
print("US data created")

## Move all the log files
os.system('mv *.log ../log_file')
print("Total directory took {} min".format(str((time.time() - tot_time)/60) ))
logging.info('process completed ')
