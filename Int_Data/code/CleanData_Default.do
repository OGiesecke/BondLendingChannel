cap log close 
clear all 
set more off , permanently

* Set directories 
local 1 "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Int_Data/code"
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"


********************************************************************************
*** Do Analysis on the default sample
********************************************************************************
		
	
use ../data/MergedData_Default_Sample,clear
keep if year>2000 & year < 2019

	* Adjust the shock Coresetti et al.
replace MP_event=0 if MP_event==.

	* Mark the non-conventional MP dates
gen SMP = .
replace SMP=1 if date == date("05/10/2010","MDY")
replace SMP=1 if date == date("08/0/2011","MDY")

gen OMT = .
replace OMT = 1 if date == date("07/26/2012","MDY")
replace OMT = 1 if date ==date("08/02/2012","MDY")
replace OMT = 1 if date == date("09/06/2012","MDY") 
	
gen LTRO = .
replace LTRO = 1 if date == date("12/01/2011","MDY")
replace LTRO = 1 if date ==date("12/08/2011","MDY")

gen unc_event = 1 if SMP==1 | OMT ==1 | LTRO ==1
sort isin date

	* Sample stats IQ level
drop tag_IQ
egen tag_IQ=tag(isin date_q)
tab year if  tag_IQ 

	* Stats for different shock series 
egen tag_date = tag(date)
tab MP_event if tag_date
tab JK_event if tag_date
tab Altavilla_event if tag_date
tab unc_event if tag_date 
tab Altavilla_event MP_event if tag_date 
list date if tag_date &  Altavilla_event==1 & MP_event==0
// Altavilla shocks that do not have Coresetti equivalent happen in 2018
tab Altavilla_event unc_event if tag_date
// Unconventinal shocks occurr in 3 instances contemporaneously with conv. dates
tab Altavilla_event JK_event if tag_date 
list date if tag_date &  Altavilla_event==1 & JK_event==0 // this is only year 2017 / 2018
list date if tag_date &  Altavilla_event==0 & JK_event==1 // JK have additional dates that do not coincide with MP decision.

	* Go with Altavilla events for now
keep if Altavilla_event == 1 
// This excludes a few non-convential dates. And a few Coresetti dates are missing.

	*** Define the sample
egen tag_FD = tag(isin date) // isin date observations. This are in fact only empty obs.
tab tag_FD // No duplicates any more

	*Identity financial companies
gen id_non_fin=1
	replace id_non_fin=0 if sic >=6000 & sic < 6800
	*Identity utility companies companies
gen id_non_utility=1
	replace id_non_utility=0 if sic>=4900 & sic < 5000

	*Main sample restriction (exclude financials and utilities)
gen insample=(year<2019&year>2000&id_non_fin==1&id_non_utility==1)
*gen insample_unc = year<=2018&year>2000&id_non_fin==1&dtag==1&id_non_utility==1 & ( MP_event==1| SMP==1 | OMT ==1 | LTRO ==1)
keep if insample

	* Create 2 digit sic fixed effects
gen d2sic=int(sic/100)
gen d3sic=int(sic/10)
*egen d3count=count(d3sic) if finalsample==1, by(d3sic)
gen ind_group =d2sic

	* Create industry labeling for illustration
*Contruct industries (based on the sic code)
gen industry=0
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

label define industrylabel 0 "no industry" 1 "Agriculture, Forestry and Fishing" ///
2 "Mining" 3 "Construction" 4 "Manufacturing" 5 "Transportation, Communications" ///
6 "Wholesale Trade" 7 "Retail Trade" 8 "Finance, Insurance and Real Estate" ///
9 "Services" 10 "Public Administration"

label val industry industrylabel


	*Units of shock and return
replace d_ois1mtl=d_ois1mtl*100
sum return d_ois1mtl if  insample==1

replace d_EUSWEA=d_EUSWEA*100
replace d_EURIBOR1M_adj=d_EURIBOR1M_adj*100

replace eureon3m_hf = eureon3m_hf * 100 

	* Adjust units of market value to other BS variables
replace MV = MV * 1000000

	*Appears that return is in [0,1] and shock in basis point
	*Make return in basis points as well
