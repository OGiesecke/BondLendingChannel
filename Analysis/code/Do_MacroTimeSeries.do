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
** Lending Market Conditions Eurozone 
********************************************************************************

* Put data together
use ../../Int_Data/data/Financial_Variables,clear
keep date GER_5Y GER_10Y
gen date_q = qofd(date)
collapse (mean) GER_5Y GER_10Y,by(date_q)
format date_q %tq
tempfile bunds
save `bunds'

use ../../Int_Data/data/ECB_interest_loan,clear
gen date_q = qofd(dofm(date_mon))
collapse (mean) loan_rate,by(date_q)
tempfile rate_q
save `rate_q'	

use ../../Int_Data/data/ECB_loans_NFC_stocks,clear

merge 1:1 date_mon using ../../Int_Data/data/EA_priceindex.dta,nogen
drop date_m

gen vol_defl = volume  / (EA_priceindex / 100) / 1000
label var vol_defl "NFC debt out (in bn EUR 2015)"
gen date_q = qofd(dofm(date_mon))
collapse (mean) vol_defl,by(date_q)

merge 1:1 date_q using `rate_q',nogen

merge 1:1 date_q using `bunds',nogen
gen loan_spread = loan_rate - GER_5Y

gen year = year(dofq(date_q))

tsset date_q 
tssmooth ma year_loan_spread = loan_spread, window(12)


*egen year_loan_spread = mean(loan_spread), by(year)


*egen tag_year = tag(year)

drop if date_q < quarterly("2000Q1","YQ") | date_q > quarterly("2019Q1","YQ")

format date_q %tq

gen a =2000
gen b =6000

twoway (rarea  a b  date_q if  date_q >= quarterly("2001Q1","YQ") & date_q <= quarterly("2007Q3","YQ"),col(gs8) fi( inten40) lwidth(vvthin)) ///
(rarea  a b  date_q if  date_q >= quarterly("2013Q1","YQ") , col(gs14) fi( inten40) lwidth(vvthin)) ///
(scatter vol_defl date_q ,c(l) mc(red) ms(oh) ytitle("Loans out. (in bn 2015 EUR)")) ///
(scatter year_loan_spread date_q ,c(l) mc(blue) ms(sh) yaxis(2) ytitle("Avg. 5yr loan rate - 5 yr Bund (in %)",axis(2))),	///
xlabel(,format(%tqCCYY)) xtitle("Year") legend(order(3 "Loans outstanding (LHS)" 4 "Loan spread (RHS)" 1 "Baseline Sample" 2 "Post-Crisis Sample")) 
graph export ../../Analysis/output/Default_LendingMarket.pdf,replace

********************************************************************************
** Interest Rates Eurozone and US
********************************************************************************


use ../../Int_Data/data/MergedCleaned_MarketData.dta,clear

gen poschange=d_MP_policy_rate>0
gen negchange=d_MP_policy_rate<0

rename d_ff_US d_ff_USbps
rename d_shock_je d_shock_jebps

label var d_ois1mtl "$\Delta$ Unexp."
label var d_MP_rate_exp "$\Delta$ Exp."
label var d_MP_policy_rate "$\Delta$ Rate"

label var d_ff_USbps "$\Delta$ FFR"
label var d_shock_jebps "$\Delta$ FFR NS"
label var d_ff_US "$\Delta$ FFR"
label var d_shock_je "$\Delta$ FFR NS"

keep if date < date("01082007","DMY") & year(date)>2000

	*** Output Eurozone ***
#delimit ;
twoway (line MP_policy_rate date,lcolor(black) lpattern("-"))
(line loan_rate date ,lcolor(black))
(line BBB_5Y date ,lcolor(red))
(line AA_5Y date ,lcolor(blue)), 
legend(order(1 "Target rate (ECB)" 2 "Loan rate" 3 "BBB 5yr Bonds" 4 "AA 5yr Bonds")) 
xtitle("") ytitle("Interest rate (in %)") xlabel(,format(%tdCCYY));
#delimit cr
graph export ../output/Default_fig_agg_prices.pdf, replace

	*** Output US ***
#delimit ;
twoway (line ff_target date ,lcolor(black) lpattern("-"))
(line USloanrate date ,lcolor(black))
(line USyieldBBB date ,lcolor(red))
(line USyieldAA date ,lcolor(blue)), 
legend(order(1 "FFR target" 2 "Loan rate" 3 "BBB 5yr Bonds" 4 "AA 5yr Bonds")) 
xtitle("") ytitle("Interest rate (in %)") xlabel(,format(%tdCCYY));
#delimit cr
graph export ../output/US_fig_agg_prices.pdf, replace

********************************************************************************
** Indebtedness Eurozone and US
********************************************************************************

import excel ../../Raw_Data/original/FRED_corpdebttogdp.xlsx, cellrange(A11) clear firstrow
rename observation_date date
rename  BCNSDODNS_GDP NFC_US
replace NFC_US = NFC_US*100
gen quarter = qofd(date)
format quarter %tq
tempfile NFC_US
save `NFC_US'

import excel ../../Raw_Data/original/ECB_debttogdp.xlsx, cellrange(A5) clear firstrow
rename Period date
rename  debttogdp NFC_EA
gen quarter = quarterly(date,"YQ")
format quarter %tq
drop date
tempfile NFC_EA
save `NFC_EA'

import excel ../../Raw_Data/original/BIS_totcredit.xlsx,sheet("Quarterly Series (2)") cellrange(A4) clear firstrow
rename Period date
drop if year( date ) < 2000
gen quarter = qofd(date)
format quarter %tq
drop NFC_US NFC_EA

merge 1:1 quarter using `NFC_US'
keep if _merge==3
drop _merge

merge 1:1 quarter using `NFC_EA'
keep if _merge==3
drop _merge


label var HH_US "Household US"
label var HH_EA "Household Euroarea"
label var NFC_US "Nonfinancial Corp. US"
label var NFC_EA "Nonfinancial Corp. Euroarea"

twoway (scatter  HH_US date,lp(solid) lc(red) ms(none) c(l) yaxis(1)) ///
(scatter NFC_US date,lp(dash)  lc(red) c(l) ms(none) yaxis(1)) ///
(scatter  HH_EA date,lp(solid) lc(blue) ms(none) c(l) yaxis(1)) ///
(scatter NFC_EA date,lp(dash)  lc(blue) c(l) ms(none) yaxis(1)),  ///
ytitle("Debt as of GDP (in %)",size(large))  xlabel(,format(%tdCY) labsize(large)) ylabel(,labsize(large)) xtitle("") 
graph export "../output/Fig_debtasofGDP.pdf",replace

/*
********************************************************************************
** Compare Histograms Eurozone and US
********************************************************************************

gr combine ../output/US_histlevmarket.gph ../output/EU_histlevmarket.gph ../output/US_histframdebt.gph  ../output/EU_histframdebt.gph, name("Histograms", replace ) 
graph export ../output/Fig_SampleComp.pdf,replace



