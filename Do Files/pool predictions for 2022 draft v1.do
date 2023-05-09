#delimit
set more 1;
clear;
set mem 150m;
set matsize 800;
cd "/Users/chandonadger/Desktop/NCAA Project";

/*Notes for doing predictions next year:

1.  Update the All NCAA Data through [YEAR] file.  (Change to current year obviously)

2.  copy and paste kenpom data into its own spreadsheet - don't put it directly in.

3.  Run the Kenpom prep do file.  

4.  Make sure you change the name of the file I pull in on the first line below to the current year.  

5.  The way I deal with play-in teams is as follows: I first generate the simple predicted points for each
 of the play-in teams, which is # games times points per game.  Then I go through and basically take a weighted average of each
 play-in matchup's stats, like the advanced analytics stats, and I sum the probabilities.  I even change the name so it is clear that
 the opponent is "Team x - Team y".  I use that to construct my matchup data.  
 
6.  for play-in-team players, I take a weighted average of their scoring so that both players are right next to each other.  I created another 
column to show how much those guys actually score, but ranked them based on the weighted average so we would know when to pick them.  

4.  Somewhere in the code I made sure I didn't drop 2021 guys for prediction purposes.  You want to change that for the future.
*/




/*search for &&&&& and make sure that code runs once you start predicting*/

/*things to try:
1. Get game level data and do machine learning
2.  Get game level data and estimate points per game at end of season.  
3.  maybe code players who were injured and out for season.  Try to increase predictions for other guys in those cases
4.  Drop guys if they had a known injury risk - don't use them for predictions - I worry they might drive the minutes and games adjustment*/


import excel using "All NCAA Data through 2022", firstrow;


drop if year==2021;
/*keep if year>=2014;
&&&&&&&&&&&&&&&&&&fix this&&&&&&&*/
/*replace paceofplay=. if year<2021;
replace adjdefeff=. if year<2021;
replace adjoffeff=. if year<2021;
replace adjpaceofplay=. if year<2021;*/
replace team = "Arkansas Little Rock" if team=="Little Rock";
replace team = "Miami FL" if team=="Miami" & year>2015 & year<2019;
replace team = "Loyola Chicago" if team=="Loyola" & year==2018;
replace team = "North Carolina State" if team=="North Carolina St.";
replace team = "Mississippi" if team=="Ole Miss";




/*right here I am going to predict scoring for play-in players - then I intend to average all the playin team characteristics so everything 
else is computed correctly*/

gen p2=.;
gen p3=.;
gen p4=.;
gen p5=.;
gen p6=.;

replace p2 = rd2_win/(rd1_win) if rd1_win<1 & rd1_win>0;
replace p3 = rd3_win/(rd1_win) if rd1_win<1 & rd1_win>0;
replace p4 = rd4_win/rd1_win if rd1_win<1 & rd1_win>0;
replace p5 = rd5_win/rd1_win if rd1_win<1 & rd1_win>0;
replace p6 = rd6_win/rd1_win if rd1_win<1 & rd1_win>0;

replace odds_region2 = odds_region2*2 if rd1_win<1 & rd1_win>0;
replace odds2 = odds2*2 if rd1_win<1 & rd1_win>0;

gen playinpredictedpoints538=.;
replace playinpredictedpoints538=-1.971657+ 1.003332*points*(1+p2+p3+p4+p5+p6) if rd1_win<1 & year>2020;

/*the above equation comes from the pure model*/

/*not sure what this was for
gen prd2_win=rd2_win;
gen prd3_win=rd3_win;
gen prd4_win=rd4_win;
gen prd5_win=rd5_win;
gen prd6_win=rd6_win;*/




egen teamgames_espn=max(games), by (team year);
gen seasonpts= points*games;
egen teamseasonpts= sum(seasonpts), by(team year);
gen teamppg_espn=teamseasonpts/teamgames_espn;
gen f3=points/teamppg_espn;


drop paceofplay - adjdefeff;
sort team year;
merge m:1 team year using kenpom; 
drop if _merge==2;
tab _merge;
assert _merge==3  if year>=2014;
/*&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&need to fix the above before predicting!&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
This is basically just making sure kenpom got merged in correctly.  If it isn't, go to the pomeroy_prep 
file and change the names there for that year such that they match what is in the "master only" here*/
sort year team;





/*below is how to find problems if assert doesn't work*/
/*sort year team;
drop if year==year[_n-1] & team==team[_n-1];
drop if _merge==3;
sort team year;
stop;*/


gen teamppg_pom=teamseasonpts/games_pom;
gen f4=points/teamppg_pom;

sum teamgames_espn games_pom;
sum f3 f4;
corr f3 f4;

gen conflict_games_played = .;
egen tag_shit=tag(year team);
replace conflict=1*tag_shit if teamgames_espn>games_pom;
replace conflict=2*tag_shit if teamgames_espn<games_pom;
list team year if conflict==1;
list team year if conflict==2;
sort team year;
drop teamgames_espn games_pom seasonpts teamseasonpts teamppg_espn tag_shit conflict;



replace round2pts = subinstr(round2pts, "x", "", .);
destring round2pts, replace;



replace threep=threep*100 if year<2019;
replace fg=fg*100 if year<2019;
replace ft=ft*100 if year<2019;



keep year team seed matchup player games min points totpoints pointspread over_under odds1 odds2 averagegm playinteam odds_region1 odds_region2 injuryreport playinpredictedpoints538
paceofplay adjoffeff adjdefef OppD conf_adjoffeff conf_paceofplay conf_adjdefeff rd1_win - rd7_win f3 f4 round1pts round2pts poy;



/*below is from when I tried to adjust point average, but it didn't work*/
gen unadjpoints=points;
egen bestdefense=mean(OppD), by(year);
/*gen adjpointreplace points=points/OppD*bestdefense;*/



/*note - in feb of 2020 I determined adjusted pace of play was better for predictions than pace of play*/
drop if player=="";
drop if year==. & team=="".;

/*Things to do:
1.  code in each team's average opponent def efficiency from course of season.  Use that to scale points per game average by that.
I think what I want to do is the following:
points/avg opponent defense = adjpoints/avg opponent defense you will play in tourney (using probabilities)

OR:
points/avg opponent defense = adjpoints/avg opponent defense overall (or say, for tournament) which is about 98.5 

2.  Another option is rather than do an adjutment factor for likely opponents, wrap that into the main estimate.  So what I would do is simply adjust point average for each game played, based on defense and pace of likely opponent.  Then do weighted average. 
3.  Compare two limited info estimators.  
4.  When 538 comes out with odds, see how they report things for the play in teams.  I may just hand compute these things.  Otherwise it's a real pain in the ass.  
But see if their probabilities add up to one.  If they do - that is if each playin team has the same probability of making the second/real first round, then 
I can just sum them and I think i'll be fine.  BUt somehow I need to sort that shit out.   

5.  I think I want to do first game separate, then do subsequent games in another term.  This would let me use the odds and spread separately.  
*/



