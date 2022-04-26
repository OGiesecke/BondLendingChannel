clear

global path = "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Extra_Analysis"
global overleaf "/Users/olivergiesecke/Dropbox/Apps/Overleaf/Firms and Monetary Policy/tables_figures"

cd "$path"

* Import quarterly data 
use "comp_fund_quarterly.dta",clear

gen date_q = qofd(datadate)
format date_q %tq
sort gvkey date_q

drop if atq == 0 
duplicates tag gvkey date_q,gen(dup)
*browse if dup==1
sort gvkey date_q
by gvkey date_q: gen nn =_n
drop if dup == 1 & nn==1
drop dup nn

/*
gen lev=tdebt/assets //total debt leverage
gen long_lev=ldebt/assets // long term debt leverage
gen mnet_lev= (tdebt-cash)/assets // manual net debt leverage
gen capexoverppnet=capex/ppnet
gen capexoverassets=capex / assets[_n-1]
gen noncashassets = (assets - cash)/assets[_n-1]
gen lev_ST=sandcdebt/assets
gen fra_ST=sandcdebt/tdebt
gen cov_ratio = ebitda/intexp
gen profitability = ebitda/assets
gen DTI = tdebt/ebitda
gen NDTI = (tdebt-cash)/ebitda
gen CF = ebitda + ch_receivables - ch_inventories - ch_payables
gen networth = assets - tot_liabilities
*/

tempfile bs_raw
save `bs_raw'


	* Create panel to fill the gaps. Quarterly spacing
use "comp_fund_quarterly.dta",clear
keep gvkey
duplicates drop gvkey,force
gen date_q = qofd(date("01012000","DMY"))
format date_q %tq
gen dup = 81
expand dup
sort gvkey
by gvkey: gen n =_n-1
replace date_q = date_q + n
drop dup n
merge 1:1 gvkey date_q using `bs_raw'
drop if _merge==2
drop _merge
gen fyear = fyearq - 1 // merge leverage with lag

gen networth = atq - ltq
sort gvkey date_q

* Note that the shocks are defined backwards t-(t-1)
* Hence the changes in the balance sheet variables have to be defined forwards.
global bsitems "saleq  cheq atq dlttq ltq ppentq networth"
foreach var of varlist $bsitems{
	forvalues i=1/8{
		bys gvkey: gen d`i'q_`var'=(ln(`var'[_n+`i'-1])-ln(`var'[_n-1]))*100
	}
}

foreach var of varlist $bsitems{
	forvalues i=1/8{
		bys gvkey: gen d`i'q_alt`var'= (`var'[_n + `i' - 1] - `var'[_n-1] ) / atq[_n-1] * 100
	}
}

forvalues i=1/8{
	bys gvkey: gen d`i'q_netassets = ( (atq[_n+`i'-1] -  cheq[_n+`i'-1]) - ///
	(atq[_n - 1] -  cheq[_n - 1]))   / atq[_n-1] * 100
}

forvalues i=1/8{
	bys gvkey: gen d`i'q_capoverassets = capxy[_n+`i'-1] / atq[_n-1] * 100
}


	* Lagged growth
foreach var of varlist $bsitems{
		bys gvkey: gen l1q_`var'=ln(`var'[_n])-ln(`var'[_n-1])
		bys gvkey: gen l2q_`var'=ln(`var'[_n-1])-ln(`var'[_n-2])
		bys gvkey: gen l3q_`var'=ln(`var'[_n-2])-ln(`var'[_n-3])
}


* Create three lags of the dependent variable
sort gvkey date_q
foreach var of varlist $bsitems{
	bys gvkey: gen L1`var'=`var'[_n-1]
	bys gvkey: gen L2`var'=`var'[_n-2]
	bys gvkey: gen L3`var'=`var'[_n-3]
}



	*** Final Panel	***


merge m:1 date_q using ../Raw_Data/data/shock_weightedquarterly
drop if _merge==2
drop _merge

merge m:1 date_q using ../Int_Data/data/shock_quarterly
drop if _merge==2
drop _merge

merge m:1 date_q using ../Int_Data/data/Default_JKshock_quarterly
drop if _merge==2
drop _merge

merge m:1 date_q using ../Int_Data/data/gdp_growth
drop if _merge==2
drop _merge

merge m:1 date_q using ../Int_Data/data/inflation_yoy
drop if _merge==2
drop _merge

save broad_lp_q_balancesheet,replace

