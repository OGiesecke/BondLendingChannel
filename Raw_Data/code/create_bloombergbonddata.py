#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Feb 10 18:00:44 2020

@author: olivergiesecke
"""


import os
import xlrd
import pandas as pd
import datetime as dt
import numpy as np



# =============================================================================

# Give the location of the file

def extract_sheet(sheet):
    row = 0
    column = 0


    bond_features = 12
    firstentry = 4

    sent_topics_df = pd.DataFrame()
    for i in range(101):
        emptylist=[]
        isin  = sheet.cell_value(row, column)
        #print(isin)
        k=firstentry
        while k < sheet.nrows:
            #print(k)
            if sheet.cell_value(k,column)=="":
                break
            else:
                emptydict={}
                emptydict.update({"isin":isin})
                max_col = min(bond_features,sheet.ncols-column )
                #print(max_col)
                for kk in range(max_col):
                    header = sheet.cell_value(firstentry-1, column + kk)
                    entry= sheet.cell_value(k, column + kk)
                    #print(entry)
                    emptydict.update({header:entry})

            k=k+1
            #print(emptydict)
            emptylist.append(emptydict)

        sent_topics_df = sent_topics_df.append(pd.DataFrame(emptylist), ignore_index=True)


        column=column+bond_features
        #print(column)

        if column >= sheet.ncols:
            break

    return sent_topics_df



def create_data(workbooks):

    data = pd.DataFrame()
    for workbook in workbooks:
        print(f"Work on workbook: {workbook}")
        wb = xlrd.open_workbook(f"../original/{workbook}")

        sheets = wb.sheet_names()
        for sheet in sheets:
            print(f"Process sheet: {sheet}")
            sheetobj=wb.sheet_by_name(sheet)
            newdata=extract_sheet(sheetobj)
            data = data.append(newdata,ignore_index=True)



    data.columns
    data.drop(columns=["","#IssuerName.ORIG_IDS:0"],inplace=True)
    data.rename(columns={'#AMT':'amount', '#CPN':'coupon','ID':'cusip',
                         '#IssuerName': 'issuer', '#Maturity':'maturity',
                         '#issue':'issue_date', 'BB_COMPOSITE':'comp_rating',
                         'CALLABLE':'callable', 'CALLED':'called', 'CRNCY':'ccy',
                         'SERIES':'bondtype'}, inplace=True)

    data['real_maturity'] = pd.TimedeltaIndex(data['maturity'], unit='d') + dt.datetime(1899,12,30)
    data['real_issue_date'] = pd.TimedeltaIndex(data['issue_date'], unit='d') + dt.datetime(1899,12,30)

    return data

def main():
        ### CONSOLIDATED DATA ###
    workbooks = ["Default_cons_fistbatch.xlsx","Default_cons_secondbatch.xlsx","Default_cons_thirdbatch.xlsx"]
    data = create_data(workbooks)
    data.to_csv("../data/bloombergbonddata_consolidated.csv")
    print("Consolidated data created")


        ### UNCONSOLIDATED DATA ###
    workbooks = ["Default_uncons_valuesupd.xlsx"]
    data = create_data(workbooks)
    data.to_csv("../data/bloombergbonddata_unconsolidated.csv")
    print("Unconsolidated data created")

if __name__ == "__main__":
    main()
