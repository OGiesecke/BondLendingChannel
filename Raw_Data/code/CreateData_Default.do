cap log close 
clear all 
set more off , permanently

* Set directories 
global path "/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Raw_Data/code"
*display `"this is the path: `1'""'
*global path "`1'"

display "${path}"
cd "$path"

*************************************************
** Execute all programs
*************************************************

program main_default
    select_sample_default
	prepare_capitaliq_default_sample
	create_stockdata_default
	create_mandebtstructure
	gen_shock_JK
	create_marketvalue
	create_priceindex
	gen_shock_altavilla
	gen_nation
	quarterly_shock
	create_age_WS
end

*************************************************
** Get Index Constituents from Industry Indices
*************************************************

program select_sample_default
	local dates "03/31/2000 06/30/2000 09/30/2000 12/31/2000 03/31/2001 06/30/2001 09/30/2001 12/31/2001 03/31/2002 06/30/2002 09/30/2002 12/31/2002 03/31/2003 06/30/2003 09/30/2003  12/31/2003 03/31/2004 06/30/2004 09/30/2004 12/31/2004 03/31/2005 06/30/2005 09/30/2005 12/31/2005 03/31/2006 06/30/2006 09/30/2006 12/31/2006 03/31/2007 06/30/2007 09/30/2007 12/31/2007 03/31/2008 06/30/2008 09/30/2008 12/31/2008 03/31/2009 06/30/2009 09/30/2009 12/31/2009 03/31/2010 06/30/2010 09/30/2010 12/31/2010 03/31/2011 06/30/2011 09/30/2011 12/31/2011 03/31/2012 06/30/2012 09/30/2012 12/31/2012 03/31/2013 06/30/2013 09/30/2013 12/31/2013 03/31/2014 06/30/2014 09/30/2014 12/31/2014 03/31/2015 06/30/2015 09/30/2015 12/31/2015 03/31/2016 06/30/2016 09/30/2016 12/31/2016 03/31/2017 06/30/2017 09/30/2017 12/31/2017 03/31/2018 06/30/2018 09/30/2018 12/31/2018 03/31/2019 06/30/2019 09/30/2019 12/31/2019"
	forvalue j=1/18{
		* Equity Indices *
		local i=1
		
		foreach num of local dates{
			display "This is industry `j' and spreadsheet `i'"
			import excel using ../original/Constituents`j'.xlsm, sheet("Sheet`i'") clear firstrow
			drop DSCD
			gen date=date("`num'","MDY")
			format date %td
			egen sum_MV=total(MV)
			gen f_float=NOSHFF/100
			replace f_float=1 if NOSHFF==.
			egen sum_FMV=total(MV*f_float)
			gen w_MV=MV/sum_MV
			gen w_FMV=MV/sum_FMV
			gen ind_code="s`j'"
			tempfile Int_S`j'_W`i'
			save `Int_S`j'_W`i''
			local i=`i'+1
		}
	}

	forvalue j=1/18{
		use `Int_S`j'_W1',clear
		forvalue k=2/80{
			append using `Int_S`j'_W`k''
		}
		tempfile Int_S`j'
		save `Int_S`j''
	}

	* Create ind
	use `Int_S1',clear
	forvalue j=2/18{
	append using `Int_S`j''
	}
	
	save ../data/Data_sample_default_ext.dta,replace
end


*************************************************
** Load capital IQ data default
*************************************************

program prepare_capitaliq_default_sample

	forvalue val =1/3{
		display "`val'"		
		
		import excel ../original/Default_cap_IQ_`val'.xlsx,clear firstrow
		rename A isin
		rename B year
		rename C capIQid
		duplicates drop isin year,force
		tempfile capiq`val'
		save `capiq`val''
	}

	use `capiq1'
	forvalue val =2/3{
	merge 1:1 isin year using `capiq`val'',nogen
	}
	
	save ../data/Default_CapitalIQ,replace
end

*************************************************
** Create file with daily stock market prices for the index constituents
*************************************************

program create_stockdata_default
	import excel using ../original/european_stock_extension.xlsx,firstrow clear
	tempfile equityprices
	save `equityprices',replace
	
	import excel using ../original/default_add_prices.xlsx,firstrow clear sheet("Sheet1")
	rename Code date
	rename *P *
	
	merge 1:1 date using `equityprices'
	keep if _merge==3
	drop _merge

	
	save ../data/Default_stock_data_ext.dta,replace
end

*************************************************
** Market value
*************************************************

program create_marketvalue
	import excel using ../original/default_mv.xlsx,firstrow clear
	rename *MV MV*

	gen date= quarterly("2000 Q1","YQ")
	replace date = date + _n -1
	drop Code
	format date %tq

	reshape long MV, i(date) j(isin) string
	drop JQ MU
	sort isin date
	gen year = year(dofq(date))
	collapse (mean) MV,by(isin year)
	
	gen yr_adj = year 
	
	save ../data/Default_marketvalue.dta,replace
end

*************************************************
** Price index
*************************************************

program create_priceindex
	import excel using ../original/ECB_HPI.xlsx,firstrow clear cellrange(A5)
	rename PeriodUnit date
	rename B EA_priceindex 
	
	gen date_mm = monthly(date,"YM")
	format date_mm %tm
	drop date
	
	gen date_mon =date_mm
	
	gen date_m=date_mm + 12
	format date_m %tm
	drop date_mm
	
	save ../data/EA_priceindex.dta,replace
end


*************************************************
** Jarocinsky and Karadi shock
*************************************************

program gen_shock_JK
	import excel using ../../Raw_Data/original/JK_eadata.xlsx,clear firstrow
	gen date=mdy(month,day,year)
	format date %td
	drop year month day 

		* classify the  shock 
	gen d_info=.
	replace d_info = 1 if eureon3m_hf >= 0 & stoxx50_hf >= 0 
	replace d_info = 1 if eureon3m_hf < 0 & stoxx50_hf < 0 
	replace d_info = 0 if eureon3m_hf >= 0 & stoxx50_hf < 0 
	replace d_info = 0 if eureon3m_hf < 0 & stoxx50_hf >= 0 

	gen year = year(date)

	tab year d_info 

	save ../data/JK_eadata,replace
	
	
	* create quarterly series with no-info only
	
	gen date_q=qofd(date)
	format date_q %tq
	egen agg_shock_JK_q = total(eureon3m_hf) ,by(date_q)
	egen agg_shock_JK_q_noinfo=total(eureon3m_hf) if d_info==0,by(date_q)
	egen tagq=tag(date_q)
	keep if tagq==1
	keep agg_shock_JK_q date_q agg_shock_JK_q_noinfo
	save ../data/Default_JKshock_quarterly,replace
	
end

*************************************************
** Altavilla et al. shock
*************************************************

program gen_shock_altavilla
	import excel using ../../Raw_Data/original/Dataset_EA-MPD.xlsx, clear sheet("Press Release Window") firstrow
	keep OIS_1M OIS_3M OIS_6M OIS_1Y OIS_2Y OIS_3Y OIS_4Y OIS_5Y date
	
	* Alt: Monetary Event Window or Press Conference Window or Press Release Window

	sum  OIS_1M  if year(date)> 2012 & year(date)<2019,det
	sum  OIS_1M  if year(date)>2000 & year(date)<2008,det
	save ../data/Altavilla_EAdata,replace

	import excel using ../../Raw_Data/original/Dataset_EA-MPD.xlsx, clear sheet("Press Conference Window") firstrow
	keep OIS_1M OIS_3M OIS_6M OIS_1Y OIS_2Y OIS_3Y OIS_4Y OIS_5Y date
	rename * *_conf
	rename date* date
	* Alt: Monetary Event Window or Press Conference Window or Press Release Window
	*twoway scatter OIS_1M_conf date if year(date)>2012
	save ../data/Altavilla_EAdataconf,replace
end


*************************************************
*** Add nation data
*************************************************

program gen_nation
	import excel ../../Raw_data/original/Default_nation.xlsx,firstrow clear
	tab NATION
	rename Type isin
	save ../data/nation,replace 
end

*************************************************
** Construct the quarterly shock
*************************************************

program quarterly_shock
	*** Altavilla et al. shock
	import excel using ../../Raw_Data/original/Dataset_EA-MPD.xlsx, clear sheet("Press Release Window") firstrow
	gen date_q=qofd(date)
	format date_q %tq
	egen agg_shock_ois_q=total(OIS_1M),by(date_q)
	egen tagq=tag(date_q)
	keep if tagq==1
	keep agg_shock_ois_q date_q
	save ../data/shock_quarterly,replace
	
	
	clear 
	set obs 100000
	gen date = 100 +  _n
	format date %td
	
	gen date_q=qofd(date)
	format date_q %tq
	bys date_q: gen run = _n
	keep if run==1
	gen daysinquarter = date - date[_n-1]
	keep date_q daysinquarter
	tempfile daysinquarter
	save `daysinquarter'
	
	clear 
	set obs 100000
	gen date = 100 +  _n
	format date %td
	
	gen date_q=qofd(date)
	format date_q %tq
	bys date_q: gen dayinquarter = _n
	keep date dayinquarter
	tempfile dayinquarter
	save `dayinquarter'
	
	
	import excel using ../../Raw_Data/original/Dataset_EA-MPD.xlsx, clear sheet("Press Release Window") firstrow
	gen date_q=qofd(date)
	keep date OIS_1M date_q
	format date_q %tq
	merge m:1 date_q using `daysinquarter'
	drop if _merge==2
	drop _merge
	
	merge m:1 date using `dayinquarter'
	drop if _merge==2
	drop _merge
	
	gen wa_shock = (daysinquarter - dayinquarter) / daysinquarter * OIS_1M
	gen wb_shock = (dayinquarter / daysinquarter) * OIS_1M
	
	collapse (sum) wa_shock wb_shock,by(date_q)
	
	gen prevwb_shock = wb_shock[_n-1]
	
	gen sm_shock = wa_shock + prevwb_shock
	
	sum sm_shock,det
	
	keep date_q sm_shock

	save ../data/shock_weightedquarterly,replace
	
		*** Altavilla et al. shock
	import excel using ../../Raw_Data/original/Dataset_EA-MPD.xlsx, clear sheet("Press Release Window") firstrow
	gen date_m = mofd(date)
	format date_m %tm
	egen agg_shock_ois_m=total(OIS_1M),by( date_m)
	egen tagm=tag( date_m)
	keep if tagm==1
	keep agg_shock_ois_m date_m
	tempfile shock_monthly
	save ../data/shock_monthly,replace
end

*************************************************
** Construct the age
*************************************************

program create_age
	use ../original/Default_age.dta,clear
	duplicates drop dateinc ipo_date sd_isin,force
	gen date =  dateinc
	replace  date = ipo_date if dateinc==.
	format date %td
	gen year_start =year(date)
	rename sd_isin isin
	* generate a panel for the age
	expand 20
	bys isin: gen year = 2000 - 1 + _n
	drop if year_start > year 
	gen age = year - year_start
	gen yr_adj = year
	keep isin yr_adj age
	save ../data/Default_age,replace
end


*************************************************
** Construct age from Wordscope data as in Cloyne et al.
*************************************************

program create_age_WS
	use ../original/Default_Worldscope_age, clear 
	drop code freq
	rename year_ year
	rename item6008 isin
	rename item18273 date_incorporation
	rename item18272 date_founded
	gen start_date = date_incorporation
	replace start_date = date_founded if  date_incorporation==.
	gen year_start = year(start_date)
	drop date_incorporation date_founded
	drop if isin ==""
	
	duplicates drop isin year_start ,force
	drop year
	* generate a panel for the age
	expand 20
	bys isin: gen year = 2000 - 1 + _n
	drop if year_start > year 
	gen age = year - year_start
	gen yr_adj = year
	keep isin yr_adj age
	label var age "Age since Incorporation"
	save ../data/Default_WS_age,replace
end

*************************************************
** Manual debt struture 
*************************************************

program create_mandebtstructure
	import excel using ../original/CapitalStructure.xlsx,firstrow clear     cellrange(A1:J151) 
	drop if isin == "NL0000008977" // Drop Heineken Holding
	foreach var of varlist bonds2000 bonds2001 cp2000 cp2001{
		destring `var' ,replace
	}
	foreach year in 2000 2001{
		egen man_market`year' = rowtotal(bonds`year' cp`year'),missing
		gen mlev`year' = man_market`year' / IQ_TOTAL_ASSETS`year'
	}
	
	keep isin man_market2000 man_market2001
	reshape long man_market, i(isin) j(year)
	replace man_market = man_market * 1000000
	save ../data/Default_man_mdebt.dta,replace
end


*************************************************
main_default