********************************************************************************

import delimited "../Raw_Data/original/dailydataset.csv",clear
gen statadate = date(date,"YMD")
format statadate %td
gen date_q = qofd(statadate)
format date_q %tq

collapse (sum) ratefactor1 conffactor1 conffactor2 conffactor3,by(date_q)

label var ratefactor1 "Target Factor"
label var conffactor1 "Timing Factor"
label var conffactor2 "Forward Guidance Factor"

tempfile factors
save `factors'

	* Import debt data
use "comp_annual_date.dta",clear
drop if at == .
duplicates tag gvkey fyear,gen(dups)
tab dups
*browse if dups ==1
drop if fyear <= 2001
sort gvkey fyear datadate
by gvkey fyear: gen nn = _n
drop if dups ==1 & nn==1
drop nn at dups
tempfile time
save `time'

use "wrds_compustat2002-18.dta",clear
gen profitability = op_profit / at 

gen lev_mb_IQ =  bonds / at 
replace lev_mb_IQ = 1 if lev_mb_IQ > 1 & lev_mb_IQ !=.
sum lev_mb_IQ, det
label var lev_mb_IQ "Bond debt over assets"

gen fra_mb_IQ =  bonds / tdebt
replace fra_mb_IQ = 1 if fra_mb_IQ > 1 & fra_mb_IQ !=.
sum fra_mb_IQ, det
label var fra_mb_IQ "Bond debt over debt"

rename td_ta lev_IQ
replace lev_IQ = lev_IQ / 100 
winsor2 lev_IQ,cut(0 99) replace
label var lev_IQ "Debt over assets"
sum lev_IQ,det

global firmcontrols "cash_at log_at tang at bookmkt intrcov profitability intr_td"
global leveragevars "lev_mb_IQ fra_mb_IQ lev_IQ"
keep gvkey fyear $firmcontrols $leveragevars

tostring gvkey,replace
replace gvkey = "000" + gvkey
replace gvkey  = substr(gvkey,-6,.)
merge 1:1  gvkey fyear using `time'
drop if _merge==2
drop _merge
gen merge_year = year(datadate)
drop if datadate ==.
duplicates tag gvkey merge_year,gen(dups)
tab dups
*browse if dups>0
sort gvkey merge_year datadate
by gvkey merge_year: gen nn = _n
drop if dups ==1 & nn==1
drop nn at dups
tempfile mlev
save `mlev'


use ../Analysis/data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
gen d_sample =1
keep d_sample date isin
format date %td
rename date datadate
tempfile samplef
save `samplef'

use ../Analysis/data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
drop tag_date
egen tag_date = tag(date)
keep if tag_date
keep date OIS_1M OIS_3M OIS_6M
sort date
format date %td
rename date datadate
tempfile shock
save `shock'

	*** EQUITY RESPONSE
use comp_sec_daily.dta,clear	
order gvkey datadate prccd
sort gvkey datadate
merge m:1 datadate using `shock'
*keep if OIS_1M != .
drop _merge
*merge m:1 datadate isin using `samplef'
*drop _merge

keep if isin != ""
tab iid
keep if iid == "01W"

*duplicates tag  gvkey datadate,gen(dups)
*tab dups
*browse if dups>0

sort gvkey datadate
by gvkey: gen ln_return = log(prccd) - log(prccd[_n-1])
*replace ln_return = ln_return 
destring sic,replace
gen merge_year = year(datadate) - 1
merge m:1 gvkey merge_year using `mlev'
drop if _merge ==2
drop _merge
gen d2sic= int(sic/100)
egen ind_group = group(d2sic)
rename datadate date

gen log_bookmkt = log(bookmkt)
global firmcontrols "cash_at log_at tang log_bookmkt intrcov profitability intr_td"
gen date_q = qofd(date)
gen year = year(date)
format date_q %tq
*replace lev_mb_IQ = lev_mb_IQ

egen tag_date = tag(date)
tab year if tag_date ==1 & OIS_1M != .
gen d_act_volume = cshtrd > 10000

egen tag_IY = tag(gvkey year)
	
	* Winsorize control BS

foreach var of varlist $firmcontrols{
	winsor2 `var' if  tag_IY==1, cuts(1 99) by(year)
	replace `var'_w=0 if `var'_w==.
	egen `var'w=total(`var'_w),by(year gvkey)
	replace `var'=`var'w
}

save aux_data_equityresponse,replace


***********************************************************
*** Test some of the equity response specifications.

