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

program main
	clean_sample_US
	clean_IBES
    create_stock_return
    clean_Capital_IQ
	create_shocks
	gen_ratings
end


*************************************************
** Clean the Sample
*************************************************

program clean_sample_US
	use ../data/Data_sample_US.dta,clear

	preserve
	keep cusip 
	duplicates drop cusip,force
	save ../data/US_cusip_data,replace
	export delimited ../data/US_cusip_data.csv,replace
	restore
	
	drop if cusip==""
	gen  help = "0000000"+cusip
	gen d9cusip = substr(help,-9,9)
	gen d6cusip = substr(d9cusip,1,6)
	
	gen date_q=qofd(date)
	format date_q %tq
	rename ISIN isin
	
	
	rename NAME name
	gen year=year(date)
	drop date
	
	duplicates drop isin date_q,force
	
	* get stats
	keep  if year > 2000 & year < 2019
	egen tag_FQ=tag(date_q isin)
	egen tag_YI = tag(isin year)
	tab year tag_YI 
	
	
	drop if isin ==""
	sort isin date_q 
	
	tab year if tag_YI
	
	* check for gaps in the time series
	keep if tag_FQ==1
	by isin: gen dist = date_q-date_q[_n-1]
	
	* Output the sample for the paper
	
	egen start_date = min(date_q) ,by(isin)
	egen end_date = max(date_q) ,by(isin)
	
	egen tag_F = tag(isin)
	keep if tag_F ==1


	keep isin name start_date end_date d6cusip
	format start_date %tq
	format end_date %tq
	sort name
	
		* create panel
	gen gap = end_date - start_date + 1
	expand gap
	bys isin: gen counter = _n -1
	gen date_q = start_date + counter
	format date_q %tq
	sort isin
	drop gap counter
	gen year = year(dofq(date_q))	
	
	
	
	* save files
	drop if isin =="NA"
	save ../data/FQ_US_Sample.dta,replace
	keep isin name d6cusip
	duplicates drop isin,force
	save ../data/F_US_Sample.dta,replace
	export delimited ../data/F_US_Sample.csv,replace
end

*************************************************
** Clean the IBES data 
*************************************************

program clean_IBES
	use ../data/FQ_US_Sample.dta,clear
	duplicates drop  isin year, force
	drop if isin ==""
	merge m:1 isin using ../data/crosswalk_US_IBES.dta
    keep if _merge==3
	drop _merge
	
	gen nonUS = 0

	merge m:1 IBES_ticker year nonUS using ../data/Default_IBES_LTG.dta
	drop if _merge==2
	drop _merge
	
	replace nonUS=1
	
	merge m:1 IBES_ticker year nonUS using ../data/Default_IBES_LTG.dta,update 
	drop if _merge==2
	drop _merge
	
	keep isin  year LTG_EPS
	bysort isin: carryforward LTG_EPS, gen(LTG_EPSn)
	replace LTG_EPS = LTG_EPSn
	drop LTG_EPSn
		* Merge with a lag
	gen yr_adj = year 
	save ../data/US_IBES_LTG,replace
end



*************************************************
*** Default probabilities
*************************************************

program gen_default_probabilities_US
	use ../data/US_defprobabilities_kmv,clear
	label var defprob "Default probability (KMV)"
	label var dtd "Distance-to-default (KMV)"
	save ../data/US_defprobability,replace
end

*************************************************
** Clean the CapitalIQ data
*************************************************


program clean_Capital_IQ
	use ../data/CapitalIQ_US.dta,replace
	label var year "fiscal year"
	label var IQ_TOTAL_ASSETS "total assets"
	label var IQ_TOTAL_DEBT "total debt"
	
	label var IQ_BANK_DEBT "bank debt"
	
	label var IQ_SR_BONDS_NOTES "Senior bonds or notes"
	label var IQ_SUB_BONDS_NOTES "Subordinates bonds or notes"
	
	label var IQ_TERM_LOANS "Term loans"
	label var IQ_RC "Revolving loans"
	label var IQ_UNDRAWN_RC "Undrawn revolving loans (pres. credit lines)"


	drop IQ_EBITDA

	* Adjust the unit to Worldscope
	foreach i of varlist IQ_CASH_ST_INVEST IQ_UNDRAWN_RC IQ_UNDRAWN_TL  ///
	IQ_BANK_DEBT IQ_CP IQ_RC IQ_TERM_LOANS IQ_SR_BONDS_NOTES IQ_SUB_BONDS_NOTES ///
	IQ_TRUST_PREFERRED IQ_LEASES_TOTAL IQ_OTHER_DEBT IQ_UNAMORT_PREMIUM ///
	IQ_UNAMORT_DISC IQ_DEBT_ADJ IQ_TOTAL_DEBT IQ_TOTAL_ASSETS {
		replace `i'=`i'*1000000
	}
	* Define bond debt
	egen IQ_BONDS_NOTES=rowtotal(IQ_SR_BONDS_NOTES IQ_SUB_BONDS_NOTES)
	label var  IQ_BONDS_NOTES "Total bonds or notes"
	replace IQ_BONDS_NOTES =. if IQ_SR_BONDS_NOTES==. &  IQ_SUB_BONDS_NOTES==.
	
	* Define market based debt
	egen IQ_MARKET=rowtotal(IQ_SR_BONDS_NOTES IQ_SUB_BONDS_NOTES IQ_CP)
	label var  IQ_MARKET "Market based financing"
	replace IQ_MARKET =. if IQ_SR_BONDS_NOTES==. &  IQ_SUB_BONDS_NOTES==. & IQ_CP ==.
	

	drop if IQ_TOTAL_ASSETS==.
	gen yr_adj=year
	save ../data/Capital_IQ_US.dta,replace
end

*************************************************
** Clean the shocks
*************************************************

program create_shocks
	import excel using ../../Raw_Data/original/JK_usdata.xlsx,clear firstrow
	gen date=mdy(month,day,year)
	format date %td
	drop year month day 

	duplicates tag date,gen(new)
		* classify the  shock 
	gen d_info=.
	replace d_info = 1 if ff4_hf >= 0 & sp500_hf >= 0 
	replace d_info = 1 if ff4_hf < 0 & sp500_hf < 0 
	replace d_info = 0 if ff4_hf >= 0 & sp500_hf < 0 
	replace d_info = 0 if ff4_hf < 0 & sp500_hf >= 0 

	*twoway scatter ff4_hf date
	gen year = year(date)

	tab year d_info 

	save ../data/JK_usdata,replace
end

*************************************************
** Create Stock Returns from Datastream
*************************************************

program create_stock_return
	use ../data/US_stock_data.dta,replace
	rename * price*
	rename *P *
	rename pricedate date
	reshape long price, i(date) j(isin) string
	
	duplicates tag date,gen(new)
	sort isin date
	by isin: gen return=log(price)-log(price[_n-1])
	gen quarter=qofd(date)
	format quarter %tq
	drop _merge new
	gen year=year(date)
	save ../data/US_stock_return.dta,replace
end

*************************************************
** Clean the ratings from Bloomberg
*************************************************


program gen_ratings
	import delimited ../data/US_fullrating.csv, clear
	rename date datestring
	gen date = date(datestring,"MDY")
	format date %td
	keep isin date n_mean_rating mean_rating
	gen year = year(date)
	gen yr_adj = year
	
	save ../data/US_fullratingpanel,replace 
end


main
