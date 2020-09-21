cap log close 
clear all 
set more off , permanently

* Set directories 
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"


*************************************************
** Execute all Programs
*************************************************

program main 
	clean_market_data
	clean_price_index
	extract_quarterly_shock
end

*************************************************
** Get quarterly shock **
*************************************************

program extract_quarterly_shock
	use ../data/MergedCleaned_MarketData.dta,clear
	
	gen date_q=qofd(date)
	
	egen agg_shock_ois_m=total(d_ois1mtl*MP_event),by(date_q)
	egen tagm=tag(date_q)
	keep if tagm==1
	drop date
	keep date_q d_ois1mtl
	format date_q %tq

	save ../data/OIS_quarterly,replace
end


*************************************************
** Clean Master Data **
*************************************************

program clean_market_data
	use ../data/Merged_MarketData,clear
	sort date
	drop EUROSTOXXNETRETURN EUROSTOXXPRICEINDEX MSCIEMUSMALLCAPEPRICEIND 
	* The following series are monthly, not daily
	drop MSCIEMUETOTRETURNIND MSCIEMUENETRETURN MSCIEUROTOTRETURNIND MSCIEURONETRETURN

	rename EURO3MONTHOISMIDDLERATE ois3m
	rename EURO1MONTHOISMIDDLERATE ois1m

		
	/*
	forvalues i=1/30{
	gen r`i'_MSCIEMUpi=.
	replace r`i'_MSCIEMUpi=(ln(MSCIEMUpi[_n+`i'-1])-ln(MSCIEMUpi[_n-1]))*100
	}
	*/

	gen year=year(date)

	* Create continuous MP policy rate series (timing of changes is the announcement)
	gen MP_policy_rate=min_var_rate
	replace MP_policy_rate=fixed_rate  if MP_policy_rate==.
	sort date
	replace MP_policy_rate=MP_policy_rate[_n+1] 
	replace MP_policy_rate=MP_policy_rate[_n+2] if date==date("12/01/2005","MDY")
	replace MP_policy_rate=. if date==date("12/05/2005","MDY")
	replace MP_policy_rate=. if date>date("12/05/2005","MDY")
	replace MP_policy_rate=2.5 if date==date("03/02/2006","MDY")
	replace MP_policy_rate=2.75 if date==date("06/08/2006","MDY")
	replace MP_policy_rate=3 if date==date("08/03/2006","MDY")
	replace MP_policy_rate=3.25 if date==date("10/05/2006","MDY")
	replace MP_policy_rate=3.50 if date==date("12/07/2006","MDY")
	replace MP_policy_rate=3.75 if date==date("03/08/2007","MDY")
	replace MP_policy_rate=4.00 if date==date("06/06/2007","MDY")
	replace MP_policy_rate=4.25 if date==date("07/03/2008","MDY")

	replace MP_policy_rate=MP_policy_rate[_n-1] if missing(MP_policy_rate)
	gen d_MP_policy_rate=MP_policy_rate-MP_policy_rate[_n-1]

	* Adjust for the fact that EURIBOR fixing is at 11 am whereas policy announcement 
	* takes place between 1.30 - 2.30 pm. Hence, the surprise is captured in the rate of the following day.
	gen EURIBOR1M_adj=EURIBOR1M[_n+1]
	gen d_EURIBOR1M_adj=EURIBOR1M_adj-EURIBOR1M_adj[_n-1]

	label var EURIBOR1M_adj "EURIBOR1M(adj)"
	label var d_EURIBOR1M_adj "Change EURIBOR 1M"

	gen EURIBOR1W_adj=EURIBOR1W[_n+1]
	gen d_EURIBOR1W_adj=EURIBOR1W_adj-EURIBOR1W_adj[_n-1]

	label var EURIBOR1W_adj "EURIBOR1W(adj)"
	label var d_EURIBOR1W_adj "Change EURIBOR 1W"

	gen EURIBOR3M_adj=EURIBOR3M[_n+1]
	gen d_EURIBOR3M_adj=EURIBOR3M_adj-EURIBOR3M_adj[_n-1]

	gen EURIBOR6M_adj=EURIBOR6M[_n+1]
	gen d_EURIBOR6M_adj=EURIBOR6M_adj-EURIBOR6M_adj[_n-1]

	gen EURIBOR9M_adj=EURIBOR9M[_n+1]
	gen d_EURIBOR9M_adj=EURIBOR9M_adj-EURIBOR9M_adj[_n-1]


	label var EURIBOR1M_adj "EURIBOR1M(adj)"
	label var d_EURIBOR1M_adj "Change EURIBOR 1M"

	* Generate the Bloomberg 1 difference
	gen d_EUSWEA=EUSWEA-EUSWEA[_n-1]
	gen d_EUSWE1=EUSWE1-EUSWE1[_n-1]

	label var d_EUSWEA "1. diff OIS1M Bl."
	label var d_EUSWE1 "1. diff OIS1Y Bl."

	* Adjust for the fact that OIS Survey is conducted on the subsequent days.
	gen ois1M_adj=ois1m[_n+1]
	label var ois1M_adj "OIS 1M (adj)"

	gen ois3M_adj=OIEUR3M[_n+1]
	label var  ois3M_adj "OIS 3M (adj)"

	gen ois1Y_adj=OIEUR1Y[_n+1]
	label var ois1Y_adj "OIS 1Y (adj)"

	gen d_ois1M_adj = ois1M_adj-ois1M_adj[_n-1]
	label var d_ois1M_adj "OIS 1M Change"

	* Create alternative OIS 1M series
	gen d_ois1M_adj_lagged=d_ois1M_adj[_n-1]
	gen d_ois1M_adj_2day=ois1M_adj-ois1M_adj[_n-2]

	gen d_ois3M_adj = ois3M_adj-ois3M_adj[_n-1]
	label var ois3M_adj "OIS 3M Change"

	gen d_ois1Y_adj = ois1Y_adj-ois1Y_adj[_n-1]
	label var ois1Y_adj "OIS 1Y Change"

	* Create daily changes in EURIBOR 3M future rates
	gen d_eur1st=ER1Comdty[_n-1]-ER1Comdty
	gen d_eur2nd=ER2Comdty[_n-1]-ER2Comdty
	gen d_eur3rd=ER3Comdty[_n-1]-ER3Comdty
	gen d_eur4th=ER4Comdty[_n-1]-ER4Comdty

	* Calculate changes in the swap rate 
	gen d_3m1y=EUSW1V3CMPLCurncy-EUSW1V3CMPTCurncy
	gen d_3m2y= EUSW2V3CMPTCurncy-EUSW2V3CMPLCurncy

	* Calculate the change in location specific OIS rates
	gen d_ois1mtl=EUSWEA_L- EUSWEA_T
	gen d_ois3mtl=EUSWEC_L- EUSWEC_T
	gen d_ois6mtl= EUSWEFCMPLCurncy-EUSWEFCMPTCurncy
	gen d_ois9mtl= EUSWEICMPLCurncy- EUSWEICMPTCurncy
	gen d_ois1ytl=EUSWE1_L- EUSWE1_T

	* Calculate forwards OIS rates  
	gen f13ml=(exp(ln(EUSWEC_L/100*90/360+1)-ln(EUSWEA_L/100*30/360+1))-1)*360/60
	gen f13mt=(exp(ln(EUSWEC_T/100*90/360+1)-ln(EUSWEA_T/100*30/360+1))-1)*360/60

	gen f36ml=(exp(ln(EUSWEFCMPLCurncy/100*180/360+1)-ln(EUSWEC_L/100*90/360+1))-1)*360/90
	gen f36mt=(exp(ln(EUSWEFCMPTCurncy/100*180/360+1)-ln(EUSWEC_T/100*90/360+1))-1)*360/90

	gen f69ml=(exp(ln(EUSWEICMPLCurncy/100*270/360+1)-ln(EUSWEFCMPLCurncy/100*180/360+1))-1)*360/90
	gen f69mt=(exp(ln(EUSWEICMPTCurncy/100*270/360+1)-ln(EUSWEFCMPTCurncy/100*180/360+1))-1)*360/90

	gen f912ml=(exp(ln(EUSWE1_L/100+1)-ln(EUSWEICMPLCurncy/100*270/360+1))-1)*360/90
	gen f912mt=(exp(ln(EUSWE1_T/100+1)-ln(EUSWEICMPTCurncy/100*270/360+1))-1)*360/90

	gen f16ml=(exp(ln(EUSWEFCMPLCurncy/100*180/360+1)-ln(EUSWEA_L/100*30/360+1))-1)*360/150
	gen f16mt=(exp(ln(EUSWEFCMPTCurncy/100*180/360+1)-ln(EUSWEA_T/100*30/360+1))-1)*360/150
	
	gen d_f13mtl=(f13ml-f13mt)*100
	gen d_f36mtl=(f36ml-f36mt)*100
	gen d_f69mtl=(f69ml-f69mt)*100
	gen d_f912mtl=(f912ml-f912mt)*100
	gen d_f16mtl=(f16ml-f16mt)*100

	*** Construct path factor in adoption of Lunsford
	*keep if year > 2001 & year <2009
	*twoway (scatter d_f16mtl d_ois1mtl if MP_event==1)(lfit d_f16mtl d_ois1mtl if MP_event==1)
	reg  d_f16mtl d_ois1mtl if MP_event==1 & year > 2001 & year <2008
	predict d_path16mtl if MP_event==1 & year > 2001 & year <2008,residual
	
	reg d_ois6mtl d_ois1mtl if MP_event==1 & year > 2001 & year <2008
	predict d_path6mtl if MP_event==1 & year > 2001 & year <2008,residual
	label var d_path6mtl "6m path shock"
	
	reg d_EURIBOR6M_adj d_EURIBOR1M_adj if MP_event==1 & year > 2001 & year <2008
	predict d_path6EUR if MP_event==1 & year > 2001 & year <2008,residual
	
	

	* Construct Expected Change *
	gen  d_MP_rate_exp=d_MP_policy_rate-d_ois1mtl
	
	* add US data
	merge 1:1 date using ../data/US_marketreturn
	drop _merge


	merge 1:1 date using ../data/US_bondyields
	drop _merge

	merge 1:1 date using ../data/US_targetrate
	drop _merge

	merge 1:1 date using ../data/US_loanrate
	drop _merge
	
		
	
	save ../data/MergedCleaned_MarketData.dta,replace
end


*************************************************
** Clean Price Deflator EMU
*************************************************

program clean_price_index
	use ../data/ECB_HPI,clear
	gen year=year(date)
	drop date
	order year
	* Shift year one year forward to reflect the lagged control variables.
	replace year=year+1
	save ../data/ECB_HPI_Clean,replace
end

*************************************************

main

