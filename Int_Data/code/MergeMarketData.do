cap log close 
clear all 
set more off , permanently

* Set directories 
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"


*************************************************
** Merge Market Data
*************************************************

use ../data/Int_Equity1,clear
merge 1:1 date using ../data/fff_6m
drop _merge
merge 1:1 date using ../data/Int_Equity2
drop _merge
merge 1:1 date using ../data/Int_AddOIS
drop _merge
merge 1:1 date using ../data/Int_Swap3m
drop _merge
merge 1:1 date using ../data/OIS
drop _merge
merge 1:1 date using ../data/OIS_M
drop _merge
merge 1:1 date using ../data/US_riskfree
drop _merge
merge 1:1 date using ../data/OIS1m
drop _merge
merge 1:1 date using ../data/OIS1y
drop _merge
merge 1:1 date using ../data/MP_dates
drop _merge
merge 1:1 date using ../data/ECBRate1
drop _merge
merge 1:1 date using ../data/ECBRate2
drop _merge
*merge 1:1 date using ../../Raw_Data/data/Futures
*drop _merge
merge 1:1 date using ../data/EONIA_ECB
drop _merge
merge 1:1 date using ../data/EURIBOR
drop _merge
merge 1:1 date using ../data/EURIBOR1W
drop _merge
*merge 1:1 date using ../../Raw_Data/data/Futures_Ind
*drop _merge
merge 1:1 date using ../data/Int_EurFut
drop _merge
merge 1:1 date using ../data/Int_Equity_Indices
drop _merge
*merge 1:1 date using ../../Raw_Data/data/Int_SS_Indices
*drop _merge
merge 1:1 date using ../data/Int_SSS_Indices
drop _merge
merge 1:1 date using ../data/Int_Equity_Nat_Indices
drop _merge

merge 1:1 date using ../data/Financial_Variables
drop _merge

merge 1:1 date using ../data/Fed_shocks_Clean.dta
rename d_ois1mtl d_ff_US
gen MP_event_US=0
replace MP_event_US=1 if _merge==3
drop _merge

merge 1:1 date using ../data/US_FED_emi_jon_data_Clean
gen MP_event_USalt=0
replace MP_event_USalt=1 if _merge==3
drop _merge

gen date_mon=mofd(date)
merge m:1 date_mon using ../data/ECB_interest_loan
drop _merge

drop if date == .

foreach var of newlist EUSWEA_L EUSWEA_T  EUSWEC_L  EUSWEC_T  EUSWE1_L  EUSWE1_T{
merge 1:1 date using ../data/data_`var'
drop _merge
}

save ../data/Merged_MarketData,replace