gsort year team -matchup;
replace matchup=matchup[_n-1] if year==year[_n-1] & team==team[_n-1] & matchup==.;
gsort year team paceofplay;
replace paceofplay=paceofplay[_n-1] if year==year[_n-1] & team==team[_n-1] & paceofplay==.;
gsort year team adjoffeff;
replace adjoffeff=adjoffeff[_n-1] if year==year[_n-1] & team==team[_n-1] & adjoffeff==.;
gsort year team adjdefeff;
replace adjdefeff=adjdefeff[_n-1] if year==year[_n-1] & team==team[_n-1] & adjdefeff==.;
gsort year team rd1_win;
replace rd1_win=rd1_win[_n-1] if year==year[_n-1] & team==team[_n-1] & rd1_win==.;
gsort year team rd2_win;
replace rd2_win=rd2_win[_n-1] if year==year[_n-1] & team==team[_n-1] & rd2_win==.;
gsort year team rd3_win;
replace rd3_win=rd3_win[_n-1] if year==year[_n-1] & team==team[_n-1] & rd3_win==.;
gsort year team rd4_win;
replace rd4_win=rd4_win[_n-1] if year==year[_n-1] & team==team[_n-1] & rd4_win==.;
gsort year team rd5_win;
replace rd5_win=rd5_win[_n-1] if year==year[_n-1] & team==team[_n-1] & rd5_win==.;
gsort year team rd6_win;
replace rd6_win=rd6_win[_n-1] if year==year[_n-1] & team==team[_n-1] & rd6_win==.;
gsort year team rd7_win;
replace rd7_win=rd7_win[_n-1] if year==year[_n-1] & team==team[_n-1] & rd7_win==.;

sum rd1_win rd2_win rd3_win rd4_win rd5_win rd6_win rd7_win;
/*Note - RD1 is play-in game, so the rest should all be less than one*/

gen flag=.;
replace flag=0 if rd1_win>0 & rd1_win<=1 & rd2_win<1 & rd2_win>0 & rd3_win<1 & rd3_win>0 & rd4_win<1 & rd5_win>0 & rd6_win<1 & rd6_win>=0;
replace flag=. if year<2014;
replace flag=9999999999 if year>=2014 & flag~=0 & flag~=.;

assert rd1_win>0 & rd1_win<=1 & rd2_win<1 & rd2_win>0 & rd3_win<1 & rd3_win>0 & rd4_win<1 & rd5_win>0 & rd6_win<1 & rd6_win>=0 if year>=2014;

/*next, to prepare for main predictions, I fix probabilities for the play-in teams
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
This should only */




/*below i say that if you're a play-in game, i want to scale up your probability of winning each round.  But I should check 538 odds and make sure this is right
that is, that they give too low of probabilities for round 2 because they are not conditioning on winning the playin game*/






/*I think I may want to define this as 1 minus odds others win.  I think this will keep it from getting too screwed up.  Or I need to average them, then undo that later before regressions.  */

/*I don't think I want to hard code it.  but I think it may be simplest if I do that for the purposes of predicting for all the others, then undo it right before
I run regressions.  Plus this way I will know what 538 puts out, exactly.

But I definitely need to do something - otherwise it'll give me really wacky stuff


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!Read above before predicting for 2020 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
*/



/*Now we also need to create a weighted average for team statistics for the cases where there is a play-in game
I am averaging pace of play and adjdefeff because those are the two i use for computing expected defense of opponents.  Also, I don't use them
to predict points for play in teams, so I don't need to change them back.  
*/


/*stop here - mark needs to make sure these are getting averaged correctly. First look at the value for a team and then make sure the average is right */

egen t = tag (year matchup seed team);
gen weightedpaceofplay = rd1_win*t*paceofplay;
gen weightedadjdefeff = rd1_win*t*adjdefeff;
gen weightedadjoffeff=rd1_win*t*adjoffeff;
gen fuck2=rd2_win*t;
gen fuck3=rd3_win*t;
gen fuck4=rd4_win*t;
gen fuck5=rd5_win*t;
gen fuck6=rd6_win*t;

egen temp_paceofplay=sum(weightedpaceofplay), by(year matchup seed);
egen temp_adjdefeff=sum(weightedadjdefeff), by(year matchup seed);
egen temp_adjoffeff=sum(weightedadjoffeff), by(year matchup seed);
egen temp_rd2win=sum(fuck2), by(year matchup seed);
egen temp_rd3win=sum(fuck3), by(year matchup seed);
egen temp_rd4win=sum(fuck4), by(year matchup seed);
egen temp_rd5win=sum(fuck5), by(year matchup seed);
egen temp_rd6win=sum(fuck6), by(year matchup seed);


drop t - fuck6;

replace paceofplay = temp_paceofplay if rd1_win<1 & year>2020;
replace adjdefeff = temp_adjdefeff if rd1_win<1 & year>2020;
replace adjoffeff = temp_adjoffeff if rd1_win<1 & year>2020;
replace rd2_win = temp_rd2win if rd1_win<1 & year>2020;
replace rd3_win = temp_rd3win if rd1_win<1 & year>2020;
replace rd4_win = temp_rd4win if rd1_win<1 & year>2020;
replace rd5_win = temp_rd5win if rd1_win<1 & year>2020;
replace rd6_win = temp_rd6win if rd1_win<1 & year>2020;
drop temp_paceofplay - temp_rd6win;


/*above should all be replacing enough obs such that it is all the guys on all the playin games*/

gen original_team=team;

sort year matchup seed team player;
gen otherplayin1=team;
replace otherplayin1=otherplayin1[_n-1] if year==year[_n-1] & matchup==matchup[_n-1] & seed==seed[_n-1] & team~=team[_n-1] & year>2020;
replace otherplayin1=otherplayin1[_n-1] if year==year[_n-1] & matchup==matchup[_n-1] & seed==seed[_n-1] & team==team[_n-1] & year>2020;

gsort year matchup seed -team player;
gen otherplayin2=team;
replace otherplayin2=otherplayin2[_n-1] if year==year[_n-1] & matchup==matchup[_n-1] & seed==seed[_n-1] & team~=team[_n-1] & year>2020;
replace otherplayin2=otherplayin2[_n-1] if year==year[_n-1] & matchup==matchup[_n-1] & seed==seed[_n-1] & team==team[_n-1] & year>2020;

replace team=otherplayin1+"+" + otherplayin2 if year>2020 & rd1_win<1;






/*end of adjustments for playin games*/
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/







/*below I use spread and over/under to estimate points for the first game*/
/*Below is not a great way of constructing team points, but is based on summing point averages*/

