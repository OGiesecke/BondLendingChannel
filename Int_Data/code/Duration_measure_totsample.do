cap log close 
clear all 
set more off , permanently

* Set directories 
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"

********************************************************************************
*** Do Analysis on the default sample
********************************************************************************

use ../data/F_US_Sample.dta,clear
drop if isin =="NA"
tempfile US_isins
save `US_isins'

use ../data/F_Default_Constituents_ext.dta,clear
keep isin
*rename ISIN isin 
*duplicates drop isin,force
tempfile Default_isins
save `Default_isins'

use ../data/duration.dta,clear
	* restrain to US and Default sample
merge m:1 isin using `US_isins'
rename _merge US_merge
merge m:1 isin using `Default_isins'
rename _merge Default_merge
keep if US_merge == 3 | Default_merge == 3
*keep if Default_merge == 3

	* check for isin x year duplicates
drop if sales==.
duplicates tag isin year,gen(dup)
tab dup

	* check for distances
sort isin year 
by isin: gen nn=_n
by isin: gen l_year = year[_n-1]

gen d_check = 1 if nn==1
replace d_check = year == (l_year+ 1) if nn!=1
// still 14 observations that do not have annual frequency.
// This seems minor though. Keep for now.

	* generate 3d sic
gen sic3d = round(sic/10)

	* calculate dividend yield
gen divyield = cash_dividends / market_cap
winsor2 divyield if US_merge == 3, cuts(0 99.5) suffix(US)
winsor2 divyield if Default_merge == 3, cuts(0 99.5) suffix(EU)

replace divyield = divyieldUS if US_merge == 3 
replace divyield = divyieldEU if Default_merge == 3

egen m_divyield = mean(divyield),by(isin)
sum m_divyield,det

xtile quintile_divy = m_divyield , nquantiles(5)
egen tag_isin = tag(isin)

sort isin year 
winsor2 roe, cuts(1 99)
by isin: gen l_roe_w = roe_w[_n-1]

reg roe_w c.l_roe_w#i.year i.year  if year > 1993 & year < 2009
reg roe_w c.l_roe_w  if year >= 2000 & year <= 2007

	* book equity
foreach var of varlist deftax prefstock retearnings ceq{
	replace `var' = 0 if `var'==.
}

gen be = ceq + deftax 
*gen be = sh_equity + deftax - prefstock
by isin: gen l_be = be[_n-1]

	* compute manually roe
gen man_roe = netincome_bitems / l_be
by isin: gen l_man_roe = man_roe[_n-1]
by isin: gen l2_man_roe = man_roe[_n-2]
winsor2 man_roe, cuts(2 98)
by isin: gen l_man_roe_w = man_roe_w[_n-1]
by isin: gen l2_man_roe_w = man_roe_w[_n-2]
reg  man_roe_w l_man_roe_w 

reg  man_roe_w c.l_man_roe_w#i.sic3d  i.sic3d

	* sales growth
by isin: gen l_sales = sales[_n-1]
gen g_sales = ( sales - l_sales ) / l_sales

winsor2 g_sales,  cuts(2 98)
by isin: gen l_g_sales = g_sales[_n-1]
by isin: gen l2_g_sales = g_sales[_n-2]
by isin: gen l_g_sales_w = g_sales_w[_n-1]
by isin: gen l2_g_sales_w = g_sales_w[_n-2]
reg g_sales_w l_g_sales_w 

foreach var of varlist market_cap netincome netincome_bitems be l_be {
	replace `var' = `var' / 1000000
}

gen g_be = ( be - l_be ) / l_be
by isin: gen l_g_be = g_be[_n-1]

gen pe_ratio = market_cap / netincome_bitems
gen mtb = market_cap / l_be

	* make an adjustment to matured firms
/*
sort isin year 
by isin: replace man_roe_w =  man_roe_w[_n-1] if quintile_divy==5 &  man_roe_w<0
by isin: replace man_roe_w =  man_roe_w[_n-1] if quintile_divy==5 &  man_roe_w<0
*/

	* drop negative book equity observations 

*keep market_cap l_be be g_sales_w l_g_sales_w netincome netincome_bitems isin year man_roe* l_man_roe* l2_man_roe*  g_sales* l_g_sales* l2_g_sales* l_g_be  g_be pe_ratio mtb divyield quintile_divy

*keep if isin=="US0231351067"
*keep if isin=="US3453708600"


export delimited ../data/duration_data.csv,replace

** Call Matlab file

shell /Applications/MATLAB_R2019a.app/bin/matlab -nodesktop -nosplash -r "ImpliedEquityDuration"

** Merge all the data

import delimited using "../data/ImpliedEquityDuration.csv",clear
*sum impldur, det
sort isin year
*twoway scatter  impldur year if isin=="AN8068571086"
	* Merge with a lag
gen yr_adj = year
save ../data/Matlab_impldur,replace

