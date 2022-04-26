cap log close 
clear all 
set scheme sol, permanently
graph set window fontface "Times New Roman"
set linesize 150

* Set directories 
local 1 "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Analysis/code/"
display `"This is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"


********************************************************************************
*** Do Analysis on the US sample
********************************************************************************

*******************************
*** Sample Description ***
*******************************
use ../data/Firm_Return_WS_Bond_Duration_Data_US_Sample,clear

preserve 
keep if tag_IY
keep isin year
gen cov_year = year - 1
save ../data/US_finalsample_FY,replace
restore

preserve 
keep if tag_isin
keep isin
save ../data/US_finalsample_F,replace
restore

tab nation

tab year if tag_IY

*******************************************
*** Rating Coverage ***
*******************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_US_Sample,clear
keep if tag_IY==1

replace rating_group =0 if rating_group==.
tab year rating_group

collapse (count) date, by(yr_adj rating_group)
format date %9.0g
rename date count
egen tot_count=total(count),by(yr_adj)
gen sh_rating = count /tot_count
drop count tot_count
reshape wide sh_rating,i(yr_adj ) j(rating_group) 

	* create cumulative share
forvalue val=0/3{
	egen cum_share`val' = rowtotal(sh_rating0-sh_rating`val') 
	replace cum_share`val'=cum_share`val'*100
}

twoway (area cum_share3 yr_adj, color(gs13)) (area cum_share2 yr_adj, color(gs9)) ///
(area cum_share1 yr_adj, color(gs4))(area cum_share0 yr_adj, color(gs2)), ///
ylabel(0 (25) 100) xlabel(2001(3)2013) xtitle("") text(8 2006 "{bf:Unrated}") ///
text(23 2006 "{bf:High-Yield}") text(60 2006 "{bf: IG below AA}") ///
text(99 2006 "{bf: IG AA and above}") legend(off) name(RatingCov,replace)
graph export ../output/US_Ratingcov.pdf, replace

*******************************************
*** Capital Structure and Coverage ***
*******************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_US_Sample,clear

keep if tag_IY

collapse (sum) IQ_TOTAL_ASSETS IQ_TOTAL_DEBT  IQ_BONDS_NOTES  ///
(mean) lev_market_IQ lev_IQ fra_mdebt_IQ us_priceindex,by(yr_adj)
rename yr_adj year

label var lev_IQ "Debt over assets (left-axis)"
label var lev_market_IQ "Bond debt over assets (left-axis)"
label var fra_mdebt_IQ "Bond debt / total debt (right-axis)"

twoway (scatter lev_IQ lev_market_IQ year if year > 2000 , ///
c(l l ) mc(red blue) ytitle("") yaxis(1) ) ///
(scatter  fra_mdebt_IQ  year if year > 2000, ///
yaxis(2) ms(Oh) c(l)  ytitle("Bond debt / total debt",axis(2))), ///
title("Sample Capital Structure") name(Coverage,replace) xtitle("")
graph export  ../output/US_Samplecapitalstructure.pdf,replace


***********************************************************
*** Summary Statistics - Baseline 2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_US_Sample,clear
keep if date < date("01082007","DMY") & year > 2001

*keep if tag_IY
*gen man_fra_market = 1 - fra_bank_IQ
*twoway scatter man_fra_market fra_mb_IQ


drop tag_isin
egen tag_isin=tag(isin)
tab tag_isin

drop tag_IY
egen tag_IY=tag(isin year) 
tab year if  tag_IY


est clear

	*** Big table across terciles of bond debt ***
estpost tabstat assets_inBN cash_oa profitability tangibility LTG_EPS_mx MB DTI cov_ratio lev_IQ fra_ST lev_mb_IQ  fra_mb_IQ, by(q_lev_mb_IQ) stat (mean q n) col(stat) listwise
esttab using ../output/US_CrossSection_SumStat.tex, ///
replace cells("mean(fmt(%9.3f)) p25 p50 p75 count(fmt(%9.0fc) label(count))") noobs nomtitle nonumber  label

	*** Sum Stat Presentation ***