gen return_bps=return*10000
replace return= return_bps

	* check capital IQ vs worldscope
egen tag_IY = tag(isin year)
drop if isin =="IT0003121644" | isin == "IT0003856405" | isin=="ES0132580319" ///
| isin =="PTBRI0AM0000"  | isin =="GRS085101004" | isin =="GRS307333005" ///
| isin=="PTTLE0AM0004" | isin == "ES0184933812" // drop outlier
 
twoway scatter asset IQ_TOTAL_ASSETS if tag_IY & insample

	* Variable definitions
gen assets_inBN = IQ_TOTAL_ASSETS/1e9
gen assets_mv= tot_liabilities + MV

gen lev=tdebt/assets
replace lev=1 if lev>1 & lev!=. //: not trivial amount has lev above 1...

gen lev_net=(tdebt- cashandsec)/assets
gen lev_mv=tdebt/assets_mv
gen enterprise_value = tdebt- cashandsec + MV
*twoway scatter enterprise_value assets
gen cash_oa = cashandsec/assets
gen profitability=ebitda/assets
gen operating_profitability=ebitda/assets_mv
gen tangibility=ppenet/assets
gen DTI = tdebt/ebitda
gen cov_ratio= ebitda/intexp
gen NDTI = (tdebt-cashandsec)/ebitda
gen MB=MV/(assets-tot_liabilities)
gen lev_LT=ldebt/assets
gen sdebt=tdebt-ldebt
gen lev_ST= sdebt/assets
gen fra_ST=sdebt/tdebt
replace IQ_BONDS_NOTES =0 if IQ_BONDS_NOTES==.
replace IQ_MARKET =0 if IQ_MARKET==.

gen lev_IQ = IQ_TOTAL_DEBT/IQ_TOTAL_ASSETS




	* Adjust the level variables by the price index
replace assets = assets / (EA_priceindex / 100)
replace assets_inBN = assets_inBN / (EA_priceindex / 100)
gen size=ln(assets)
label var size "Log assets"


	* Remove isins with lev_IQ > 1
preserve
keep if tag_IY
keep if lev_IQ>1 | lev_IQ==.
keep isin 
duplicates drop isin,force
tempfile dropouts
save `dropouts'
restore

merge m:1 isin using `dropouts'
drop if _merge ==3
drop _merge


*twoway scatter IQ_MARKET IQ_BONDS_NOTES if insample==1 &  tag_IY 

	* Define market debt
gen fra_mdebt_IQ=IQ_BONDS_NOTES / IQ_TOTAL_DEBT
replace fra_mdebt_IQ = 0 if fra_mdebt_IQ ==.
replace fra_mdebt_IQ = 1 if fra_mdebt_IQ > 1

gen lev_market_IQ = IQ_BONDS_NOTES/IQ_TOTAL_ASSETS
replace lev_market_IQ = 0 if lev_market_IQ ==.
replace lev_market_IQ = 1 if lev_market_IQ>1

gen fra_mb_IQ = IQ_MARKET / IQ_TOTAL_DEBT
replace fra_mb_IQ = 0 if fra_mb_IQ ==.
replace fra_mb_IQ = 1 if fra_mb_IQ > 1

gen lev_mb_IQ = IQ_MARKET/IQ_TOTAL_ASSETS
replace lev_mb_IQ = 0 if lev_mb_IQ ==.
replace lev_mb_IQ = 1 if lev_mb_IQ > 1


gen lev_bank_IQ = IQ_BANK_DEBT/IQ_TOTAL_ASSETS
gen nonbondebt_IQ=IQ_TOTAL_DEBT-IQ_BONDS_NOTES
gen lev_notmarket_IQ= nonbondebt_IQ/IQ_TOTAL_ASSETS
replace lev_notmarket_IQ=0 if lev_notmarket ==.
replace lev_notmarket_IQ=1 if lev_notmarket > 1

gen bond_issuer_IQ = lev_market_IQ>0
gen mb_issuer_IQ = lev_mb_IQ>0

capture gen bondtimesshock=c.OIS_1M*mb_issuer_IQ




	* Define a consistent sample: balance sheet items are there
