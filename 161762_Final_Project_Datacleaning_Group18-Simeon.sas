/*==============================================================*/
/* 161.762 Final Project                                        */
/* Garment Employee Productivity Dataset                        */
/* Shared Data Cleaning and Preparation Code                    */
/* Group 18                                                     */
/*==============================================================*/


/*--------------------------------------------------------------*/
/* 0. Set GitHub raw data URL                                   */
/* The CSV file is stored on GitHub. Use the raw file URL so    */
/* SAS Studio can read the dataset directly from the internet.  */
/*--------------------------------------------------------------*/

filename garcsv url
"https://raw.githubusercontent.com/SimeonAKL/161762-final-project-data/main/18-garment_employee_productivity.csv";


/*--------------------------------------------------------------*/
/* 1. Import raw data                                           */
/*--------------------------------------------------------------*/

proc import datafile=garcsv
    out=garment_raw
    dbms=csv
    replace;
    guessingrows=max;
    getnames=yes;
run;


/*--------------------------------------------------------------*/
/* 2. Initial data inspection                                   */
/* Purpose: understand variable names, formats, missing values, */
/* and basic distributions before cleaning.                     */
/*--------------------------------------------------------------*/

title "Raw Dataset Structure";
proc contents data=garment_raw varnum;
run;

title "First 10 Rows of Raw Data";
proc print data=garment_raw(obs=10);
run;

title "Frequency Check for Categorical Variables";
proc freq data=garment_raw;
    tables quarter department day team / missing;
run;

title "Missing Value Check for Numeric Variables";
proc means data=garment_raw n nmiss mean std min max;
    var targeted_productivity smv wip over_time incentive
        idle_time idle_men no_of_style_change no_of_workers
        actual_productivity;
run;


/*--------------------------------------------------------------*/
/* 3. Create cleaned master dataset                             */
/* This dataset keeps all observations unless there is a clear  */
/* reason to exclude them. Method-specific exclusions should be */
/* done later for each research question.                       */
/*--------------------------------------------------------------*/

data garment_clean;
    set garment_raw;

    /*----------------------------------------------------------*/
    /* 3.1 Convert date variable                               */
    /* The original date is read from CSV and converted into a  */
    /* SAS date value for possible time-based summaries.        */
    /*----------------------------------------------------------*/

    date_sas = date;
	format date_sas yymmdd10.;

    /*----------------------------------------------------------*/
    /* 3.2 Clean categorical text variables                     */
    /* Standardise case and correct obvious spelling issue in   */
    /* department: "sweing" should be "sewing".                 */
    /*----------------------------------------------------------*/

    quarter_clean = strip(propcase(quarter));
    day_clean     = strip(propcase(day));

    department_clean = lowcase(strip(department));

    if department_clean = "sweing" then department_clean = "sewing";
    if department_clean = "finishing" then department_clean = "finishing";

    /*----------------------------------------------------------*/
    /* 3.3 Treat team as a group variable                       */
    /* Team is numeric in the raw data, but analytically it is  */
    /* a group identifier rather than a continuous measurement. */
    /*----------------------------------------------------------*/

    team_id = team;

    /*----------------------------------------------------------*/
    /* 3.4 Missing value flag for WIP                           */
    /* WIP has many missing values. We do not silently impute or*/
    /* delete them in the master dataset. Instead, we create a  */
    /* flag so each later method can decide whether to use WIP. */
    /*----------------------------------------------------------*/

    if missing(wip) then wip_missing = 1;
    else wip_missing = 0;

    /*----------------------------------------------------------*/
    /* 3.5 Create useful derived productivity variables         */
    /* These are useful for interpretation and later supervised */
    /* methods such as LDA/QDA.                                 */
    /*----------------------------------------------------------*/

    productivity_gap = actual_productivity - targeted_productivity;

    if actual_productivity >= targeted_productivity then met_target = 1;
    else met_target = 0;

    length met_target_group $12;
    if met_target = 1 then met_target_group = "Met target";
    else met_target_group = "Below target";

    /*----------------------------------------------------------*/
    /* 3.6 Flag logically unusual or extreme-looking values     */
    /* These are not automatically removed. They are flagged so */
    /* the group can discuss them transparently in the report.  */
    /*----------------------------------------------------------*/

    if actual_productivity > 1 then actual_prod_above_1 = 1;
    else actual_prod_above_1 = 0;

    if incentive > 1000 then high_incentive_flag = 1;
    else high_incentive_flag = 0;

    if idle_time > 0 or idle_men > 0 then idle_flag = 1;
    else idle_flag = 0;

    /*----------------------------------------------------------*/
    /* 3.7 Keep original variables and cleaned variables        */
    /* Raw variables are retained for traceability. Cleaned     */
    /* variables should be used in the report and analysis.     */
    /*----------------------------------------------------------*/

