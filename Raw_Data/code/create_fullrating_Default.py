import sys
import os
import xlrd
import pandas as pd
import datetime as dt
import numpy as np
import re

#os.chdir("/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Raw_Data/code")

# Do adjustments to the rating categories.

def adj_rating(val):
    if re.match(".*u",val):
        val = re.search("(.*)(u)",val)[1]
    elif re.match(".*pi",val):
        val = re.search("(.*)(pi)",val)[1]
    else:
        val=val
    return val

def clean_moody(val):
    #print(val)
    if val=="#N/A Invalid Security":
        val = np.nan
    if val=="WR":
        val = np.nan
    if val=="NR":
        val = np.nan
    if val=="WD":
        val =  np.nan
    if val=="SD":
        val = "D"
    if val=="RD":
        val = "D"

    if not str(val)=="nan":
        if re.match(".*\s\*\W?",val):
            newv =  adj_rating(re.search("(.*)(\s\*\W?)",val)[1])
            if re.match("\(P\).*",newv):
                newv = adj_rating(re.search("(\(P\))(.*)",newv)[2])


        else:
            if re.match("\(P\).*",val):

                newv = adj_rating(re.search("(\(P\))(.*)",val)[2])
            else:

                newv=adj_rating(val)
    else:
        newv=val
    return newv

# Read data
df = pd.read_excel("../original/Default_ratings_values.xlsx")
df.rename(columns={'Unnamed: 0':'isin', 'Unnamed: 1':'date', 'Unnamed: 2':'bb_ticker'},inplace=True)

df['Mdy_senuns']=df['RTG_MDY_SEN_UNSECURED_DEBT'].apply(lambda x: clean_moody(x))
df['Mdy_issuer']=df['RTG_MDY_ISSUER'].apply(lambda x: clean_moody(x))
df['Mdy_ltlc']=df['RTG_MDY_LT_LC_DEBT_RATING'].apply(lambda x: clean_moody(x))
df['SP_ltlc']=df['RTG_SP_LT_LC_ISSUER_CREDIT'].apply(lambda x: clean_moody(x))
df['Fitch_ltlc']=df['RTG_FITCH_LT_ISSUER_DEFAULT'].apply(lambda x: clean_moody(x))
df['Fitch_senuns']=df['RTG_FITCH_SEN_UNSECURED'].apply(lambda x: clean_moody(x))

df_clean= df[['isin', 'date','Mdy_senuns','Mdy_issuer','Mdy_ltlc','SP_ltlc','Fitch_ltlc','Fitch_senuns']].copy()

rating_trans = {"Aaa":"AAA","Aa1":"AA+","Aa2":"AA","Aa3":"AA-","A1":"A+",	"A2":"A","A3":"A-","Baa1":"BBB+","Baa2":"BBB","Baa3":"BBB-","Ba1":"BB+","Ba2":"BB","Ba3":"BB-","B1":"B+","B2":"B","B3":"B-","Caa1":"CCC+","Caa2":"CCC","Caa3":"CCC-","Ca":"C"}
df_clean.replace({"Mdy_issuer":rating_trans},inplace=True)
df_clean.replace({"Mdy_senuns":rating_trans},inplace=True)
df_clean.replace({"Mdy_ltlc":rating_trans},inplace=True)

# Create numerical rating dictionary
ratings = ["AAA","AA+","AA","AA-","A+","A","A-","BBB+","BBB","BBB-","BB+","BB","BB-","B+","B","B-","CCC+","CCC","CCC-","CC","C","D"]

ratingclass={}
for idx,element in enumerate(ratings):
    #print({element:idx})
    ratingclass.update({element:idx})

# Numerical rating
for element in ['Mdy_senuns','Mdy_issuer','Mdy_ltlc','SP_ltlc','Fitch_ltlc','Fitch_senuns']:
    name = f"N_{element}"
    #print(name)
    df_clean[name] = df_clean[element]
    df_clean.replace({name:ratingclass},inplace=True)


# Get mean rating for Mooody's and Fitch
df_mdy = df_clean[['N_Mdy_senuns','N_Mdy_issuer','N_Mdy_ltlc']].mean(axis=1,skipna=True)
df_fitch = df_clean[['N_Fitch_ltlc','N_Fitch_senuns']].mean(axis=1,skipna=True)

df_clean = pd.concat([df_clean,df_mdy,df_fitch],join="inner",axis=1)
df_clean.rename(columns={0:"N_mdy_mean",1:"N_fitch_mean"},inplace=True)
df_mean = df_clean[['N_SP_ltlc',"N_mdy_mean","N_fitch_mean"]].mean(axis=1)

df_clean = pd.concat([df_clean,df_mean],join="inner",axis=1)

df_clean["N_mean_rating"] = df_clean[0].apply(lambda x: round(x,0))
df_clean.drop(columns={0},inplace=True)

inv_map = {v: k for k, v in ratingclass.items()}

df_clean["Mean_rating"] = df_clean["N_mean_rating"]
df_clean.replace({"Mean_rating":inv_map},inplace=True)

df_clean['dateformat']=pd.to_datetime(df_clean['date'])

df_clean.to_csv("../data/Default_fullrating.csv",index=False)
print("File processed")
