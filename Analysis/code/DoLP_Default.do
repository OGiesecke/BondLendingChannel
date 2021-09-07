cap log close 
clear all 
set scheme sol, permanently
graph set window fontface "Times New Roman"
set linesize 150

* Set directories
local 1 "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Analysis/code/" 

* Set directories 
display `"This is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"

*************************************************
** Variable definition and panel construction
*************************************************

	*** Variable defintion Worldscope ***
use ../../Int_Data/data/ws_bs_quarterly,clear
// Define outcome variables analogously to before
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

sort isin date_q
drop if assets==.
duplicates drop isin date_q sales assets,force
duplicates tag isin date_q,gen(new)
tab new
by isin: egen tot_n = total(new)
drop if tot_n >0
drop new tot_n 
order isin date_q

tempfile bs_raw
save `bs_raw'

	* Create panel to fill the gaps
use ../../Int_Data/data/ws_bs_quarterly,clear
keep isin 
duplicates drop isin,force
gen date_q = qofd(date("01012000","DMY"))
format date_q %tq
gen dup = 81
expand dup
sort isin
by isin: gen n =_n-1
replace date_q = date_q + n
drop dup n
merge 1:1 isin date_q using `bs_raw'
drop if _merge==2
drop _merge
drop date



* Note that the shocks are defined backwards t-(t-1)
* Hence the changes in the balance sheet variables have to be defined forwards.
global bsitems "sales  cash assets ldebt tdebt tot_liabilities ppnet profitability networth"
foreach var of varlist $bsitems{
	forvalues i=1/8{
		bys isin: gen d`i'q_`var'=(ln(`var'[_n+`i'-1])-ln(`var'[_n-1]))*100
	}
}

foreach var of varlist $bsitems{
	forvalues i=1/8{
		bys isin: gen d`i'q_alt`var'= (`var'[_n + `i' - 1] - `var'[_n-1] ) / assets[_n-1] * 100
	}
}

forvalues i=1/8{
	bys isin: gen d`i'q_netassets = ( (assets[_n+`i'-1] -  cash[_n+`i'-1]) - ///
	(assets[_n - 1] -  cash[_n - 1]))   / assets[_n-1] * 100
}

forvalues i=1/8{
	bys isin: gen d`i'q_capoverassets = capex[_n+`i'] / assets[_n-1] * 100
}


	* Lagged growth
foreach var of varlist $bsitems{
		bys isin: gen l1q_`var'=ln(`var'[_n])-ln(`var'[_n-1])
		bys isin: gen l2q_`var'=ln(`var'[_n-1])-ln(`var'[_n-2])
		bys isin: gen l3q_`var'=ln(`var'[_n-2])-ln(`var'[_n-3])
}


* Create three lags of the dependent variable
sort isin date_q
foreach var in sales cash assets ldebt tdebt tot_liabilities ppnet{
bys isin: gen L1`var'=`var'[_n-1]
bys isin: gen L2`var'=`var'[_n-2]
bys isin: gen L3`var'=`var'[_n-3]
}

tempfile bs_quarterly
save `bs_quarterly'

	*** Get GDP Data ***
import excel ../../Raw_Data/original/ECB_gdp_growth.xlsx,clear firstrow cellrange(A5)
gen date_q = quarterly(PeriodUnit,"YQ")
format date_q %tq
sort date_q
gen l1_gdp_growth = gdp_growth[_n-1]
gen l2_gdp_growth = gdp_growth[_n-2]
drop PeriodUnit
save ../../Int_Data/data/gdp_growth,replace

	*** Get Inflation Data ***
import excel ../../Raw_Data/original/ECB_hicp.xlsx,clear firstrow cellrange(A5)
gen date_m = monthly(PeriodUnit,"YM")
gen date_q = qofd(dofm(date_m))
format date_q %tq
bys date_q: gen nn=_n
keep if nn==3
drop PeriodUnit date_m nn
rename Percentagechange inflation_yoy
gen l1_inflation_yoy = inflation_yoy[_n-1]
save ../../Int_Data/data/inflation_yoy,replace

	*** Final Panel	***
use ../data/Default_quarterly_sample,clear
gen length = (end_date + 1 - start_date) 
gen date_q = start_date
expand length
sort isin 
by isin: gen n = _n-1
replace date_q = date_q + n
keep isin date_q
sort isin date_q
format date_q %tq 
/// 12,223 quarter isin observations

merge m:1 date_q using ../../Raw_Data/data/shock_weightedquarterly
drop if _merge==2
drop _merge

merge m:1 date_q using ../../Int_Data/data/shock_quarterly
drop if _merge==2
drop _merge

merge m:1 date_q using ../../Int_Data/data/Default_JKshock_quarterly
drop if _merge==2
drop _merge

merge m:1 date_q isin using `bs_quarterly'
gen d_sample = _merge!=2
gen d_merged = _merge==3
gen d_unmerged = _merge==1
drop _merge