egen team_points_simple=sum(points), by(team year);
replace team_points_simple=. if year<=2011;
gen f1=points/team_points_simple;

/*below is second way to construct the fraction of team points you score - it is based on analytics*/
gen team_points_analyt=paceofplay*adjoffeff/100;
gen f2=points/team_points_analyt;



/*below variable is legit good - it is from odds market, and is how many points your team is expected to score in the first round game*/
gen first_tgame_points=.;
replace first_tgame_points = 0.5*over_under -0.5*pointspread;




/*now I start predictions for individual scoring in first round game
1st one is based on simple method of computing team scoring
2nd one is based on more complex method of computing team scoring*/


gen pred_fgame_points1=f1*first_tgame_points;
gen pred_fgame_points2=f2*first_tgame_points;




sum pred_fgame_points1 pred_fgame_points2;

/*below I am trying to drop the players who will never be drafted, so they don't affect the estimates.  I do it in two ways - one way 
where I drop those who score less than 3% of their team's points, and one where I drop those with less than 4 points.  
I decided to just stick with the 4 points threshold though*/

/*egen sum_averages=sum(points), by(team year);
gen fraction_averages=points/sum_averages;
drop if fraction_averages<0.03;*/
/*drop if points<4 & year~=2020;*/


/*below i merge in the probability of winning the first game*/


merge m:m pointspread using spread_to_exp_win_perc, nogenerate;
replace exp_win_prob=1 if pointspread<-30 & pointspread~=.;
replace exp_win_prob=0 if pointspread>30 & pointspread~=.;




gen points_allowed=paceofplay*adjdefeff/100;
sum points_allowed;
egen tag=tag(year team matchup);
replace tag=. if tag==0;

/*below I try to compute matchup data for 1st round*/

gen exp_p_scored_on_1st_round_opp=.;
sort year matchup seed team;
replace exp_p_scored_on_1st_round_opp=points_allowed[_n-1] if seed~=[_n-1] & year==year[_n-1] & matchup==matchup[_n-1] & team~=team[_n-1];

replace exp_p_scored_on_1st_round_opp=exp_p_scored_on_1st_round_opp[_n-1] if year==year[_n-1] & team==team[_n-1] & seed==seed[_n-1];

gsort year matchup -seed team;


replace exp_p_scored_on_1st_round_opp=points_allowed[_n-1] if seed~=[_n-1] & year==year[_n-1] & matchup==matchup[_n-1] & team~=team[_n-1];

replace exp_p_scored_on_1st_round_opp=exp_p_scored_on_1st_round_opp[_n-1] if year==year[_n-1] & team==team[_n-1] & seed==seed[_n-1];



/*^^^^^^^^^^^^^^^^^^^^^^   NOW I TRY TO COMPUTE MATCHUP DATA FOR 2ND+ ROUNDS^^^^^^^^^^^^^^^^^^^^^^^^^^*/




sort year team points;

gen temp1 = tag*rd2_win*points_allowed;
egen exp_p_allowedR2 = sum(temp1), by(year matchup);
replace exp_p_allowedR2=. if exp_p_allowedR2==0;

gen shit=.;
replace shit=1 if temp1==exp_p_allowedR2 & year>=2014;
list team year if shit==1;

drop if player=="";
count if temp1==exp_p_allowedR2 & year>=2014;
assert r(N)==0;
drop shit;


count if exp_p_allowedR2==0;


gen p2 = tag*rd2_win;
egen check1 = sum(p2), by(year matchup);
by year: sum check1;
list year team check1 if check1~=1&year>=2014;
assert check1>0.991 & check1<1.001 if year>=2014;
drop p2 check1;

/*So right now, exp_p_allowedR2 is how many points the expected winner of the first game is expected to give up when they play the second game*/
gen second_rd_matchup=.;
replace second_rd_matchup=2 if matchup==1;
replace second_rd_matchup=1 if matchup==2;
replace second_rd_matchup=4 if matchup==3;
replace second_rd_matchup=3 if matchup==4;
replace second_rd_matchup=6 if matchup==5;
replace second_rd_matchup=5 if matchup==6;
replace second_rd_matchup=8 if matchup==7;
replace second_rd_matchup=7 if matchup==8;

replace second_rd_matchup=10 if matchup==9;
replace second_rd_matchup=9 if matchup==10;
replace second_rd_matchup=12 if matchup==11;
replace second_rd_matchup=11 if matchup==12;
replace second_rd_matchup=14 if matchup==13;
replace second_rd_matchup=13 if matchup==14;
replace second_rd_matchup=16 if matchup==15;
replace second_rd_matchup=15 if matchup==16;


replace second_rd_matchup=18 if matchup==17;
replace second_rd_matchup=17 if matchup==18;
replace second_rd_matchup=20 if matchup==19;
replace second_rd_matchup=19 if matchup==20;
replace second_rd_matchup=22 if matchup==21;
replace second_rd_matchup=21 if matchup==22;
replace second_rd_matchup=24 if matchup==23;
replace second_rd_matchup=23 if matchup==24;

replace second_rd_matchup=26 if matchup==25;
replace second_rd_matchup=25 if matchup==26;
replace second_rd_matchup=28 if matchup==27;
replace second_rd_matchup=27 if matchup==28;
replace second_rd_matchup=30 if matchup==29;
replace second_rd_matchup=29 if matchup==30;
replace second_rd_matchup=32 if matchup==31;
replace second_rd_matchup=31 if matchup==32;


save maindata_mod1, replace;
keep year matchup second_rd_matchup exp_p_allowedR2;
drop matchup;
rename second_rd_matchup matchup;
sort year matchup exp_p_allowedR2;
drop if year==year[_n-1] & matchup==matchup[_n-1] & exp_p_allowedR2==exp_p_allowedR2[_n-1];
rename exp_p_allowedR2 exp_p_scored_on_2nd_round_opp;
sort year matchup exp_p_scored_on_2nd_round_opp;
save matchup_merge, replace;
clear;
use maindata_mod1;
sort year matchup team;
merge m:1 year matchup using matchup_merge;
sum _merge;
sum _merge;
drop _merge;



/*gen points_allowed=paceofplay*adjdefeff/100;
sum points_allowed;
sort year team points;
egen tag=tag(year team matchup);
replace tag=. if tag==0;*/


/*first i will define groups, out of which a 3rd round team will emerge, where 3rd round counts play-in just like 538*/