estpost tabstat assets_inBN cash_oa profitability tangibility LTG_EPS_mx MB DTI cov_ratio lev_IQ fra_ST lev_mb_IQ  fra_mb_IQ, stat (mean q n) col(stat) listwise
esttab using ../output/US_SumStatPres.tex, ///
replace cells("mean(fmt(%9.3f) label(Mean)) p25 p50 p75 count(fmt(%9.0fc) label(count))") noobs nomtitle nonumber label

tabstat  lev_mb_IQ , stat (mean q n) col(stat) save
return list
matrix list r(StatTotal)
matrix stats=r(StatTotal)

local avg  = stats[1,1] *100
local fmtavg : display %4.0f `avg'
display `fmtavg'
tempname uhandle
file open `uhandle' using ../output/par_bondlevmeanUS.tex,write text replace
file write `uhandle' "`fmtavg'\unskip"
file close `uhandle'



***********************************************************
*** Table Debt structure - Baseline 2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_US_Sample,clear
keep if date < date("01082007","DMY") & year > 2001
est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx
gen OIS_1M = d_shock_je
label var OIS_1M "$\Delta$ FFR"


* Avg Response
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy  c.OIS_1M  $firmcontrols ,absorb(isin_num) cluster(isin_num date)

	* Replication of Ippolito et al.
reghdfe return c.OIS_1M#c.lev_bank_IQ c.lev_bank_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.OIS_1M#c.fra_bank_IQ c.fra_bank_IQ c.OIS_1M#c.lev_IQ c.lev_IQ $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

	
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy  c.OIS_1M#c.lev_IQ  lev_IQ  $firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

matrix coeff=r(table)
local intcoeff = coeff[1,3]


	*Bond issuer dummy works
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy bondtimesshock  mb_issuer_IQ   $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

drop q_lev_mb_IQ 
local nq = 3
foreach var of varlist lev_mb_IQ{
	di "########################################################################"
	di "########################## Working on Variable `var' ###################"

	gen q_`var'_help=.
	levelsof year,local(years)
	foreach y of local years {	
		xtile q_help_`y' = `var' if year==`y'  & tag_IY==1, nquantiles(`nq')
		*tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y'
		drop  q_help_`y'
	}
	egen q_`var' = mean(q_`var'_help),by(year isin)
	drop q_`var'_help
		
	loc getlabel: var label `var'
	label define label`var' 2 "2. Tercile `getlabel'" 3  "3. Tercile `getlabel'"
	label values q_`var' label`var'

	reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 
	est store b4
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}



reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


drop q_fra_mb_IQ 
local nq = 3
foreach var of varlist fra_mb_IQ{
	di "########################################################################"
	di "########################## Working on Variable `var' ###################"

	gen q_`var'_help=.
	levelsof year,local(years)
	foreach y of local years {		
		xtile q_help_`y' = `var' if year==`y'  & tag_IY==1, nquantiles(`nq')
		*tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y'
		drop  q_help_`y'
	}
	egen q_`var' = mean(q_`var'_help),by(year isin)
	drop q_`var'_help
		
	loc getlabel: var label `var'
	label define label`var' 2 "2. Tercile `getlabel'" 3  "3. Tercile `getlabel'"
	label values q_`var' label`var'

	reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols c.lev_IQ c.OIS_1M#c.lev_IQ, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 

	est store b6
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}


reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols ///
 ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b8
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"


	*MAKE TABLE
#delimit;
esttab   b2 b3 b4 b5 b6 b7 b8 b1
		using ../output/US_Firm_DebtStructure.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ c.OIS_1M#c.dur_proxy dur_proxy  *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr

