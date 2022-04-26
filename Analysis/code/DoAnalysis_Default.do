 cap log close 
clear all 
set scheme sol, permanently
graph set window fontface "Times New Roman"
set linesize 150

* Set directories 
local 1 "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Analysis/code/"
global overleaf "/Users/olivergiesecke/Dropbox/Apps/Overleaf/Firms and Monetary Policy/tables_figures"

display `"This is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"


********************************************************************************
*** Summary Statistics for the MP shock 
********************************************************************************

est clear
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
gen d_EU = 1
append using ../data/Firm_Return_WS_Bond_Duration_Data_US_Sample
keep  if finalsample==1
replace d_EU = 0 if d_EU==.
keep if date < date("01082007","DMY") & year>2000

replace d_ois1mtl =. if d_EU!=1

drop tag_date
egen tag_date=tag(date d_EU) 
keep if tag_date

label var d_ois1mtl "$\Delta$ OIS1M Corsettietal"  
label var eureon3m_hf "$\Delta$ OIS3M JK" 
label var OIS_1M "$\Delta$ OIS1M" 
label var OIS_3M "$\Delta$ OIS3M" 
label var d_shock_je "$\Delta$ FFR"

eststo c1: estpost summarize OIS_1M OIS_3M d_ois1mtl eureon3m_hf d_shock_je
esttab c1 using "$overleaf/Tab_SumStats_Shock.tex", ///
cells("count(pattern(1) fmt(0) label(N)) mean(pattern(1 ) fmt(3) label(Mean)) sd(pattern(1) fmt(2) label(SD) ) min(pattern(1) fmt(2) label(Min)) max(pattern(1) fmt(2) label(Max))") nonotes nomtitles label replace noobs compress substitute(\_ _)  booktabs nonumbers



********************************************************************************
*** Sample Description ***
********************************************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear


drop tag_IQ
egen tag_IQ=tag(isin date_q) 
keep if tag_IQ

drop tag_IY
egen tag_IY=tag(isin year) 
tab year if  tag_IY

drop tag_isin
egen tag_isin=tag(isin)
tab tag_isin


preserve 
keep if tag_IY
keep isin year
gen cov_year = year - 1
save ../data/Default_finalsample_FY,replace
restore

preserve 
keep if tag_isin
keep isin
save ../data/Default_finalsample_Y,replace
restore

	* Big table across terciles of bond debt 

graph hbar (count) tag_IY if tag_IY, over(year) ///
ytitle("Number of firms") name(ISINSbyyear,replace) 

graph hbar (count) tag_isin if tag_isin,over(NATION,sort((count) tag_isin)  ) ///
ytitle("Number of firms") name(ISINSbycountry,replace)

gr combine ISINSbyyear  ISINSbycountry , name("SampleDesc", replace ) 
graph export "$overleaf/Default_SampleStats.pdf", replace

gen help_lev_IQ = lev_IQ  if date < date("01082007","DMY") & year > 2000 & tag_IY
gen help_lev_mb_IQ = lev_mb_IQ  if date < date("01082007","DMY") & year > 2000 & tag_IY
graph hbar (mean) help_lev_IQ help_lev_mb_IQ,over(industry,sort(help_lev_IQ) descending) ///
ytitle("") name(Levbyindustry,replace) legend(order(1 "Mean Leverage" 2 "Mean Bond Leverage"))
graph export "$overleaf/Default_IndustryCapStructure.pdf", replace

keep isin date_q NATION year
sort isin  date_q
* check for gaps in the time series
by isin: gen dist = date_q-date_q[_n-1]
tab dist

egen start_date = min(date_q) ,by(isin)
egen end_date = max(date_q) ,by(isin)

egen tag_isin=tag(isin)
tab tag_isin

keep if tag_isin
format start_date %tq
format end_date %tq
keep isin start_date end_date
save ../data/Default_quarterly_sample,replace
export excel "$overleaf/Default_finalsample.xlsx",replace
export delimited "$overleaf/Default_finalsample.csv",replace

********************************************************************************
*** Rating Coverage ***
********************************************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
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

/*
twoway (area cum_share3 yr_adj, color(gs13)) (area cum_share2 yr_adj, color(gs9)) ///
(area cum_share1 yr_adj, color(gs4))(area cum_share0 yr_adj, color(gs2)), ///
ylabel(0 (25) 100) xlabel(2001(3)2016) xtitle("") text(40 2008 "{bf:Unrated}") ///
text(65 2008 "{bf:High-Yield}") text(80 2008 "{bf: IG below AA}") ///
text(99 2008 "{bf: IG AA and above}") legend(off) name(RatingCov,replace)
graph export "$overleaf/Default_Ratingcov.pdf", replace
*/
twoway (area cum_share3 yr_adj, color(gs13)) (area cum_share2 yr_adj, color(gs9)) ///
(area cum_share1 yr_adj, color(gs4))(area cum_share0 yr_adj, color(gs2)), ///
ylabel(0 (25) 100) xlabel(2001(3)2016) xtitle("") text(30 2008 "{bf:Unrated}") ///
text(57 2006 "{bf:High-Yield}") text(80 2004 "{bf: IG below AA}") ///
text(99 2002 "{bf: IG AA and above}") legend(off) name(RatingCov,replace)
graph export "$overleaf/Default_Ratingcov.pdf", replace



********************************************************************************
*** Capital Structure and Coverage ***
********************************************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear

drop tag_IY
egen tag_IY=tag(isin year) 
tab year if  tag_IY
keep if tag_IY

collapse (sum) IQ_TOTAL_ASSETS IQ_TOTAL_DEBT  IQ_MARKET  ///
(mean) lev_mb_IQ lev_IQ fra_mb_IQ EA_priceindex,by(yr_adj)
rename yr_adj year

label var lev_IQ "Debt over assets (left-axis)"
label var lev_mb_IQ "Bond debt over assets (left-axis)"
label var fra_mb_IQ "Bond debt over total debt (right-axis)"

twoway (scatter lev_IQ lev_mb_IQ year if year >= 2000 , ///
c(l l ) mc(red blue) ytitle("") yaxis(1) ) ///
(scatter  fra_mb_IQ  year if year >= 2000, ///
xlabel(2000(5)2015) yaxis(2) ms(Oh) c(l)  ytitle("Bond debt / total debt",axis(2))), ///
name(CapitalStructure,replace) xtitle("")
graph export "$overleaf/Samplecapitalstructure.pdf",replace

merge m:1 year using ../../Raw_Data/data/bis_euroarea
drop if _merge==2
drop _merge 

foreach var of varlist IQ_MARKET IQ_TOTAL_ASSETS IQ_TOTAL_DEBT{
replace `var' = `var' / 1000000
}

* Express all variables in bnEUR 2015

foreach var of varlist IQ_MARKET IQ_TOTAL_ASSETS IQ_TOTAL_DEBT  issue_nonfincorp_fx{
replace `var' = `var' / 1000
}

gen fra_ds = IQ_MARKET / issue_nonfincorp_fx

label var IQ_MARKET "Sample"
label var issue_nonfincorp_fx "BIS debt securities (EA)"
label var fra_ds "Fraction sample as of total BIS "

