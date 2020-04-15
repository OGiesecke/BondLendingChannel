cap log close 
clear all 
set more off , permanently

* Set directories 
display `"this is the path: `1'""'
global path "`1'"

display "${path}"
cd "$path"


program main
	get_worldscope
	get_yearly_sic
	*create_ratings
	*create_q_ratings
	get_shares_outstanding
	get_worldscope_q
	fed_shock
	define_shock
	*create_rating_panel
end

*************************************************
* Creates Balance Sheet Var. from Datastream

program get_worldscope
	* Get country information 
	use ../../Raw_data/original/Worldscope_bs_items_0125.dta,clear
	rename year_ year
	label var year "year"
	drop code freq

	rename item1001 sales
	label var sales "Sales / Revenue"
	rename item1251 intexp
	label var intexp "Interest on Debt"
	rename item2001 cash
	label var cash "Cash"
	rename item2501 ppenet
	label var ppenet "Property Plant and Equipment"
	rename item2999 assets
	label var assets "Total Assets"
	rename item3051 sandcdebt
	label var  sandcdebt "Short and current portion of long term debt"
	rename item3251 ldebt
	label var ldebt "Long Term Debt"
	rename item3351 tot_liabilities
	label var  tot_liabilities  "Total liabilities"
	rename item3501 cequity
	label var cequity "Common Equity"
	rename item4601 capex
	label var capex "Capital expenditures"
	rename  item6008 isin
	rename item18191 ebit
	label var ebit "EBIT"
	rename item18198 ebitda
	label var ebitda "EBITDA"
	rename item3255 tdebt
	label var tdebt "Total Debt"
	rename item8301 roe
	label var roe "Return on Equity"
	rename  item6001 name 
	rename item1051 cogs
	label var cogs "Cost of goods sold"
	rename item1151 depreciation
	label var depreciation "Depreciation and Amortization"
	rename item2003 cashandsec
	label var  cashandsec "Cash and marketable securities"
	rename  item3101 currliab
	label var currliab "Current libabilities"
	rename item4900 chwc
	label var chwc "Change in working capital"
	rename item2301 ppeqgross
	label var ppeqgross "Property pland and equipment gross"
	rename item18232 currltdebt
	label var  currltdebt "Current portion of long term debt"
	rename item6027 country
	label var country "Country of domicile"
	drop if isin ==""
	rename item8326 roa
	label var roa "Return on assets"
	rename item7021 sic
	label var sic "Primary SIC Code"
	drop item7022 item7023 item7024 item7025 item7026 item7027 item7028
	drop country
	*rename item6026 country
	*label var country "Country of domicile"

	drop if assets==.
	order isin year
	sort isin year
	duplicates drop *,force // duplicates with repect to all variables 
	duplicates tag year isin,gen(new)
	tab new
	// no satisfactory way to sort out this duplicates -> drop all
	drop if new==1
	drop new
	gen yr_adj=year
	
	sort isin year 
	

	*
	gen ln_sales = log(sales)
	
	by isin: gen g3_sales = (sales / sales[_n-3])^(1/3)-1
	by isin: gen time = _n
	foreach num of numlist 1/10{
		by isin: replace 	g3_sales = g3_sales[_n+1] if g3_sales==.
	}
	foreach num of numlist 1/10{
		by isin: replace 	g3_sales = g3_sales[_n-1] if g3_sales==.
	}
	*
	save ../data/worldscope_bs,replace
end

program get_worldscope_q
	* Get additional BS items
	use ../../Raw_data/original/ws_bs_q.dta,clear

	gen date = yq(year_,seq)
	format date %tq
	
	rename item1001 sales
	label var sales "Sales / Revenue"
	rename item1251 intexp
	label var intexp "Interest on Debt"
	rename item2001 cash
	label var cash "Cash"
	rename item2501 ppnet
	label var ppnet "Property Plant and Equipment"
	rename item2999 assets
	label var assets "Total Assets"
	rename item3051 sandcdebt
	label var  sandcdebt "Short and current portion of long term debt"
	rename item3251 ldebt
	label var ldebt "Long Term Debt"
	rename item3351 tot_liabilities
	label var  tot_liabilities  "Total liabilities"
	rename item3501 cequity
	label var cequity "Common Equity"
	rename item4601 capex
	label var capex "Capital expenditures"
	rename  item6008 isin
	rename item18191 ebit
	label var ebit "EBIT"
	rename item18198 ebitda
	label var ebitda "EBITDA"
	rename item3255 tdebt
	label var tdebt "Total Debt"
	rename item8301 roe
	label var roe "Return on Equity"
	rename item4825 ch_receivables
	rename item4826 ch_inventories
	rename item4827 ch_payables
	rename item8326 roa
	label var roa "Return on Assets"
	rename  item6001 name 
	drop code year_ freq seq
	order isin date
	sort isin date
	drop if isin ==""

	gen date_q=date
	format date_q %tq
	save ../data/ws_bs_quarterly,replace
end

program get_yearly_sic
	** Get the sic code manually 
	use ../data/worldscope_bs,replace
	keep sic isin
	drop if sic==.

	
	duplicates drop isin,force
	save ../data/sic_classification,replace
end
	
********************************************************************************

program get_shares_outstanding
	* Get country information 
	use ../data/shares_outstanding_Default.dta,clear
	destring year,replace
	rename *NOSH *
	rename * sh_out*
	rename sh_outyear year
	drop sh_outKG
	reshape long sh_out,i(year) j(isin) string
	sort isin year
	save ../data/shares_outstanding_clean,replace
	
	use ../data/shares_outstanding_US.dta,clear
	rename *NOSH *
	rename * sh_out*
	rename sh_outyear year
	reshape long sh_out,i(year) j(isin) string
	sort isin year
	save ../data/shares_outstanding_US_clean,replace
	
end

*************************************************
** Move FED shocks
*************************************************

program fed_shock
	use ../data/Fed_shocks.dta,clear
	drop MP_event d_fed_future scalef
	rename d_fed_future_scaled  d_ois1mtl
	replace   d_ois1mtl=  d_ois1mtl*100
	save ../data/Fed_shocks_Clean.dta,replace
end

*************************************************
** Clean the Emi and Jon MP shocks
*************************************************

program define_shock
	use ../data/US_FED_emi_jon_data.dta,clear
	rename date_daily date
	drop day month year 
	rename FFR_shock d_ois1mtl
	// Transform into basispoints
	replace d_ois1mtl=d_ois1mtl*100
	rename d_ois1mtl d_shock_je
	save ../data/US_FED_emi_jon_data_Clean.dta,replace
end





main
