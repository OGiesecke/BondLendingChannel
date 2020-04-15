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

	* Replication of Ippolito et al.
reghdfe return c.OIS_1M#c.lev_bank_IQ c.lev_bank_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)

reghdfe return c.OIS_1M#c.fra_bank_IQ c.fra_bank_IQ c.OIS_1M#c.lev_IQ c.lev_IQ $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
	*
	
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
		using ../output/US_Firm_DebtStructure.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  
		noconstant  nomtitles nogaps obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS_1M *.d_lev_IQ c.OIS_1M#c.dur_proxy dur_proxy)
		order( c.OIS_1M#c.lev_mb_IQ lev_mb_IQ  bondtimesshock  mb_issuer_IQ c.OIS_1M#c.q_lev_mb_IQ q_lev_mb_IQ c.OIS_1M#c.fra_mb_IQ fra_mb_IQ c.OIS_1M#c.q_fra_mb_IQ q_fra_mb_IQ c.OIS_1M#c.lev_IQ lev_IQ)
		label substitute(\_ _);
#delimit cr


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

