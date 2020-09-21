*************************************************************
* Purpose: Performs 1yr rolling CAPM beta regressions
* Author: Oliver Giesecke
* Last Update: 11/24/2019
*************************************************************

cap log close 
clear all 
set more off , permanently


* Set directories 
local 1 "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Int_Data/code"
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"

*************************************************************
*** Data Set Construction and Estimation
*************************************************************


use  ../data/MergedCleaned_MarketData.dta,clear
keep EUSWEA EUSWE1 EUSWEC_T rMSCIEMUpi date MP_event
tempfile shortrates
save `shortrates'

use ../data/Default_stock_return_ext.dta,clear
merge m:1 date using `shortrates', nogen

gen rf_rate=((EUSWE1/100)/360)

* Create excess returns
gen ex_return=return-rf_rate
gen ex_market=rMSCIEMUpi/100-rf_rate


* Organize the data
gen date_b=date-365
order date*
format date_b %td
format date %td
sort isin date
drop if isin==""

* Requires to install asreg: ssc install asreg
bys isin: asreg ex_return ex_market , window(date 365)

gen abn_return = ex_return -  _b_ex_market * ex_market

keep date isin abn_return _b_ex_market
rename _b_ex_market CAPMbeta

save  ../data/Default_abn_return,replace



