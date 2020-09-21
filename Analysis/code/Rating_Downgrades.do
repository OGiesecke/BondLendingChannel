cap log close 
clear all 
set scheme sol, permanently
graph set window fontface "Times New Roman"
set linesize 150

* Set directories 
display `"This is the path: `1'""'
global path "`1'"

display "${path}"
*cd "$path"

****************************************
* Preparation Stock Returns
****************************************


foreach var of newlist IQ_SUB_BONDS_NOTES IQ_SR_BONDS_NOTES IQ_TOTAL_ASSETS IQ_TOTAL_DEBT IQ_LT_DEBT{
display "`var'"

import excel ../../Raw_Data/original/RatingDowngrad_CapStructure.xlsx,sheet("`var'") firstrow clear
rename ID_ISIN companyid
drop Capit*
reshape long Y, i(companyid) j(year)
destring Y,replace force
rename Y `var'
tempfile file_`var'
save `file_`var''
}

use `file_IQ_SUB_BONDS_NOTES',clear
foreach newvar of newlist IQ_SR_BONDS_NOTES IQ_TOTAL_ASSETS IQ_TOTAL_DEBT IQ_LT_DEBT{
merge 1:1 companyid year using `file_`newvar'',nogen
}

egen tot_mdebt = rowtotal(IQ_SUB_BONDS_NOTES IQ_SR_BONDS_NOTES)
gen lev = IQ_TOTAL_DEBT / IQ_TOTAL_ASSETS
gen lev_mdebt = tot_mdebt / IQ_TOTAL_ASSETS
winsor2 lev,cuts(1 97) replace
winsor2 lev_mdebt,cuts(1 99) replace
gen year_m=year

save ../data/bs_characteristics,replace


****************************************
* Preparation Stock Returns
****************************************

import excel ../../Raw_Data/original/DS_ratingevents_stock.xlsx,sheet("stockprices") firstrow clear

	* Bring the data into long format
rename * price*
rename pricedate date

foreach var of varlist price*{
tostring `var',replace
replace `var'="" if `var'=="NA"
}

foreach var of varlist price*{
destring `var',replace
}

drop priceUS31865X1063 priceUS2310828015 priceUS4207814033 priceUS52736R1023 priceUS3843135084 priceUS9134311029 priceUS92923C1045 priceGB0008845728 priceUS90331S1096 priceUS8086261059 priceUS87956T1079 priceUS26874Q1004 priceUS4496691001 priceBMG4776G1015 priceUS90338N2027 priceUS7444998808 priceUS29364N2071 priceCH0010782446 priceUS9202551068 priceUS3886901095 priceBE0010621481 priceUS90131G1076 priceUS08520T1007 priceUS03071G1022


reshape long price,i(date) j(isin) string
sort isin date

*save ../data/intstock,replace
*use ../data/intstock,clear

	* Create returns
gen ln_price = log(price)
foreach lead of numlist 1/5{
by isin: gen  l`lead'_return = ( ln_price[_n-1+`lead'] - ln_price[_n-1] ) * 100
}
foreach lag of numlist 1/5{
by isin: gen lag`lag'_return = - ( ln_price[_n-1] - ln_price[_n-1-`lag'] ) * 100
}

rename isin isin1
gen isin2 = isin1

save ../data/intstockreturn,replace

import excel ../../Raw_Data/original/Additional_stock_info_rating_downgrade.xlsx, ///
sheet("stockprices") firstrow clear cellrange(A2)
rename Code date
rename *P *
rename * price*
rename pricedate date

reshape long price,i(date) j(isin) string
sort isin date

	* Create returns
gen ln_price = log(price)
foreach lead of numlist 1/5{
by isin: gen  l`lead'_return = ( ln_price[_n-1+`lead'] - ln_price[_n-1] ) * 100
}
foreach lag of numlist 1/5{
by isin: gen lag`lag'_return = - ( ln_price[_n-1] - ln_price[_n-1-`lag'] ) * 100
}

rename isin isin1
gen isin2 = isin1

append using ../data/intstockreturn

save ../data/finstockreturn,replace



****************************************
* Crosswalk -- Companyid - ISIN
****************************************

import excel ../../Raw_Data/original/DS_ratingevents_stock.xlsx, /// 
sheet("Sheet1") firstrow clear
tempfile cw1
save `cw1'

import excel ../../Raw_Data/original/Additional_stock_info_rating_downgrade.xlsx, ///
sheet("crosswalk") firstrow clear
append using `cw1'

