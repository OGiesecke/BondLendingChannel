cap log close 
clear all 
set scheme sol, permanently
graph set window fontface "Times New Roman"
set linesize 150

* Set directories 
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
esttab c1 using ../output/Tab_SumStats_Shock.tex, ///
cells("count(pattern(1) fmt(0) label(N)) mean(pattern(1 ) fmt(3) label(Mean)) sd(pattern(1) fmt(2) label(SD) ) min(pattern(1) fmt(2) label(Min)) max(pattern(1) fmt(2) label(Max))") nonotes nomtitles label replace noobs compress substitute(\_ _)  booktabs nonumbers

********************************************************************************
*** Do Analysis on the default sample
********************************************************************************


*******************************
*** Sample Description ***
*******************************
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
graph export ../output/Default_SampleStats.pdf, replace

gen help_lev_IQ = lev_IQ  if date < date("01082007","DMY") & year > 2000 & tag_IY
gen help_lev_mb_IQ = lev_mb_IQ  if date < date("01082007","DMY") & year > 2000 & tag_IY
graph hbar (mean) help_lev_IQ help_lev_mb_IQ,over(industry,sort(help_lev_IQ) descending) ///
ytitle("") name(Levbyindustry,replace) legend(order(1 "Mean Leverage" 2 "Mean Bond Leverage"))
graph export ../output/Default_IndustryCapStructure.pdf, replace

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
export excel ../output/Default_finalsample.xlsx,replace
export delimited ../output/Default_finalsample.csv,replace

*******************************************
*** Rating Coverage ***
*******************************************

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
graph export ../output/Default_Ratingcov.pdf, replace
*/
twoway (area cum_share3 yr_adj, color(gs13)) (area cum_share2 yr_adj, color(gs9)) ///
(area cum_share1 yr_adj, color(gs4))(area cum_share0 yr_adj, color(gs2)), ///
ylabel(0 (25) 100) xlabel(2001(3)2016) xtitle("") text(30 2008 "{bf:Unrated}") ///
text(57 2006 "{bf:High-Yield}") text(80 2004 "{bf: IG below AA}") ///
text(99 2002 "{bf: IG AA and above}") legend(off) name(RatingCov,replace)
graph export ../output/Default_Ratingcov.pdf, replace



*******************************************
*** Capital Structure and Coverage ***
*******************************************

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
graph export  ../output/Samplecapitalstructure.pdf,replace

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
graph export ../output/Default_SampleCovDebtSec.pdf,replace

*reg issue_nonfincorp_fx IQ_BONDS_NOTES if year > 2000
*twoway scatter issue_nonfincorp_fx IQ_BONDS_NOTES if year > 2000
*gen d_bis = ln(issue_nonfincorp_fx)-ln(issue_nonfincorp_fx[_n-1])
*gen d_issue = ln(IQ_BONDS_NOTES)-ln(IQ_BONDS_NOTES[_n-1])
*twoway scatter d_bis d_issue if year > 2001

**********************************************************************
*** 2001 - 08 / 2007 Sample Statistics and Cross-Section Figures ***
**********************************************************************

est clear
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

drop tag_isin
egen tag_isin=tag(isin)
tab tag_isin

drop tag_IY
egen tag_IY=tag(isin year) 
tab year if  tag_IY


est clear

	*** Big table across terciles of bond debt ***
estpost tabstat assets_inBN cash_oa profitability tangibility LTG_EPS_mx MB DTI cov_ratio lev_IQ fra_ST lev_mb_IQ  fra_mb_IQ, by(q_lev_mb_IQ) stat (mean q n) col(stat) listwise
esttab using ../output/Default_CrossSection_SumStat.tex, ///
replace cells("mean(fmt(%9.3f)) p25 p50 p75 count(fmt(%9.0fc) label(count))") noobs nomtitle nonumber  label

	*** Sum Stat Presentation ***