replace IQ_MARKET = IQ_MARKET / (EA_priceindex / 100)
replace issue_nonfincorp_fx = issue_nonfincorp_fx / (EA_priceindex / 100)

twoway (scatter IQ_MARKET  issue_nonfincorp_fx year  if year >= 2000 , ///
c(l l )  mc(red blue) ytitle("bnEUR (2015 EUR)") yaxis(1) ) ///
(scatter  fra_ds  year if year >= 2000, yaxis(2) ms(Oh) c(l)  ylabel(0(0.1)1, ///
axis(2)) xlabel(2000(5)2015)  ytitle("Fraction sample as of total BIS",axis(2))), ///
name(Coverage,replace) xtitle("")
graph export "$overleaf/Default_SampleCovDebtSec.pdf",replace



********************************************************************************
*** 2001 - 08 / 2007 Sample Statistics and Cross-Section Figures ***
********************************************************************************

est clear
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

drop tag_isin
egen tag_isin=tag(isin)
tab tag_isin

drop tag_IY
egen tag_IY=tag(isin year) 
tab year if  tag_IY


	*** Big table across terciles of bond debt ***
estpost tabstat assets_inBN cash_oa profitability tangibility LTG_EPS_mx MB DTI cov_ratio lev_IQ fra_ST lev_mb_IQ  fra_mb_IQ, by(q_lev_mb_IQ) stat (mean q n) col(stat) listwise
esttab using "$overleaf/Default_CrossSection_SumStat.tex", ///
replace cells("mean(fmt(%9.3f)) p25 p50 p75 count(fmt(%9.0fc) label(count))") noobs nomtitle nonumber  label

	*** Sum Stat Presentation ***
estpost tabstat assets_inBN cash_oa profitability tangibility LTG_EPS_mx MB DTI cov_ratio lev_IQ fra_ST lev_mb_IQ  fra_mb_IQ, stat (mean q n) col(stat) 
esttab using "$overleaf/Default_SumStatPres.tex", ///
replace cells("mean(fmt(%9.3f) label(Mean)) p25 p50 p75 count(fmt(%9.0fc) label(count))") noobs nomtitle nonumber label

	*** Output numbers
tabstat  lev_mb_IQ , stat (mean q n) col(stat) save
return list
matrix list r(StatTotal)
matrix stats=r(StatTotal)

local avg  = stats[1,1] *100
local fmtavg : display %4.0f `avg'
display `fmtavg'
tempname uhandle
file open `uhandle' using "$overleaf/par_bondlevmean.tex",write text replace
file write `uhandle' "`fmtavg'\unskip"
file close `uhandle'

tabstat  fra_mb_IQ if q_lev_mb_IQ==2, stat (mean q n) col(stat) save
return list
matrix list r(StatTotal)
matrix stats=r(StatTotal)

local avg  = stats[3,1] *100
local fmtavg : display %4.0f `avg'
display `fmtavg'
tempname uhandle
file open `uhandle' using "$overleaf/par_bondoverdebtmed.tex",write text replace
file write `uhandle' "`fmtavg'\unskip"
file close `uhandle'

tabstat  fra_mb_IQ if q_lev_mb_IQ==3, stat (mean q n) col(stat) save
return list
matrix list r(StatTotal)
matrix stats=r(StatTotal)

local avg  = stats[3,1] *100
local fmtavg : display %4.0f `avg'
display `fmtavg'
tempname uhandle
file open `uhandle' using "$overleaf/par_bondoverdebthighmed.tex",write text replace
file write `uhandle' "`fmtavg'\unskip"
file close `uhandle'

tabstat  fra_ST, stat (mean q n) col(stat) save
return list
matrix list r(StatTotal)
matrix stats=r(StatTotal)

local avg  = stats[1,1] *100
local fmtavg : display %4.0f `avg'
display `fmtavg'
tempname uhandle
file open `uhandle' using "$overleaf/par_fraSTmean.tex",write text replace
file write `uhandle' "`fmtavg'\unskip"
file close `uhandle'

keep if tag_IY
	*** Cross-section in picture ***
foreach v of varlist size cash_oa profitability tangibility log_MB  DTI dtd {
xtile dec_`v' = `v' , nq(10)
loc getlabel: var label `v'
label var dec_`v' "`getlabel' deciles"
egen lev_med_dec_`v'= median(lev_IQ), by(dec_`v')
*egen lev_med_dec_`v'= mean(mlev_IQ), by(dec_`v')
egen lev_market_med_dec_`v'= median(lev_mb_IQ), by(dec_`v')
egen tag_dec_`v'=tag(dec_`v')
label var lev_med_dec_`v' "Debt over assets"
label var lev_market_med_dec_`v' "Bond debt over assets"
twoway scatter  lev_med_dec_`v' lev_market_med_dec_`v' dec_`v' if tag_dec_`v'==1, mcolor(red blue)  name(`v', replace)
}


grc1leg size cash_oa  profitability tangibility log_MB  dtd , name("Cross_SectionBondDebt", replace )
graph export "$overleaf/Default_Cross_SectionBondDebt.pdf",  replace


	*** Histogram of Cross-Section ***
hist size  , xtitle(,size(large)) ytitle(,size(large)) ylabel(,labsize(large)) xlabel(,labsize(large)) name(size, replace)

hist lev_IQ  if lev_IQ<1,width(.02) xscale(range(0 1)) xtitle(,size(large)) ytitle(,size(large)) ylabel(,labsize(large)) xlabel(0(0.2)1,labsize(large)) name(levbefore, replace)

hist lev_mb_IQ   , width(.02)   xscale(range(0 1)) xtitle(,size(large)) ytitle(,size(large)) ylabel(,labsize(large)) xlabel(0(0.2)1,labsize(large)) name(mlevbefore, replace) 

hist fra_mb_IQ   , width(.02)   xscale(range(0 1)) xtitle(,size(large)) ytitle(,size(large)) ylabel(,labsize(large)) xlabel(0(0.2)1,labsize(large))  name(fmarketbefore, replace)

gr combine size levbefore mlevbefore fmarketbefore, name("Histograms", replace ) 
graph export "$overleaf/Default_Histograms.pdf", replace


***********************************************************
*** Baseline - 2001 - 08 / 2007
*** 2 Day Window ***
***********************************************************

use ../../Int_Data/data/Default_stock_return_ext.dta,clear
keep date isin return2d
replace return2d = return2d * 10000
tempfile twodaywindow
save `twodaywindow'

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

merge 1:1 date isin using `twodaywindow'
drop if _merge == 2
drop _merge

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx

* Avg Response
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy  c.OIS_1M  $firmcontrols ,absorb(isin_num) cluster(isin_num date)

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy  c.OIS_1M#c.lev_IQ  lev_IQ  $firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

encode(NATION),gen(newNATION)

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa c.OIS_1M##c.profitability c.OIS_1M##c.tangibility c.OIS_1M##c.log_MB DTI, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa c.OIS_1M##c.profitability c.OIS_1M##c.tangibility c.OIS_1M##c.log_MB DTI, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)





reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

matrix coeff=r(table)
local intcoeff = coeff[1,3]