merge m:1 date_q using ../../Int_Data/data/gdp_growth
drop if _merge==2
drop _merge

merge m:1 date_q using ../../Int_Data/data/inflation_yoy
drop if _merge==2
drop _merge

merge m:1 isin using ../data/Default_finalsample_Y
keep if _merge==3
drop _merge
sort isin date_q

save ../../Int_Data/data/Default_lp_q_balancesheet,replace

********************************************************************************

import delimited "../../Raw_Data/original/dailydataset.csv",clear
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
use ../../Analysis/data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
drop tag_IY
egen tag_IY=tag(isin year) 
keep if tag_IY

global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
keep isin year lev_mb_IQ q_lev_mb_IQ lev_IQ fra_mb_IQ dtd $firmcontrols sic 
tempfile mlev
save `mlev'

use ../../Int_Data/data/Default_lp_q_balancesheet,clear
gen year = year(dofq(date_q))

merge m:1 year isin using `mlev'
drop _merge
sort isin date_q

merge m:1 date_q using `factors'
drop _merge
*keep if  date_q <= quarterly("2006q3","YQ") 
sort isin date_q

tab date_q
gen d2sic= int(sic/100)
egen YI_FE = group(date_q d2sic)

foreach var of varlist lev_mb_IQ dtd lev_IQ fra_mb_IQ{
	by isin: egen `var'_std = std(`var')
}

*winsor2 d1q_altppnet,cut(1 99)


	*** Investment ***
label var sm_shock "MP Shock"
label var lev_mb_IQ_std "Bond over Assets"
label var lev_IQ_std "Debt over Assets"
	
forvalues h = 1/6{
	di "Horizon: `h'"
	reghdfe d`h'q_altppnet c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ_std  ///
	$firmcontrols  if date_q <= quarterly("2006q1","YQ")  | (year >= 2013 & date_q <= quarterly("2017q1","YQ")) ///
	& d_sample , absorb(YI_FE isin) cluster(date_q isin)
	est store inv`h'
	estadd local FE "Ind2d $\times$ Date"
	estadd local CT "\checkmark"
	estadd local CL "Ind2d $\times$ Date"
}

	*MAKE TABLE