estpost tabstat assets_inBN cash_oa profitability tangibility LTG_EPS_mx MB DTI cov_ratio lev_IQ fra_ST lev_mb_IQ  fra_mb_IQ, stat (mean q n) col(stat) 
esttab using ../output/Default_SumStatPres.tex, ///
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
file open `uhandle' using ../output/par_bondlevmean.tex,write text replace
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
file open `uhandle' using ../output/par_bondoverdebtmed.tex,write text replace
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
file open `uhandle' using ../output/par_bondoverdebthighmed.tex,write text replace
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
file open `uhandle' using ../output/par_fraSTmean.tex,write text replace
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
graph export ../output/Default_Cross_SectionBondDebt.pdf,  replace


	*** Histogram of Cross-Section ***
hist size  , xtitle(,size(large)) ytitle(,size(large)) ylabel(,labsize(large)) xlabel(,labsize(large)) name(size, replace)

hist lev_IQ  if lev_IQ<1,width(.02) xscale(range(0 1)) xtitle(,size(large)) ytitle(,size(large)) ylabel(,labsize(large)) xlabel(0(0.2)1,labsize(large)) name(levbefore, replace)

hist lev_mb_IQ   , width(.02)   xscale(range(0 1)) xtitle(,size(large)) ytitle(,size(large)) ylabel(,labsize(large)) xlabel(0(0.2)1,labsize(large)) name(mlevbefore, replace) 

hist fra_mb_IQ   , width(.02)   xscale(range(0 1)) xtitle(,size(large)) ytitle(,size(large)) ylabel(,labsize(large)) xlabel(0(0.2)1,labsize(large))  name(fmarketbefore, replace)

gr combine size levbefore mlevbefore fmarketbefore, name("Histograms", replace ) 
graph export ../output/Default_Histograms.pdf, replace




***********************************************************
*** Table Debt structure - Baseline - 2001 - 08 / 2007 ***
***********************************************************
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx

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

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_lev_mb_IQ c.q_lev_mb_IQ  $firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_fra_mb_IQ c.q_fra_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ   $firmcontrols  ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


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
		using ../output/Default_Firm_DebtStructure.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ c.OIS_1M#c.dur_proxy dur_proxy)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ c.OIS_1M#c.q_lev_mb_IQ q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ q_fra_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ)
		label substitute(\_ _);
#delimit cr


	*MAKE PRESENTATION TABLE
