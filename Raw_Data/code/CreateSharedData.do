cap log close 
clear all 
set more off , permanently

* Set directories 
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"

*************************************************
** Execute all programs
*************************************************


program shareddata
	create_findata
	create_ratings
	create_shares_out
	create_duration
	create_IBES
	create_IBES_crosswalk
	create_US_market
	create_riskfree
	create_target
	create_loanrate
	create_bisdata
end



*************************************************
** create the rating data 
*************************************************

program create_ratings 
	import delimited ../original/Entity_Ratings.csv,clear
	save ../data/SandPRatings.dta,replace
end

*************************************************
** create the duration data from Worldscope
*************************************************

program create_duration
	use ../original/WS_duration.dta,clear

	rename item6008 isin
	rename item7210 market_cap
	rename item6038 ibes_ticker
	rename item3501 ceq
	rename item7240 sales
	rename item7250 netincome
	rename item8301 roe
	rename item6026 nation
	rename item6027 nation_iso
	rename year_ year 
	rename item1001 sales_usd
	rename item1551 netincome_bitems
	rename item3263 deftax
	rename item3451 prefstock
	rename item3495 retearnings
	rename item6004 cusip
	rename item3999 sh_equity
	rename item7021 sic
	rename item4551 cash_dividends
	rename item6001 compname

	* generate lag of sales and roe
	drop if isin ==	""

	save ../data/duration.dta,replace
end

*************************************************
** get IBES analyst data on EPS and LTG
*************************************************

program create_IBES
	use ../original/IBES_joint.dta,clear

	gen year = year(statpers)
	sort ticker fpi year statpers
	by ticker fpi year: gen number=_n
	by ticker fpi year: gen tot_number=_N
	keep if number == tot_number
	drop statpers tot_number number

	preserve 
	keep cname ticker
	duplicates drop ticker,force
	tempfile compname
	save `compname'
	restore 

	drop  oftic cname cusip
	reshape wide medest, i(ticker measure year) j(fpi) string
	merge m:1 ticker using `compname'
	drop _merge
	gen IBES_ticker =  regexr(ticker,"^@","")

		* Keep US companies only
	gen nonUS = regexm(ticker,"^@")
	keep if nonUS == 0

	duplicates tag IBES_ticker year,gen(dup)
	tab  dup

	rename  medest0 LTG_EPS
	label var LTG_EPS "Long-term growth rate EPS (in %)"
		* Merge with a lag


	gen d_EU=0 
	tempfile Default_IBES_LTG
	save ../data/US_IBES_LTG,replace

	**

	use ../original/IBES_joint.dta,clear

	gen year = year(statpers)
	sort ticker fpi year statpers
	by ticker fpi year: gen number=_n
	by ticker fpi year: gen tot_number=_N
	keep if number == tot_number
	drop statpers tot_number number

	preserve 
	keep cname ticker
	duplicates drop ticker,force
	tempfile compname
	save `compname'
	restore 

	drop  oftic cname cusip
	reshape wide medest, i(ticker measure year) j(fpi) string
	merge m:1 ticker using `compname'
	drop _merge
	gen IBES_ticker =  regexr(ticker,"^@","")

	gen nonUS=0
	replace nonUS = 1 if regexm(ticker,"^@")

	duplicates tag IBES_ticker year,gen(dup)
	tab  dup

	rename  medest0 LTG_EPS
	label var LTG_EPS "Long-term growth rate EPS (in %)"
		* Merge with a lag
	gen d_EU=1
	save ../data/Default_IBES_LTG,replace
end

*************************************************
** get the IBES crosswalk to isin
*************************************************