use aux_data_equityresponse,clear

gen daterange = date_q <= quarterly("2007q3","YQ") | (date_q >= quarterly("2014q1","YQ") & date_q <= quarterly("2018q4","YQ")) 



reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ ///
$firmcontrols if daterange, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)

reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ ///
$firmcontrols if daterange & d_act_volume, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)




reghdfe ln_return c.OIS_1M##c.lev_IQ c.lev_IQ  $firmcontrols if  daterange & d_sample==1 , absorb(gvkey i.ind_group#i.date) cluster(gvkey date)


reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols if date_q <= quarterly("2007q3","YQ") | (date_q >= quarterly("2014q1","YQ") & date_q <= quarterly("2018q4","YQ")) & d_act_volume , absorb(gvkey i.ind_group#i.date) cluster(gvkey date)

reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M##c.lev_IQ c.lev_IQ $firmcontrols if date_q <= quarterly("2007q3","YQ") | (date_q >= quarterly("2014q1","YQ") & date_q <= quarterly("2018q4","YQ")) & d_act_volume , absorb(gvkey i.ind_group#i.date) cluster(gvkey date)

gen d_sample = e(sample)
tab date if d_sample
egen tag_gvkey = tag(gvkey) if d_sample
tab tag_gvkey

* BEFORE
reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols if date_q <= quarterly("2007q3","YQ")  , absorb(gvkey i.ind_group#i.date) cluster(gvkey date)

reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols if date_q <= quarterly("2007q3","YQ")  & d_act_volume  , absorb(gvkey i.ind_group#i.date) cluster(gvkey date)


* AFTER
reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols if (date_q >= quarterly("2014q1","YQ") & date_q <= quarterly("2018q4","YQ")) , absorb(gvkey i.ind_group#i.date) cluster(gvkey date)

reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols if (date_q >= quarterly("2014q1","YQ") & date_q <= quarterly("2018q4","YQ")) & d_act_volume, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)

*/
***********************************************************
*** Table Debt structure - Broadest Sample and Long Period
***********************************************************

use aux_data_equityresponse, clear
est clear

replace ln_return = ln_return * 10000

keep if date_q <= quarterly("2007q3","YQ") | (date_q >= quarterly("2013q1","YQ") & date_q <= quarterly("2018q4","YQ"))
drop if OIS_1M ==.
drop tag_IY 
egen tag_IY = tag(gvkey year)

global firmcontrols "cash_at log_at tang log_bookmkt intrcov profitability intr_td"
global controlinteractions "c.OIS_1M#c.cash_at c.OIS_1M#c.log_at c.OIS_1M#c.tang c.OIS_1M#c.log_bookmkt c.OIS_1M#c.intrcov c.OIS_1M#c.profitability c.OIS_1M#c.intr_td"

reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)
gen prevsample = e(sample)

egen tag_fim = tag(gvkey) if prevsample
tab tag_fim

*xtile q_lev_mb_IQ_help = lev_mb_IQ if tag_IY,nq(3)
*estpost tabstat cash_at if prevsample, by(q_lev_mb_IQ) stat (mean q n) col(stat) listwise
*esttab using ../output/Default_CrossSection_SumStat.tex, ///
*replace cells("mean(fmt(%9.3f)) p25 p50 p75 count(fmt(%9.0fc) label(count))") noobs nomtitle nonumber  label

est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe ln_return c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols if prevsample, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


gen mb_issuer_IQ = 0
replace mb_issuer_IQ = 1 if lev_mb_IQ > 0  & lev_mb_IQ!=.
gen bondtimesshock = mb_issuer_IQ * OIS_1M
label var bondtimesshock "$\Delta$ OIS $\times$ Bond outstanding"
label var mb_issuer_IQ "Bond outstanding"
reghdfe ln_return bondtimesshock  mb_issuer_IQ $firmcontrols if prevsample, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


local nq = 3
foreach var of varlist lev_mb_IQ{
	di "########################################################################"
	di "########################## Working on Variable `var' ###################"

	gen q_`var'_help=.
	foreach y of numlist 2003/2007 2013/2018 {	
		di "Work on year: `y'"
		xtile q_help_`y' = `var' if year==`y' & tag_IY==1, nquantiles(`nq')
		tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y' & tag_IY==1
		drop  q_help_`y'
	}
	egen q_`var' = mean(q_`var'_help),by(gvkey year)
	drop q_`var'_help
		
	loc getlabel: var label `var'
	label define label`var' 2 "2. Tercile `getlabel'" 3  "3. Tercile `getlabel'"
	label values q_`var' label`var'

	reghdfe ln_return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)
	est store b4
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}


reghdfe  ln_return c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ  $firmcontrols, ///
absorb(gvkey i.ind_group#i.date) cluster(gvkey date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


local nq = 3
foreach var of varlist fra_mb_IQ{
	di "########################################################################"
	di "########################## Working on Variable `var' ###################"

	gen q_`var'_help=.
	foreach y of numlist 2003/2007 2013/2018 {	
		di "Work on year: `y'"
		xtile q_help_`y' = `var' if year==`y' & tag_IY==1, nquantiles(`nq')
		*tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y'
		drop  q_help_`y'
	}
	egen q_`var' = mean(q_`var'_help),by(year isin)
	drop q_`var'_help
		
	loc getlabel: var label `var'
	label define label`var' 2 "2. Tercile `getlabel'" 3  "3. Tercile `getlabel'"
	label values q_`var' label`var'

	
	reghdfe ln_return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)
	
	est store b6
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}


reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols, ///
absorb(gvkey i.ind_group#i.date) cluster(gvkey date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


	*Quintiles of variables leverage (defined on year by year basis)
foreach var of varlist lev_IQ{
	gen q_`var'_help=.
	foreach y of numlist 2003/2007 2013/2018 {	
		xtile q_help_`y' = `var' if year==`y' & tag_IY==1, nq(5)
		tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y'
		drop  q_help_`y'
	}
	egen d_`var' = mean(q_`var'_help),by(year isin)
	drop q_`var'_help
}


reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols, ///
absorb(gvkey i.ind_group#i.date) cluster(gvkey date)
est store b8
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

	*MAKE TABLE
#delimit;
esttab  b2 b3 b4 b5 b6 b7 b8 b1
		using "$overleaf/BS_Firm_DebtStructure.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  ///
		noconstant  nomtitles nogaps obslast booktabs  nonotes ///
		scalar("FE Firm FE" "CT Firm controls" "DC Firm control x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction") 
		drop(cash_at log_at tang  log_bookmkt intrcov profitability intr_td _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ  *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M )
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr


	*MAKE TABLE
#delimit;
esttab  b2 b3 b4 b5 b6 b7 b8
		using "$overleaf/BS_Firm_DebtStructurePres.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  ///
		noconstant  nomtitles nogaps obslast booktabs  nonotes ///
		scalar("FE Firm FE" "CT Firm controls" "DC Firm control x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction") 
		drop(cash_at log_at tang  log_bookmkt intrcov profitability intr_td _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ  *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M )
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr


********************************************************************************


import delimited "../Raw_Data/original/dailydataset.csv",clear
gen statadate = date(date,"YMD")
format statadate %td
gen date_q = qofd(statadate)
format date_q %tq

collapse (sum) ratefactor1 conffactor1 conffactor2 conffactor3,by(date_q)

label var ratefactor1 "Target Factor"
label var conffactor1 "Timing Factor"
label var conffactor2 "Forward Guidance Factor"

tempfile factors
save `factors'

	***

* Import debt data
use "comp_annual_date.dta",clear
drop if at == .
duplicates tag gvkey fyear,gen(dups)
tab dups
*browse if dups ==1
drop if fyear <= 2001
sort gvkey fyear datadate
by gvkey fyear: gen nn = _n
drop if dups ==1 & nn==1
drop nn at dups
tempfile time
save `time'

use "wrds_compustat2002-18.dta",clear
gen profitability = op_profit 
gen lev_mb_IQ =  bonds / at * 100
replace lev_mb_IQ = . if lev_mb_IQ > 100
sum lev_mb_IQ

global firmcontrols "cash_at log_at tang at bookmkt intrcov profitability intr_td"
global leveragevars "lev_mb_IQ td_ta bond_td"
keep gvkey fyear $firmcontrols $leveragevars
rename td_ta lev_IQ
rename bond_td fra_mb_IQ
tostring gvkey,replace
replace gvkey = "000" + gvkey
replace gvkey  = substr(gvkey,-6,.)
merge 1:1  gvkey fyear using `time'
drop if _merge==2
drop _merge
gen merge_year = year(datadate)
drop if datadate ==.
duplicates tag gvkey merge_year,gen(dups)
tab dups
*browse if dups>0
sort gvkey merge_year datadate
by gvkey merge_year: gen nn = _n
drop if dups ==1 & nn==1
drop nn at dups
tempfile mlev
save `mlev'

	*** REAL RESPONSE
use  broad_lp_q_balancesheet,clear	
	
merge m:1 fyear gvkey using `mlev'
drop _merge
sort gvkey date_q

merge m:1 date_q using `factors'
drop _merge
*keep if  date_q <= quarterly("2006q3","YQ") 
sort isin date_q

tab date_q
destring sic,replace
gen d2sic= int(sic/100)
egen YI_FE = group(date_q d2sic)

foreach var of varlist lev_mb_IQ fra_mb_IQ lev_IQ{
	by gvkey: egen `var'_std = std(`var')
}