egen finalsample=tag(date isin) if lev_IQ!=. & assets_inBN!=. & cash_oa!=.& profitability!=.& ///
tangibility!=.& MB!=.& DTI!=.& cov_ratio!=. &lev_market_IQ!=. & return!=.& insample==1
tab finalsample // Identical sample to the summary stat table
keep if finalsample

drop tag_IQ
egen tag_IQ=tag(isin date_q) 
tab year if  tag_IQ 

drop tag_IY
egen tag_IY=tag(isin year)
tab year if  tag_IY

	*Tercile of variables (defined on year by year basis)
foreach var of varlist lev_market_IQ fra_mdebt_IQ lev_IQ fra_mb_IQ lev_mb_IQ{
	gen q_`var'_help=.
	forvalues y = 2001/2018 {	
		xtile q_help_`y' = `var' if year==`y' & finalsample==1 & tag_IY==1, nq(3)
		tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y'
		drop  q_help_`y'
	}
	egen q_`var' = mean(q_`var'_help),by(year isin)
	drop q_`var'_help
}

	*Quintiles of variables leverage (defined on year by year basis)
foreach var of varlist lev_IQ{
	gen q_`var'_help=.
	forvalues y = 2001/2018 {	
		xtile q_help_`y' = `var' if year==`y' & finalsample==1 & tag_IY==1, nq(5)
		tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y'
		drop  q_help_`y'
	}
	egen d_`var' = mean(q_`var'_help),by(year isin)
	drop q_`var'_help
}


	*Quartiles of variables defaultprobability and distance-to-default (defined on year by year basis)
foreach var of varlist defprob dtd{
	gen q_`var'_help=.
	forvalues y = 2001/2007 {	
		xtile q_help_`y' = `var' if year==`y' & finalsample==1 & tag_IY==1, nquantiles(4)
		tab q_help_`y'
		replace q_`var'_help=q_help_`y' if year==`y'
		drop  q_help_`y'
	}
	egen q_`var' = mean(q_`var'_help),by(year isin)
	drop q_`var'_help
}

	
	* Winsorize control BS

foreach var of varlist  cash_oa DTI cov_ratio MB tangibility profitability LTG_EPS impldur{
	winsor2 `var' if finalsample==1 & tag_IY==1, cuts(1 99) by(year)
	replace `var'_w=0 if `var'_w==.
	egen `var'w=total(`var'_w),by(year isin)
	replace `var'=`var'w
}

gen log_MB = log(MB)

	*Label var
label var d_ois1mtl "MP Shock"
label var assets "Assets"
label var assets_inBN "Assets (in bn)"

label var lev "Debt over assets"
*label var lev_market "Bond debt over assets"
label var lev_bank "Bank debt over assets"
label var lev_ST "ST debt over assets"
label var lev_LT "LT debt over assets"
label var lev_net "Net debt over assets"
label var fra_ST "Debt due within year over debt"


label var lev_IQ "Debt over assets"
label var lev_market_IQ "Bond debt over assets"
label var lev_bank_IQ "Bank debt over assets"
label var lev_notmarket_IQ "Non-bond debt over assets"
label var q_lev_market_IQ "Tercile of bond debt over assets"
label var q_fra_mdebt_IQ "Tercile of bond debt over debt"
label var bond_issuer_IQ "Bond outstanding (Capital IQ)"
label var q_fra_mdebt_IQ "Tercile of bond debt over debt"
label var fra_mdebt_IQ "Bond debt over debt"
label define bonlevq 1 "No bond debt" 2 "Low bond debt" 3 "High bond debt"
label values lev_market_IQ bonlevq  


label var fra_mb_IQ "Bond debt over debt"
label var q_fra_mb_IQ "Tercile of bond debt over debt"
label var lev_mb_IQ "Bond debt over assets"
label var q_lev_mb_IQ "Tercile of bond debt over assets"
label var mb_issuer_IQ "Market fin. outstanding"
label var  bondtimesshock "$\Delta$ OIS1M $\times$ bond outstanding"
label define bondebt 1 "No bond debt" 2 "Low bond debt" 3 "High bond debt"
label val q_lev_mb_IQ bondebt