#delimit;
esttab  inv1 inv2 inv3 inv4 inv5 inv6
		using "../../Extra_Analysis/Default_Firm_Investment.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  
		noconstant   nogaps obslast booktabs  nonotes 
		scalar("FE Fixed Effects" "CT Firm controls" "CL Cluster-SE") 
		mtitles("t+1" "t+2" "t+3" "t+4" "t+5" "t+6")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio sm_shock _cons)
		order(c.sm_shock#c.lev_mb_IQ_std lev_mb_IQ_std c.sm_shock#c.lev_IQ_std  lev_IQ_std )
		label substitute(\_ _);
#delimit cr


/*

reghdfe d1q_ppnet c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ $firmcontrols  L1assets L2assets  ///
if date_q <= quarterly("2006q3","YQ") | (year >= 2013 & date_q <= quarterly("2017q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d2q_ppnet c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ $firmcontrols  ///
if date_q <= quarterly("2006q3","YQ") | (year >= 2013 & date_q <= quarterly("2017q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d3q_ppnet c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ $firmcontrols  ///
if date_q <= quarterly("2006q3","YQ") | (year >= 2013 & date_q <= quarterly("2017q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d4q_ppnet c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ $firmcontrols  ///
if date_q <= quarterly("2006q3","YQ") | (year >= 2013 & date_q <= quarterly("2017q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d5q_ppnet c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ $firmcontrols  ///
if date_q <= quarterly("2006q3","YQ") | (year >= 2013 & date_q <= quarterly("2017q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d6q_ppnet c.sm_shock##c.lev_mb_IQ_std c.sm_shock##c.lev_IQ $firmcontrols  ///
if date_q <= quarterly("2006q3","YQ") | (year >= 2013 & date_q <= quarterly("2017q4","YQ")) & d_sample, absorb(YI_FE isin)








* assets
reghdfe d1q_assets c.sm_shock##c.lev_mb_IQ_std lev_IQ $firmcontrols  ///
if date_q <= quarterly("2007q3","YQ") | (year >= 2014 & date_q <= quarterly("2018q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d2q_assets c.sm_shock##c.lev_mb_IQ_std lev_IQ $firmcontrols  ///
if date_q <= quarterly("2007q3","YQ") | (year >= 2014 & date_q <= quarterly("2018q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d3q_assets c.sm_shock##c.lev_mb_IQ_std lev_IQ $firmcontrols  ///
if date_q <= quarterly("2007q3","YQ") | (year >= 2014 & date_q <= quarterly("2018q4","YQ")) & d_sample, absorb(YI_FE isin)

* tot_liabilities
reghdfe d1q_tot_liabilities c.sm_shock##c.lev_mb_IQ_std lev_IQ $firmcontrols  ///
if date_q <= quarterly("2007q3","YQ") | (year >= 2014 & date_q <= quarterly("2018q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d2q_tot_liabilities c.sm_shock##c.lev_mb_IQ_std lev_IQ $firmcontrols  ///
if date_q <= quarterly("2007q3","YQ") | (year >= 2014 & date_q <= quarterly("2018q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d3q_tot_liabilities c.sm_shock##c.lev_mb_IQ_std lev_IQ $firmcontrols  ///
if date_q <= quarterly("2007q3","YQ") | (year >= 2014 & date_q <= quarterly("2018q4","YQ")) & d_sample, absorb(YI_FE isin)

* networth
reghdfe d1q_networth c.sm_shock##c.lev_mb_IQ_std lev_IQ $firmcontrols  ///
if date_q <= quarterly("2007q3","YQ") | (year >= 2014 & date_q <= quarterly("2018q4","YQ")) & d_sample, absorb(YI_FE isin)

reghdfe d2q_networth c.sm_shock##c.lev_mb_IQ_std lev_IQ $firmcontrols  ///
if date_q <= quarterly("2007q3","YQ") | (year >= 2014 & date_q <= quarterly("2018q4","YQ")) & d_sample, absorb(YI_FE isin)

* baseline with altppnet
reghdfe d1q_altppnet c.sm_shock##c.lev_mb_IQ_std  $firmcontrols  if date_q <= quarterly("2007q3","YQ") & d_sample, absorb(YI_FE isin)

		
gen temp = 1
gen leads=_n-1
*sales ppnet profitability tot_liabilities
forvalues tercile = 1/1{
	local var = "ppnet"
		
	
	display "################# Process variable `var' ########################"
	
	gen coef_`var'=.
	gen se_`var'=.
	gen ciub_`var'=.
	gen cilb_`var'=.


	replace coef_`var'=0 if leads==0
	replace ciub_`var'=0 if leads==0
	replace cilb_`var'=0 if leads==0

	display "################# This is tercile `tercile' ########################"
	
	forvalues i=1/8{
		
		reghdfe d`i'q_`var' c.sm_shock##c.lev_mb_IQ_std  ///
		$firmcontrols  if d_sample, absorb(YI_FE isin) 
		
		capture replace coef_`var'=_b[c.lev_mb_IQ_std#c.sm_shock] if leads==`i'
		capture replace se_`var'=_se[c.lev_mb_IQ_std#c.sm_shock]  if leads==`i'
		replace ciub_`var'=coef_`var' + 1.68*se_`var'  if leads==`i'
		replace cilb_`var'=coef_`var' - 1.68*se_`var'  if leads==`i'
	}
}

twoway  (rarea cilb_`var' ciub_`var' leads if leads>=0 & leads<=6, sort  color(blue%10) lw(vvthin)) ///
(scatter coef_`var'  leads if leads>=0 & leads<=6,c( l) lp(solid) mc(blue)), legend(order(1 "CI 90%")) ///
yline(0,lp(dash) lc(gs10)) xtitle("Horizon (in quarters)",size(large)) ytitle("Change in NetPPE (in %)",size(large)) name(ppnet,replace)
graph export ../../Analysis/output/Default_LP_PPENetTerciles.pdf,replace
 
 





/*
gen industry = 0
replace industry=1 if sic >=100 & sic < 1000
replace industry=2 if sic >=1000 & sic < 1500
replace industry=3 if sic >=1500 & sic < 1800
replace industry=4 if sic >=2000 & sic < 4000
replace industry=5 if sic >=4000 & sic < 5000
replace industry=6 if sic >=5000 & sic < 5200
replace industry=7 if sic >=5200 & sic < 6000
replace industry=8 if sic >=6000 & sic < 6800
replace industry=9 if sic >=7000 & sic < 9000
replace industry=10 if sic >=9100 & sic < 9730
replace d2sic =industry
*/

preserve
* Within industry and year market leverage tercile
	local timeunit "date_q"

	egen tag_FY = tag(isin `timeunit')
	keep if tag_FY == 1

	egen n_indyear_FYI = count(lev_mb_IQ) ,by(`timeunit' d2sic)
	tab n_indyear_FYI

	drop if n_indyear_FYI<3

	*  Terciles of bond debt per industry x year
	gen q_levmarketIQ_YI=.

	levelsof `timeunit', local(years)
	foreach y of local years {
		levelsof d2sic if `timeunit' == `y', local(inds)
		foreach industry of local inds {	
			display "Year: `y' and industry: `industry'"	
			xtile q_help = lev_mb_IQ if `timeunit' == `y' & d2sic == `industry' , nq(3)	
			replace q_levmarketIQ_YI=q_help if `timeunit' == `y' & d2sic == `industry'
			drop  q_help
		}
	}

	keep q_levmarketIQ_YI isin `timeunit'
	tempfile FY_withinInd_tercile
	save `FY_withinInd_tercile'
restore

merge m:1 isin `timeunit' using `FY_withinInd_tercile'
drop _merge



egen IQ_dummy = group(d2sic `timeunit')
*assets sales ppnet profitability tot_liabilities 
foreach var in assets sales ppnet profitability tot_liabilities  altppnet netassets capoverassets{
	forvalues i=1/8{
		quietly areg d`i'q_`var',absorb(IQ_dummy)
		predict d`i'q_`var'_res,residual
	}
}

