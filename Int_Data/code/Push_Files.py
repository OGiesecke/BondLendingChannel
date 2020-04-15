#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jun  4 21:44:51 2019

@author: olivergiesecke
"""

###############################################################################
### Import Python packages ###
import os
import subprocess
import logging
import sys

###############################################################################

## Push files from the Int_Data folder

def query_yes_no(question, default="yes"):
    """Ask a yes/no question via raw_input() and return their answer.

        "question" is a string that is presented to the user.
        "default" is the presumed answer if the user just hits <Enter>.
        It must be "yes" (the default), "no" or None (meaning
        an answer is required of the user).

        The "answer" return value is True for "yes" or False for "no".
        """
    valid = {"yes": True, "y": True, "ye": True,
        "no": False, "n": False}

    sys.stdout.write(question+" Enter 'yes' or 'no':")
    choice = input().lower()
    if choice in valid:
        return valid[choice]
    else:
        print("Invalid response")

# Local projection data
answer=query_yes_no("Push all files from processed Raw_Data to Int_Data?",None)
if answer==True:
    try:
        os.system('cp ../../Raw_Data/data/* ../data/')
        print('All data pushed')
    except:
        print('Error')

answer=query_yes_no("Delete all data in Raw_Data/data/",None)
if answer==True:
    try:
        os.system('rm ../../Raw_Data/data/*')
        print('Raw_Data/data/ cleaned')
    except:
        print('Error')

print("Process finished")