#delimit;
esttab  b2 b4 b5 b6 b7 b8
		using ../output/Default_Firm_DebtStructurePres.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI q_fra_mb_IQ fra_mb_IQ cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ  lev_mb_IQ q_lev_mb_IQ  c.OIS_1M#c.dur_proxy dur_proxy lev_IQ)
		order(c.OIS_1M#c.lev_mb_IQ c.OIS_1M#c.q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ)
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
file open `uhandle' using ../output/par_baselineeffect.tex,write text replace
file write `uhandle' "`fmtavg'\unskip"
file close `uhandle'

***********************************************************
*** Table Robustness Shock  2001 - 08 / 2007 ***
***********************************************************
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000


est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx


	* Baseline Altavilla et al. - OIS 1M
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  ///
 $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ ///
lev_IQ c.OIS_1M#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	* Altavilla 3M
reghdfe return c.OIS_3M#c.dur_proxy dur_proxy c.OIS_3M#c.lev_mb_IQ c.lev_mb_IQ  ///
 $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_3M#c.dur_proxy dur_proxy c.OIS_3M#c.fra_mb_IQ c.fra_mb_IQ ///
lev_IQ c.OIS_3M#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	* Giancarlo Corsetti et al. - OIS 1M Quasi-intraday
reghdfe return c.d_ois1mtl#c.dur_proxy dur_proxy c.d_ois1mtl#c.lev_mb_IQ c.lev_mb_IQ  ///
  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.d_ois1mtl#c.dur_proxy dur_proxy c.d_ois1mtl#c.fra_mb_IQ c.fra_mb_IQ  ///
lev_IQ c.d_ois1mtl#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	* Jarocinsky and Karadi 3M EONIA

reghdfe return c.eureon3m_hf#c.dur_proxy dur_proxy c.eureon3m_hf#c.lev_mb_IQ c.lev_mb_IQ ///
  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.eureon3m_hf#c.dur_proxy dur_proxy c.eureon3m_hf#c.fra_mb_IQ c.fra_mb_IQ ///
lev_IQ c.eureon3m_hf#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b8
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	*MAKE TABLE
#delimit;
esttab  b1 b2 b3 b4 b5 b6 b7 b8
		using ../output/Default_Firm_RobShock.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons lev_mb_IQ fra_mb_IQ lev_IQ c.eureon3m_hf#c.dur_proxy dur_proxy  c.d_ois1mtl#c.dur_proxy dur_proxy c.OIS_3M#c.dur_proxy dur_proxy c.OIS_1M#c.dur_proxy )
		label substitute(\_ _);
#delimit cr

#delimit;
esttab  b1 b2 b3 b4 b5 b6 b7 b8
		using ../output/Default_Firm_RobShockPres.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons lev_mb_IQ fra_mb_IQ lev_IQ c.eureon3m_hf#c.dur_proxy dur_proxy  c.d_ois1mtl#c.dur_proxy dur_proxy c.OIS_3M#c.dur_proxy dur_proxy c.OIS_1M#c.dur_proxy lev_mb_IQ fra_mb_IQ c.eureon3m_hf#c.lev_IQ c.OIS_3M#c.lev_IQ c.d_ois1mtl#c.lev_IQ  c.OIS_1M#c.lev_IQ)
		label substitute(\_ _);
#delimit cr


***********************************************************
*** Table Robustness Information Effect  2001 - 08 / 2007 ***
***********************************************************
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx

reghdfe return c.eureon3m_hf#c.dur_proxy dur_proxy  c.eureon3m_hf#c.lev_mb_IQ c.lev_mb_IQ  ///
 $firmcontrols if d_info == 0, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.eureon3m_hf#c.dur_proxy dur_proxy c.eureon3m_hf#c.q_lev_mb_IQ ///
 c.q_lev_mb_IQ  $firmcontrols if d_info == 0, ///
 absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.eureon3m_hf#c.dur_proxy dur_proxy c.eureon3m_hf#c.fra_mb_IQ ///
c.fra_mb_IQ  c.eureon3m_hf#c.lev_IQ lev_IQ  $firmcontrols if d_info == 0 ,  ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.eureon3m_hf#c.dur_proxy dur_proxy c.eureon3m_hf#c.q_fra_mb_IQ  ///
c.q_fra_mb_IQ c.eureon3m_hf#c.lev_IQ c.lev_IQ   $firmcontrols  if d_info == 0, ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe  return c.eureon3m_hf#c.dur_proxy dur_proxy c.eureon3m_hf#c.lev_mb_IQ ///
 c.lev_mb_IQ c.eureon3m_hf#c.lev_IQ c.lev_IQ  $firmcontrols if d_info == 0 ///
 ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


	*MAKE TABLE
#delimit;
esttab  b1 b2 b3 b4 b5 
		using ../output/Default_Firm_InfoEffect.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop(c.eureon3m_hf#c.dur_proxy dur_proxy size cash_oa profitability tangibility log_MB DTI cov_ratio _cons   )
		order(c.eureon3m_hf#c.lev_mb_IQ lev_mb_IQ  c.eureon3m_hf#c.q_lev_mb_IQ q_lev_mb_IQ   c.eureon3m_hf#c.fra_mb_IQ fra_mb_IQ c.eureon3m_hf#c.q_fra_mb_IQ q_fra_mb_IQ)
		label substitute(\_ _);
#delimit cr

	*PRESENTATION
#delimit;
esttab  b1 b2 b3 b4 b5 
		using ../output/Default_Firm_InfoEffectPres.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop(c.eureon3m_hf#c.dur_proxy dur_proxy size cash_oa profitability tangibility log_MB DTI cov_ratio _cons  lev_mb_IQ q_fra_mb_IQ  q_lev_mb_IQ fra_mb_IQ lev_IQ)
		order(c.eureon3m_hf#c.lev_mb_IQ  c.eureon3m_hf#c.q_lev_mb_IQ   c.eureon3m_hf#c.fra_mb_IQ c.eureon3m_hf#c.q_fra_mb_IQ)
		label substitute(\_ _);
#delimit cr

***********************************************************
*** Table Robustness Rating  2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx


replace  rating_group = 0 if  rating_group ==.
est clear

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##ib0.rating_group $firmcontrols  , ///
absorb(isin_num i.ind_group#i.date)  cluster(isin_num date)
est store g1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"	

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##ib0.rating_group ///
c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store g2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"	

	*Fraction of bond debt, controling for leverage, works
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##ib0.rating_group ///
c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ $firmcontrols , ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store g3
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"	

	*Tercile of fraction of bond debt, controling for leverage, works
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M##ib0.rating_group ///
c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ ///
$firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store g4
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"		

#delimit;
esttab  g1 g2 g3 g4
        using ../output/Default_Firm_DebtStructureRatingShock.tex, 
	    replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 ) noconstant  nomtitles nogaps
		obslast booktabs  nonotes scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio OIS_1M _cons 0.rating_group 0.rating_group#c.OIS_1M c.OIS_1M#c.dur_proxy dur_proxy)
		order(c.OIS_1M#c.lev_mb_IQ lev_mb_IQ c.OIS_1M#c.fra_mb_IQ fra_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ)
		label substitute(\_ _);
#delimit cr

#delimit;
esttab  g1 g2 g3 g4
        using ../output/Default_Firm_DebtStructureRatingShockPres.tex, 
	    replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 ) 
		noconstant  nomtitles nogaps obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio OIS_1M lev_IQ lev_mb_IQ
		_cons *.rating_group c.OIS_1M#c.dur_proxy dur_proxy 0.rating_group 0.rating_group#c.OIS_1M fra_mb_IQ)
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
gen  dur_proxy = LTG_EPS_mx
replace  abn_return =  abn_return * 10000
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"

reghdfe abn_return c.OIS_1M#c.dur_proxy dur_proxy  c.OIS_1M#c.lev_IQ  lev_IQ  ///
$firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe abn_return c.OIS_1M#c.dur_proxy dur_proxy  c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ  ///
 $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

	*Bond issuer dummy works
reghdfe abn_return c.OIS_1M#c.dur_proxy dur_proxy bondtimesshock  mb_issuer_IQ ///
   $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  abn_return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_lev_mb_IQ ///
c.q_lev_mb_IQ  $firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  abn_return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.fra_mb_IQ ///
c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  abn_return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_fra_mb_IQ ///
c.q_fra_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols  ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe  abn_return  c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ  ///
c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols ///
 ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"



	*MAKE TABLE
#delimit;
esttab  b2 b3 b4 b5 b6 b7 b1 
		using ../output/Default_Firm_RobCAPM.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons c.OIS_1M#c.dur_proxy dur_proxy)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ c.OIS_1M#c.q_lev_mb_IQ q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ q_fra_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ)
		label substitute(\_ _);
#delimit cr


	*MAKE PRESENTATION TABLE
#delimit;
esttab   b2 b4 b5 b6 b7 
		using ../output/Default_FirmRobCAPMPres.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI q_fra_mb_IQ fra_mb_IQ cov_ratio _cons lev_IQ lev_mb_IQ q_lev_mb_IQ c.OIS_1M#c.dur_proxy dur_proxy)
		order(c.OIS_1M#c.lev_mb_IQ c.OIS_1M#c.q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ)
		label substitute(\_ _);
#delimit cr


***********************************************************
*** Table Robustness  -  Sept 17th 2001 -  2001 - 08 / 2007 ***
***********************************************************
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000
drop if date == date("09172001","MDY")

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx


reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_IQ  lev_IQ  ///
$firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ ///
c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local ID "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy bondtimesshock  mb_issuer_IQ  ///
 $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_lev_mb_IQ ///
c.q_lev_mb_IQ  $firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ ///
lev_IQ c.OIS_1M#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_fra_mb_IQ ///
c.q_fra_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ   $firmcontrols  , ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ  ///
c.lev_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ  $firmcontrols ///
 ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ ///
c.lev_mb_IQ c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b8
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"




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
gen  dur_proxy = LTG_EPS_mx

*replace OIS_1M =  OIS_1M 

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

	*Bond issuer dummy works
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy bondtimesshock  mb_issuer_IQ   $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_lev_mb_IQ c.q_lev_mb_IQ  $firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS_1M#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_fra_mb_IQ c.q_fra_mb_IQ c.OIS_1M#c.lev_IQ c.lev_IQ   $firmcontrols  ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


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
esttab  b2 b3 b4 b5 b6 b7 b8 b1 
		using ../output/Default_Firm_PostCrisis.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ c.OIS_1M#c.dur_proxy dur_proxy)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ c.OIS_1M#c.q_lev_mb_IQ q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ q_fra_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ)
		label substitute(\_ _);
#delimit cr


	*MAKE PRESENTATION TABLE
#delimit;
esttab  b2 b4 b5 b6 b7 b8
		using ../output/Default_Firm_PostCrisisPres.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI q_fra_mb_IQ fra_mb_IQ cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ lev_mb_IQ q_lev_mb_IQ  c.OIS_1M#c.dur_proxy dur_proxy lev_IQ)
		order(c.OIS_1M#c.lev_mb_IQ c.OIS_1M#c.q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ)
		label substitute(\_ _);
#delimit cr


***********************************************************
*** Table Default Probabilities  2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx

*sum defprob if q_defprob==3&finalsample==1 ,det
*sum defprob if q_defprob==4&finalsample==1 ,det
*label var m_dfprob "Median Default"
label var q_defprob "Quartile Default"

	* default probability as control
reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ ///
c.lev_mb_IQ c.OIS_1M#i.q_defprob i.q_defprob $firmcontrols ///
, absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return  c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ ///
c.lev_mb_IQ c.OIS_1M#c.defprob defprob   $firmcontrols , ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b2
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return  c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_lev_mb_IQ ///
c.q_lev_mb_IQ c.OIS_1M#i.q_defprob i.q_defprob  $firmcontrols , ///
absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.q_lev_mb_IQ ///
c.q_lev_mb_IQ c.OIS_1M#c.defprob defprob $firmcontrols , ///
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
        using ../output/Default_Firm_DistancetoDefaultControl.tex, 
	    replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01  ) noconstant  nomtitles nogaps
		obslast booktabs  
		nonotes scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop( c.OIS_1M#c.dur_proxy dur_proxy size cash_oa profitability tangibility log_MB DTI cov_ratio 	_cons 4.q_defprob#c.OIS_1M *.q_defprob)
		order(  c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  c.OIS_1M#c.q_lev_mb_IQ q_lev_mb_IQ)
		label substitute(\_ _);
#delimit cr

	* PRESENTATION
#delimit;
esttab  b2 b1 b4 b3
        using ../output/Default_Firm_DistancetoDefaultControlPres.tex, 
	    replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01  ) noconstant  nomtitles nogaps
		obslast booktabs  
		nonotes scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE")
		drop( c.OIS_1M#c.dur_proxy dur_proxy q_lev_mb_IQ lev_mb_IQ size cash_oa profitability tangibility log_MB DTI cov_ratio _cons 4.q_defprob#c.OIS_1M *.q_defprob defprob)
		order(  c.OIS_1M#c.lev_mb_IQ c.OIS_1M#c.q_lev_mb_IQ c.OIS_1M#c.defprob)
		label substitute(\_ _);
#delimit cr

***********************************************************
*** Additional Robustness - 2001 - 08 / 2007 ***
***********************************************************
use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx

label var age "Age"
reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.age c.age  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b1
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.size c.size  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
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
reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.log_enterprise_value c.log_enterprise_value c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.tangibility c.tangibility  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"


reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.cash_oa c.cash_oa  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"
estadd local CLEV "\checkmark"


reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.cov_ratio c.cov_ratio  c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
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
reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.equity_vol c.equity_vol c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
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
reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS_1M#c.lev_mb_IQ c.lev_mb_IQ c.OIS_1M#c.operating_profitability c.operating_profitability c.OIS_1M#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
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
		using ../output/Default_Firm_AddRobustness.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(age size log_enterprise_value cash_oa cov_ratio equity_vol profitability tangibility log_MB DTI _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ c.OIS_1M#c.dur_proxy dur_proxy operating_profitability)
		label substitute(\_ _);
#delimit cr


	*MAKE PRESENTATION TABLE
#delimit;
esttab  b1 b2 b6 b3 b4 b5 b7 b8
		using ../output/Default_Firm_AddRobustnessPres.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(age size log_enterprise_value cash_oa cov_ratio equity_vol profitability tangibility log_MB DTI _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ c.OIS_1M#c.dur_proxy dur_proxy lev_mb_IQ operating_profitability)
		label substitute(\_ _);
#delimit cr