gen group2 = .;
replace group2 = 12 if matchup==1 | matchup==2;
replace group2 = 34 if matchup==3 | matchup==4;
replace group2 = 56 if matchup==5 | matchup==6;
replace group2 = 78 if matchup==7 | matchup==8;
replace group2 = 910 if matchup==9 | matchup==10;
replace group2 = 1112 if matchup==11 | matchup==12;
replace group2 = 1314 if matchup==13 | matchup==14;
replace group2 = 1516 if matchup==15 | matchup==16;
replace group2 = 1718 if matchup==17 | matchup==18;
replace group2 = 1920 if matchup==19 | matchup==20;
replace group2 = 2122 if matchup==21 | matchup==22;
replace group2 = 2324 if matchup==23 | matchup==24;
replace group2 = 2526 if matchup==25 | matchup==26;
replace group2 = 2728 if matchup==27 | matchup==28;
replace group2 = 2930 if matchup==29 | matchup==30;
replace group2 = 3132 if matchup==31 | matchup==32;

gen temp2 = tag*rd3_win*points_allowed;

egen exp_p_allowedR3 = sum(temp2), by(year group2);
replace exp_p_allowedR3=. if exp_p_allowedR3==0;

gen third_rd_matchup=.;
replace third_rd_matchup=34 if group2==12;
replace third_rd_matchup=12 if group2==34;
replace third_rd_matchup=78 if group2==56;
replace third_rd_matchup=56 if group2==78;
replace third_rd_matchup=1112 if group2==910;
replace third_rd_matchup=910 if group2==1112;
replace third_rd_matchup=1516 if group2==1314;
replace third_rd_matchup=1314 if group2==1516;
replace third_rd_matchup=1920 if group2==1718;
replace third_rd_matchup=1718 if group2==1920;
replace third_rd_matchup=2324 if group2==2122;
replace third_rd_matchup=2122 if group2==2324;
replace third_rd_matchup=2728 if group2==2526;
replace third_rd_matchup=2526 if group2==2728;
replace third_rd_matchup=3132 if group2==2930;
replace third_rd_matchup=2930 if group2==3132;

save maindata_mod2, replace;
keep year group2 third_rd_matchup exp_p_allowedR3;
drop group2;
rename third_rd_matchup group2;
sort year group2 exp_p_allowedR3;
drop if year==year[_n-1] & group2==group2[_n-1] & exp_p_allowedR3==exp_p_allowedR3[_n-1];
rename exp_p_allowedR3 exp_p_scored_on_3rd_round_opp;
sort year group2 exp_p_scored_on_3rd_round_opp;
save matchup_mergeRd3, replace;
clear;
use maindata_mod2;
sort year group2 team;
merge m:1 year group2 using matchup_mergeRD3;
sum _merge;
drop _merge;



gen p3=tag*rd3_win;
sort year team group2;
egen check3=sum(p3), by(year group2);
by year: sum check3;
assert check3>0.999 & check3<1.001 if year>=2014;





/*___________________next i define groups out of which a 4th round team will emerge, where 4th round counts play-in just like 538*/

gen group3 = .;
replace group3 = 14 if matchup==1 | matchup==2 | matchup==3 | matchup==4;
replace group3 = 58 if matchup==5 | matchup==6 | matchup==7 | matchup==8;
replace group3 = 912 if matchup==9 | matchup==10 | matchup==11 | matchup==12;
replace group3 = 1316 if matchup==13 | matchup==14 | matchup==15 | matchup==16;
replace group3 = 1720 if matchup==17 | matchup==18 | matchup==19 | matchup==20;
replace group3 = 2124 if matchup==21 | matchup==22 | matchup==23 | matchup==24;
replace group3 = 2528 if matchup==25 | matchup==26 | matchup==27 | matchup==28;
replace group3 = 2932 if matchup==29 | matchup==30 | matchup==31 | matchup==32;



gen temp3 = tag*rd4_win*points_allowed;

gen p4=tag*rd4_win;
sort year team group3;
egen check4 = sum(p4), by(year group3);
by year: sum check4;
assert check4>0.999 & check4<1.001 if year>=2014;
list year team if year>2015 & check4<0.98;
drop check4;


gen p2 = tag*rd2_win;
egen check1 = sum(p2), by(year matchup);
by year: sum check1;
assert check1>0.999 & check1<1.001 if year>=2014;
drop p2 check1;





egen exp_p_allowedR4 = sum(temp3), by(year group3);
replace exp_p_allowedR4=. if exp_p_allowedR4==0;
by year: sum exp_p_allowedR4;

gen fourth_rd_matchup=.;
replace fourth_rd_matchup=58 if group3==14;
replace fourth_rd_matchup=14 if group3==58;
replace fourth_rd_matchup=1316 if group3==912;
replace fourth_rd_matchup=912 if group3==1316;
replace fourth_rd_matchup=2124 if group3==1720;
replace fourth_rd_matchup=1720 if group3==2124;
replace fourth_rd_matchup=2932 if group3==2528;
replace fourth_rd_matchup=2528 if group3==2932;


save maindata_mod3, replace;
keep year group3 fourth_rd_matchup exp_p_allowedR4;
drop group3;
rename fourth_rd_matchup group3;
sort year group3 exp_p_allowedR4;
drop if year==year[_n-1] & group3==group3[_n-1] & exp_p_allowedR4==exp_p_allowedR4[_n-1];
rename exp_p_allowedR4 exp_p_scored_on_fourth_round_opp;
drop if group3==.;
sort year group3 exp_p_scored_on_fourth_round_opp;
save matchup_mergeRd4, replace;
clear;
use maindata_mod3;
sort year group3 team;
merge m:1 year group3 using matchup_mergeRD4;
sum _merge;
drop _merge;



sort year team;
by year: sum exp_p_allowedR2 exp_p_allowedR3 exp_p_allowedR4, det;



/*___________________next i define groups out of which a 4th round team will emerge, where 4th round counts play-in just like 538*/

gen group4 = .;
replace group4 = 18 if matchup>=1 & matchup<=8 & matchup~=.;
replace group4 = 916 if matchup>=9 & matchup<=16 & matchup~=.;
replace group4 = 1724 if matchup>=17 & matchup<=24 & matchup~=.;
replace group4 = 2532 if matchup>=25 & matchup<=32 & matchup~=.;




gen temp4 = tag*rd5_win*points_allowed;

gen p5=tag*rd5_win;
sort year team group4;
egen check5 = sum(p5), by(year group4);
by year: sum check5;
assert check5>0.999 & check5<1.001 if year>=2014;
list year team if year>2015 & check5<0.98;
drop check5;





egen exp_p_allowedR5 = sum(temp4), by(year group4);
replace exp_p_allowedR5=. if exp_p_allowedR5==0;
by year: sum exp_p_allowedR5;

gen fifth_rd_matchup=.;
replace fifth_rd_matchup=916 if group4==18;
replace fifth_rd_matchup=18 if group4==916;
replace fifth_rd_matchup=2532 if group4==1724;
replace fifth_rd_matchup=1724 if group4==2532;