***********************************************************
*** Table Debt structure - Baseline - 2001 - 08 / 2007
*** Bankrupty Resolution ***
***********************************************************

import delimited ../../Raw_Data/original/bankruptcyframework.csv,clear
keep if indicator == "Resolving insolvency: Strength of insolvency framework index"
rename countryname  NATION
replace NATION = upper(NATION)
gen aux = inlist(NATION, "AUSTRIA", "BELGIUM", "FINLAND", "FRANCE", "GERMANY", "GREECE", "IRELAND")
replace aux = 1 if inlist(NATION,"ITALY", "LUXEMBOURG", "NETHERLANDS", "PORTUGAL", "SPAIN")
keep if aux ==1
drop countryiso3 indicatorid indicator subindicatortype aux
rename year* wbframe*
/*
drop wbframe2020
keep if wbframe2019!=.
xtile t_wbframe2019 =  wbframe2019,nq(3)
keep NATION t_wbframe2019 wbframe2019
tempfile bankruptcydataold
save `bankruptcydataold'
*/

foreach num of numlist 2003/2019{
	xtile t_wbframe`num' =  wbframe`num', nq(3)
}
foreach num of numlist 2000/2002{
	gen wbframe`num' = wbframe2003
	xtile t_wbframe`num' =  t_wbframe2003
}

keep NATION t_* wbf*
*label var t_wbframe "Bankruptcy Framework Tercile"
*tab NATION t_wbframe
reshape long t_wbframe wbframe, i(NATION) j(year)
rename year yr_adj

tempfile bankruptcydatayear
save `bankruptcydatayear'

keep if yr_adj == 2003
drop yr_adj
rename wbframe wbframe_beg 
rename t_wbframe t_wbframe_beg
tempfile bankruptcydatabeginning
save `bankruptcydatabeginning'

