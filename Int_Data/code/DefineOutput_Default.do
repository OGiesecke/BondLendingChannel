cap log close 
clear all 
set more off , permanently
set maxvar 20000,perm

* Set directories 
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"


*************************************************
** Execute all programs
*************************************************

program main
	clean_sample
    create_stock_return_default
    clean_Capital_IQ
	clean_IBES
	gen_ratings
	create_equityvol
	get_sample
end

*************************************************
** Clean the Sample Data
*************************************************

program clean_sample
	use ../data/Data_sample_default_ext.dta,clear
	keep ISIN NAME w_MV MV sum_MV ind_code date
	gen year = year(date)
	gen date_q = qofd(date)
	format date_q %tq
	
	rename ISIN isin
	gen yr_adj=year-1
	drop date

	drop sum_MV w_MV 
	rename NAME name
	replace MV=MV*1000000 // adjust unit
	
	* drop one dead company
	drop if name=="FORTIS (AMS) DEAD - SEE MOR 929303"
	
	// no duplicates anymore
	duplicates tag isin date_q ind_code,gen(n_dup)
	tab n_dup
	drop n_dup
	
	* get stats
	keep  if year > 2000 & year < 2019
	egen tag_FQ = tag(date_q isin) 
	egen tag_YI = tag(isin year)
	tab year tag_YI 
	egen tag_F = tag(isin)  
	
	drop if isin ==""
	tab tag_FQ
	tab tag_F 
	sort isin date_q 
	
	* check for gaps in the time series
	keep if tag_FQ==1
	by isin: gen dist = date_q-date_q[_n-1]
	tab dist
	
	* Output the sample for the paper
	egen start_date = min(date_q) ,by(isin)
	egen end_date = max(date_q) ,by(isin)

	keep if tag_F ==1	

	keep isin name start_date end_date
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
	
	gen length = end_date - start_date +1
	
	egen tag_F = tag(isin)
	
	tab length if tag_F==1
	drop if length < 4 // drop observation with less than four quarters
	keep isin name date
	
	
	gen year = year(dofq(date_q))
	
	save ../data/FQ_Default_Constituents_ext.dta,replace
	keep isin name
	duplicates drop isin,force
	save ../data/F_Default_Constituents_ext.dta,replace
	export delimited ../data/F_Default_Constituents_ext.csv,replace
end

*************************************************
** Clean the IBES data 
*************************************************

program clean_IBES
	use ../data/FQ_Default_Constituents_ext.dta,clear
	duplicates drop  isin year, force
	drop if isin ==""
	merge m:1 isin using ../data/crosswalk_Default_IBES.dta
    keep if _merge==3
	drop _merge
	
	replace IBES_ticker = "HKN" if isin=="NL0000008977"
	replace IBES_ticker = "YAU" if isin=="LU0061462528"
	replace IBES_ticker = "PFI" if isin=="IT0003826473"
	replace IBES_ticker = "DCJ" if isin =="IE0002424939"
	replace IBES_ticker = "GOE" if isin =="IE00B00MZ448"
	
	gen nonUS =1 

	merge m:1 IBES_ticker year nonUS using ../data/Default_IBES_LTG.dta
	drop if _merge==2
	drop _merge
	
	replace nonUS=0
	
	merge m:1 IBES_ticker year nonUS using ../data/Default_IBES_LTG.dta,update 
	drop if _merge==2
	drop _merge
	
	keep isin  year LTG_EPS
	bysort isin: carryforward LTG_EPS, gen(LTG_EPSn)
	replace LTG_EPS = LTG_EPSn
	drop LTG_EPSn
		* Merge with a lag
	gen yr_adj = year 
	save ../data/Default_IBES_LTG_ext,replace
end


*************************************************
** Create Stock Returns from Datastream
*************************************************

program create_stock_return_default
	use ../data/Default_stock_data_ext.dta,replace
	rename * price*
	rename pricedate date
	reshape long price, i(date) j(isin) string
	gen year =year(date)
	gen quarter=quarter(date)
	gen yr_adj=year-1
	sort isin date 
	by isin: gen return=ln(price)-ln(price[_n-1])
	save ../data/Default_stock_return_ext.dta,replace
end

program create_equityvol
	use  ../data/Default_stock_return_ext.dta,clear
	egen daycount = count(return), by(year isin)
	egen equity_vol = sd(return) if daycount>200,by(year isin)
	// get equity vol only if more than 200 active trading days.
	egen tag = tag(year isin)
	keep if tag==1
	keep isin yr_adj equity_vol
	save ../data/Default_equityvol.dta,replace
end
	

*************************************************
** Clean the CapitalIQ data
*************************************************

program clean_Capital_IQ
	use ../data/Default_CapitalIQ.dta,replace
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
	
	* Update the entries for 2000 and 2001 with manually collected data
	merge 1:1 year isin using ../data/Default_man_mdebt.dta
	replace IQ_MARKET = man_market if _merge==3 & man_market!=.
	drop _merge man_market
	
	save ../data/Capital_IQ_Default_Clean_ext.dta,replace
end


	

*************************************************
** Clean the ratings from Bloomberg
*************************************************


program gen_ratings
	import delimited ../data/Default_fullrating.csv, clear
	rename date datestring
	gen date = date(datestring,"MDY")
	format date %td
	keep isin date n_mean_rating mean_rating
	gen year = year(date)
	gen yr_adj = year
	
	save ../data/Default_fullratingpanel,replace 
end

*************************************************
** Clean the ratings from Bloomberg
*************************************************


program gen_ratings
	import delimited ../data/Default_fullrating.csv, clear
	rename date datestring
	gen date = date(datestring,"MDY")
	format date %td
	keep isin date n_mean_rating mean_rating
	gen year = year(date)
	gen yr_adj = year
	
	save ../data/Default_fullratingpanel,replace 
end

*************************************************
** Get sample restrictions
*************************************************

program get_sample
	import delimited using ../../Data_Files/Default_finalsample.csv,clear varnames(1)
	gen startd =  year(dofq(quarterly(start_date,"YQ")))
	gen endd =  year(dofq(quarterly(end_date,"YQ")))
	expand (endd - startd +1)
	sort isin startd
	by isin: gen nn = _n-1
	gen year = startd + nn
	gen cov_year = year-1
	keep isin year cov_year
	save ../data/Default_finalsample_FY.dta
end

*************************************************

main

