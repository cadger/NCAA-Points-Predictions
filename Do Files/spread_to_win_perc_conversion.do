#delimit
set more 1;
clear;
set mem 150m;
set matsize 800;
cd "C:\Users\markhoekstra\Google Drive\ncaa-pool\";

use working_win_to_perc;
drop var3 var4;
lpoly winperc_fav spread [fweight = weight_tot_games_sp] if spread<0, degree(2) at(spread) bwidth(3) generate(exp_win_prob);
drop winperc_fav weight;
replace exp_win_prob = 0.5 if spread==0;
replace exp_win_prob = (0.5+0.5148)/2 if spread==-0.5;
replace exp_win_prob = 0.995 if spread<-24.5;
