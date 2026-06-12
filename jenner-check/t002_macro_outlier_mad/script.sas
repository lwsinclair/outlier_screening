/* ------------------------------------------------------------------ *
 * outlier_screening  -  %outlier_MAD demonstration bundle
 *
 * Macro source : outlier_screening/06_macro/outlier_mad.sas (verbatim)
 * Test data    : adsl, from the repo README "Test Data" section
 * Caller       : README usage example  %outlier_MAD(data=adsl, var=age)
 *
 * The only adaptation is the size of the normal-row loop (200 -> 90) so
 * the injected extreme ages stay inside an unlicensed 100-obs run; the
 * macro, the seed, and the outlier injection are exactly as published.
 *
 * MAD robust-Z (0.6745 * MAD-standardized) is more resistant to the
 * outliers themselves than the SD method, so at criteria=3.5 it flags
 * the moderate extremes (AGE 17 and 95) that |Z|>3 does not.
 * ------------------------------------------------------------------ */

data adsl;
  call streaminit(20251126);
  length USUBJID $12 SEX $1 TRT01A $8;
  do i = 1 to 90;
    USUBJID = cats("SUBJ", put(i, z4.));
    SEX = ifc(rand("Bernoulli", 0.5)=1, "M", "F");
    TRT01A = ifc(rand("Bernoulli", 0.5)=1, "Drug", "Placebo");
    AGE = round(rand("Normal", 55, 10), 1);
    if AGE < 18 then AGE = 18;
    if AGE > 90 then AGE = 90;
    output;
  end;
  do j = 1 to 6;
    i + 1;
    USUBJID = cats("SUBJ", put(i, z4.));
    SEX = ifc(mod(i,2)=0, "M", "F");
    TRT01A = ifc(mod(i,2)=0, "Drug", "Placebo");
    select (j);
      when (1,2) AGE = 19;
      when (3)   AGE = 95;
      when (4)   AGE = 101;
      when (5)   AGE = 17;
      when (6)   AGE = 110;
      otherwise;
    end;
    output;
  end;
  drop i j;
run;

%macro outlier_MAD(data = ,  var= ,  by=, criteria = 3.5 , out= outlier_MAD );
%if %length(&by) ne 0 %then %do;
  proc sort data = &data;
    by &by;
  run;
%end;
proc stdize data=&data out=outlier_MAD1 sprefix=mad_ oprefix=ori_ method=mad;
  var &var.;
  %if %length(&by) ne 0 %then %do;
    by &by;
  %end;
run;
data &out.;
set outlier_MAD1;
mad_&var._abs=abs(0.6745 * mad_&var.);
Criteria_MAD=&criteria.;
if Criteria_MAD < mad_&var._abs then outlier_MADFL="Y";
else outlier_MADFL="N";
rename ori_&var.= &var.;
run;
proc delete data=outlier_MAD1;
run;
%mend;

%outlier_MAD(data=adsl, var=age);

title "MAD robust-Z outliers flagged in adsl.AGE (criteria=3.5)";
proc print data=outlier_MAD;
  where outlier_MADFL="Y";
  var USUBJID AGE mad_age mad_age_abs Criteria_MAD outlier_MADFL;
run;

proc freq data=outlier_MAD;
  tables outlier_MADFL / nocum;
run;
