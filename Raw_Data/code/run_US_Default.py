
###############################################################################
### Import Python packages ###
import os
import subprocess
import logging
import pandas as pd
import numpy as np
import pathlib

###############################################################################
def run_stata(dofile,directory):
    cmd = ["stata-se", '-b', "do", dofile, f"\"{directory}\"", "&"]
    subprocess.run(cmd)

## Set the working directory 
directory=str(pathlib.Path().absolute())
print(f"The script is executed on path: {directory}")

## Create folders if not present
if not os.path.isdir("../data/"):
    os.mkdir("../data/")
    print("data folder created")
if not os.path.isdir("../log_file/"):
    os.mkdir("../log_file/")
    print("log_file folder created")


## Setup the log file
logging.basicConfig(filename='logfile.log',format='%(asctime)s %(message)s',level=logging.DEBUG)
logging.info('start bash')

## Clear output and the intermediary files
try:
    os.system('rm -r ../data/*')
    os.system('rm -r ../log_file/*')
except:
    print("no pre-existing files")

## Generate the data from the rawdata

os.system("python create_bloombergbonddata.py")

os.system("python create_fullrating_Default.py")

os.system("python create_fullrating_US.py")

dofile = 'CreateData_US'
run_stata(dofile,directory)

dofile = 'CreateData_Default'
run_stata(dofile,directory)

dofile = 'CreateSharedData'
run_stata(dofile,directory)

## Move all the log files
os.system('mv *.log ../log_file')

logging.info('process completed ')

print("Process completed")