save "LP_data",replace

********************************************************************************
*** Investment specifications

use "LP_data",clear
keep if  date_q <= quarterly("2006q3","YQ") | (date_q >= quarterly("2013q1","YQ") & date_q <= quarterly("2017q2","YQ"))


global firmcontrols "cash_at log_at tang bookmkt intrcov profitability intr_td"

/*
reghdfe d4q_altppentq c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols  , absorb(YI_FE gvkey) cluster(gvkey date_q)

reghdfe d4q_altppentq c.sm_shock##c.fra_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols  , absorb(YI_FE gvkey)
reghdfe d6q_altppentq c.sm_shock##c.fra_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols  , absorb(YI_FE gvkey)
*/
	
	*** Investment ***
label var sm_shock "MP Shock"
label var lev_mb_IQ_std "Bond over Assets"
label var lev_IQ_std "Debt over Assets"
reghdfe d2q_altppentq c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols  , absorb(YI_FE gvkey) cluster(date_q d2sic)
gen d_sample = e(sample)
	
/*
forvalues h = 1/6{
	di "Horizon: `h'"
	reghdfe d`h'q_altppentq c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols , absorb(YI_FE gvkey) cluster(date_q gvkey)
	est store inv`h'
	estadd local FE "Ind2d $\times$ Date"
	estadd local CT "\checkmark"
	estadd local CL "Ind2d $\times$ Date"
}
*/