run;


/*--------------------------------------------------------------*/
/* 4. Check cleaned categorical variables                       */
/*--------------------------------------------------------------*/

title "Cleaned Categorical Variable Frequencies";
proc freq data=garment_clean;
    tables quarter_clean department_clean day_clean team_id
           wip_missing met_target_group idle_flag
           actual_prod_above_1 high_incentive_flag / missing;
run;


/*--------------------------------------------------------------*/
/* 5. Check cleaned numeric variables                           */
/*--------------------------------------------------------------*/

title "Cleaned Numeric Variable Summary";
proc means data=garment_clean n nmiss mean std min q1 median q3 max;
    var targeted_productivity actual_productivity productivity_gap
        smv wip over_time incentive idle_time idle_men
        no_of_style_change no_of_workers;
run;


/*--------------------------------------------------------------*/
/* 6. Check missing WIP by department                           */
/* This helps decide whether WIP can be used fairly in later    */
/* analyses.                                                    */
/*--------------------------------------------------------------*/

title "WIP Missingness by Department";
proc freq data=garment_clean;
    tables department_clean*wip_missing / norow nocol nopercent;
run;


/*--------------------------------------------------------------*/
/* 7. Create complete-case dataset for analyses that require WIP*/
/* This is not the main dataset. It is only for methods where   */
/* WIP is needed and missing values cannot be accepted.         */
/*--------------------------------------------------------------*/

data garment_clean_with_wip;
    set garment_clean;
    if not missing(wip);
run;

title "Dataset Size: Master Cleaned Data";
proc sql;
    select count(*) as n_master_cleaned
    from garment_clean;
quit;

title "Dataset Size: Complete Cases with WIP";
proc sql;
    select count(*) as n_with_wip
    from garment_clean_with_wip;
quit;


/*--------------------------------------------------------------*/
/* 8. Create analysis dataset without WIP                       */
/* This version is useful for PCA, clustering, MDS, LDA, or QDA */
/* when the group wants to retain all observations.             */
/*--------------------------------------------------------------*/

data garment_analysis_no_wip;
    set garment_clean;

    keep date_sas quarter_clean department_clean day_clean team_id
         targeted_productivity actual_productivity productivity_gap
         met_target met_target_group
         smv over_time incentive idle_time idle_men
         no_of_style_change no_of_workers
         wip_missing idle_flag actual_prod_above_1 high_incentive_flag;
run;


/*--------------------------------------------------------------*/
/* 9. Standardise numeric variables for distance-based and      */
/* dimension-reduction methods                                 */
/*                                                              */
/* This creates z-score standardised variables. It is suitable  */
/* for PCA, clustering, MDS, and other methods affected by      */
/* different measurement scales.                               */
/*--------------------------------------------------------------*/

proc standard data=garment_analysis_no_wip
    mean=0 std=1
    out=garment_scaled_no_wip;

    var targeted_productivity actual_productivity productivity_gap
        smv over_time incentive idle_time idle_men
        no_of_style_change no_of_workers;
run;


/*--------------------------------------------------------------*/
/* 10. Standardised dataset including WIP                       */
/* Use this only for analyses where WIP is included and missing */
/* WIP observations have been removed.                          */
/*--------------------------------------------------------------*/

data garment_analysis_with_wip;
    set garment_clean_with_wip;

    keep date_sas quarter_clean department_clean day_clean team_id
         targeted_productivity actual_productivity productivity_gap
         met_target met_target_group
         smv wip over_time incentive idle_time idle_men
         no_of_style_change no_of_workers
         wip_missing idle_flag actual_prod_above_1 high_incentive_flag;
run;

proc standard data=garment_analysis_with_wip
    mean=0 std=1
    out=garment_scaled_with_wip;

    var targeted_productivity actual_productivity productivity_gap
        smv wip over_time incentive idle_time idle_men
        no_of_style_change no_of_workers;
run;


/*--------------------------------------------------------------*/
/* 11. Final check of prepared datasets                         */
/*--------------------------------------------------------------*/

title "Final Master Cleaned Dataset Structure";
proc contents data=garment_clean varnum;
run;

title "Final Analysis Dataset Without WIP";
proc contents data=garment_analysis_no_wip varnum;
run;

title "Final Standardised Dataset Without WIP";
proc contents data=garment_scaled_no_wip varnum;
run;

title "Final Analysis Dataset With WIP";
proc contents data=garment_analysis_with_wip varnum;
run;

title "Final Standardised Dataset With WIP";
proc contents data=garment_scaled_with_wip varnum;
run;


/*==============================================================*/
/* End of Shared Data Cleaning Code                             */
/*==============================================================*/