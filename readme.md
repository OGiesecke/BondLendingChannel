# Replication File for "The Bond Lending Channel of Monetary Policy"
Olivier Darmouni, Oliver Giesecke, Alexander Rodnyansky

April 16, 2020

Contact: o.giesecke@columbia.edu

## Data

Data has been obtained from a variety of public and proprietary databases. The following enumeration lists the source for each:

- Index constituents for  EURO STOXX sectoral indices and S&P500 index: Datastream terminal
- Capital structure: Capital IQ Excel Plug-in, manual collection from https://www.mergentarchives.com, Capital IQ terminal and publicly available annual reports.
- Daily stock prices: Datastream terminal
- Market capitalization: Datastream terminal
- ECB HPI: ECB Statistical Data Warehouse (SDW), series as indicated.
- US CPI: https://fred.stlouisfed.org, mnemonic: CPIAUCSL_NBD20150101
- BIS total debt securities outstanding: Debt securities statistics (DEBT_SEC2), http://stats.bis.org:8089/statx/srs/table/c1?f=csv
- US / EUR quarterly exchange rate: https://fred.stlouisfed.org, mnemonic: CCUSMA02EZQ618N
- Jarocinski, Karadi shock series: Jarociński, Marek, and Peter Karadi. 2020. "Deconstructing Monetary Policy Surprises—The Role of Information Shocks." American Economic Journal: Macroeconomics, 12 (2): 1-43.
- Altavilla shock series: Altavilla, Carlo, Luca Brugnolini, Refet S. Gürkaynak, Roberto Motto, and Giuseppe Ragusa. "Measuring euro area monetary policy." Journal of Monetary Economics 108 (2019): 162-179.
- Nakamura and Steinsson shock series: Nakamura, Emi, and Jón Steinsson. "High-frequency identification of monetary non-neutrality: the information effect." The Quarterly Journal of Economics 133, no. 3 (2018): 1283-1330.
- Balance sheet information: Worldscope (annual) and Worldscope (quarterly) from WRDS
- Credit ratings: Bloomberg terminal
- Analyst forecasts: Thomson Reuters IBES
- OIS swaps: Bloomberg terminal
- Bond yields: Bloomberg terminal, ticker as indicated
- Monetary policy target rates:  ECB Statistical Data Warehouse (SDW), series as indicated
- Aggregate Lending Volume and Rate: ECB Statistical Data Warehouse (SDW), series as indicated.
- S&P worldwide credit rating panel: WRDS
- Individual bond issues: Bloomberg terminal
- Aggregate security issues Euroarea: https://www.bis.org/statistics/secstats.htm

## Software requirements

The following scripts have been executed with Matlab R2019a, Stata/SE 16.1 and Python 3.7.

## Data assembly

The data assembly consists of multiple scripts and is conducted in the directory Raw_Data. The file *run_US_Default.py* in Raw_Data/code runs the entire directory. The file executes the following scripts. The data output is collected in a separate directory Raw_Data/data that is also created in the process. Finally the directory Raw_Data/log_file is created to collect all the log files.

```
- CreateSharedData.do
- CreateData_US.do
- CreateData_Default.do
- create_bloombergbonddata.py
- create_fullrating_Default.py
- create_fullrating_US.py
```

## Data cleaning and merging

The data cleaning and merging consists of multiple scripts and is conducted in the directory Int_Data. The file *runcleaning_Default_US.py* in Int_Data/code runs the entire directory consisting of following scripts. The data output is collected in a separate directory Int_Data/data that is also created in the process. Finally the directory Int_Data/log_file is created to collect all the log files.

```
- DefineOutput_Default.do
- MergeData_Default.do
- CleanData_Default.do
- DefineOutput_US.do
- MergeData_US.do
- CleanData_US.do
- Define_MarketData.do
- MergeMarketData.do
- Clean_MarketData.do
- Duration_measure_totsample.do
- ImpliedEquityDuration.m
- fn_duration.m
- fn_vector.m
- Default_beta_regressions.do
- Distance_to_Default_Default.do
- Distancetodefaultmodel_Default.m
- fn_value1.m
```

## Analysis

The file *Run_Analysis.py* runs the analysis and creates all tables and figures of the paper. The output is collected in a separate directory Analysis/output that is also created in the process. Finally the directory Analysis/log_file is created to collect all the log files. It executes the following files:

```
- Rating_Downgrades.do
- DoLP_Default.do
- DoAnalysis_US.do
- DoAnalysis_Default.do
- Do_MacroTimeSeries.do
- Do_lp_bloombergbond.do
```

## Final Sample

The file *Default_finalsample.csv* in the directory Data_Files/ contains the final sample of the EURO STOXX sectoral indices constituents--excluding financials and utilities and removing some observation for the lack of data.

## Manually collected capital structure data

The file *CapitalStructure_manual.xlsx* in the directory Data_Files/ contains the manually collected market debt data for the years 2000 and 2001.