forvalues h = 1/6{
	di "Horizon: `h'"
	reghdfe d`h'q_altppentq c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	c.sm_shock##c.cash_at c.sm_shock##c.log_at c.sm_shock##c.tang c.sm_shock##c.bookmkt c.sm_shock##c.intrcov c.sm_shock##c.profitability c.sm_shock##c.intr_td , absorb(YI_FE gvkey) cluster(date_q gvkey)
	est store inv`h'
	estadd local FE "Ind2d $\times$ Date"
	estadd local CT "controls x shock"
	estadd local CL "Ind2d $\times$ Date"
}

	*MAKE TABLE
#delimit;
esttab  inv1 inv2 inv3 inv4 inv5 inv6
		using "BS_Firm_Investment.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  
		noconstant   nogaps obslast booktabs  nonotes 
		scalar("FE Fixed Effects" "CT Firm controls" "CL Cluster-SE") 
		mtitles("t+1" "t+2" "t+3" "t+4" "t+5" "t+6")
		drop(cash_at log_at tang  bookmkt intrcov profitability intr_td sm_shock _cons)
		order(c.sm_shock#c.lev_mb_IQ_std lev_mb_IQ_std c.sm_shock#c.lev_IQ_std  lev_IQ_std )
		label substitute(\_ _);
#delimit cr



gen leads=_n-1
forvalues tercile = 1/1{
	local var = "altppentq"
		
	display "################# Process variable `var' ########################"
	
	gen coef_`var'=.
	gen se_`var'=.
	gen ciub_`var'=.
	gen cilb_`var'=.


	replace coef_`var'=0 if leads==0
	replace ciub_`var'=0 if leads==0
	replace cilb_`var'=0 if leads==0

	display "################# This is tercile `tercile' ########################"
	
	forvalues h=1/8{
		*reghdfe d`h'q_`var' c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
		*$firmcontrols, absorb(YI_FE gvkey)
		
		reghdfe d`h'q_altppentq c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
		c.sm_shock##c.cash_at c.sm_shock##c.log_at c.sm_shock##c.tang c.sm_shock##c.bookmkt c.sm_shock##c.intrcov c.sm_shock##c.profitability c.sm_shock##c.intr_td , absorb(YI_FE gvkey) cluster(date_q gvkey)
	
		capture replace coef_`var'=_b[c.lev_mb_IQ_std#c.sm_shock] if leads==`h'
		capture replace se_`var'=_se[c.lev_mb_IQ_std#c.sm_shock]  if leads==`h'
		replace ciub_`var'=coef_`var' + 1.68*se_`var'  if leads==`h'
		replace cilb_`var'=coef_`var' - 1.68*se_`var'  if leads==`h'
	}
}

twoway  (rarea cilb_`var' ciub_`var' leads if leads>=0 & leads<=6, sort  color(blue%10) lw(vvthin)) ///
(scatter coef_`var'  leads if leads>=0 & leads<=6,c( l) lp(solid) mc(blue)), legend(order(1 "CI 90%")) ///
yline(0,lp(dash) lc(gs10)) xtitle("Horizon (in quarters)",size(large)) ytitle("Change in NetPPE (in %)",size(large)) name(ppnet,replace) 
drop leads coef_* se_* ciub_* cilb*
graph export "lp_investment.png",replace





	*** Assets ***
	
forvalues h = 1/8{
	di "Horizon: `h'"
	reghdfe d`h'q_altatq c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols  , absorb(YI_FE gvkey)
	est store inv`h'
	estadd local FE "Ind2d $\times$ Date"
	estadd local CT "\checkmark"
	estadd local CL "Ind2d $\times$ Date"
}


	*MAKE TABLE
#delimit;
esttab  inv1 inv2 inv3 inv4 inv5 inv6
		using "BS_Firm_Assets.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  
		noconstant   nogaps obslast booktabs  nonotes 
		scalar("FE Fixed Effects" "CT Firm controls" "CL Cluster-SE") 
		mtitles("t+1" "t+2" "t+3" "t+4" "t+5" "t+6")
		drop(cash_at log_at tang  bookmkt intrcov profitability intr_td sm_shock _cons)
		label substitute(\_ _);
#delimit cr

	*** tot_liabilities ***
	
forvalues h = 1/8{
	di "Horizon: `h'"
	reghdfe d`h'q_altdlttq c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols  , absorb(YI_FE gvkey)
	est store inv`h'
	estadd local FE "Ind2d $\times$ Date"
	estadd local CT "\checkmark"
	estadd local CL "Ind2d $\times$ Date"
}


	*MAKE TABLE
#delimit;
esttab  inv1 inv2 inv3 inv4 inv5 inv6
		using "BS_Firm_TotalLiabilities.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  
		noconstant   nogaps obslast booktabs  nonotes 
		scalar("FE Fixed Effects" "CT Firm controls" "CL Cluster-SE") 
		mtitles("t+1" "t+2" "t+3" "t+4" "t+5" "t+6")
		drop(cash_at log_at tang  bookmkt intrcov profitability intr_td sm_shock _cons)
		label substitute(\_ _);
#delimit cr


	*** Net Worth ***
	
forvalues h = 1/8{
	di "Horizon: `h'"
	reghdfe d`h'q_altnetworth c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols  , absorb(YI_FE gvkey)
	est store inv`h'
	estadd local FE "Ind2d $\times$ Date"
	estadd local CT "\checkmark"
	estadd local CL "Ind2d $\times$ Date"
}

	*MAKE TABLE
#delimit;
esttab  inv1 inv2 inv3 inv4 inv5 inv6
		using "BS_Firm_Networth.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  
		noconstant   nogaps obslast booktabs  nonotes 
		scalar("FE Fixed Effects" "CT Firm controls" "CL Cluster-SE") 
		mtitles("t+1" "t+2" "t+3" "t+4" "t+5" "t+6")
		drop(cash_at log_at tang  bookmkt intrcov profitability intr_td sm_shock _cons)
		label substitute(\_ _);
#delimit cr


***********************************************************
*** Table Debt structure - Broadest Sample and Long Period
***********************************************************

use aux_data_equityresponse,clear
est clear

replace ln_return = ln_return * 10000

keep if date_q <= quarterly("2007q3","YQ") | (date_q >= quarterly("2013q1","YQ") & date_q <= quarterly("2018q4","YQ"))
drop if OIS_1M ==.
drop tag_IY 
egen tag_IY = tag(gvkey year)

global firmcontrols "cash_at log_at tang bookmkt intrcov profitability intr_td"

reghdfe ln_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols, absorb(gvkey i.ind_group#i.date) cluster(gvkey date)