save ../data/Default_lp_q_balancesheet_terciles,replace


********************************************************************************

use ../data/Default_lp_q_balancesheet_terciles,clear
drop temp coef_*
*egen YI_FE = group(year d2sic)

*replace agg_shock_ois_q = agg_shock_JK_q_noinfo * 100
keep if (year > 2000 & date_q <= quarterly("2006q2","YQ"))  //| (year > 2013 & date_q <= quarterly("2017q1","YQ"))
*keep if  date_q <= quarterly("2006q3","YQ") | (date_q >= quarterly("2014q1","YQ") & date_q <= quarterly("2017q4","YQ"))
// account for the leads reaching until 2007q4

areg lev_mb_IQ,absorb(IQ_dummy)
predict lev_mb_IQ_res,res

areg fra_mb_IQ,absorb(isin)
predict fra_mb_IQ_res,res

areg lev_IQ,absorb(isin)
predict lev_IQ_res,res




*
local nq = 3
foreach var of varlist lev_mb_IQ_res{
	di "########################################################################"
	di "########################## Working on Variable `var' ###################"

	gen q_`var'_help=.
	foreach y of numlist  2001/2007 2014/2017{	
		capture xtile q_help_`y' = `var' if year==`y' , nquantiles(`nq')
		*tab q_help_`y'
		capture replace q_`var'_help=q_help_`y' if year==`y'
		captur edrop  q_help_`y'
	}
	egen q_`var' = mean(q_`var'_help),by(year isin)
	drop  q_`var'_help
		
	loc getlabel: var label `var'
	label define label`var' 2 "2. Tercile `getlabel'" 3  "3. Tercile `getlabel'"
	label values q_`var' label`var'

}
	