import excel ../../Raw_Data/original/indicator_resolvingbankrupty.xlsx,clear firstrow
keep if A =="x"
drop A
replace Location = upper(Location)
rename Location NATION
foreach var of varlist ResolvingInsolvencyscore Recoveryratecentsonthedoll Timeyears Costofestate Outcome0aspiecemealsaleand Strengthofinsolvencyframework ResolvingInsolvencyrank{
	destring `var',replace
}

rename ResolvingInsolvencyscore bankruptcyindex
rename Recoveryratecentsonthedoll bankruptcyrecoveryrate
rename Timeyears bankruptcyyears
rename Strengthofinsolvencyframework bankruptcyframework

xtile t_bankruptcyframework =  bankruptcyframework,nq(3)

tempfile bankruptcydata
save `bankruptcydata'

use ../../Raw_Data/original/europe_hyshare.dta,clear
xtile hy_tercile = hy_share, nquantiles(3)
tempfile hydata
save `hydata'

use ../../Int_Data/data/Default_stock_return_ext.dta,clear
keep date isin return2d
replace return2d = return2d * 10000
tempfile twodaywindow
save `twodaywindow'


use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
gen fullsample = date < date("01082007","DMY") & year > 2000
replace  fullsample  = 1 if year < 2019 & year > 2012
tab tag_date if fullsample
keep if fullsample
merge m:1 NATION using `bankruptcydata'
drop if _merge == 2
drop _merge
merge m:1 NATION yr_adj using `bankruptcydatayear'
drop if _merge == 2
drop _merge
merge m:1 NATION using `bankruptcydatabeginning'
drop if _merge == 2
drop _merge
merge m:1 NATION using `hydata'
drop if _merge == 2
drop _merge
merge 1:1 date isin using `twodaywindow'
drop if _merge == 2
drop _merge

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"
gen  dur_proxy = LTG_EPS_mx

* Baseline
* reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

* HY Share  Continuous Interaction (year based)
gen d_hy = hy_share > 0


encode(NATION),gen(countryfe)

reghdfe return2d c.OIS_1M##c.lev_mb_IQ#ibn.hy_tercile $firmcontrols $controlinteractions ,  ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b_hy
estadd local FE "\checkmark"
estadd local DC "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return2d c.OIS_1M##c.lev_mb_IQ#i.hy_tercile $firmcontrols $controlinteractions c.OIS_1M#i.countryfe i.countryfe,  ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b_hy_cfe
estadd local FE "\checkmark"
estadd local DC "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local NFE "\checkmark"

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ#i.t_wbframe $firmcontrols $controlinteractions ,  ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b_bankruptcy
estadd local FE "\checkmark"
estadd local DC "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ#i.t_wbframe $firmcontrols $controlinteractions c.OIS_1M#i.countryfe i.countryfe,  ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b_bankruptcy_cfe
estadd local FE "\checkmark"
estadd local DC "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local NFE "\checkmark"


#delimit;
esttab b_bankruptcy b_bankruptcy_cfe b_hy b_hy_cfe 
		using "$overleaf/Default_Bankruptcy.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  	 nogaps
		obslast booktabs  nonotes nomtitles
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "NFE Country x shock")
		keep(1.t_wbframe#c.OIS_1M#c.lev_mb_IQ 2.t_wbframe#c.OIS_1M#c.lev_mb_IQ 3.t_wbframe#c.OIS_1M#c.lev_mb_IQ  1.hy_tercile#c.OIS_1M#c.lev_mb_IQ 2.hy_tercile#c.OIS_1M#c.lev_mb_IQ 3.hy_tercile#c.OIS_1M#c.lev_mb_IQ)
		coeflabels(1.t_wbframe#c.OIS_1M#c.lev_mb_IQ "1. Tercile Bank. Framwork $\times \Delta$ OIS1M $\times$ Bond debt over assets"   2.t_wbframe#c.OIS_1M#c.lev_mb_IQ "2. Tercile Bank. Framwork $\times \Delta$ OIS1M $\times$ Bond debt over assets" 3.t_wbframe#c.OIS_1M#c.lev_mb_IQ "3. Tercile Bank. Framwork $\times \Delta$ OIS1M $\times$ Bond debt over assets" 1.hy_tercile#c.OIS_1M#c.lev_mb_IQ "1. Tercile HY Share $\times \Delta$ OIS1M $\times$ Bond debt over assets" 2.hy_tercile#c.OIS_1M#c.lev_mb_IQ "2. Tercile HY Share $\times \Delta$ OIS1M $\times$ Bond debt over assets" 3.hy_tercile#c.OIS_1M#c.lev_mb_IQ "3. Tercile HY Share $\times \Delta$ OIS1M $\times$ Bond debt over assets")
		label substitute(\_ _);
#delimit cr


/*
* Bankrupty Framework Continuous Interaction (year based)
label var wbframe "Bankruptcy Framework"
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ##c.wbframe ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "control x shock"
estadd local IS "\checkmark"

tab NATION t_wbframe_beg

tab NATION t_wbframe

* Bankrupty Framework BEGINNING Tercile Interaction
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ#ibn.t_wbframe_beg ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ#ibn.t_wbframe_beg ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)



/*
* Nation Dummy
encode(NATION),gen(nation_num)

replace t_wbframe = 4 if NATION == "FRANCE"
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ#ibn.t_wbframe ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)


* Bankrupty Framework Tercile Interaction (year based)
label var t_wbframe "Tercile Bankruptcy Fr."
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ#i.t_wbframe ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "control x shock"
estadd local IS "\checkmark"
*/

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ##c.wbframe  ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "control x shock"
estadd local IS "\checkmark"

* Bankrupty Framework Control
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.wbframe ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "control x shock"
estadd local IS "\checkmark"


*
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ##c.wbframe ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size /// 
c.OIS_1M##c.cash_oa c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)


* Bankrupty Framework Continuous Interaction (year based) -- shock year interaction
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ##c.wbframe ///
c.OIS_1M##ibn.nation_num c.OIS_1M##c.lev_IQ c.OIS_1M##c.size /// 
c.OIS_1M##c.cash_oa c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

gen d_france = NATION == "FRANCE" 
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy ///
c.OIS_1M##c.lev_mb_IQ#i.d_france ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size /// 
c.OIS_1M##c.cash_oa c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy ///
c.OIS_1M##c.lev_mb_IQ##c.wbframe#i.d_france ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size /// 
c.OIS_1M##c.cash_oa c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy ///
c.OIS_1M##c.lev_mb_IQ#ibn.nation_num ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size /// 
c.OIS_1M##c.cash_oa c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)


reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ  ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "control x shock"
estadd local IS "\checkmark"
estadd local NFE "country x shock"
*/


***********************************************************
*** Table Debt structure - Baseline - 2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"
gen  dur_proxy = LTG_EPS_mx

* Avg Response
reghdfe return c.OIS_1M  $firmcontrols $controlinteractions ,absorb(isin_num) cluster(isin_num date)


reghdfe return  c.OIS_1M#c.lev_IQ  lev_IQ  $firmcontrols $controlinteractions ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols $controlinteractions , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


local intcoeff = _b[c.OIS_1M#c.lev_mb_IQ ]
display `intcoeff'

	*Bond issuer dummy works
reghdfe return bondtimesshock  mb_issuer_IQ   $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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
	forvalues y = 2001/2007 {	
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

	reghdfe return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols $controlinteractions , absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 
	est store b4
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}



reghdfe return c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ $firmcontrols $controlinteractions , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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
	forvalues y = 2001/2007 {	
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

	reghdfe return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols $controlinteractions c.lev_IQ c.OIS_1M#c.lev_IQ, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 

	est store b6
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}


reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols ///
$controlinteractions ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols $controlinteractions ///
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
		using "$overleaf/Default_Firm_DebtStructure.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr


	*MAKE PRESENTATION TABLE
#delimit;
esttab  b2 b4 b5 b6 b7 b8
		using "$overleaf/Default_Firm_DebtStructurePres.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ   *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr


	* OUTPUT NUMBER
tabstat  lev_mb_IQ , stat (mean q n) col(stat) save
matrix list r(StatTotal)
matrix stats=r(StatTotal)

local teffect  =  - (stats[4,1] - stats[2,1] ) * `intcoeff' * 25
local fmtavg : display %4.0f `teffect'
display `fmtavg'
tempname uhandle
file open `uhandle' using "$overleaf/par_baselineeffect.tex" ,write text replace
file write `uhandle' "`fmtavg'\unskip"
file close `uhandle'

***********************************************************
*** Table Robustness Shock  2001 - 08 / 2007 ***
***********************************************************

est clear
import delimited "../../Raw_Data/original/dailydataset.csv",clear
gen statadate = date(date,"YMD")
format statadate %td
drop date
rename statadate date
tempfile factors
save `factors'

	***
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"

merge m:1 date using `factors'
drop if _merge==2

label var ratefactor1 "Target Factor"
label var conffactor1 "Timing Factor"
label var conffactor2 "Forward Guidance Factor"

	/// Interaction All factors
reghdfe return c.ratefactor1#c.lev_mb_IQ c.conffactor1#c.lev_mb_IQ c.conffactor2#c.lev_mb_IQ c.lev_mb_IQ  c.surprise_std#c.lev_mb_IQ $firmcontrols $controlinteractions ///
if date < date("01082007","DMY") & year > 2000, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b_altavilla
estadd local DC "\checkmark"
estadd local LC "\checkmark"
estadd local FE "\checkmark"
estadd local UI "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	* Baseline Altavilla et al. - OIS 1M
reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	* Altavilla 3M
reghdfe return c.OIS_3M#c.lev_mb_IQ c.lev_mb_IQ  ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_3M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_3M#c.lev_IQ ///
$firmcontrols $controlinteractions , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	* Giancarlo Corsetti et al. - OIS 1M Quasi-intraday
reghdfe return c.d_ois1mtl#c.lev_mb_IQ c.lev_mb_IQ  ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.d_ois1mtl#c.fra_mb_IQ c.fra_mb_IQ  ///
lev_IQ c.d_ois1mtl#c.lev_IQ  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	* Jarocinsky and Karadi 3M EONIA

reghdfe return c.eureon3m_hf#c.lev_mb_IQ c.lev_mb_IQ ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.eureon3m_hf#c.fra_mb_IQ c.fra_mb_IQ ///
lev_IQ c.eureon3m_hf#c.lev_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b8
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	*MAKE TABLE
#delimit;
esttab  b5 b7 b1 b3 b_altavilla
		using "$overleaf/Default_Firm_RobShock.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "UI UI claim controls")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons lev_mb_IQ  c.surprise_std#c.lev_mb_IQ c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		label substitute(\_ _);
#delimit cr

#delimit;
esttab   b5 b7 b1 b3 b_altavilla
		using "$overleaf/Default_Firm_RobShockPres.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "UI UI claim controls")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons lev_mb_IQ c.surprise_std#c.lev_mb_IQ c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		label substitute(\_ _);
#delimit cr


***********************************************************
*** Table Robustness Information Effect  2001 - 08 / 2007 ***
***********************************************************
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"
*gen  dur_proxy = LTG_EPS_mx

reghdfe return c.eureon3m_hf#c.lev_mb_IQ c.lev_mb_IQ  ///
 $firmcontrols $controlinteractions if d_info == 0, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
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
}


reghdfe return eureon3m_hf c.eureon3m_hf#ib1.q_lev_mb_IQ ///
ib1.q_lev_mb_IQ $firmcontrols $controlinteractions if d_info == 0, ///
 absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"



reghdfe return c.eureon3m_hf#c.fra_mb_IQ ///
fra_mb_IQ c.eureon3m_hf#c.lev_IQ lev_IQ $firmcontrols $controlinteractions if d_info == 0 ,  ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
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
}

reghdfe return eureon3m_hf c.eureon3m_hf#ib1.q_fra_mb_IQ ///
ib1.q_fra_mb_IQ c.eureon3m_hf#c.lev_IQ c.lev_IQ $firmcontrols $controlinteractions  if d_info == 0, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe return c.eureon3m_hf#c.lev_mb_IQ ///
 c.lev_mb_IQ c.eureon3m_hf#c.lev_IQ c.lev_IQ  $firmcontrols $controlinteractions if d_info == 0, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


	*MAKE TABLE
#delimit;
esttab  b1 b2 b3 b4 b5 
		using "$overleaf/Default_Firm_InfoEffect.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		drop(*.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.eureon3m_hf 1.q_fra_mb_IQ#c.eureon3m_hf  size cash_oa profitability tangibility log_MB DTI cov_ratio _cons eureon3m_hf c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio )
			order(c.eureon3m_hf#c.lev_mb_IQ lev_mb_IQ *.q_lev_mb_IQ#c.eureon3m_hf c.eureon3m_hf#c.fra_mb_IQ fra_mb_IQ c.eureon3m_hf#c.lev_IQ lev_IQ *.q_fra_mb_IQ#c.eureon3m_hf  )
		label substitute(\_ _);
#delimit cr


	*PRESENTATION
#delimit;
esttab  b1 b2 b3 b4 b5 
		using "$overleaf/Default_Firm_InfoEffectPres.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		drop(*.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.eureon3m_hf 1.q_fra_mb_IQ#c.eureon3m_hf  size cash_oa profitability tangibility log_MB DTI cov_ratio _cons eureon3m_hf c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order(c.eureon3m_hf#c.lev_mb_IQ lev_mb_IQ *.q_lev_mb_IQ#c.eureon3m_hf c.eureon3m_hf#c.fra_mb_IQ fra_mb_IQ c.eureon3m_hf#c.lev_IQ lev_IQ *.q_fra_mb_IQ#c.eureon3m_hf  )
		label substitute(\_ _);
#delimit cr


***********************************************************
*** Table Robustness Rating  2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"
*gen  dur_proxy = LTG_EPS_mx

replace  rating_group = 0 if  rating_group ==.
est clear

reghdfe return c.OIS_1M##ib0.rating_group $firmcontrols $controlinteractions , ///
absorb(isin_num i.ind_group#i.date)  cluster(isin_num date)
est store g1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"	

reghdfe return c.OIS_1M##ib0.rating_group ///
c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store g2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"	

	*Fraction of bond debt, controling for leverage, works
reghdfe return c.OIS_1M##ib0.rating_group ///
c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ $firmcontrols $controlinteractions, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store g3
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"	

	*Tercile of fraction of bond debt, controling for leverage, works
reghdfe return c.OIS_1M##ib0.rating_group ///
c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store g4
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"		

#delimit;
esttab  g1 g2 g3 g4
        using "$overleaf/Default_Firm_DebtStructureRatingShock.tex", 
	    replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 ) noconstant  nomtitles nogaps
		obslast booktabs  nonotes scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio OIS_1M _cons 0.rating_group 0.rating_group#c.OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.fra_mb_IQ fra_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ)
		label substitute(\_ _);
#delimit cr

#delimit;
esttab  g1 g2 g3 g4
        using "$overleaf/Default_Firm_DebtStructureRatingShockPres.tex", 
	    replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 ) 
		noconstant  nomtitles nogaps obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio OIS_1M lev_IQ lev_mb_IQ _cons *.rating_group  0.rating_group 0.rating_group#c.OIS_1M fra_mb_IQ c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order(c.OIS_1M#c.lev_mb_IQ c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ)
		label substitute(\_ _);
#delimit cr


***********************************************************
*** Table Abnormal Returns CAPM  2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
merge 1:1 date isin using ../../Int_Data/data/Default_abn_return.dta
drop if _merge==2
drop _merge
keep if date < date("01082007","DMY") & year > 2000

est clear
*gen  dur_proxy = LTG_EPS_mx
replace  abn_return =  abn_return * 10000
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"

reghdfe abn_return c.OIS_1M#c.lev_IQ  lev_IQ $firmcontrols $controlinteractions ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe abn_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

matrix coeff=r(table)
local intcoeff = coeff[1,3]

	*Bond issuer dummy works
reghdfe abn_return bondtimesshock mb_issuer_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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

	reghdfe abn_return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 
	est store b4
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}



reghdfe  abn_return c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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

	reghdfe abn_return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols $controlinteractions c.lev_IQ c.OIS_1M#c.lev_IQ, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 

	est store b6
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}


reghdfe abn_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols $controlinteractions ///
 ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe abn_return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols $controlinteractions ///
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
		using "$overleaf/Default_Firm_RobCAPM.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr

	*MAKE TABLE
#delimit;
esttab   b2  b4 b5 b6 b7 
		using "$overleaf/Default_Firm_RobCAPMPres.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr




***********************************************************
*** Robustness: Table Debt structure - Full Sample
***********************************************************
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"

drop q_lev_mb_IQ 
local nq = 3
foreach var of varlist lev_mb_IQ{
	di "########################################################################"
	di "########################## Working on Variable `var' ###################"

	gen q_`var'_help=.
	forvalues y = 2001/2018 {	
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

}

drop q_fra_mb_IQ 
local nq = 3
foreach var of varlist fra_mb_IQ{
	di "########################################################################"
	di "########################## Working on Variable `var' ###################"

	gen q_`var'_help=.
	forvalues y = 2001/2018 {	
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
}

gen fullsample = date < date("01082007","DMY") & year > 2000
replace  fullsample  = 1 if year < 2019 & year > 2012
tab tag_date if fullsample
keep if fullsample

drop tag_isin
egen tag_isin = tag(isin)
tab tag_isin if fullsample


egen tag_d = tag(date)
tab tag_d if fullsample

reghdfe return c.OIS_1M#c.lev_IQ  lev_IQ  $firmcontrols $controlinteractions ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

matrix coeff=r(table)
local intcoeff = coeff[1,3]


	*Bond issuer dummy works
reghdfe return bondtimesshock mb_issuer_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe return c.OIS_1M c.OIS_1M#ib1.q_lev_mb_IQ ib1.q_lev_mb_IQ $firmcontrols $controlinteractions , absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe return c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"



reghdfe return c.OIS_1M c.OIS_1M#ib1.q_fra_mb_IQ ib1.q_fra_mb_IQ $firmcontrols $controlinteractions c.lev_IQ c.OIS_1M#c.lev_IQ, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 

est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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
		using "$overleaf/Default_Firm_DebtStructureFullSample.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr




#delimit;
esttab   b2 b4 b5 b6 b7 b8 
		using "$overleaf/Default_Firm_DebtStructureFullSamplePres.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr



***********************************************************
*** Table Robustness: QE Response
***********************************************************

est clear
import delimited "../../Raw_Data/original/dailydataset.csv",clear
gen statadate = date(date,"YMD")
format statadate %td
drop date
rename statadate date
* twoway scatter ois_de_con_5y conffactor3
tempfile factors
save `factors'

	***

use "../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample",clear

global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"
* gen  dur_proxy = LTG_EPS_mx

merge m:1 date using `factors'
drop if _merge==2
drop _merge

label var ratefactor1 "Target Factor"
label var conffactor1 "Timing Factor"
label var conffactor2 "Forward Guidance Factor"
label var conffactor3 "QE Factor"
label var surprise_std "UI Shock"
rename conffactor3 QEfactor

* QE Specification 

drop tag_date
egen tag_date = tag(date)
tab tag_date if year < 2019 & year > 2012
label var ois_de_con_5y "OIS 5Y"

 * Altavilla preferred specification 
reghdfe return c.OIS_1M#c.lev_mb_IQ c.QEfactor#c.lev_mb_IQ c.lev_mb_IQ  ///
$firmcontrols $controlinteractions if year < 2019 & year > 2013, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.ois_de_con_5y#c.lev_mb_IQ c.lev_mb_IQ  ///
$firmcontrols $controlinteractions if year < 2019 & year > 2013, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.QEfactor#c.lev_mb_IQ c.surprise_std#c.lev_mb_IQ c.lev_mb_IQ surprise_std  ///
$firmcontrols $controlinteractions if year < 2019 & year > 2013, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"
 
 	*MAKE TABLE
#delimit;
esttab  b1 b2 b4
		using "$overleaf/Default_Firm_QE.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons lev_mb_IQ c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		label substitute(\_ _);
#delimit cr



***********************************************************
*** TablePost Crisis Sample Output 2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if year > 2012 & year<2019

drop tag_isin
egen tag_isin=tag(isin)
tab tag_isin

drop tag_IY
egen tag_IY=tag(isin year) 
tab year if  tag_IY

egen tag_d = tag(date)
tab year if tag_d

estpost tabstat assets_inBN cash_oa profitability tangibility LTG_EPS_mx MB DTI cov_ratio lev_IQ fra_ST lev_market_IQ  fra_mdebt_IQ, stat (mean q n) col(stat) listwise

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"

reghdfe return c.OIS_1M#c.lev_IQ  lev_IQ  $firmcontrols $controlinteractions ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

matrix coeff=r(table)
local intcoeff = coeff[1,3]

	*Bond issuer dummy works
reghdfe return bondtimesshock mb_issuer_IQ $firmcontrols $controlinteractions , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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

	reghdfe return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 
	est store b4
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}



reghdfe return c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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

	reghdfe return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols $controlinteractions c.lev_IQ c.OIS_1M#c.lev_IQ, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 

	est store b6
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}


reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols $controlinteractions ///
 ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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
		using "$overleaf/Default_Firm_PostCrisis.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ  *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr

/*
	*MAKE PRESENTATION TABLE
#delimit;
esttab  b2 b4 b5 b6 b7 b8
		using "$overleaf/Default_Firm_PostCrisisPres.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI q_fra_mb_IQ fra_mb_IQ cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ lev_mb_IQ q_lev_mb_IQ  c.OIS_1M#c.dur_proxy dur_proxy lev_IQ)
		order(c.OIS_1M#c.lev_mb_IQ c.OIS_1M#c.q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ)
		label substitute(\_ _);
#delimit cr
*/

***********************************************************
*** Table Default Probabilities  2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"


*sum defprob if q_defprob==3&finalsample==1 ,det
*sum defprob if q_defprob==4&finalsample==1 ,det
*label var m_dfprob "Median Default"
label var q_defprob "Quartile Default"

	* default probability as control
reghdfe return c.OIS_1M c.OIS_1M#c.lev_mb_IQ ///
c.lev_mb_IQ c.OIS_1M#ib1.q_defprob ib1.q_defprob $firmcontrols $controlinteractions ///
, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.defprob ///
defprob $firmcontrols $controlinteractions, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
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
}


reghdfe return OIS_1M c.OIS_1M#ib1.q_lev_mb_IQ ib1.q_lev_mb_IQ ///
 c.OIS_1M#ib1.q_defprob ib1.q_defprob  $firmcontrols $controlinteractions, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return OIS_1M c.OIS_1M#ib1.q_lev_mb_IQ ib1.q_lev_mb_IQ ///
c.OIS_1M#c.defprob defprob $firmcontrols $controlinteractions, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	
	* TABLE
#delimit;
esttab  b2 b1 b4 b3
        using "$overleaf/Default_Firm_DistancetoDefaultControl.tex", 
	    replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01  ) noconstant  nomtitles nogaps
		obslast booktabs  
		nonotes scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		drop( *.q_lev_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M OIS_1M size cash_oa profitability tangibility log_MB DTI cov_ratio 	_cons 1.q_defprob#c.OIS_1M *.q_defprob c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ *.q_lev_mb_IQ#c.OIS_1M OIS_1M  c.OIS_1M#c.q_lev_mb_IQ)
		label substitute(\_ _);
#delimit cr

/*
	* PRESENTATION
#delimit;
esttab  b2 b1 b4 b3
        using "$overleaf/Default_Firm_DistancetoDefaultControlPres.tex", 
	    replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01  ) noconstant  nomtitles nogaps
		obslast booktabs  
		nonotes scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop( c.OIS_1M#c.dur_proxy dur_proxy q_lev_mb_IQ lev_mb_IQ size cash_oa profitability tangibility log_MB DTI cov_ratio _cons 4.q_defprob#c.OIS_1M *.q_defprob defprob)
		order(  c.OIS_1M#c.lev_mb_IQ c.OIS_1M#c.q_lev_mb_IQ c.OIS_1M#c.defprob)
		label substitute(\_ _);
#delimit cr
*/

***********************************************************
*** Additional Robustness - 2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx

label var age "Age"
reghdfe  return  c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.age c.age  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

reghdfe  return  c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.size c.size  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

* Enterprise value 
gen log_enterprise_value =log(enterprise_value)
label var log_enterprise_value "Log Enterprise Value"
reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.log_enterprise_value c.log_enterprise_value c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.tangibility c.tangibility  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"


reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.cash_oa c.cash_oa  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"


reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.cov_ratio c.cov_ratio  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

* Equity vol
*replace equity_vol = equity_vol
label var equity_vol "Equity std."
reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.equity_vol c.equity_vol c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

* Operating profitability
label var operating_profitability "Operating profitability"
reghdfe return c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.operating_profitability c.operating_profitability c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
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
esttab  b1 b2 b6 b3 b4 b5 b7 b8
		using "$overleaf//Default_Firm_AddRobustness.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(age size log_enterprise_value cash_oa cov_ratio equity_vol profitability tangibility log_MB DTI _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ operating_profitability)
		label substitute(\_ _);
#delimit cr



***********************************************************
*** Triple Difference - 2001 - 08 / 2007 ***
***********************************************************


use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"


drop tag_IY
egen tag_IY=tag(isin year) 
tab year if  tag_IY

drop tag_isin
egen tag_isin=tag(isin)
tab tag_isin

drop q_dtd q_defprob


local nq = 3
foreach var of varlist   equity_vol dtd defprob {
	gen q_`var'_help=.
	forvalues y = 2001/2007 {	
		xtile q_help_`y' = `var' if year==`y'  & tag_IY==1, nquantiles(`nq')
		*tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y'
		drop  q_help_`y'
	}
	egen q_`var' = mean(q_`var'_help),by(year isin)
	drop q_`var'_help
	
	di "########################################################################"
	di "########################## Working on Variable `var' ###################"


	
}

label define vollabel 2 "2. Tercile Equity Vol." 3 "3. Tercile Equity Vol."
label values q_equity_vol vollabel
	
local var "equity_vol"
reghdfe return ib1.q_`var'##c.lev_mb_IQ##c.OIS_1M  ///
		  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	***
	
label define defproblabel 2 "2. Tercile Default Probability" 3 "3. Tercile Default Probability"
label values  q_defprob defproblabel
	
*local var "dtd"
local var "defprob"
reghdfe return ib1.q_`var'##c.lev_mb_IQ##c.OIS_1M  ///
		  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


	*MAKE TABLE
#delimit;
esttab  b2 b1 
		using "$overleaf/Default_Firm_TripleDiff.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons lev_mb_IQ  		*.q_equity_vol#c.OIS_1M OIS_1M *.q_equity_vol#c.lev_mb_IQ *.q_equity_vol 1.q_equity_vol#c.lev_mb_IQ#c.OIS_1M *.q_defprob#c.OIS_1M OIS_1M *.q_defprob#c.lev_mb_IQ *.q_defprob 1.q_defprob#c.lev_mb_IQ#c.OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		label substitute(\_ _);
#delimit cr



***********************************************************
*** Table  -- ROBUSTNESS 2 DAY RETURNS 
***********************************************************


global additionaldatapath = "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Extra_Analysis"

est clear
import delimited "../../Raw_Data/original/dailydataset.csv",clear
gen statadate = date(date,"YMD")
format statadate %td
drop date
rename statadate date
tempfile factors
save `factors'

use ../../Int_Data/data/Default_stock_return_ext.dta,clear
keep date isin return2d
replace return2d = return2d * 10000
tempfile twodaywindow
save `twodaywindow'

	***

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"


merge 1:1 date isin using `twodaywindow'
drop if _merge == 2
drop _merge

reghdfe return2d c.OIS_1M#c.lev_IQ lev_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return2d c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

matrix coeff=r(table)
local intcoeff = coeff[1,3]


	*Bond issuer dummy works
reghdfe return2d bondtimesshock mb_issuer_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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
	forvalues y = 2001/2007 {	
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

	reghdfe return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 
	est store b4
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}

reghdfe return2d c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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
	forvalues y = 2001/2007 {	
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

	reghdfe return c.OIS_1M c.OIS_1M#ib1.q_`var' ib1.q_`var' ///
		  $firmcontrols $controlinteractions c.lev_IQ c.OIS_1M#c.lev_IQ, absorb(isin_num i.ind_group#i.date) cluster(isin_num date) 

	est store b6
	estadd local DC "\checkmark"
	estadd local FE "\checkmark"
	estadd local D "\checkmark"
	estadd local CT "\checkmark"
	estadd local IS "\checkmark"
}