/*

	*MAKE PRESENTATION TABLE
#delimit;
esttab  b2  b4 b5 b6 b7 b8
		using ../output/US_Firm_DebtStructurePres.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  
		noconstant  nomtitles nogaps obslast booktabs  nonotes
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI q_fra_mb_IQ fra_mb_IQ cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ lev_mb_IQ q_lev_mb_IQ  c.OIS_1M#c.dur_proxy dur_proxy lev_IQ)
		order(c.OIS_1M#c.lev_mb_IQ c.OIS_1M#c.q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ)
		label substitute(\_ _);
#delimit cr
*/


***********************************************************
*** Table  -- EXPOSURE
***********************************************************



*************************************

import excel "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Raw_Data/original/hedgedata.xls", sheet("Sheet1") firstrow clear

drop if filingdate<td(1,1,2003)

*Fist check for duplicates by filingtype.
*We checked manually that hedging information is the same across these duplicates.
by gvkey filingdate filingtype, sort: gen dup=cond(_N==1,0,_n)
by gvkey filingdate filingtype, sort: egen lastob=max(dup)
by gvkey filingdate filingtype, sort: keep if dup==lastob
drop dup lastob

*Now check if there are duplicates for a given filing date.
by gvkey filingdate, sort: gen dup=cond(_N==1,0,_n)
*Now keep 10-Ks (these are cases when 10-qs and 10-ks are filed on the same date).
drop if dup>=1 & filingtype!="10-K"

*Rename filingdate to make it compatible with CIQ data.
gen month=month(filingdate)
gen year=year(filingdate)
gen ddatefil=ym(year,month)
format ddatefil %tm
sort gvkey ddatefil
drop year month dup

destring, replace
sort gvkey ddatefil 
*There are cases where a firm filed more than one report of the same type within the same month.
by gvkey ddatefil, sort: gen dup=cond(_N==1,0,_n)
*Check their types and keep the latest ones.
by gvkey ddatefil filingtype, sort: egen lastob=max(filingdate)
by gvkey ddatefil filingtype, sort: keep if lastob==filingdate
drop lastob dup

sort gvkey ddatefil
*There are still duplicates. These are the cases where a firm filed 10-Qs and 10-Ks on different days within the same month.
by gvkey ddatefil, sort: gen dup=cond(_N==1,0,_n)
drop if dup>=1 & filingtype!="10-K"
drop dup 
save webhedgedatatouse12set, replace


*************************************

use "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Raw_Data/data/US_stock_return.dta", clear
keep isin date return2d
tempfile twodayreturn
save `twodayreturn'

import delimited "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Raw_Data/original/capitaliq_gvkey.csv",clear
sort companyid gvkey
by companyid: gen nn = _n
drop startdate enddate companyname
reshape wide gvkey, i(companyid) j(nn)
tempfile idfile
save `idfile'

import excel "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Raw_Data/original/hedgedata.xls",clear firstrow
gen yr_adj = year(filingdate)
bys gvkey yr_adj: gen number_obs = _N
drop if  filingtype=="10-Q" & number_obs > 1
drop number_obs
bys gvkey yr_adj: gen number_obs = _N
tab number_obs
sort gvkey yr_adj
bys gvkey yr_adj: gen nn_obs = _n
keep if nn_obs == number_obs 
keep gvkey yr_adj hedge2 
rename yr_adj year
tempfile hedge
save `hedge'

use "/Users/olivergiesecke/Dropbox/US_CapitalStructure/output/us_exposure.dta",clear
rename fyear yr_adj
tempfile exposurevar
save `exposurevar'

use "/Users/olivergiesecke/Dropbox/US_CapitalStructure/output/us_floatingdebt.dta",clear
rename fyear yr_adj
tempfile floatingdebt
save `floatingdebt'

use "/Users/olivergiesecke/Dropbox/US_CapitalStructure/output/us_bankdebt.dta",clear
rename fyear yr_adj
tempfile bankdebt
save `bankdebt'