drop leads
gen leads=_n-1
*sales ppnet profitability tot_liabilities
forvalues tercile = 1/1{
	local var = "ppnet"
		
	
	display "################# Process variable `var' ########################"
	
	gen coef_`var'=.
	gen se_`var'=.
	gen ciub_`var'=.
	gen cilb_`var'=.


	replace coef_`var'=0 if leads==0
	replace ciub_`var'=0 if leads==0
	replace cilb_`var'=0 if leads==0

	display "################# This is tercile `tercile' ########################"
	
	forvalues i=1/8{
		
		reghdfe d`i'q_`var' c.sm_shock##c.lev_mb_IQ ///
		 $firmcontrols l1_gdp_growth l2_gdp_growth lev_IQ 	///
		l1_inflation_yoy  l1q_assets l2q_assets L1ppnet L2ppnet if  d_sample, absorb(YI_FE isin) cluster(year isin)
		
		capture replace coef_`var'=_b[c.lev_mb_IQ#c.sm_shock] if leads==`i'
		capture replace se_`var'=_se[c.lev_mb_IQ#c.sm_shock]  if leads==`i'
		replace ciub_`var'=coef_`var'+1.68*se_`var'  if leads==`i'
		replace cilb_`var'=coef_`var'-1.68*se_`var'  if leads==`i'
	}
}

