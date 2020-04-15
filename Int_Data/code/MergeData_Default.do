cap log close 
clear all 
set more off , permanently

* Set directories 
*global path "/Users/olivergiesecke/Dropbox/NewMP/Int_Data/code"
display `"this is the path: `1'"'
global path "`1'"


display "${path}"
cd "$path"
	
*************************************************
** Merge Default Data
*************************************************

* Take the cleaned stock market file
use ../data/Default_stock_return_ext.dta,clear

gen date_q = qofd(date)
drop if return ==.

* Merge the sample definition (firm x year X quarter)
merge m:1 isin date_q using ../data/FQ_Default_Constituents_ext.dta
keep if _merge==3
drop _merge

egen tag_IQ=tag(isin date_q) 
tab year if  tag_IQ 

* Merge with worldscope
merge m:1 isin yr_adj using ../data/worldscope_bs.dta
keep if _merge==3
drop _merge
tab year if  tag_IQ 

* Get the sic code (avoid empty entries by merging only by isin not by isin year)
drop sic
merge m:1 isin using ../data/sic_classification.dta
drop if _merge==2
drop _merge

* Add Capital IQ Data 
merge m:1 isin yr_adj using ../data/Capital_IQ_Default_Clean_ext.dta
drop if _merge==2
gen d_capIQ=_merge==3
drop _merge

tab year if  tag_IQ & d_capIQ

* Add the shock data
merge m:1 date using ../data/MergedCleaned_MarketData.dta
drop if _merge==2
drop _merge

* Merge with rating data
//merge m:1 yr_adj isin using ../data/Default_sandp_rating
merge m:1 yr_adj isin using ../data/Default_fullratingpanel
drop if _merge==2
drop _merge

* Merge with default probability data
merge m:1 isin yr_adj isin using ../data/Default_defprobability
drop if _merge==2
drop _merge

* merge the Jarocinsky and Karadi (2019) shock series
merge m:1 date using ../data/JK_eadata
drop if _merge==2
gen JK_event = _merge==3
drop _merge

* merge the Altavilla et al (2019) shock series
merge m:1 date using ../data/Altavilla_EAdata
drop if _merge==2
gen Altavilla_event = _merge==3
drop _merge

merge m:1 date using ../data/Altavilla_EAdataconf
drop if _merge==2
drop _merge

* merge country from worldscope
merge m:1 isin using ../data/nation
drop if _merge==2
drop _merge

* merge in the price index data
gen date_m = mofd(date)
format date_m %tm
merge m:1 date_m using ../data/EA_priceindex
drop if _merge==2
drop _merge

* merge with analyst growth measure
merge m:1 yr_adj isin using ../data/Default_IBES_LTG_ext
drop if _merge==2
drop _merge

* merge with accouting based duration measure
merge m:1 yr_adj isin using ../data/Matlab_impldur
drop if _merge==2
drop _merge 

* add marketvalue measure
merge m:1 isin yr_adj using ../data/Default_marketvalue.dta
drop if _merge==2
drop _merge

* merge with age from Worldscope
merge m:1 yr_adj isin using ../data/Default_WS_age
* merge with age from Orbis
*merge m:1 yr_adj isin using ../data/Default_age
drop if _merge==2
drop _merge 

* merge with equity duration
merge m:1 yr_adj isin using ../data/Default_equityvol
drop if _merge==2
drop _merge


save ../data/MergedData_Default_Sample,replace

