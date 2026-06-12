/* ------------------------------------------------------------------ *
 * outlier_screening  -  %outlier_SD demonstration bundle
 *
 * Macro source : outlier_screening/06_macro/outlier_sd.sas (verbatim)
 * Test data    : adsl, from the repo README "Test Data" section
 * Caller       : README usage example  %outlier_SD(data=adsl, var=age)
 *
 * The only adaptation is the size of the normal-row loop (200 -> 90) so
 * the injected extreme ages stay inside an unlicensed 100-obs run; the
 * macro, the seed, and the outlier injection are exactly as published.
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

%macro outlier_SD(data = ,  var= ,  by=, criteria = 3 , out= outlier_SD );
%if %length(&by) ne 0 %then %do;
  proc sort data = &data;
    by &by;
  run;
%end;
proc stdize data=&data. out=outlier_SD1 sprefix=std_ oprefix=ori_ method=std;
  var &var. ;
  %if %length(&by) ne 0 %then %do;
      by &by;
  %end;
run;
data &out.;
  set outlier_SD1;
  std_&var._abs = abs(std_&var.);
  Criteria_SD = &criteria.;
  if Criteria_SD < std_&var._abs then outlier_SDFL="Y";
   else outlier_SDFL="N";
  rename ori_&var.=&var.;
run;
proc delete data=outlier_SD1;
run;
%mend;

%outlier_SD(data=adsl, var=age);

title "SD (Z-score) outliers flagged in adsl.AGE";
proc print data=outlier_SD;
  where outlier_SDFL="Y";
  var USUBJID AGE std_age std_age_abs Criteria_SD outlier_SDFL;
run;

proc freq data=outlier_SD;
  tables outlier_SDFL / nocum;
run;