twoway  (rarea cilb_`var' ciub_`var' leads if leads>=0 & leads<=6, sort  color(blue%10) lw(vvthin)) ///
(scatter coef_`var'  leads if leads>=0 & leads<=6,c( l) lp(solid) mc(blue)), legend(order(1 "CI 90%")) ///
yline(0,lp(dash) lc(gs10)) xtitle("Horizon (in quarters)",size(large)) ytitle("Change in NetPPE (in %)",size(large)) name(ppnet,replace)
graph export ../../Analysis/output/Default_LP_PPENetTerciles.pdf,replace
 
 
 forvalues tercile = 1/1{
	* assets ppnet sales  tot_liabilities
	foreach var in  ppnet{ 
	
	local shock = "sm_shock"
	
	display "################# Process variable `var' ########################"
	
	gen coef_`var'1=.
	gen se_`var'1=.
	gen ciub_`var'1=.
	gen cilb_`var'1=.
	
	gen coef_`var'3=.
	gen se_`var'3=.
	gen ciub_`var'3=.
	gen cilb_`var'3=.


	replace coef_`var'1=0 if leads==0
	replace ciub_`var'1=0 if leads==0
	replace cilb_`var'1=0 if leads==0
	
	replace coef_`var'3=0 if leads==0
	replace ciub_`var'3=0 if leads==0
	replace cilb_`var'3=0 if leads==0

	display "################# This is tercile `tercile' ########################"
	
	forvalues i=1/8{
			
		reg d`i'q_ppnet_res c.sm_shock#ibn.q_levmarketIQ_YI ///
		ibn.q_levmarketIQ_YI $firmcontrols l1_gdp_growth l2_gdp_growth 	///
		l1_inflation_yoy  l1q_assets l2q_assets if  d_sample
		

		capture replace coef_`var'1=_b[1.q_levmarketIQ_YI#`shock'] if leads==`i'
		capture replace se_`var'1=_se[1.q_levmarketIQ_YI#`shock']  if leads==`i'
		replace ciub_`var'1=coef_`var'1+1.68*se_`var'1  if leads==`i'
		replace cilb_`var'1=coef_`var'1-1.68*se_`var'1  if leads==`i'
			
		capture replace coef_`var'3=_b[3.q_levmarketIQ_YI#`shock'] if leads==`i'
		capture replace se_`var'3=_se[3.q_levmarketIQ_YI#`shock']  if leads==`i'
		replace ciub_`var'3=coef_`var'3+1.68*se_`var'3  if leads==`i'
		replace cilb_`var'3=coef_`var'3-1.68*se_`var'3  if leads==`i'
			
		
		
		}
	}
}

/*
forvalues i=1/8{
		winsor2 d`i'q_altppnet,cut(2 98) replace
		reghdfe d`i'q_altppnet c.agg_shock_ois_q ///
		 $firmcontrols l1_gdp_growth l2_gdp_growth 	///
		l1_inflation_yoy  l1q_assets l2q_assets if  d_sample,absorb(YI_FE)
}

forvalues i=1/8{
		winsor2 d`i'q_altppnet_res,cut(2 98) replace
		reg d`i'q_altppnet_res c.agg_shock_ois_q#ibn.q_levmarketIQ_YI ///
		 $firmcontrols l1_gdp_growth l2_gdp_growth 	///
		l1_inflation_yoy  l1q_assets l2q_assets if  d_sample & date_q 
}
*/
 

 

twoway  (rarea cilb_ppnet1 ciub_ppnet1 leads if leads>=0 & leads<=6, sort  color(blue%10) lw(vvthin)) ///
(scatter coef_ppnet1  leads if leads>=0 & leads<=6,c( l) lp(solid) mc(blue))  ///
(rarea cilb_ppnet3 ciub_ppnet3 leads if leads>=0 & leads<=6, sort  color(red%10) lw(vvthin)) ///
(scatter coef_ppnet3  leads if leads>=0 & leads<=6,c( l) lp(solid) mc(red)), ///
 yline(0,lp(dash) lc(gs10)) ///
legend(order( 2 "Low Bond Leverage" 4 "High Bond Leverage" 1 "CI Tercile Low"  3 "CI Tercile High"  )) ///
xtitle("Horizon (in quarters)",size(large)) ytitle("Change in NetPPE (in %)",size(large)) name(ppnet,replace)
graph export ../../Analysis/output/Default_LP_PPENetTerciles.pdf,replace
*ylabel(-2(0.5)2)
  twoway  (rarea cilb_ppnet1 ciub_ppnet1 leads if leads>=0 & leads<=6, sort  color(blue%10) lw(vvthin)) ///
(scatter coef_ppnet1  leads if leads>=0 & leads<=6,c( l) lp(solid) mc(blue))  ///
 (rarea cilb_ppnet3 ciub_ppnet3 leads if leads>=0 & leads<=6, sort  color(red%10) lw(vvthin)) ///
 (scatter coef_ppnet3  leads if leads>=0 & leads<=6,c( l) lp(solid) mc(red)), ///
 yline(0,lp(dash) lc(gs10)) ///
legend(order( 2 "Low Bond Leverage" 4 "High Bond Leverage" 1 "CI Tercile Low"  3 "CI Tercile High"  )) ///
xtitle("Horizon (in quarters)",size(large)) ytitle("Change in NetPPE (in %)",size(large)) name(ppnet,replace)
graph export ../../Analysis/output/Default_LP_PPENetTerciles.pdf,replace

 
 

*/*******************************************************************************

	*** Altavilla et al. shock
import excel using ../../Raw_Data/original/Dataset_EA-MPD.xlsx, clear sheet("Press Release Window") firstrow

gen date_m = mofd(date)
format date_m %tm

egen agg_shock_ois_m = total(OIS_1M),by(date_m)
egen tagm = tag(date_m)
keep if tagm==1
keep agg_shock_ois_m date_m
tempfile shock_monthly
save `shock_monthly'