program	create_IBES_crosswalk
	import excel using ../../Raw_Data/original/sample_US_isin.xlsx,clear firstrow sheet("IBES_ticker")  
	gen IBES_ticker =  regexr(IBESTICKER,"^@:","")
	drop if IBES_ticker == ""
	drop if IBES_ticker == "NA"
	rename Type isin 
	keep isin IBES_ticker
	save ../data/crosswalk_US_IBES,replace

	import excel using ../../Raw_Data/original/Default_sample_isin_ext.xlsx,clear firstrow sheet("IBES_ticker")  
	gen IBES_ticker =  regexr(IBES TICKER,"^@:@","")
	replace IBES_ticker =  regexr(IBES_ticker,"^@:","")
	drop if IBES_ticker == ""
	drop if IBES_ticker == "NA"
	rename Type isin 
	keep isin IBES_ticker
	save ../data/crosswalk_Default_IBES,replace
end

*************************************************
** create financial market data
*************************************************

program create_findata
	* federal funds futures up to 6m 
	import delimited using ../original/federal_funds_futures.csv,clear 
	gen statadate =date(date,"MDY",2020)
	format statadate %td
	drop date
	rename statadate date
	drop ffr_future
	foreach num of numlist 1/6{
		gen d_fff_`num'_rate = fff_`num'_rate - fff_`num'_rate[_n-1]
	}
	// Define the shock 'a la Lunsford (2018)
	egen d_path_fff3m = rowmean(d_fff_1_rate d_fff_2_rate d_fff_3_rate)
	save ../data/fff_6m,replace
	
	* 3m Swap Rates
	import excel using ../original/20190318_swap_rates.xlsx, clear firstrow
	rename Dates date
	format date %td
	drop if year(date)<2001
	destring EUSW1V3CMPTCurncy,replace
	destring EUSW1V3CMPLCurncy,replace
	save ../data/Int_Swap3m,replace

	* Additional ois swap data
	import excel using ../original/20190318_add_ois.xlsx, clear firstrow
	rename Dates date
	format date %td
	drop if year(date)<2001
	save ../data/Int_AddOIS,replace

	* Euribor futures
	import excel using ../original/20190319_euribor_futures.xlsx, clear firstrow
	rename Dates date
	format date %td
	save ../data/Int_EurFut,replace

	* Equity Indices *
	import excel using ../original/Int_Equity_Data_0314.xlsx, sheet("EUROSTOXX") clear firstrow
	drop D G
	rename EUROSTOXX50NETRETURN STOXX50nr 
	rename EUROSTOXX50PRICEINDEX STOXX50pi
	foreach element of varlist STOXX50nr STOXX50pi{
	gen r`element'=.
	replace r`element'=(ln(`element'[_n])-ln(`element'[_n-1]))*100
	}	
	rename Name date
	format date %td
	save ../data/Int_Equity1,replace

	import excel using ../original/Int_Equity_Data_0314.xlsx, sheet("MSCI") clear firstrow
	rename MSCIEMUEPRICEINDEX MSCIEMUpi 
	rename MSCIEUROPRICEINDEX MSCIEUROpi
	foreach element of varlist MSCIEMUpi MSCIEUROpi{
	gen r`element'=.
	replace r`element'=(ln(`element'[_n])-ln(`element'[_n-1]))*100
	}	
	rename Name date
	format date %td
	save ../data/Int_Equity2,replace

	* OIS Swap Rate
	import excel using ../original/Int_Future_0314.xlsx, clear firstrow
	rename Name date
	format date %td
	save ../data/OIS,replace

	* OIS Swap Rate
	import excel using ../original/OIS1MB.xlsx, clear firstrow
	rename Date date
	format date %td
	save ../data/OIS1m,replace

	import excel using ../original/OIS1YB.xlsx, clear firstrow
	rename Date date
	format date %td
	save ../data/OIS1y,replace

	* Additional OIS Maturities
	import excel using ../original/20180702_OIS_D_Mat.xlsx, clear firstrow
	rename Code date
	format date %td
	save ../data/OIS_M,replace

	* MP Policy Decision Dates
	import excel ../original/raw_dates.xlsx, clear firstrow
	format x %td
	rename x date
	gen MP_event=1
	la var MP_event "Dummy for MP Announcement Date"
	save ../data/MP_dates,replace

	* Monetary Policy Target Rates (ECB - Website)
	import excel using ../original/Int_Policy_Rate1_0321.xlsx, clear firstrow
	format date %td
	replace min_var_rate="." if min_var_rate=="-"
	destring min_var_rate,replace
	save ../data/ECBRate1,replace

	import excel using ../original/Int_Policy_Rate2_0321.xlsx, clear firstrow
	format date %td
	save ../data/ECBRate2,replace

	* Import EONIA Rate (ECB)
	import excel using ../original/Int_EONIA_ECB_0323.xlsx, clear firstrow
	format date %td
	replace EONIA_ECB= EONIA_ECB
	la var EONIA_ECB "Realized EONIA Rate (Survey at End of Day)"
	save ../data/EONIA_ECB,replace

	* Import all EURIBOR
	import excel using ../original/Int_Future_Euribor_data_update.xlsx, clear sh("Sheet4") firstrow
	rename Code date
	format date %td
	rename EIBOR?? EURIBOR??
	tempfile EURIBOR1
	save `EURIBOR1'

	import excel using ../original/Int_Future_Euribor_data_update.xlsx, clear sh("Sheet6") firstrow
	rename Code date
	format date %td
	rename EIBOR?? EURIBOR??
	rename EIBOR??? EURIBOR???
	tempfile EURIBOR2
	save `EURIBOR2'

	use `EURIBOR1',clear
	merge 1:1 date using `EURIBOR2'
	drop _merge
	save ../data/EURIBOR,replace

	* Import EURIBOR 1W
	import excel using ../original/Int_EURIBOR_0327.xlsx,clear firstrow
	rename Date date
	format date %td
	keep date EIBOR1WIO
	rename EIBOR1WIO EURIBOR1W
	save ../data/EURIBOR1W,replace

	* Import ois rate from tokyo and london

	foreach var of newlist EUSWEA_L EUSWEA_T  EUSWEC_L  EUSWEC_T  EUSWE1_L  EUSWE1_T{
	import excel using ../original/20180805_ois_data.xls,clear firstrow sheet("`var'")
	rename Date date
	format date %td
	save ../data/data_`var',replace
	}

	* Add additional equity indices
	import excel using ../original/20180704_Stoxx_SS.xlsx, clear firstrow
	rename Name date
	format date %td

	rename EUROSTOXX* * 
	rename *EPR* *

	global SSSIndices "BANKS AUTOPARTS INSURANCE BASICMATS BASICRESOURCE CHEMICALS CONMAT FINANCIALSVS FINANCIALS FOODBEV HEALTHCARE OILGAS MEDIA INDUSTRIALS INDSGDSSVS TECHNOLOGY TELECOM UTILITIES HEALTHCAR"

	foreach element of varlist $SSSIndices{
	gen r`element'=.
	replace r`element'=(ln(`element'[_n])-ln(`element'[_n-1]))*100
	}

	save ../data/Int_SSS_Indices,replace


	import excel using ../original/Int_New_Equity_Indices1.xlsx, clear firstrow
	rename Code date
	format date %td

	gen statadate = date + td(30dec1899)
	format statadate %td
	drop date
	rename statadate date

	global Indices "FTEFC1E FTEU300 DAXINDX IBEX35I FRCAC40 FTSEMIB"

	foreach element of varlist $Indices{
	gen r`element'=.
	replace r`element'=(ln(`element'[_n])-ln(`element'[_n-1]))*100
	}

	save ../data/Int_Equity_Indices,replace

	* Add national indices
	import excel using ../original/20180809_Nat_Indices.xlsx, clear firstrow
	format date %td

	global Nat_Indices "ATXINDX GRAGENL ISECP20 LXLUXXI AMSTEOE POPSI20 DAXINDX FRCAC40 IBEX35I FTSEMIB HEXINDX BGBEL20"

	foreach element of varlist $Nat_Indices{
	gen r`element'=.
	replace r`element'=(ln(`element'[_n])-ln(`element'[_n-1]))*100
	}

	foreach element of varlist $Nat_Indices{
	forvalues i=1/30{
	gen r`i'_`element'=.
	replace r`i'_`element'=(ln(`element'[_n+`i'-1])-ln(`element'[_n-1]))*100
	}
	}
	save ../data/Int_Equity_Nat_Indices,replace


	** Prepare price index data EU
	import excel ../original/ECB_HPI.xls,firstrow clear
	save ../data/ECB_HPI,replace



	****

	forvalue i=1/3{
	import excel using ../original/Bund_Yields.xlsx, sheet("Sheet`i'") clear firstrow
	rename Dates date 
	format date %td
	tempfile Int_Bund`i'
	save `Int_Bund`i'',replace
	}


	forvalue i=1/23{
	import excel using ../original/Bloomberg_data_full.xlsx, sheet("Sheet`i'") clear firstrow
	rename Date date 
	format date %td
	tempfile Int_Bl`i'
	save `Int_Bl`i''
	}

	use `Int_Bl1',clear
	forvalue i=2/23{
	merge 1:1  date using `Int_Bl`i''
	drop _merge
	}

	forvalue i=1/3{
	merge 1:1  date using `Int_Bund`i''
	drop _merge
	}

	*** Generate first differences and percentage incr for the financial variables

	local finvar "ITA_10Y NLD_10Y FRA_10Y GER_10Y ESP_10Y ITA_5Y NLD_5Y FRA_5Y GER_5Y ESP_5Y" 

	foreach var of local finvar{
	gen d_`var'=`var'[_n]-`var'[_n-1]
	gen pct_`var'=ln(`var'[_n])-ln(`var'[_n-1])
	}

	* Swap Rate Change between Tokyio and London (5hour window)
	gen d_swap3yr_tl=Y3_V_3M_LON- Y3_V_3M_TOK
	* One day change swap rate London
	gen d_swap3yr_LON=Y3_V_3M_LON-Y3_V_3M_LON[_n-1]

	* Credit spread BBB and Germany--5yr and 10yr
	gen BBB_spread_10yr=BBB_10Y-GER_10Y
	gen BBB_spread_5yr=BBB_5Y-GER_5Y
	* Change in the credit spread BBB
	gen d_BBB_spread_10yr=BBB_spread_10yr-BBB_spread_10yr[_n-1]
	gen d_BBB_spread_5yr=BBB_spread_5yr-BBB_spread_5yr[_n-1]

	* Credit spread AA and Germany--5yr and 10yr
	gen AA_spread_10yr=AA_10Y-GER_10Y
	gen AA_spread_5yr=AA_5Y-GER_5Y
	* Change in the credit spread BBB
	gen d_AA_spread_10yr=AA_spread_10yr-AA_spread_10yr[_n-1]
	gen d_AA_spread_5yr=AA_spread_5yr-AA_spread_5yr[_n-1]

	*Calculate term spreads (wrt 3M)
	gen tp5yr=GER_5Y-Y5_V_3M_LON
	gen tp3yr=BUND_3Y-Y3_V_3M_LON

	gen d_tp5yr=tp5yr-tp5yr[_n-1]
	gen d_tp3yr=tp3yr-tp3yr[_n-1]


	save ../data/Financial_Variables,replace
	
	


	*************************************************
	** Rate and Voume Data from the ECB
	*************************************************

	* Interest rate (monthly) ECB
	import delimited using ../original/ECB_avg_int_rate.csv, rowrange(6)   delimiters(",")  clear
	gen date_mon = monthly(v1,"YM")
	format date_mon %tm
	rename v2 loan_rate
	drop v1
	label var  loan_rate "Interest rate on NFC loans (monthly)"
	*twoway line rate date if year(date)<2008
	save ../data/ECB_interest_loan,replace

	import excel using ../original/ECB_loans_flow_update.xlsx,clear firstrow
	gen statadate=date(date,"YM")
	format statadate %td
	drop date
	rename statadate date
	gen year =year(date)
	collapse (sum) volume,by(year)
	twoway line volume year
	rename volume vol_origination
	label var vol_origination "vol_origination (per year)"
	save ../data/ECB_loans_flow,replace

	import excel using ../original/ECB_loan_imp_duration.xlsx,clear firstrow
	gen statadate=date(date,"YM")
	format statadate %td
	drop date
	rename statadate date
	gen year =year(date)
	collapse (mean) duration,by(year)
	save ../data/ECB_loan_imp_duration,replace

	import delimited using ../original/ECB_loans_NFC_stocks.csv, rowrange(6)   delimiters(",")  clear
	gen date_mon = monthly(v1,"YM")
	format date_mon %tm
	rename v2 volume
	drop v1
	
	label var volume "ECB NFC loan volume (stock)"
	
	*gen year =year(dofm(date))
	*collapse (mean) volume,by(year)
	
	save ../data/ECB_loans_NFC_stocks,replace
	
end

program create_shares_out
	import excel using ../original/Ind_shares_outstanding.xlsx,clear firstrow
	save ../data/shares_outstanding_Default,replace
	
	import excel using ../original/US_sharesout.xlsx,sheet("Sheet1") clear firstrow
	destring year,replace
	save ../data/shares_outstanding_US,replace
end

program create_US_market
	import excel using ../original/US_marketprices.xlsx,sheet("equity_sp500") clear cellrange(A2) firstrow
	rename Code date
	gen rSP500return = (log(SPCOMPPI) - log(SPCOMPPI[_n-1]))*100
	save ../data/US_marketreturn,replace
	
	import excel using ../original/US_marketprices.xlsx,sheet("bond_yield") clear cellrange(A2) firstrow
	rename Code date
	rename MLU3BTLRY USyieldBBB
	rename ML2ARTLRY USyieldAA
	save ../data/US_bondyields,replace
end

program create_riskfree
	import excel using ../original/US_treasury1yr.xlsx,clear cellrange(A6) firstrow 
	rename Dates date
	drop year
	rename PX_LAST yield
	save ../data/US_riskfree,replace
end

program create_target
	import excel using ../original/FRED_DFEDTAR.xlsx,clear cellrange(A11) firstrow 
	rename observation_date date
	rename DFEDTAR ff_target
	save ../data/US_targetrate,replace
end

program create_loanrate
	import excel using ../original/Fred_EEANQ.xlsx,clear cellrange(A11) firstrow 
	rename observation_date date
	rename EEANQ USloanrate
	save ../data/US_loanrate,replace
end

program create_bisdata
	import excel "../original/EURUSDfx.xlsx",clear  cellrange(A11) firstrow
	rename observation_date  dateday
	rename CCUSMA02EZQ618N fxEURUSD
	gen date = qofd(  dateday)
	format date %tq
	tempfile fx 
	save `fx'


	import delimited "../original/BIS_debtissuance.csv" , rowrange(6) varnames(6) clear 

	* generate iso of issuer
	gen iso = substr(issuerresidence,1,2)

	* limit the sample
	keep if inlist(iso,"AT","BE","DE","ES","FR","IT") | inlist(iso,"NL","FI","PT","GR","LU","IE")
	*CY, MT,SI,SK,LT,LV,

	* gen issuer 
	keep if issuersectorimmediateborrower == "J:Non-financial corporations"

	keep if issuemarket =="1:All markets"

	keep if measure == "I:Amounts outstanding"

	ds date_*, has(type string)
	foreach var in `r(varlist)' {
		destring `var', gen(n`var')
	}

	drop date_*
	collapse (sum) ndate_*
	gen id=_n
	reshape long ndate_,i(id) j(date)
	rename ndate_ tot_ds
	tostring date,replace
	gen datestata  = date(date,"DMY")
	format datestata %td
	drop date
	gen date = qofd(datestata)
	format date %tq
	merge 1:1 date using `fx'
	keep if _merge==3
	drop _merge
	gen issue_nonfincorp_fx = tot_ds * fxEURUSD
	gen year =year(datestata)
	gen quarter = quarter(dofq(date))
	keep if quarter == 4

	sort year
	drop if year < 2000
	keep year issue_nonfincorp_fx 

	save ../data/bis_euroarea.dta,replace
end


shareddata