save maindata_mod4, replace;
keep year group4 fifth_rd_matchup exp_p_allowedR5;
drop group4;
rename fifth_rd_matchup group4;
sort year group4 exp_p_allowedR5;
drop if year==year[_n-1] & group4==group4[_n-1] & exp_p_allowedR5==exp_p_allowedR5[_n-1];
rename exp_p_allowedR5 exp_p_scored_on_fifth_round_opp;
drop if group4==.;
sort year group4 exp_p_scored_on_fifth_round_opp;
save matchup_mergeRd5, replace;
clear;
use maindata_mod4;
sort year group4 team;
merge m:1 year group4 using matchup_mergeRD5;
sum _merge;
drop _merge;





/*___________________next i define groups out of which a 5th round team will emerge, where 5th round counts play-in just like 538*/

gen group5 = .;
replace group5 = 116 if matchup>=1 & matchup<=16 & matchup~=.;
replace group5 = 1732 if matchup>=17 & matchup<=32 & matchup~=.;





gen temp5 = tag*rd6_win*points_allowed;

gen p6=tag*rd6_win;
sort year team group5;
egen check6 = sum(p6), by(year group5);
by year: sum check6;
assert check6>0.999 & check6<1.001 if year>=2014;
list year team if year>2015 & check6<0.98;
drop check6;





egen exp_p_allowedR6 = sum(temp5), by(year group5);
replace exp_p_allowedR6=. if exp_p_allowedR6==0;
by year: sum exp_p_allowedR6;

gen sixth_rd_matchup=.;
replace sixth_rd_matchup=1732 if group5==116;
replace sixth_rd_matchup=116 if group5==1732;




save maindata_mod5, replace;
keep year group5 sixth_rd_matchup exp_p_allowedR6;
drop group5;
rename sixth_rd_matchup group5;
sort year group5 exp_p_allowedR6;
drop if year==year[_n-1] & group5==group5[_n-1] & exp_p_allowedR6==exp_p_allowedR6[_n-1];
rename exp_p_allowedR6 exp_p_scored_on_sixth_round_opp;
drop if group5==.;
sort year group5 exp_p_scored_on_sixth_round_opp;
save matchup_mergeRd6, replace;
clear;
use maindata_mod5;
sort year group5 team;
merge m:1 year group5 using matchup_mergeRD6;
sum _merge;
drop _merge;






/*Note, odds and odds2 are vegas odds (like 60 to 1) for odds of winning tournament; 
odds_region1 and odds_region2 are similar except for odds of winning region.  
Data availability is different but in general latter I have better data for*/

/*below I generate new variables*/

gen seedsq=seed*seed;
gen oddstourney=odds2/(odds1+odds2);/*I'm actually not sure how to define this, old way was odds2/odds1*/
gen oddsregion=odds_region2/(odds_region1+odds_region2);
drop odds1 odds2 odds_region1 odds_region2;
gen oddsregionsq=oddsregion*oddsregion;
gen pointsXoddsregion=points*oddsregion;
gen pointsXoddsregionsq=points*oddsregion*oddsregion;
gen pointsXseed = points*seed;
gen pointsXoddstourney=points*oddstourney;
gen pointsXoddstourneysq=points*oddstourney*oddstourney;
gen pointsXpointspread=points*pointspread;
gen pointsXover_under=points*over_under;
gen pointsXexp_win_prob = points*exp_win_prob;
gen pointsXexp_win_probXoddsregion=points*exp_win_prob*oddsregion;



gen pointsXrd2_winXexp_p_allowedR2 = points*rd2_win*exp_p_allowedR2;
gen pointsXrd3_winXexp_p_allowedR3 = points*rd3_win*exp_p_allowedR3;
gen pointsXrd4_winXexp_p_allowedR4 = points*rd4_win*exp_p_allowedR4;
gen pointsXrd5_winXexp_p_allowedR5 = points*rd5_win*exp_p_allowedR5;



/*note, I tried interactions with pred_fgame_points, and it didn't help, so I deleted it*/

/*here I input average games played, by seed - the first ones are from 2006, the second is for 2014.  I 
don't have 2015 ones (that is, ones that include 2014 data*/
replace average=1 if seed==16;
replace average=1.07 if seed==15;
replace average=1.18 if seed==14;
replace average=1.24 if seed==13;
replace average=1.53 if seed==12;
replace average=1.58 if seed==11;
replace average=1.61 if seed==10;
replace average=1.58 if seed==9;
replace average=1.73 if seed==8;
replace average=1.90 if seed==7;
replace average=2.11 if seed==6;
replace average=2.09 if seed==5;
replace average=2.58 if seed==4;
replace average=2.79 if seed==3;
replace average=3.33 if seed==2;
replace average=4.19 if seed==1;




drop exp_p_allowedR2 exp_p_allowedR3 exp_p_allowedR4 exp_p_allowedR5 exp_p_allowedR6;




gen pointsXrd2_win = points*rd2_win;
gen pointsXrd3_win = points*rd3_win;
gen pointsXrd4_win = points*rd4_win;
gen pointsXrd5_win = points*rd5_win;
gen pointsXrd6_win = points*rd6_win;

gen scalar1_rd2=rd2_win*exp_p_scored_on_2nd_round_opp;
gen scalar1_rd3=rd3_win*exp_p_scored_on_3rd_round_opp;
gen scalar1_rd4=rd4_win*exp_p_scored_on_fourth_round_opp;
gen scalar1_rd5=rd5_win*exp_p_scored_on_fifth_round_opp;
gen scalar1_rd6=rd6_win*exp_p_scored_on_sixth_round_opp;


/*note, for below I think we really want to go 6 rounds*/
/*here i want to create one variable that sums up how good of defenses/how slow of teams you will play in the tournament*/
egen avg1=mean(exp_p_scored_on_1st_round_opp);
egen avg2=mean(exp_p_scored_on_2nd_round_opp);
egen avg3=mean(exp_p_scored_on_3rd_round_opp);
egen avg4=mean(exp_p_scored_on_fourth_round_opp);
egen avg5=mean(exp_p_scored_on_fifth_round_opp);
egen avg6=mean(exp_p_scored_on_sixth_round_opp);



/* below we do it relative to typical team scoring*/
gen sum_stat_opp_def1 = rd2_win*(exp_p_scored_on_2nd_round_opp-team_points_analyt)/team_points_analyt + rd3_win*(exp_p_scored_on_3rd_round_opp-team_points_analyt)/team_points_analyt + rd4_win*(exp_p_scored_on_fourth_round_opp-team_points_analyt)/team_points_analyt + rd5_win*(exp_p_scored_on_fifth_round_opp-team_points_analyt)/team_points_analyt + rd6_win*(exp_p_scored_on_sixth_round_opp-team_points_analyt)/team_points_analyt;