reghdfe return2d c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return2d c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
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
		using "$overleaf/Default_Firm_DebtStructure_2dayReturn.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ *.q_lev_mb_IQ *.q_fra_mb_IQ 1.q_lev_mb_IQ#c.OIS_1M 1.q_fra_mb_IQ#c.OIS_1M OIS_1M c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ *.q_lev_mb_IQ#c.OIS_1M c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.lev_IQ fra_mb_IQ lev_IQ )
		label substitute(\_ _);
#delimit cr

***********************************************************
*** Table  -- MATURITY -- FIRST SAMPLE
***********************************************************

global additionaldatapath = "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Extra_Analysis"

est clear
import delimited "../Raw_Data/original/dailydataset.csv",clear
gen statadate = date(date,"YMD")
format statadate %td
drop date
rename statadate date
tempfile factors
save `factors'

use "../Int_Data/data/Default_stock_return_ext.dta",clear
keep date isin return2d
replace return2d = return2d * 10000
tempfile twodaywindow
save `twodaywindow'

	***

*use "/Users/olivergiesecke/Dropbox/Replication kit/Data/Final/wrds_compustat2002-18.dta",clear
*keep fyear companyid maturity_waverage 
*replace maturity_waverage = maturity_waverage / 365
*rename fyear yr_adj


	***

