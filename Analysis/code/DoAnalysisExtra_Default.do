cap log close 
clear all 
set scheme sol, permanently
graph set window fontface "Times New Roman"
set linesize 150

* Set directories 
global path "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Analysis/code"

display "${path}"
cd "$path"


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
*** Table Check Symmetry - Baseline - 2001 - 08 / 2007 ***
***********************************************************

use ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
keep if date < date("01082007","DMY") & year > 2000
drop if date == date("09172001","MDY")  //| date == date("05102001","MDY")

est clear
global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
gen  dur_proxy = LTG_EPS_mx

egen tag =tag(date)
sum OIS_1M if tag,det

gen OIS1Mplus = 0
replace OIS1Mplus = OIS_1M if OIS_1M >=0 & OIS_1M!=. 

gen OIS1Mminus = 0
replace OIS1Mminus = OIS_1M if OIS_1M <0 & OIS_1M!=.

label var OIS1Mplus "$\Delta\text{OIS1M}^+$"
label var OIS1Mminus "$\Delta\text{OIS1M}^-$"

reghdfe return c.OIS_1M#c.dur_proxy dur_proxy c.OIS1Mplus#c.lev_mb_IQ c.OIS1Mminus#c.lev_mb_IQ c.lev_mb_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b3
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS1Mplus#c.q_lev_mb_IQ c.OIS1Mminus#c.q_lev_mb_IQ c.q_lev_mb_IQ  $firmcontrols ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b4
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS1Mplus#c.fra_mb_IQ c.OIS1Mminus#c.fra_mb_IQ c.fra_mb_IQ lev_IQ c.OIS1Mplus#c.lev_IQ c.OIS1Mminus#c.lev_IQ  $firmcontrols , absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b5
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"

reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS1Mplus#c.q_fra_mb_IQ c.OIS1Mminus#c.q_fra_mb_IQ c.q_fra_mb_IQ c.lev_IQ   $firmcontrols  ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b6
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS1Mplus#c.lev_mb_IQ c.OIS1Mminus#c.lev_mb_IQ c.lev_mb_IQ c.OIS1Mplus#c.lev_IQ c.OIS1Mminus#c.lev_IQ c.lev_IQ  $firmcontrols ///
 ,absorb(isin_num i.ind_group#i.date) cluster(isin_num date)
est store b7
estadd local DC "\checkmark"
estadd local FE "\checkmark"
estadd local D "\checkmark"
estadd local CT "\checkmark"
estadd local IS "\checkmark"


reghdfe  return c.OIS_1M#c.dur_proxy dur_proxy c.OIS1Mplus#c.lev_mb_IQ c.OIS1Mminus#c.lev_mb_IQ c.lev_mb_IQ c.OIS1Mminus#i.d_lev_IQ c.OIS1Mplus#i.d_lev_IQ i.d_lev_IQ  $firmcontrols ///
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
esttab b3 b4 b5 b6 b7 b8
		using ../output/Default_Firm_DebtStructureAsy.tex, 
		replace compress b(a3) se(a3) r2  star(* 0.10 ** 0.05 *** 0.01 )  noconstant  nomtitles nogaps
		obslast booktabs  nonotes 
		scalar("DC Duration control" "FE Firm FE" "CT Firm controls" "IS Sector $\times$ Date FE" "CLEV Lev. Quintile Interaction")
		drop(size cash_oa profitability tangibility log_MB DTI cov_ratio _cons *.d_lev_IQ#c.OIS1Mplus *.d_lev_IQ#c.OIS1Mminus *.d_lev_IQ c.OIS_1M#c.dur_proxy dur_proxy lev_mb_IQ q_lev_mb_IQ fra_mb_IQ  q_fra_mb_IQ lev_mb_IQ lev_IQ) 
		label substitute(\_ _);
#delimit cr










