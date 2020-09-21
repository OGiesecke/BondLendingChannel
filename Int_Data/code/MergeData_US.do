cap log close 
clear all 
set more off , permanently

* Set directories 
*global path "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Int_Data/code"
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"
	
*************************************************
** Merge US Data
*************************************************

* Take the cleaned stock market file
use ../data/US_stock_return.dta,clear
gen date_q = qofd(date)
drop if return ==.

* Merge the sample definition (firm x quarter)
merge m:1 isin date_q using  ../data/FQ_US_Sample.dta
keep if _merge==3
drop _merge

gen yr_adj=year-1

* Merge with worldscope
merge m:1 isin yr_adj using ../data/worldscope_bs.dta
keep if _merge==3
drop _merge

* Get the sic code (avoid empty entries by merging only by isin not by isin year)
drop sic
merge m:1 isin using ../data/sic_classification.dta
drop if _merge==2
drop _merge

* Add Capital IQ Data 
merge m:1 d6cusip yr_adj using ../data/Capital_IQ_US.dta
drop if _merge==2
gen d_capIQ=_merge==3
drop _merge

* Merge with rating data
merge m:1 yr_adj isin using ../data/US_fullratingpanel
drop if _merge==2
drop _merge

* Add US MP shock -- Emi and Jon shock
merge m:1 date using ../data/US_FED_emi_jon_data_Clean.dta
gen MP_event_alt=0
replace MP_event_alt=1 if _merge==3
drop if _merge==2
drop _merge


* Add default probability
*merge m:1 year isin using ../data/US_defprobability
*drop if _merge==2
*drop _merge

* Add the Jarocinsky and Karadi (2019) shock series
merge m:1 date using ../data/JK_usdata
drop if _merge==2
drop _merge

* Add marketvalue
merge m:1 isin yr_adj using ../data/US_marketvalue.dta
drop if _merge==2
drop _merge

* Add nation
merge m:1 isin using ../data/US_nation.dta
drop if _merge==2
drop _merge

** Add duration
merge m:1 isin yr_adj using ../data/US_IBES_LTG
drop if _merge==2
drop _merge

* merge with accouting based duration measure
merge m:1 yr_adj isin using ../data/Matlab_impldur
drop if _merge==2
drop _merge 


gen date_m = mofd(date)
merge m:1 date_m using ../data/US_cpi.dta
drop if _merge==2
drop _merge 


save ../data/MergedData_US_Sample,replace
