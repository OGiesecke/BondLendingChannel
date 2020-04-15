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


********************************************************
** Local Projection Probability Bond Issues - Monthly
********************************************************

	*** Bondissue data
import delimited ../../Raw_Data/data/bloombergbonddata_unconsolidated.csv,clear

drop maturity issue_date
gen maturity =date(real_maturity,"YMD")
format maturity %td
gen issue_date =date(real_issue_date,"YMD")
format issue_date %td

drop real_issue_date real_maturity

gen date_q = qofd(issue_date)
format date_q %tq

gen date_m = mofd(issue_date)
format date_m %tm

collapse (sum) amount,by(isin date_m)
tempfile bond_monthly
save `bond_monthly'

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

	***
use ../../Analysis/data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,clear
drop tag_IY
egen tag_IY=tag(isin year) 
keep if tag_IY

global firmcontrols "size cash_oa profitability tangibility log_MB DTI cov_ratio"
keep isin year lev_mb_IQ q_lev_mb_IQ lev_IQ fra_mb_IQ $firmcontrols sic 
tempfile mlev
save `mlev'


	*** Final Panel
	
use ../../Analysis/data/Default_quarterly_sample,clear
gen length = (end_date + 1 - start_date) * 3
gen date = dofq(start_date)
gen date_m = mofd(dofq(start_date))
format date_m %tm
expand length
sort isin 
by isin: gen n = _n-1
replace date_m = date_m + n
keep isin date_m
sort isin date_m

gen date_q=qofd(dofm(date_m))
gen year = year(dofm(date_m))

merge m:1 date_m using `shock_monthly'
drop if _merge==2
drop _merge

merge m:1 date_m isin using `bond_monthly'
gen d_sample = _merge!=2
drop _merge


merge m:1 date_q using ../../Int_data/data/gdp_growth
drop if _merge==2
drop _merge

merge m:1 date_q using ../../Int_data/data/inflation_yoy
drop if _merge==2
drop _merge

merge m:1 year isin using `mlev'
drop  if _merge==2
drop _merge


replace amount =. if amount==42
gen d_bond = amount > 0 & amount!=.

sort isin date_m
forvalues i=1/12{
	bys isin: gen F_pissue`i'=d_bond[_n+`i']
}

sort isin date_m
	forvalues i=1/12{
	egen S`i'_issue=rowtotal(F_pissue1-F_pissue`i')
	}

	sort isin date_m
	forvalues i=1/12{
	gen d`i'q_incissue=S`i'_issue>0
	}

gen leads=_n-1

foreach var in F_pissue{
	gen coef_`var'=.
	gen se_`var'=.
	gen ciub_`var'=.
	gen cilb_`var'=.
	gen n_`var'=.

	replace coef_`var'=0 if leads==0
	replace ciub_`var'=0 if leads==0
	replace cilb_`var'=0 if leads==0


	forvalues i=1/12{
		reghdfe d`i'q_incissue agg_shock_ois_m  $firmcontrols l1_gdp_growth l2_gdp_growth l1_inflation_yoy if d_sample, absorb(isin) cluster(isin)
		*reg d`i'q_incissue agg_shock_ois_m if d_sample, cluster(isin)
		*qui areg d`i'q_incissue agg_shock_ois_m if d_sample, absorb(isin) cluster(isin)
		capture replace coef_`var'=_b[agg_shock_ois_m] * 100 if leads==`i'
		capture replace se_`var'=_se[agg_shock_ois_m] * 100 if leads==`i'
		replace ciub_`var'=coef_`var'+1.68*se_`var'  if leads==`i'
		replace cilb_`var'=coef_`var'-1.68*se_`var'  if leads==`i'
		replace n_`var'=e(N) if leads == `i'
	}
}

egen taglead=tag(leads)
twoway  (rarea ciub_F_pissue cilb_F_pissue leads if leads>=0 & leads<=12 & taglead, sort  color(blue%10) lw(vvthin)) ///
(scatter coef_F_pissue leads if  leads>=0 & leads<=12 & taglead,c( l) lp(solid) mc(blue)) ,   ///
yline(0,lp(dash) lc(gs10)) ytitle("Probability of Bond Issuance",size(large)) legend(off) xlabel(0(3)12) ///
legend(off) xtitle("Horizon (in month)",size(large))  name(cumprobissuemonthly,replace)
graph export ../../Analysis/output/Default_lp_bondissuemonthly.pdf,replace