use "/Users/olivergiesecke/Desktop/datsurprisewithpath.dta",clear
rename Date date
keep date transfact1 transfact2
tempfile newshock
save `newshock'

use "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Analysis/data/Firm_Return_WS_Bond_Duration_Data_US_Sample",clear
keep if year >= 2004 & year < 2009
* keep if year >= 2004 & date < date("01082008","DMY")

egen dd = tag(date)
tab date if dd

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx
gen OIS_1M = d_shock_je
label var OIS_1M "$\Delta$ FFR"

gen companyid = substr(capIQid,3,.)
destring companyid,replace

merge m:1 isin date using `twodayreturn'
drop if _merge == 2
drop _merge

merge m:1 companyid using `idfile'
drop if _merge == 2
drop _merge

rename gvkey1 gvkey
merge m:1 gvkey year using `hedge'
keep if _merge == 3
drop _merge


merge m:1 companyid yr_adj using `exposurevar'
drop if _merge == 2
drop _merge

merge m:1 companyid yr_adj using `floatingdebt'
drop if _merge == 2
drop _merge

merge m:1 companyid yr_adj using `bankdebt'
drop if _merge == 2
drop _merge

replace target =  target * 100
replace path = path * 100
*replace hedge2 = 0 if hedge2 ==. 
replace return2d = return2d * 10000

gen floatingoverassets = floating_debt / (IQ_TOTAL_ASSETS/1e6)
drop if floatingoverassets <= 0.01 & hedge2 ==1
gen ciq_bankleverage = bankdebt / (assets / 1e6)


gen newtarget = target
label var newtarget "Target"
label var target "Target"
gen newpath = path
label var newpath "Path"
label var path "Path"
label var ciq_bankleverage "Bank Leverage"
label var hedge2 "Hedge"

reghdfe return2d newtarget c.target##c.ciq_bankleverage##c.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2, absorb(isin_num) cluster(isin_num date)
est store c1
estadd local FE "\checkmark"
estadd local CT "\checkmark"

gen newexposure = exposure
label var newexposure "Exposure"

reghdfe return2d newtarget newpath newexposure c.target##c.exposure##c.hedge2 c.path##c.exposure##c.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2 c.path##c.size##i.hedge2 c.path##c.cash_oa##i.hedge2 c.path##c.profitability##i.hedge2 c.path##c.tangibility##i.hedge2 c.path##c.log_MB##i.hedge2 c.path##c.DTI##i.hedge2 c.path##c.cov_ratio##i.hedge2,absorb(isin_num) cluster(isin_num date)
est store c2
estadd local FE "\checkmark"
estadd local CT "\checkmark"

reghdfe return2d newtarget newpath newexposure c.target##c.ciq_bankleverage##c.hedge2 c.target##c.exposure##c.hedge2 c.path##c.exposure##c.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2 c.path##c.size##i.hedge2 c.path##c.cash_oa##i.hedge2 c.path##c.profitability##i.hedge2 c.path##c.tangibility##i.hedge2 c.path##c.log_MB##i.hedge2 c.path##c.DTI##i.hedge2 c.path##c.cov_ratio##i.hedge2,absorb(isin_num) cluster(isin_num date)
est store c3
estadd local FE "\checkmark"
estadd local CT "\checkmark"

reghdfe return2d newtarget newpath newexposure c.target##c.lev_mb_IQ##c.hedge2 c.target##c.exposure##c.hedge2 c.path##c.exposure##c.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2 c.path##c.size##i.hedge2 c.path##c.cash_oa##i.hedge2 c.path##c.profitability##i.hedge2 c.path##c.tangibility##i.hedge2 c.path##c.log_MB##i.hedge2 c.path##c.DTI##i.hedge2 c.path##c.cov_ratio##i.hedge2,absorb(isin_num) cluster(isin_num date)
est store c4
estadd local FE "\checkmark"
estadd local CT "\checkmark"

reghdfe return2d newtarget newpath newexposure c.target##c.lev_mb_IQ##c.hedge2 c.path##c.lev_mb_IQ##c.hedge2 c.target##c.exposure##c.hedge2 c.path##c.exposure##c.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2 c.path##c.size##i.hedge2 c.path##c.cash_oa##i.hedge2 c.path##c.profitability##i.hedge2 c.path##c.tangibility##i.hedge2 c.path##c.log_MB##i.hedge2 c.path##c.DTI##i.hedge2 c.path##c.cov_ratio##i.hedge2,absorb(isin_num) cluster(isin_num date)
est store c5
estadd local FE "\checkmark"
estadd local CT "\checkmark"


	*MAKE TABLE
#delimit;
esttab  c1 c2 c3 c4 c5
		using "$overleaf/US_RegressionSummary.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls x shock")
		keep(newtarget newpath ciq_bankleverage newexposure c.target#c.ciq_bankleverage c.target#c.ciq_bankleverage#c.hedge2 c.target#c.exposure c.target#c.exposure#c.hedge2 c.path#c.exposure c.path#c.exposure#c.hedge2 c.target#c.lev_mb_IQ c.target#c.lev_mb_IQ#c.hedge2 c.path#c.lev_mb_IQ c.path#c.lev_mb_IQ#c.hedge2)
		order(newtarget newpath ciq_bankleverage c.target#c.ciq_bankleverage c.target#c.ciq_bankleverage#c.hedge2 newexposure c.target#c.exposure c.target#c.exposure#c.hedge2 c.path#c.exposure c.path#c.exposure#c.hedge2 ciq_bankleverage c.target#c.ciq_bankleverage c.target#c.ciq_bankleverage#c.hedge2 c.target#c.lev_mb_IQ c.target#c.lev_mb_IQ#c.hedge2 c.path#c.lev_mb_IQ c.path#c.lev_mb_IQ#c.hedge2)
		label substitute(\_ _);
#delimit cr

*ev_IQ c.lev_IQ#c.target 1.hedge2#c.lev_IQ#c.target c.target#c.exposure 1.hedge2#c.target#c.exposure c.path#c.exposure 1.hedge2#c.path#c.exposure
/*
gen ciq_bankleverage = bankdebt / (assets /1e6)

sum ciq_bankleverage,det

reghdfe return c.target##c.ciq_bankleverage##i.hedge2, absorb(isin_num) cluster(isin_num date)

reghdfe return2d c.target##c.ciq_bankleverage##i.hedge2, absorb(isin_num) cluster(isin_num date)

reghdfe return2d c.target##c.lev_mb_IQ##i.hedge2 c.target##c.ciq_bankleverage##i.hedge2, absorb(isin_num) cluster(isin_num date)


reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.target#c.dur_proxy dur_proxy c.target#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.target#c.dur_proxy dur_proxy c.target#c.lev_mb_IQ c.path##c.lev_mb_IQ   c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
*/


gen newtarget = target
label var newtarget "Target"
reghdfe return2d c.newtarget c.lev_IQ##c.target##1.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2, absorb(isin_num) cluster(date)
est store c1
estadd local FE "\checkmark"
estadd local CT "\checkmark"

gen newpath = path
label var newpath "Path"
reghdfe return2d c.newtarget c.newpath exposure c.target##c.exposure##1.hedge2 c.path#c.exposure##1.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2 c.path##c.size##i.hedge2 c.path##c.cash_oa##i.hedge2 c.path##c.profitability##i.hedge2 c.path##c.tangibility##i.hedge2 c.path##c.log_MB##i.hedge2 c.path##c.DTI##i.hedge2 c.path##c.cov_ratio##i.hedge2, absorb(isin_num) cluster(date)
est store c2
estadd local FE "\checkmark"
estadd local CT "\checkmark"



reghdfe return2d c.newtarget c.newpath exposure c.target##c.exposure##1.hedge2 c.path#c.exposure##1.hedge2 c.lev_IQ##c.target##1.hedge2 c.lev_IQ##c.path##1.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2 c.path##c.size##i.hedge2 c.path##c.cash_oa##i.hedge2 c.path##c.profitability##i.hedge2 c.path##c.tangibility##i.hedge2 c.path##c.log_MB##i.hedge2 c.path##c.DTI##i.hedge2 c.path##c.cov_ratio##i.hedge2, absorb(isin_num) cluster(date)
est store c3
estadd local FE "\checkmark"
estadd local CT "\checkmark"

global overleaf "/Users/olivergiesecke/Dropbox/Apps/Overleaf/Firms and Monetary Policy/tables_figures"

	*MAKE TABLE
#delimit;
esttab  c1 c2 c3
		using "$overleaf/US_RegressionSummary.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "TFE Sector Time FE")
		keep(newtarget newpath exposure lev_IQ c.lev_IQ#c.target 1.hedge2#c.lev_IQ#c.target c.target#c.exposure 1.hedge2#c.target#c.exposure c.path#c.exposure 1.hedge2#c.path#c.exposure)
		label substitute(\_ _);
#delimit cr


reghdfe return2d c.target c.lev_IQ##c.target##1.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2 , absorb(isin_num) cluster(isin_num)

reghdfe return2d c.target c.exposure##c.target##1.hedge2 c.exposure##c.path##1.hedge2 c.lev_IQ##c.target##1.hedge2 c.target##c.size##i.hedge2 c.target##c.cash_oa##i.hedge2 c.target##c.profitability##i.hedge2 c.target##c.tangibility##i.hedge2 c.target##c.log_MB##i.hedge2 c.target##c.DTI##i.hedge2 c.target##c.cov_ratio##i.hedge2 c.path##c.size##i.hedge2 c.path##c.cash_oa##i.hedge2 c.path##c.profitability##i.hedge2 c.path##c.tangibility##i.hedge2 c.path##c.log_MB##i.hedge2 c.path##c.DTI##i.hedge2 c.path##c.cov_ratio##i.hedge2, absorb(isin_num) cluster(isin_num)
est store c1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"


	*MAKE TABLE
#delimit;
esttab   b2 b3 b4 b5 b6 b7 b8 b1
		using ../output/US_Firm_DebtStructure.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ c.OIS_1M#c.dur_proxy dur_proxy  *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr











***********************************************************
*** Table  -- MATURITY
***********************************************************

use "/Users/olivergiesecke/Dropbox/US_CapitalStructure/input/wrds_debt_clean.dta",clear
keep fyear companyid gvkey
duplicates drop  fyear gvkey, force
tempfile identifiers
save `identifiers'

