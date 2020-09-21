*************************************************************
* Purpose: Prepares Data for Distance to Default Measure
* Author: Oliver Giesecke
* Last Update: 07/04/2019
*************************************************************

cap log close 
clear all 
set more off , permanently

* Set directories 
* global path "/Users/olivergiesecke/Dropbox/NewMP/Int_Data/code"
display `"this is the path: `1'"'
global path "`1'"

display "${path}"
cd "$path"


*************************************************************
*** Distance to Default ***

use ../data/Default_stock_return_ext.dta,clear
drop yr_adj
gen cov_year = year

merge m:1 isin cov_year using ../data/Default_finalsample_FY
keep if _merge==3
drop _merge

* Merge with worldscope on CONTEMPORANEOUS BASIS
merge m:1 isin year using ../data/worldscope_bs.dta
keep if _merge==3
drop _merge

* Add the market data
merge m:1 date using ../data/MergedCleaned_MarketData.dta
drop if _merge==2
drop _merge

sort isin date

replace EUSWE1=EUSWE1[_n+1] if EUSWE1==.
replace EUSWE1=EUSWE1[_n+1] if EUSWE1==.
replace EUSWE1=EUSWE1[_n+1] if EUSWE1==.
replace EUSWE1=EUSWE1[_n+1] if EUSWE1==.
replace EUSWE1=EUSWE1[_n+1] if EUSWE1==.
replace EUSWE1=EUSWE1[_n+1] if EUSWE1==.
replace EUSWE1=EUSWE1[_n+1] if EUSWE1==.

merge m:1 isin year using ../data/shares_outstanding_clean
keep if _merge==3
drop _merge

keep date isin return  currliab ldebt tot_liabilities tdebt year price sh_out EUSWE1 

* Do end of year indicator
sort isin year 
by isin year: egen lday=max(date)
by isin year: gen eoy=(date==lday)
drop lday

drop if currliab==. | tot_liabilities==.
drop if sh_out==.
rename return xReturn
replace EUSWE1=EUSWE1/100

egen nreturns= count(xReturn),by(isin year) 
drop if nreturns<250
sort isin date

	* Note all units are in '000 now.
foreach var of varlist currliab	ldebt	tdebt	tot_liabilities{
replace `var'=`var'/1000
}

replace EUSWE1=EUSWE1[_n+1] if EUSWE1==.

*****************************************************
	*** Full sample ***
egen id =group( isin)

* Check for missing interest rate
mdesc EUSWE1
codebook id

* Matlab export 
export delimited using ../data/Default_fullsample,replace

** Call Matlab file
shell /Applications/MATLAB_R2019a.app/bin/matlab -nodesktop -nosplash -r "Distancetodefaultmodel_Default"

*****************************************************
	*** Create Output ***

import delimited using ../data/Default_KMVmodelresults.csv,clear 
label var defprob "Default probability (KMV)"
label var dtd "Distance-to-default (KMV)"
gen yr_adj=year
save ../data/Default_defprobability,replace




/****************************************************
	*** Export test sample
preserve
	* Do example with two companies
keep if  isin=="FR0000121667" | isin=="AT000000STR1"

egen id =group( isin)

*** CHECK FOR MISSING INTEREST RATES
mdesc EUSWE1

* Matlab export 
* export delimited using matlab/dd_example,replace
restore
****************************************************