use ../../Int_Data/data/Financial_Variables,replace
merge 1:1 date using ../../Int_Data/data/MergedCleaned_MarketData.dta
drop if _merge==2
drop _merge

merge m:1 date_mon using ../../Int_Data/data/ECB_interest_loan.dta
drop if _merge==2
drop _merge

collapse (mean) BBB_5Y AA_5Y BBB_spread_5yr AA_spread_5yr loan_rate,by(date_mon)

rename date_mon date_m
merge 1:1 date_m using `shock_monthly'
drop if _merge==2


// Define interest rate differential between bank and bond
gen rate_diff_BBB_5Y=loan_rate-BBB_5Y
gen rate_diff_AA_5Y=loan_rate-AA_5Y

// Create changes in the bank_rate for horizons up to one year
foreach var in rate_diff_BBB_5Y rate_diff_AA_5Y{
forvalues i=1/12{
gen LD`i'_`var'=`var'[_n+`i']-`var'[_n]
}
}

foreach var in rate_diff_BBB_5Y rate_diff_AA_5Y{
forvalues i=1/3{
gen L`i'_`var'=`var'[_n-`i']
}
}

gen year = year(dofm(date_m))
keep if year > 2000 & year < 2007
// account for the fact that we have 12 monthly leads. So this goes until 12/2007

replace agg_shock_ois_m =0 if agg_shock_ois_m==.
	
gen leads=_n-1
tsset date_m


foreach var in rate_diff_BBB_5Y rate_diff_AA_5Y{
	gen coef_`var'=.
	gen se_`var'=.
	gen ciub_`var'=.
	gen cilb_`var'=.
	*gen n_`var'=.

	replace coef_`var'=0 if leads==0
	replace ciub_`var'=0 if leads==0
	replace cilb_`var'=0 if leads==0

	forvalues i=1/12{
	*qui reg LD`i'_`var' agg_shock_ois_m L1_`var' L2_`var' L3_`var' if insample==1,r
	*qui reg LD`i'_`var' agg_shock_ois_m L1_`var' if insample==1,r
	// Try without lags
	*qui reg LD`i'_`var' agg_shock_ois_m if insample==1,r
	// With Newey-West standard errors
	newey LD`i'_`var' agg_shock_ois_m L1_`var' L2_`var' L3_`var' ,lag(12)
	capture replace coef_`var'=_b[agg_shock_ois_m] if leads==`i'
	capture replace se_`var'=_se[agg_shock_ois_m]  if leads==`i'
	replace ciub_`var'=coef_`var'+1.68*se_`var'  if leads==`i'
	replace cilb_`var'=coef_`var'-1.68*se_`var'  if leads==`i'
	*replace n_`var'=e(N) if leads == `i'
	}
}


twoway  (rarea ciub_rate_diff_BBB_5Y cilb_rate_diff_BBB_5Y leads if leads>=0 & leads<=12, sort  color(blue%10) lw(vvthin)) ///
(scatter coef_rate_diff_BBB_5Y   leads if leads>=0 & leads<=12,c( l) lp(solid) mc(blue)) ,   ///
yline(0,lp(dash) lc(gs10)) title("Diff. Bank Rate - BBB Bonds 5Y ") legend(off) xlabel(0(3)12) ///
legend(off) xtitle("Horizon (in month)",size(large))  name(DiffBBB5YSpread,replace)
graph export ../../Analysis/output/Default_LP_BankBBB5Y.pdf, replace

twoway  (rarea ciub_rate_diff_AA_5Y cilb_rate_diff_AA_5Y leads if leads>=0 & leads<=12, sort  color(blue%10) lw(vvthin)) ///
(scatter coef_rate_diff_AA_5Y   leads if leads>=0 & leads<=12,c( l) lp(solid) mc(blue)) ,   ///
yline(0,lp(dash) lc(gs10)) title("Diff. Bank Rate - AA Bonds 5Y ") legend(off) xlabel(0(3)12) ///
legend(off) xtitle("Horizon (in month)",size(large))  name(DiffAA5YSpread,replace)
graph export ../../Analysis/output/Default_LP_BankAA5Y.pdf, replace