use "../Analysis/data/Firm_Return_WS_Bond_Duration_Data_Default_Sample",clear
*keep if date < date("01082007","DMY") & year > 2000
gen fullsample = date < date("01082007","DMY") & year > 2000
replace  fullsample  = 1 if year < 2019 & year > 2012
tab tag_date if fullsample
keep if fullsample


est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
global controlinteractions "c.OIS_1M#c.size c.OIS_1M#c.cash_oa c.OIS_1M#c.profitability c.OIS_1M#c.tangibility c.OIS_1M#c.log_MB c.OIS_1M#c.DTI c.OIS_1M#c.cov_ratio"

merge 1:1 date isin using `twodaywindow'
drop if _merge == 2
drop _merge

merge m:1 date using `factors'
drop if _merge==2
drop _merge 

gen companyid = substr(capIQid,3,.)
destring companyid,replace

merge m:1 companyid yr_adj using "$additionaldatapath/debt_avgmaturity.dta"
drop if _merge ==2 
drop _merge

merge m:1 companyid yr_adj using "$additionaldatapath/debt_shfloating"
drop if _merge ==2 
drop _merge

merge m:1 companyid yr_adj using "$additionaldatapath/debt_exposure"
drop if _merge ==2 
drop _merge

label var ratefactor1 "Target Factor"
label var conffactor1 "Timing Factor"
label var conffactor2 "Forward Guidance Factor"