use "/Users/olivergiesecke/Dropbox/US_CapitalStructure/output/maturityUS.dta",clear
egen tot_principal = sum(dataitemvalue), by(gvkey fyear)
gen sh_principal = dataitemvalue / tot_principal
gen w_maturity =  maturity * sh_principal
collapse (sum) w_maturity , by(gvkey fyear)
replace w_maturity = w_maturity / 365
label var w_maturity "weighted maturity in years"
merge 1:1 gvkey fyear using `identifiers',keep(3) nogen

collapse (mean) w_maturity, by(companyid fyear)
rename fyear yr_adj
tempfile maturity 
save `maturity'


global additionaldatapath = "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Extra_Analysis"

use "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Analysis/data/Firm_Return_WS_Bond_Duration_Data_US_Sample",clear
keep if date < date("01082007","DMY") & year > 2001
est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx
gen OIS_1M = d_shock_je
label var OIS_1M "$\Delta$ FFR"

gen companyid = substr(capIQid,3,.)
destring companyid,replace
merge m:1 companyid yr_adj using `maturity'
drop if _merge == 2
drop _merge



* Avg Response
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy  c.OIS_1M  $firmcontrols ,absorb(isin_num) cluster(isin_num date)

	* Replication of Ippolito et al.
reghdfe return c.OIS_1M#c.lev_bank_IQ c.lev_bank_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.OIS_1M#c.fra_bank_IQ c.fra_bank_IQ c.OIS_1M#c.lev_IQ c.lev_IQ $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

	
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy  c.OIS_1M#c.lev_IQ  lev_IQ  $firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.w_maturity c.w_maturity  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.age c.age  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.w_maturity c.w_maturity c.OIS_1M#c.age c.age  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)