/*below we do it relative to typical opponent in each round.  It didn't perform great. */ 
gen sum_stat_opp_def2 = rd2_win*(exp_p_scored_on_2nd_round_opp-avg2) + rd3_win*(exp_p_scored_on_3rd_round_opp-avg3) + rd4_win*(exp_p_scored_on_fourth_round_opp-avg4) +
rd5_win*(exp_p_scored_on_fifth_round_opp-avg5) + rd6_win*(exp_p_scored_on_sixth_round_opp-avg6);

gen sum_stat_opp_def3 = rd2_win*exp_p_scored_on_2nd_round_opp + rd3_win*exp_p_scored_on_3rd_round_opp + rd4_win*exp_p_scored_on_fourth_round_opp +
rd5_win*exp_p_scored_on_fifth_round_opp + rd6_win*exp_p_scored_on_sixth_round_opp;



gen pointsXsum_stat_opp_def1 = points*sum_stat_opp_def1;
gen pointsXsum_stat_opp_def2 = points*sum_stat_opp_def2;
gen pointsXsum_stat_opp_def3 = points*sum_stat_opp_def3;


/*&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& MAIN PREDICTION IS BELOW &&&&&&&&&&&&&&&&&&&&&&&&&&&&&*/


/*
/*NOTE - BELOW I AM DOING WEIGHTS USING SIMPLE MEASURE BUT MAY WANT TO CHANGE THAT IF ANALYT DOES BETTER*/



/*here I create a count of observations by year so I can weight*/
gen one_fullinfo=1;
replace one_fullinfo=. if totpoints==. | pred_fgame_points1==. | pointsXoddsregion==. | pointsXexp_win_prob==.;
replace one_fullinfo=. if year<2010;
/*note, above shouldn't change anything*/
egen count_year_full = sum (one_fullinfo), by(year);
egen totalobs_full=sum(one_fullinfo);
gen fullinfoweight=totalobs_full/count_year_full;
sum fullinfoweight;
sum fullinfoweight if year>2011;

regress totpoints pred_fgame_points1 pointsXoddsregion pointsXexp_win_prob [pweight=fullinfoweight] if year>2011 & year~=2020, robust cluster(team) noconstant
;
predict ppoints_bestinfo_w;


regress totpoints pred_fgame_points1
pointsXoddsregion pointsXexp_win_prob 
if year>2011 & year~=2020, robust cluster(team) noconstant
;
predict ppoints_bestinfo_nw;
*/



/*since using 538 in feb 2020, I don't see need for using this
/*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% LIMITED INFORMATION ESTIMATOR BELOW %%%%%%%%%%%%%%%%%%*/
gen one_limitedinfo=1;
replace one_limitedinfo=. if year<2010;
/*note, we don't observe odds of region prior to 2010*/
replace one_limitedinfo=. if totpoints==. | pointsXoddsregion==.;
egen count_year_limited = sum (one_limitedinfo), by(year);
egen totalobs_limited=sum(one_limitedinfo);
gen limitedinfoweight=totalobs_limited/count_year_limited;
sum limitedinfoweight;

regress totpoints points pointsXoddsregion pointsXoddsregionsq[pweight=limitedinfoweight]
if year~=2020, robust cluster(team) noconstant
;
predict ppoints_limitedinfo;

count if ppoints_limitedinfo==. & year==2020;
/*above should be zero!!!*/
*/



/*below I replace probability of winning first real game with 538 probability if we don't observe a spread yet for that game*/

replace exp_win_prob=rd2_win if exp_win_prob==. & rd2_win~=. & year<2020.;











/*******************************************   NEW ESTIMATOR IS BELOW USING ALL MATCHUPS********************/
/*I'm adding the new estimator below*************************************************************************/
/*below is simple 538 prediction*/

gen pnumbergames=1;
replace pnumbergames=rd1_win + rd2_win*1 + rd3_win*1 + rd4_win*1 + rd5_win*1 + rd6_win*1;

gen ppoints_538pure=points*pnumbergames;

gen ppoints_538pureplusspread=points+exp_win_prob*points + rd3_win*points + rd4_win*points + rd5_win*points + rd6_win*points;

gen ppoints_538plusoddssimple = pred_fgame_points1 + rd2_win*points + rd3_win*points + rd4_win*points + rd5_win*points + rd6_win*points;

gen ppoints_538plusoddsanalyt = pred_fgame_points2 + rd2_win*points + rd3_win*points + rd4_win*points + rd5_win*points + rd6_win*points;


gen ppoints_exceptrd1_simple = (pnumbergame-1)*points;


regress totpoints ppoints_538pure;
regress totpoints ppoints_exceptrd1;
sum rd1_win - rd7_win;

/*&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&need to fix this as well
assert pred_fgame_points1~=. & pred_fgame_points2~=.;
drop if pred_fgame_points1==. | pred_fgame_points2==.;
*/


/*first we compare 538pure to pure plus spread, or 538 plus odds simple, plus odds analyt, with and without adjustment term*/






/*drop if ppoints_538pure<10;*/

/*below I try to figure out how advanced metrics are used to compute the total points scored by a team in a game*/
gen predictedownteamscoring = paceofplay*adjoffeff/100;
sum first_tgame_points;
/*keep year team player first_tgame_points exp_p_scored_on_1st_round_opp predictedownteamscoring;*/
egen scoringtag=tag(year team);

regress first_tgame_points exp_p_scored_on_1st_round_opp predictedownteamscoring;
regress first_tgame_points exp_p_scored_on_1st_round_opp predictedownteamscoring if tag==1;
/*Formula is as follows
predicted own team scoring = -58.2922 + 0.9960995*expectedpointsgivenupbyopponent + 0.8438891*predictedownteamscoring
R squared is 91.68%, which is really high*/
drop scoringtag;



/*My different fractions are as follows:
f1 fraction_team_points_simple is ppg/team points, where latter is summed from individual player scoring averages
f2 fraction_team_points_analyt=points/team_points_analyt, where latter is determined from advanced analytics
f3 points/team_ppg, as determined first computing total team games using the max of games played by a given player on that team
f4 points/team_ppg, as determined first computing it with KenPom record

Note that the latter two are using actual team scoring per game in denominator.  Problem is I don't KNOW total number of games, so I need to infer it in some way

*/


/*code below is confusing.  IN name, I say rd2 is the round of 64 game.  but in exp_p_scored i call that round 1*/
gen pteampointsrd_2 =  0.5*over_under -0.5*pointspread;
gen pteampointsrd_3 = -58.2922 + 0.9960995*exp_p_scored_on_2nd_round_opp + 0.8438891*predictedownteamscoring;
gen pteampointsrd_4 = -58.2922 + 0.9960995*exp_p_scored_on_3rd_round_opp + 0.8438891*predictedownteamscoring;
gen pteampointsrd_5 = -58.2922 + 0.9960995*exp_p_scored_on_fourth_round_opp + 0.8438891*predictedownteamscoring;
gen pteampointsrd_6 = -58.2922 + 0.9960995*exp_p_scored_on_fifth_round_opp + 0.8438891*predictedownteamscoring;
gen pteampointsrd_7 = -58.2922 + 0.9960995*exp_p_scored_on_sixth_round_opp + 0.8438891*predictedownteamscoring;