* Baseline
reghdfe return c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "simple"
estadd local IS "\checkmark"

/* Control Interactions
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "controls x shock"
estadd local IS "\checkmark"

* 2-day returns
reghdfe  return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ ///
$firmcontrols, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "simple"
estadd local IS "\checkmark"

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "control x shock"
estadd local IS "\checkmark"


#delimit;
esttab b1 b2 b3 b4 
		using "$overleaf/Default_Robustness1.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  	 nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		keep(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.lev_IQ  lev_IQ )
		label substitute(\_ _);
#delimit cr


conffactor2

c.conffactor2##c.lev_mb_IQ c.conffactor2##c.lev_IQ ///
c.conffactor2##c.w_maturity c.conffactor2##c.size  ///
c.conffactor2##c.cash_oa c.conffactor2##c.profitability ///
c.conffactor2##c.tangibility c.conffactor2##c.log_MB /// 
c.conffactor2##c.DTI c.conffactor2##c.cov_ratio
*/

* Volume weighted maturity
est clear
label var w_maturity "Maturity (principal weighted)"
reghdfe return c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ w_maturity OIS_1M c.OIS_1M#c.w_maturity c.conffactor2#c.w_maturity $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


*c.conffactor2##c.lev_mb_IQ c.conffactor2##c.lev_IQ ///
*c.conffactor2##c.w_maturity c.conffactor2##c.size  ///
*c.conffactor2##c.cash_oa c.conffactor2##c.profitability ///
*c.conffactor2##c.tangibility c.conffactor2##c.log_MB /// 
*c.conffactor2##c.DTI c.conffactor2##c.cov_ratio

/*
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.share_floatingrate c.OIS_1M##c.size ///   c.OIS_1M##c.cash_oa c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB c.OIS_1M##c.DTI c.OIS_1M##c.cov_ratio ///
c.conffactor2##c.lev_mb_IQ c.conffactor2##c.lev_IQ ///
c.conffactor2##c.w_maturity c.conffactor2##c.size  ///
c.conffactor2##c.cash_oa c.conffactor2##c.profitability ///
c.conffactor2##c.tangibility c.conffactor2##c.log_MB /// 
c.conffactor2##c.DTI c.conffactor2##c.cov_ratio, ///, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
*/
* Share floating rate
label var share_floatingrate "Floating rate share"
reghdfe return c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ c.share_floatingrate c.OIS_1M#c.share_floatingrate c.conffactor2#c.share_floatingrate c.conffactor2 ///
$firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

