/*#delimit*/
set more 1
clear
set mem 150m
set matsize 800
cd "C:\Users\markl\My Drive\Pool Stuff"

import excel using "Pomeroy data", firstrow



split WL, parse(-)
destring WL1 WL2, replace
gen games_pom = WL1+WL2
drop Rank WL WL1 WL2 junk0 junk1 junk2 junk3 junk4 Luck SOSPyth junk5 junk6 junk7 junk8 NCSOSPyth

quietly forval j = 0/9 {
     replace Team = subinstr(Team, "`j'", "", .)
}

replace Team = subinstr(Team, " St.", " State", 1) if Team~="Mount St. Mary's"
replace Team = subinstr(Team, ";", "", 1)

drop OppO
rename AdjO adjoffeff
rename AdjD adjdefeff
rename AdjT paceofplay
rename Team team
rename Year year
sort team year
replace team=trim(team)

sort year team


/*now i change team names so they merge right*/
replace team="Charleston" if team== "College of Charleston"
replace team="CS Fullerton" if team=="Cal State Fullerton" & year<2022
replace team="CSU Bakersfield" if team=="Cal State Bakersfield"
replace team="Gardner-Webb" if team=="Gardner Webb"
replace team="Louisiana-Lafayette" if team=="Louisiana Lafayette"
replace team="NC State" if team=="North Carolina State" & year~=2015
replace team="Stephen F Austin" if team=="Stephen F. Austin" & year>2017
replace team="Stephen F Austin" if team=="Stephen F. Austin" & year==2014
replace team="Virginia Commonwealth" if team=="VCU" & year>2014 & year<2017
replace team="UNC" if team=="North Carolina" & year==2018
replace team="Mount St. Mary's" if team=="Mount State Mary's" & year==2017
replace team="Texas A&M CC" if team=="Texas A&M Corpus Chris" & year==2022
replace team="CSU Fullerton" if team=="Cal State Fullerton" & year==2022
replace team="Miami" if team=="Miami FL" & year==2022
replace team="Uconn" if team=="Connecticut" & year==2022


gen one=1
egen conf_size = count(one), by (year Conf)
egen conf_paceofplay2 = sum(paceofplay), by (year Conf)
egen conf_adjoffeff2 = sum(adjoffeff), by (year Conf)
egen conf_adjdefeff2 = sum(adjdefeff), by (year Conf)
gen conf_paceofplay = (conf_paceofplay2 - paceofplay)/(conf_size-1)
gen conf_adjoffeff = (conf_adjoffeff2 - adjoffeff)/(conf_size-1)
gen conf_adjdefeff = (conf_adjdefeff2 - adjdefeff)/(conf_size-1)

/*I create the above so I can try to make an adjustment for how the defensive quality of your opponents, and how fast they play*/

drop one conf_paceofplay2 conf_adjoffeff2 conf_adjdefeff2


sort year team paceofplay adjdefeff
save kenpom, replace