gen ppoints_elite1=rd1_win*f1*pteampointsrd_2 + rd2_win*f1*pteampointsrd_3 + rd3_win*f1*pteampointsrd_4 + rd4_win*f1*pteampointsrd_5 + rd5_win*f1*pteampointsrd_6 + rd6_win*f1*pteampointsrd_7;

gen ppoints_elite2=rd1_win*f2*pteampointsrd_2 + rd2_win*f2*pteampointsrd_3 + rd3_win*f2*pteampointsrd_4 + rd4_win*f2*pteampointsrd_5 + rd5_win*f2*pteampointsrd_6 + rd6_win*f2*pteampointsrd_7;
 
gen ppoints_elite3=rd1_win*f3*pteampointsrd_2 + rd2_win*f3*pteampointsrd_3 + rd3_win*f3*pteampointsrd_4 + rd4_win*f3*pteampointsrd_5 + rd5_win*f3*pteampointsrd_6 + rd6_win*f3*pteampointsrd_7;

gen ppoints_elite4=rd1_win*f4*pteampointsrd_2 + rd2_win*f4*pteampointsrd_3 + rd3_win*f4*pteampointsrd_4 + rd4_win*f4*pteampointsrd_5 + rd5_win*f4*pteampointsrd_6 + rd6_win*f4*pteampointsrd_7; 
 
gen ppoints_exceptrd1_elite1 =  ppoints_elite1-(rd1_win*f1*pteampointsrd_2);
gen ppoints_exceptrd1_elite2 =  ppoints_elite2-(rd1_win*f2*pteampointsrd_2);
gen ppoints_exceptrd1_elite3 =  ppoints_elite3-(rd1_win*f3*pteampointsrd_2);

 
gen pred_fgame_points3 = rd1_win*f3*pteampointsrd_2;
gen pred_fgame_points4 = rd1_win*f4*pteampointsrd_2;

/*Things we need to do
1.  maybe test all models with min and games, show they do better

Note: I verified graphically that min and games should enter as is, and not as an interaction with points ?*/



gen dropthis=.;
replace dropthis=1 if ppoints_538pure<10 |points<2;
replace dropthis=. if year>2020;

drop if dropthis==1;



/*next is the best old school model.  oddsregion is better than odds tourney and 2nd points measure better than first*/
regress totpoints pred_fgame_points2 pointsXoddsregion pointsXexp_win_prob min games if year~=2020;
predict predict89;
gen resid89=sqrt((totpoints-predict89)^2);

/*This is simple model - it does well, about as well as old model - slightly better*/



regress totpoints ppoints_538pure min games if year~=2020;
predict predict1;
gen resid1=sqrt((totpoints-predict1)^2);


/*This is simpler, but works very well*/


/*gen newvar1=points*OppD;
gen newvar2=ppoints_elite2*games;*/
regress totpoints ppoints_elite2 min games if year~=2020;
predict predict9;
gen resid9=sqrt((totpoints-predict9)^2);
predict rachel, resid;
/*binscatter rachel newvar1, noaddmean nquantiles(100);
stop;
binscatter totpoints pointsXOppD, controls(ppoints_elite2 min games) noaddmean nquantiles(100)*/



/*this model is also quite good, it's my alternative model - more complicated and performs similar.  See sheet 6 in spreadsheet*/
regress totpoints ppoints_exceptrd1_elite2 pred_fgame_points2 sum_stat_opp_def2 min games if year~=2020;
predict predict6;
gen resid6=sqrt((totpoints-predict6)^2);



/*
Also notes:
-for round 2, simple points did best, but then f1 and f2 were close
-kenpom way of doing fraction was worst
*/  


















/*below is to determine what the fairest draft order is*/
/*

regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2006;
predict shit6 if year==2006;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2007;
predict shit7 if year==2007;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2008;
predict shit8 if year==2008;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2009;
predict shit9 if year==2008;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2010;
predict shit10 if year==2010;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2011;
predict shit11 if year==2011;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2012;
predict shit12 if year==2012;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2013;
predict shit13 if year==2013;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2014;
predict shit14 if year==2014;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2015;
predict shit15 if year==2015;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2016;
predict shit16 if year==2016;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2017;
predict shit17 if year==2017;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2018;
predict shit18 if year==2018;
regress totpoints points pointsXoddsregion pointsXexp_win_prob min games if year~=2019;
predict shit19 if year==2019;


gen ppoints_oldbest=.;
replace ppoints_oldbest=shit6 if year==2006;
replace ppoints_oldbest=shit7 if year==2007;
replace ppoints_oldbest=shit8 if year==2008;
replace ppoints_oldbest=shit9 if year==2009;
replace ppoints_oldbest=shit10 if year==2010;
replace ppoints_oldbest=shit11 if year==2011;
replace ppoints_oldbest=shit12 if year==2012;
replace ppoints_oldbest=shit13 if year==2013;
replace ppoints_oldbest=shit14 if year==2014;
replace ppoints_oldbest=shit15 if year==2015;
replace ppoints_oldbest=shit16 if year==2016;
replace ppoints_oldbest=shit17 if year==2017;
replace ppoints_oldbest=shit18 if year==2018;
replace ppoints_oldbest=shit19 if year==2019;


regress totpoints ppoints_elite2 min games if year~=2014;
predict crap14 if year==2014;
regress totpoints ppoints_elite2 min games if year~=2015;
predict crap15 if year==2015;
regress totpoints ppoints_elite2 min games if year~=2016;
predict crap16 if year==2016;
regress totpoints ppoints_elite2 min games if year~=2017;
predict crap17 if year==2017;
regress totpoints ppoints_elite2 min games if year~=2018;
predict crap18 if year==2018;
regress totpoints ppoints_elite2 min games if year~=2019;
predict crap19 if year==2019;

gen predictedpoints_538best = crap14;
replace predictedpoints_538best = crap15 if year==2015;
replace predictedpoints_538best = crap16 if year==2016;
replace predictedpoints_538best = crap17 if year==2017;
replace predictedpoints_538best = crap18 if year==2018;
replace predictedpoints_538best = crap19 if year==2019;

gen naive_prediction=average*points;

egen temp_rank1=rank(naive_prediction), field by(year);
egen temp_rank2=rank(ppoints_oldbest), field by(year);
egen temp_rank3=rank(predictedpoints_538best), field by(year);
gen error1 = totpoints-naive_prediction;
gen error2 = totpoints-ppoints_oldbest;
gen error3 = totpoints-predictedpoints_538best;

sum error1 if temp_rank1==1;
sum error1 if temp_rank1>=1 & temp_rank1<4;

sum error2 if temp_rank2==1;
sum error2 if temp_rank2>=1 & temp_rank2<4;

sum error3 if temp_rank3==1;
sum error3 if temp_rank3>=1 & temp_rank3<4;

binscatter error1 temp_rank1 if temp_rank1<30;
gen method2 = ppoints_oldbest;
gen method3 = predictedpoints_538best;
gen simon = naive_prediction;
binscatter totpoints method3 if method2>0, nquantiles(60);
/*the four lines of code above basically show that my predictions are on average correct - it's not like I'm overpredicting for the highest-ranked guys.  In other words, the way I am doing optimal draft order is correct*/