/*
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.exposure c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
*/
* exposure 
label var exposure "Exposure"
reghdfe return c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ c.exposure c.OIS_1M#c.exposure ///
c.conffactor2 c.conffactor2#c.exposure $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

* Share floating + Maturity
reghdfe return c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ c.w_maturity c.OIS_1M#c.w_maturity c.OIS_1M#c.share_floatingrate c.share_floatingrate c.conffactor2 c.conffactor2#c.w_maturity c.conffactor2#c.share_floatingrate $firmcontrols $controlinteractions, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

/* exposure 
label var exposure "Exposure"
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.exposure ///
c.OIS_1M##c.lev_IQ  c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "controls x shock"
estadd local IS "\checkmark"
*/

#delimit;
esttab b1 b2 b3 b4
		using "$overleaf/Default_FloatingExposure.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 ) noconstant
		nogaps nomtitles obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		keep(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ c.OIS_1M#c.w_maturity w_maturity c.OIS_1M#c.share_floatingrate share_floatingrate c.conffactor2#c.w_maturity c.conffactor2#c.share_floatingrate c.OIS_1M#c.exposure c.conffactor2#c.exposure exposure )
		order(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ c.OIS_1M#c.w_maturity c.conffactor2#c.w_maturity w_maturity c.OIS_1M#c.share_floatingrate c.conffactor2#c.share_floatingrate share_floatingrate c.OIS_1M#c.exposure c.conffactor2#c.exposure exposure)
		label substitute(\_ _);
#delimit cr


#delimit;
esttab b1 b2 b3 b4
		using "$overleaf/Default_FloatingExposurePres.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 ) noconstant
		nogaps nomtitles obslast booktabs  nonotes 
		scalar("FE Firm FE" "CT Firm controls" "DC Firm controls x shock" "IS Sector $\times$ Date FE")
		keep(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.w_maturity w_maturity c.OIS_1M#c.share_floatingrate share_floatingrate c.conffactor2#c.w_maturity c.conffactor2#c.share_floatingrate c.OIS_1M#c.exposure c.conffactor2#c.exposure exposure )
		order(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.w_maturity c.conffactor2#c.w_maturity w_maturity c.OIS_1M#c.share_floatingrate c.conffactor2#c.share_floatingrate share_floatingrate c.OIS_1M#c.exposure c.conffactor2#c.exposure exposure)
		label substitute(\_ _);
#delimit cr



/*
reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.w_maturity##c.OIS_1M $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.w_maturity##c.OIS_1M $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.share_floatingrate##c.OIS_1M $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.exposure##c.OIS_1M $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.exposure##c.OIS_1M $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.exposure##c.OIS_1M c.exposure##c.size c.exposure##c.cash_oa c.exposure##c.profitability c.exposure##c.tangibility c.exposure##c.log_MB DTI c.exposure##c.cov_ratio ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.exposure##c.OIS_1M c.exposure##c.size c.exposure##c.cash_oa c.exposure##c.profitability c.exposure##c.tangibility c.exposure##c.log_MB DTI c.exposure##c.cov_ratio ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)


reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.exposure##c.ratefactor1 c.exposure##c.conffactor2 c.ratefactor1##c.size c.ratefactor1##c.cash_oa c.ratefactor1##c.profitability c.ratefactor1##c.tangibility c.ratefactor1##c.log_MB DTI c.ratefactor1##c.cov_ratio ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
*/

***********************************************************
*** Table  -- MATURITY -- LONG SAMPLE
***********************************************************



global additionaldatapath = "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Extra_Analysis"

est clear
import delimited "../../Raw_Data/original/dailydataset.csv",clear
gen statadate = date(date,"YMD")
format statadate %td
drop date
rename statadate date
tempfile factors
save `factors'

use ../../Int_Data/data/Default_stock_return_ext.dta,clear
keep date isin return2d
replace return2d = return2d * 10000
tempfile twodaywindow
save `twodaywindow'

	***

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
gen fullsample = date < date("01082007","DMY") & year > 2000
replace  fullsample  = 1 if year < 2019 & year > 2012
tab tag_date if fullsample
keep if fullsample

global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx

merge 1:1 date isin using `twodaywindow'
drop if _merge == 2
drop _merge

merge m:1 date using `factors'
drop if _merge==2
drop _merge 

gen companyid = substr(capIQid,3,.)
destring companyid,replace

merge m:1 companyid yr_adj using "$additionaldatapath/debt_avgmaturity.dta"
drop if _merge ==2 
drop _merge

merge m:1 companyid yr_adj using "$additionaldatapath/debt_shfloating"
drop if _merge ==2 
drop _merge

merge m:1 companyid yr_adj using "$additionaldatapath/debt_exposure"
drop if _merge ==2 
drop _merge

label var ratefactor1 "Target Factor"
label var conffactor1 "Timing Factor"
label var conffactor2 "Forward Guidance Factor"

* Baseline
reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ ///
$firmcontrols, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "simple"
estadd local IS "\checkmark"

* Control Interactions
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "control x shock"
estadd local IS "\checkmark"

* 2-day returns
reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ c.OIS_1M##c.lev_IQ ///
$firmcontrols, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "simple"
estadd local IS "\checkmark"

reghdfe return2d c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "control x shock"
estadd local IS "\checkmark"


#delimit;
esttab b1 b2 b3 b4 
		using "$overleaf/Default_Robustness1_long.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  	 nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		keep(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.lev_IQ  lev_IQ )
		label substitute(\_ _);
#delimit cr



* Volume weighted maturity
est clear
label var w_maturity "Maturity (principal weighted)"
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.w_maturity c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "controls x shock"
estadd local IS "\checkmark"


* Share floating rate
label var share_floatingrate "Floating rate share"
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.share_floatingrate c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "controls x shock"
estadd local IS "\checkmark"

* exposure 
label var exposure "Exposure"
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.exposure c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "controls x shock"
estadd local IS "\checkmark"


* Share floating  + Maturity
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##c.lev_mb_IQ ///
c.OIS_1M##c.lev_IQ c.OIS_1M##c.w_maturity c.OIS_1M##c.share_floatingrate c.OIS_1M##c.size c.OIS_1M##c.cash_oa /// 
c.OIS_1M##c.profitability c.OIS_1M##c.tangibility ///
c.OIS_1M##c.log_MB DTI c.OIS_1M##c.cov_ratio, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local CT "controls x shock"
estadd local IS "\checkmark"

#delimit;
esttab b1 b2 b3 b4
		using "$overleaf/Default_Robustness2_long.tex", 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  	 nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		keep(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ c.OIS_1M#c.w_maturity w_maturity c.OIS_1M#c.share_floatingrate share_floatingrate  c.OIS_1M#c.exposure exposure  )
		label substitute(\_ _);
#delimit cr