duplicates drop companyid isin,force
duplicates tag isin, gen(dup)
duplicates tag companyid, gen(dupcomp)

drop if dup > 0
drop dup* type nn STOCKTYPE 

bys companyid: gen nn = _n
reshape wide isin,i(companyid) j(nn)

save ../data/rating_DS_crosswalk,replace



****************************************
* Credit Rating Data -- S&P
****************************************

use ../../Int_Data/data/SandPRatings.dta,clear

** Data Cleaning
	* drop if company_id---the merge key---is missing.
drop if company_id==.
rename company_id companyid

	*keep only long-term ratings --- here foreign and local
keep if rtype=="Local Currency LT" | rtype=="Foreign Currency LT" 

	* keep the rating date---date at which the rating was revised.
tostring rdate,replace
gen date=date(rdate,"YMD")
format date %td

* keep unique observations in terms of rating date, rating type rating
duplicates drop companyid date cwatch outlook rtype rating, force

** Variable Definition
	* code credit watch
sort companyid rtype date
bys companyid rtype: gen number=_n
bys companyid rtype: gen cwatch_action=-1 if cwatch[_n]=="NM" & ///
cwatch[_n-1]=="Watch Pos" & rating[_n]==rating[_n-1]
bys companyid rtype: replace cwatch_action=-1 if cwatch[_n]=="Watch Neg" & ///
 cwatch[_n-1]=="NM" & rating[_n]==rating[_n-1]
bys companyid rtype: replace cwatch_action=-1 if cwatch[_n]=="Watch Neg" & ///
cwatch[_n-1]=="Watch Pos" & rating[_n]==rating[_n-1]
bys companyid rtype: replace cwatch_action=+1 if cwatch[_n]=="NM" & ///
cwatch[_n-1]=="Watch Neg" & rating[_n]==rating[_n-1]
bys companyid rtype: replace cwatch_action=+1 if cwatch[_n]=="Watch Pos" & ///
 cwatch[_n-1]=="NM" & rating[_n]==rating[_n-1]
bys companyid rtype: replace cwatch_action=+1 if cwatch[_n]=="Watch Pos" & ///
cwatch[_n-1]=="Watch Neg" & rating[_n]==rating[_n-1]
replace cwatch_action=0 if number==1 | cwatch_action==.

	* code rating upgrade downgrade indicator
bys companyid rtype: gen action=1 if rating[_n]!=rating[_n-1]
replace action=0 if number==1 | action==.
drop number

	* define Numerical Rating 
gen num_rating=.
replace num_rating=1 if rating=="AAA"
replace num_rating=2 if rating=="AA+"
replace num_rating=3 if rating=="AA"
replace num_rating=4 if rating=="AA-"
replace num_rating=5 if rating=="A+"
replace num_rating=6 if rating=="A"
replace num_rating=7 if rating=="A-"
replace num_rating=8 if rating=="BBB+"
replace num_rating=8 if rating=="BBB+/NR"
replace num_rating=9 if rating=="BBB"
replace num_rating=10 if rating=="BBB-"
replace num_rating=11 if rating=="BB+"
replace num_rating=12 if rating=="BB"
replace num_rating=13 if rating=="BB-"
replace num_rating=14 if rating=="B+"
replace num_rating=15 if rating=="B"
replace num_rating=16 if rating=="B-"
replace num_rating=17 if rating=="CCC+"
replace num_rating=18 if rating=="CCC"
replace num_rating=19 if rating=="CCC-"
replace num_rating=20 if rating=="CC"
replace num_rating=21 if rating=="C"
replace num_rating=22 if rating=="D"

replace num_rating=13 if rating=="A-1+"
replace num_rating=14 if rating=="A-1"
replace num_rating=15 if rating=="A-2"
replace num_rating=16 if rating=="A-3"
replace num_rating=17 if rating=="B-1"
replace num_rating=18 if rating=="B-2"
replace num_rating=19 if rating=="B-3"
replace num_rating=20 if rating=="B"
replace num_rating=21 if rating=="C"
replace num_rating=22 if rating=="D"

	* generate rating upgrade downgrade indicator
bys companyid rtype: gen rating_action_steps=num_rating[_n-1]-num_rating[_n] if action==1

	* generate year
gen year = year(date)

keep if regioncd =="USA" | regioncd=="EUROMIDAFR"
drop if year<1990
tab year  regioncd