keep team player year totpoints ppoints_oldbest naive_prediction predictedpoints_538best;
replace ppoints_oldbest=naive_prediction if year>=2011 & ppoints_oldbest==.;
replace ppoints_oldbest=. if year<2011;
drop if totpoints==.;
sort year;
by year: sum totpoints naive_prediction ppoints_oldbest predictedpoints_538best ;

stop;
*/

regress totpoints ppoints_elite2 min games;
predict predictedpoints_538best;

/*for below, i predict first game points based on share of team points scored using analytics measure and based on total number of team points
scored in first game based on spread and over/under.  */
regress totpoints ppoints_exceptrd1_elite2 pred_fgame_points2 sum_stat_opp_def2 min games;
predict predictedpoints_538alt;

gen less_confident = .;
replace less_confident=1 if predictedpoints_538best==.;

regress totpoints ppoints_538pure;
predict predictedpoints_538pure;

regress totpoints pred_fgame_points2 pointsXoddsregion pointsXexp_win_prob min games;
predict predictedpoints_oldoddsmodel;


/*now I try to make it where I assign 1st ranked scorers on playin teams that play each other the same predicted points, and the 2nd-ranked guys the same
and so on*/


replace points=0 if year==2022 & injuryreport=="out for season";
replace points=0 if injuryreport=="out indefinitely - surgery on broken foot, expected out through at least 3/23" & year==2021;


egen rank_on_team=rank(points), field by(year original_team);
gen partialpredictedpoints=predictedpoints_538pure*rd1_win;
egen altpoints=sum(partialpredictedpoints), by(year matchup rank_on_team);/*altpoints is supposed to give the top ranked scorer the same number of predicted points for each of two playin teams*/
sum altpoints partialpredictedpoints points if rd1_win<1 & rd1_win>0;
/*make sure above is sensible.  partial points will be low but altpoints should be higher.  */

/*above should only be replacing for last year of sample, and should only be for around 80 guys at most*/
sum predictedpoints_538pure altpoints if rd1_win<1 & rd1_win>0;
replace predictedpoints_538pure= altpoints if rd1_win<1 & rd1_win>0;

replace predictedpoints_538pure=playinpredictedpoints538 if rd1_win<1;
replace predictedpoints_538best=predictedpoints_538pure if predictedpoints_538best==.;



egen rank=rank(predictedpoints_538best), field by(year);
egen rank538=rank(predictedpoints_538pure), field by(year);
sum rank;
gen naive_prediction=average*points;
egen naive_rank=rank(naive_prediction),  field by(year);
gen dif_in_rank538 = rank - rank538;
gen dif_in_rankSimon = rank - naive_rank;



gsort year -predictedpoints_538best;
format predictedpoints_538best predictedpoints_538alt predictedpoints_538pure pointspread points min %9.1f;
format oddstourney oddsregion exp_win_prob rd2_win %9.3f;
format pnumbergames %9.2f;
format naive_prediction %9.1f;
format pnumbergames %9.1f;

replace team=original_team if year>2020;

/*below I generate a weighted average of points for the playin teams so that we know which two guys are picked together*/
egen weightedppoints=mean(predictedpoints_538best), by(year matchup seed rank_on_team);
gen actualppoints=predictedpoints_538best;
replace actualppoints=. if rd1_win==1;
replace predictedpoints_538best = weightedppoints if rd1_win<1;

format actualppoints predictedpoints_oldoddsmodel %9.1f;


/*Below I drop guys from 2021 if they were injured and basically can't play*/
gen out=0;
replace out=1 if injuryreport=="out for season" & year==2021;
replace out=1 if injuryreport=="out for season - torn mcl" & year==2021;
replace out=1 if injuryreport=="left the team" & year==2021;
replace out=1 if injuryreport=="out indefinitely - surgery on broken foot, expected out through at least 3/23" & year==2021;
replace out=1 if injuryreport=="off team" & year==2021;
replace out=1 if injuryreport=="out for season - ankle" & year==2021;




replace predictedpoints_538best=0 if out==1;



keep year team actualppoints playinteam seed less_confident exp_win_prob injury  adjoffeff-conf_adjdefeff bestdefense points_allowed sum_stat_opp_def* oddsregion oddstourney rd1_win rd2_win rd3_win rd4_win rd5_win rd6_win rd7_win rank_on_team player totpoints predictedpoints_538best predictedpoints_538alt predictedpoints_538pure predictedpoints_oldoddsmodel dif_in_rankSimon dif_in_rank538 rank naive_rank rank538 points games min pnumbergames poy_mvp ;
order year team player rank naive_rank rank538 rank_on_team playinteam seed oddsregion oddstourney totpoints pnumbergames points games min rd1_win rd2_win rd3_win rd4_win rd5_win rd6_win rd7_win exp_win_prob adjoffeff-conf_adjdefeff bestdefense points_allowed sum_stat_opp_def* injury poy_mvp predictedpoints_538best predictedpoints_oldoddsmodel predictedpoints_538alt predictedpoints_538pure  actualppoints less_confident dif_in_rankSimon dif_in_rank538;
rename points season_avg;
rename exp_win_prob oddsfirstgame;

*drop rank naive_rank rank538 oddsregion;

*keep if year==2022;
gsort -year player;
*gsort -predictedpoints_538best;
*drop playinteam rd2_win oddsfirstgame totpoints less_confident predictedpoints_538pure;




/*Note that I am replacing prediction of play-in teams with a weighted average of predictions from players on both teams with equal rank*/

/*Summary of predicted points measures
1.  predictedpoints_538best = what I get using over/under from first game, and 538, and accounting for future likely matchups
2.  predictedpoints_538alt uses same information as 538best, but it just uses it differently (puts it all in regression separately rather than first combining it into a single prediction, basically)
3.  predictedpoints_538pure is just using # games times points per game, scaled a tiny bit based on data
4.  predictedpoints_oldoddsmodel is the prediction from the best old model I have, which uses odds of region and predicted points from first game.  It does not use 538 stuff at all, and does not adjust for future matchups.  
*/


-----------------------------------------------------------------------------------------------------------------
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@




