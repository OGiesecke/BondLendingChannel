cap log close 
clear all 
set more off , permanently

* Set directories 
display "`1'"
global path "`1'"

display "${path}"
cd "$path"

*************************************************
** Execute all programs
*************************************************

program main
    select_sample
    prepare_capitaliq
	create_stockdata
	create_fedshock
	transfer_fedshock
	*create_newcapitalIQ
	*create_def_probabilities_US
	create_marketvalue
	create_nation
	create_cpi
end

*************************************************
** Create the Sample from S&P Constituents
*************************************************

program select_sample
	local dates "03/31/2000 06/30/2000 09/30/2000 12/31/2000 03/31/2001 06/30/2001 09/30/2001 12/31/2001 03/31/2002 06/30/2002 09/30/2002 12/31/2002 03/31/2003 06/30/2003 09/30/2003  12/31/2003 03/31/2004 06/30/2004 09/30/2004 12/31/2004 03/31/2005 06/30/2005 09/30/2005 12/31/2005 03/31/2006 06/30/2006 09/30/2006 12/31/2006 03/31/2007 06/30/2007 09/30/2007 12/31/2007 03/31/2008 06/30/2008 09/30/2008 12/31/2008 03/31/2009 06/30/2009 09/30/2009 12/31/2009 03/31/2010 06/30/2010 09/30/2010 12/31/2010 03/31/2011 06/30/2011 09/30/2011 12/31/2011 03/31/2012 06/30/2012 09/30/2012 12/31/2012 03/31/2013 06/30/2013 09/30/2013 12/31/2013 03/31/2014 06/30/2014 09/30/2014 12/31/2014 03/31/2015 06/30/2015 09/30/2015 12/31/2015 03/31/2016 06/30/2016 09/30/2016 12/31/2016 03/31/2017 06/30/2017 09/30/2017 12/31/2017 03/31/2018 06/30/2018 09/30/2018 12/31/2018 03/31/2019 06/30/2019 09/30/2019 12/31/2019"
	local i=1
	foreach num of local dates{
		import excel using ../original/SandPconstituentsupdatedCUSIP.xlsm, sheet("Sheet`i'") clear firstrow
		
		rename WC06004 cusip
		gen date=date("`num'","MDY")
		format date %td
		tempfile Int_US_`i'
		save `Int_US_`i''
		local i=`i'+1
	}
	
	use `Int_US_1',clear
	forvalue k=2/80{
		append using `Int_US_`k'',force
	}
	save ../data/Data_sample_US.dta,replace
end

*************************************************
** Load and Merge the Capital IQ Data for US
*************************************************


program prepare_capitaliq
	forvalue val = 1/6{
	display `val'
	import excel ../original/US_cap_IQ_`val'.xlsx,clear firstrow
	rename A cusip 
	rename B year
	rename C capIQid
	duplicates drop cusip year,force
	tempfile capiq`val'
	save `capiq`val''
	}

	use `capiq1'
	forvalue val = 2/6{
	merge 1:1 cusip year using `capiq`val'',nogen
	}
	
	drop if capIQid=="(Invalid Identifier)"
	foreach var of varlist IQ*{
		display `var'
		destring `var',replace
	}
	
	rename cusip d6cusip
	save ../data/CapitalIQ_US,replace
end
	



*************************************************
** Create file with daily stock market prices for the index constituents
*************************************************

program create_stockdata
	import excel using ../original/US_stock_returns.xlsx,clear firstrow sheet("Sheet1")
	tempfile US_stock_return1
	save `US_stock_return1'
	
	import excel using ../original/US_stock_returns2.xlsx,clear firstrow sheet("Sheet1")
	tempfile US_stock_return2
	save `US_stock_return2'
	
	use `US_stock_return1',clear
	merge 1:1 date using `US_stock_return2'
	save ../data/US_stock_data.dta,replace
end


*************************************************
** Load Nakamura, Steinsson (2018) FFR shocks
*************************************************

program create_fedshock
	import excel using ../original/US_emi_jon_shock.xlsx,clear firstrow sheet("PolicyNewsShocks")
	save ../data/US_FED_emi_jon_data.dta,replace
end

program transfer_fedshock
	use ../original/Fed_shocks.dta,clear
	save ../data/Fed_shocks.dta,replace
end

*************************************************
** Default probabilities
*************************************************


program create_def_probabilities_US
	import delimited using ../../Int_Data/code/matlab/US_KMVmodelresults.csv,clear 
	save ../data/US_defprobabilities_kmv,replace
end

*************************************************
** market value quarterly
*************************************************

program create_marketvalue
	import excel using ../original/F_US_Sample_MV_NATION.xlsx, sheet("MV") firstrow clear
	rename *MV MV*
	*replace Code = subinstr(Code, " ", "",.) 
	gen date= quarterly("2000 Q1","YQ")
	replace date = date + _n -1
	drop Code
	format date %tq

	reshape long MV, i(date) j(isin) string
	sort isin date
	
	gen year = year(dofq(date))
	collapse (mean) MV , by(isin  year)
	gen yr_adj=year
	save ../data/US_marketvalue.dta,replace
end
*************************************************
** Nation
*************************************************

program create_nation
	import excel using ../original/F_US_Sample_MV_NATION.xlsx, sheet("Nation") firstrow clear
	rename Type isin
	rename NATION nation
	drop NATIONCODE
	sort isin 
	save ../data/US_nation.dta,replace
end


*************************************************
** CPI
*************************************************

program create_cpi
	import excel using ../original/CPIAUCSL.xls, cellrange(A11 )firstrow clear
	rename observation_date date 
	rename  CPIAUCSL_NBD20150101 us_priceindex
	gen date_mm = mofd(date)
	format date_mm %tm
	gen date_m =  date_mm + 12
	format date_m %tm
	drop date  date_mm
	save ../data/US_cpi.dta,replace
end

*************************************************
main