merge m:1 companyid using ../data/rating_DS_crosswalk
keep if _merge==3
drop _merge

/* 
keep if _merge==1
keep companyid
duplicates drop companyid,force
codebook companyid
export delimited ~/Desktop/companyid_new
*/

merge m:1 date isin1 using ../data/finstockreturn
keep if _merge==3
drop _merge

sort companyid date

save ../data/iassdata,replace

********************************************************************************

use ../data/iassdata,clear

gen year_m = year
merge m:1 companyid year_m using ../data/bs_characteristics,nogen
gen time = _n-10

gen coeff_US = .
label var  coeff_US "US"
replace coeff_US = 0 if time == 0
encode rtype , gen(rating_type)
*global samplesel " & num_rating<12  & year >2000 & year <=2016 & rating_type==2"
global samplesel " & rating_before<11 & num_rating >= 11   & year >1990 & year <=2016 & rating_type==2"

gen rating_before = num_rating + rating_action_steps

* Generate terciles
gen ter_lev_mdebt=1 if lev_mdebt==0
replace ter_lev_mdebt = 2 if lev_mdebt>0
tab ter_lev_mdebt if action==1 & rating_action_steps<0  & ///
	regioncd == "USA" $samplesel

gen hi_mdebt = lev_mdebt>0
	
foreach lead of numlist 1/5{
	reg l`lead'_return   if action==1 & rating_action_steps<0  & ///
	regioncd == "USA" $samplesel
	capture replace coeff_US = _b[_cons] if time == `lead'
}

foreach lag of numlist 1/5{
	reg lag`lag'_return  if action==1 & rating_action_steps<0  & ///
	regioncd == "USA" $samplesel
	capture replace coeff_US = _b[_cons] if time == -`lag' 
}

gen coeff_EU = .
label var  coeff_EU "Eurozone"
replace coeff_EU = 0 if time == 0

foreach lead of numlist 1/5{
	reg l`lead'_return  if action==1 & rating_action_steps<0 & ///
	regioncd == "EUROMIDAFR" $samplesel
	capture replace coeff_EU = _b[_cons] if time == `lead'
}

foreach lag of numlist 1/5{
	reg lag`lag'_return  if action==1 & rating_action_steps<0  & ///
	regioncd == "EUROMIDAFR" $samplesel
	capture replace coeff_EU = _b[_cons] if time == -`lag' 
}



twoway (scatter coeff_US time if time >= -5 & time <=5,c(l) mcolor(red) lp(solid)) ///
(scatter coeff_EU time if time >= -5 & time <=5,c(l) mcolor(blue) lp(solid)), ///
name(Level,replace) xtitle("Event time (in days)") ytitle("Stock return (in %)") ///
xline(0,lc(gs11)) xlabel(-5(1)5)
graph export ../../Analysis/output/Fig_ratingdowngrade.pdf,replace


	***
gen coeff_diff = .
replace coeff_diff = 0 if time == 0
gen se_diff = .
gen ciub_diff = .
gen cilb_diff = .

tab(regioncd),gen(region)
gen consta=1
gen intera = region1 * consta

	
foreach lead of numlist 1/5{
	reg l`lead'_return intera if action==1 & rating_action_steps<0   $samplesel
	capture replace coeff_diff = _b[intera] if time == `lead'
	capture replace se_diff = _se[intera] if time == `lead'
	capture replace ciub_diff = coeff_diff + 1.65 * se_diff if time == `lead'
	capture replace cilb_diff = coeff_diff - 1.65 * se_diff if time == `lead'
}

foreach lag of numlist 1/5{
	reg lag`lag'_return intera if action==1 & rating_action_steps<0   $samplesel
	capture replace coeff_diff = _b[intera] if time == -`lag' 
	capture replace se_diff = _se[intera] if time == -`lag' 
	capture replace ciub_diff = coeff_diff + 1.65 * se_diff if time == -`lag' 
	capture replace cilb_diff = coeff_diff - 1.65 * se_diff if time == -`lag' 
}

twoway (rcap ciub_diff cilb_diff time if time >= -5 & time <=5) ///
(scatter coeff_diff time if time >= -5 & time <=5, c(l) mcolor(blue)), ///
ytitle("{&delta}{sub:t} (in %)") legend(off) name(Diff,replace) ///
xtitle("Event time (in days)") yline(0,lc(gs11) ) xlabel(-5(1)5) 
graph export ../../Analysis/output/Fig_ratingdowngradediffindiff.pdf,replace
