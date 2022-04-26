clear

global additionaldatapath = "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Extra_Analysis"
global rawdata = "/Users/olivergiesecke/Dropbox/Replication kit/Data/Final"

cd "$path"

***

use "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Analysis/data/Firm_Return_WS_Bond_Duration_Data_Default_Sample",clear
gen companyid = substr(capIQid,3,.)
destring companyid,replace
keep companyid yr_adj IQ_TOTAL_ASSETS 
duplicates drop companyid yr_adj, force
sort  companyid yr_adj
tempfile total_assets
save `total_assets'


use "$rawdata/wrds_debt_clean.dta",clear

duplicates drop companyid fyear formtype, force
keep companyid fyear formtype
sort companyid fyear formtype
bys  companyid fyear: gen new = _N
drop if formtype == "Q" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "PRER14A" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "Interim PR" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "Interim" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "Interim Amendment" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "424B3" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "424B4" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "F-1" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "F-4" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "8-K" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "10-K" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "Annual PR" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "6-K/A" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "20-F/A" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "Annual Amendment" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "Annual" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "6-K" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop if formtype == "K" & new > 1
drop new
bys  companyid fyear: gen new = _N
drop new 
tempfile unqueentries
save `unqueentries'


use "$rawdata/wrds_debt_clean.dta",clear
merge m:1 companyid formtype fyear using `unqueentries'
keep if _merge==3
drop _merge

* do an example first 
*keep if companyid == 185801
* tab fyear formtype
* keep if formtype== "20-F" | formtype== "K"
sort fyear
tab fyear
sort companyid fyear


preserve
gen floating_debt = dum_floating * dataitemvalue
gen fixed_debt = (1 - dum_floating) * dataitemvalue
collapse (sum) floating_debt fixed_debt, by(fyear)
gen sh_floating = floating_debt /( floating_debt + fixed_debt)
twoway scatter sh_floating fyear
preserve


* Get volume weighted maturity
preserve
egen tot_principal = total(dataitemvalue), by(companyid fyear)
gen sh_principal = dataitemvalue / tot_principal
gen w_maturity = sh_principal * maturity / 365
collapse (sum) w_maturity, by(companyid fyear)
rename fyear yr_adj
winsor2 w_maturity,cut(2 98) replace
histogram w_maturity
save "$additionaldatapath/debt_avgmaturity",replace
restore 

* Get floating rate share 
preserve
gen floating_debt = dum_floating * dataitemvalue
gen fixed_debt = (1 - dum_floating) * dataitemvalue
collapse (sum) floating_debt fixed_debt, by(companyid fyear)
gen share_floatingrate = floating_debt / (floating_debt + fixed_debt)
winsor2 share_floatingrate,cut(2 98) replace
rename fyear yr_adj

*collapse (mean) share_floatingrate, by( yr_adj)
*twoway scatter share_floatingrate yr_adj


save "$additionaldatapath/debt_shfloating",replace
restore 

preserve
rename fyear yr_adj
merge m:1 companyid yr_adj using `total_assets'
keep if _merge==3
drop _merge
gen debtinstrument_leverage = dataitemvalue / (IQ_TOTAL_ASSETS / 1e6)
gen exposure = dum_floating * debtinstrument_leverage * maturity / 365
collapse (sum) exposure, by(companyid yr_adj)
winsor2 exposure,cut(2 98) replace
save "$additionaldatapath/debt_exposure",replace
restore 

********************************************************************************

use "/Users/olivergiesecke/Dropbox/Replication kit/Data/Final/wrds_compustat2002-18.dta",clear
keep fyear companyid maturity_waverage 
gen mat_inyears = maturity_waverage / 365
gen yr_adj = fyear
merge 1:1 companyid yr_adj using "$additionaldatapath/debt_avgmaturity.dta"

scatter mat_inyears w_maturity
binscatter mat_inyears w_maturity,reportreg

*twoway scatter w_maturity fyear,c(l)
* principal 
* dataitemvalue
* maturity
* maturity 
