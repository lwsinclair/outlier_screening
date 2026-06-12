/* ------------------------------------------------------------------ *
 * outlier_screening  -  %outlier_IQR demonstration bundle (BY group)
 *
 * Macro source : outlier_screening/06_macro/outlier_iqr.sas (verbatim)
 * Test data    : advs, from the repo README "Test Data" section
 * Caller       : README usage example
 *                %outlier_IQR(data=advs, var=aval, by=paramcd, out=iqr_out)
 *
 * The only adaptation is the size of the subject loop (160 -> 30) so each
 * PARAMCD group keeps its injected extremes inside an unlicensed 100-obs
 * run (30 subjects x 3 params = 90 rows). The macro is exactly as
 * published, including the per-group hash lookup of the quartiles.
 *
 * This exercises the BY path: PROC UNIVARIATE computes Q1/Q3 per PARAMCD,
 * a hash object joins them back per group, and the Tukey 1.5*IQR / 3*IQR
 * fences are applied within each group.
 * ------------------------------------------------------------------ */

data advs;
  call streaminit(20251126);
  length USUBJID $12 PARAMCD $8;
  array params[3] $8 _temporary_ ("SBP","DBP","HR");
  do i = 1 to 30;
    USUBJID = cats("SUBJ", put(i, z4.));
    do p = 1 to dim(params);
      PARAMCD = params[p];
      select (PARAMCD);
        when ("SBP") do;
          AVAL = rand("Normal", 120, 12);
          if i in (5)  then AVAL = 175;
          if i in (3)  then AVAL = 85;
        end;
        when ("DBP") do;
          AVAL = rand("Normal", 75, 8);
          if i in (12) then AVAL = 110;
          if i in (8)  then AVAL = 45;
        end;
        when ("HR") do;
          AVAL = rand("Normal", 70, 10);
          if i in (22) then AVAL = 130;
          if i in (15) then AVAL = 35;
        end;
        otherwise;
      end;
      AVAL = round(AVAL, 0.1);
      output;
    end;
  end;
  drop i p;
run;

%macro outlier_IQR(data = ,  var= ,  by=,  out= outlier_IQR );
%if %length(&by) ne 0 %then %do;
  proc sort data = &data;
    by &by;
  run;
%end;
proc univariate data=&data noprint;
  var &var. ;
  %if %length(&by) ne 0 %then %do;
   by &by;
  %end;
  output out=_iqr_
    q1=Q1
    q3=Q3;
run;
data &out.;
  set &data;
  %if %length(&by) eq 0 %then %do;
  if _n_=1 then set _iqr_;
  %end;
  %if %length(&by) ne 0 %then %do;
    if 0 then set _iqr_;
    if _n_ = 1 then do;
      declare hash h1(dataset:"_iqr_");
      h1.definekey("&by");
      h1.definedata("Q1","Q3");
      h1.definedone();
    end;
    if h1.find() ne 0 then call missing(of Q1 Q3);
  %end;
  IQR = Q3 - Q1;
  Lower1_5 = Q1 - 1.5*IQR;
  Upper1_5 = Q3 + 1.5*IQR;
  Lower3  = Q1 - 3*IQR;
  Upper3  = Q3 + 3*IQR;

  if &var. < Lower1_5 or &var. > Upper1_5 then outlier_IQR1_5FL = "Y";
  else  outlier_IQR1_5FL = "N";
  if &var. < Lower3 or &var. > Upper3 then outlier_IQR3FL = "Y";
  else  outlier_IQR3FL = "N";

run;
proc delete data=_iqr_;
run;

%mend;

%outlier_IQR(data=advs, var=aval, by=paramcd, out=iqr_out);

title "IQR-rule outliers by PARAMCD (hash lookup of per-group quartiles)";
proc print data=iqr_out;
  where outlier_IQR1_5FL="Y" or outlier_IQR3FL="Y";
  var USUBJID PARAMCD AVAL Q1 Q3 IQR outlier_IQR1_5FL outlier_IQR3FL;
run;

proc freq data=iqr_out;
  tables paramcd*outlier_IQR1_5FL / norow nocol nopercent;
run;