label var profitability "Earnings over assets"
label var cash_oa "Cash over assets"
label var tangibility "Fixed assets over assets"
label var DTI "Debt over earnings"
label var NDTI "Net debt over earnings"
label var cov_ratio "Earnings over interest expenses"
label var MB "Market-to-Book"
label var log_MB "Log Market-to-Book"

label var d_ois1mtl "$\Delta$ OIS1M Corsettietal"  
label var eureon3m_hf "$\Delta$ OIS3M JK" 
label var OIS_1M "$\Delta$ OIS1M" 
label var OIS_3M "$\Delta$ OIS3M" 
label var d_shock_je "$\Delta$ FFR"



/*
	*Rating categories
rename StandardPoorsRating rating
gen rating_group = .
replace rating_group = 0 if rating=="" | rating=="NR"
replace rating_group = 1  if rating=="D" | rating=="SD" | rating=="CCC" ///
| rating=="CPA1" | rating=="CPA1" | rating=="B" | rating=="B+" | rating=="B-" ///
| rating=="BB" | rating=="BB+" | rating=="BB-"
replace rating_group = 2  if rating=="BBB" | rating=="BBB-" | rating=="BBB+" ///
| rating=="A" | rating=="A-" | rating=="A+"
replace rating_group = 3  if rating=="AA" | rating=="AA-" | rating=="AA+" |rating=="AAA"
label define rating_class 0 "Unrated" 1 "High Yield" 2 "IG below AA" 3 "IG AA and above"
label values rating_group rating_class
*/

	*Rating categories
gen rating_group = 0
replace rating_group = 1 if n_mean_rating > 9 & n_mean_rating<=21
replace rating_group = 2  if n_mean_rating > 2 & n_mean_rating <= 9
replace rating_group = 3  if n_mean_rating <=2
label define rating_class 0 "Unrated" 1 "High Yield" 2 "IG below AA" 3 "IG AA and above"
label values rating_group rating_class


	*Necessary to use reghdfe (two way clustering)
egen isin_num=group(isin)

	* Predict and fill the duration measure
gen man_roe_w2=man_roe_w^2
gen g_sales_w2=g_sales_w^2
reg LTG_EPS c.impldur_w##i.quintile_divy c.man_roe_w man_roe_w2 c.l_man_roe_w  g_sales_w2 c.g_sales_w  if tag_IY 
predict LTG_EPS_hat,xb

gen LTG_EPS_mx = LTG_EPS
replace  LTG_EPS_mx = LTG_EPS_hat if LTG_EPS ==.
label var LTG_EPS_mx "Equity duration proxy"


	* Delete observations with gaps
preserve
	drop tag_IQ
	egen tag_IQ=tag(isin date_q)
	tab year if  tag_IQ 
	keep if tag_IQ

	keep isin date_q name year
	format  date_q %tq
	sort isin date_q

	* calculate the distance
	bys isin: gen diff =  date_q -  date_q[_n-1]

	* calculate firms with interruptions
	bys isin: egen m_dis = max(diff)
	tab m_dis
	keep if m_dis==1
	sort isin date_q

	egen tag_IY = tag(isin year)
	tab year if tag_IY
	keep if tag_IY
	save ../data/DefaultAdjSample,replace
restore

*merge m:1 isin year using ../data/DefaultAdjSample
*keep if _merge==3
*drop _merge

	* Clean the countries in which the headquarter is located -- EA only
drop if NATION=="SWITZERLAND" | NATION=="UNITED KINGDOM" | NATION=="UNITED ARAB EMIRATES"
tab year if  tag_IY 

drop tag_isin
egen tag_isin=tag(isin)
tab tag_isin

drop tag_IY
egen tag_IY=tag(isin year) 
tab year if  tag_IY

	* Drop a few observations that we identified have flaws
drop if isin == "NL0000008977" // Heineken Holding: double count
drop if isin == "ES0111847036" // Aurea: no annual report
drop if isin=="NL0000009827" & yr_adj == 2000 // DSM KONINKLIJKE: no annual report


save ../data/Firm_Return_WS_Bond_Duration_Data_Default_Sample,replace

