/* ------------------------------------------------------------------ *
 * outlier_screening  -  %outlier_all3 end-to-end demonstration bundle
 *
 * Macro sources : outlier_screening/06_macro/outlier_sd.sas
 *                 outlier_screening/06_macro/outlier_mad.sas
 *                 outlier_screening/06_macro/outlier_iqr.sas
 *                 outlier_screening/06_macro/outlier_all3.sas   (all verbatim)
 * Test data     : adsl, from the repo README "Test Data" section
 * Caller        : README usage example  %outlier_all3(data=adsl, var=age)
 *
 * The only adaptation is the size of the normal-row loop (200 -> 90) so
 * the injected extreme ages stay inside an unlicensed 100-obs run.
 *
 * The orchestrator runs all three methods, combines their flags, adds
 * ascending/descending dense ranks (PROC RANK), draws the annotated
 * scatter + boxplot (PROC SGPLOT), and prints the PROC UNIVARIATE extreme
 * observations -- the full review-ready workflow in one call.
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
  proc sort data = &data; by &by; run;
%end;
proc stdize data=&data. out=outlier_SD1 sprefix=std_ oprefix=ori_ method=std;
  var &var. ;
  %if %length(&by) ne 0 %then %do; by &by; %end;
run;
data &out.;
  set outlier_SD1;
  std_&var._abs = abs(std_&var.);
  Criteria_SD = &criteria.;
  if Criteria_SD < std_&var._abs then outlier_SDFL="Y"; else outlier_SDFL="N";
  rename ori_&var.=&var.;
run;
proc delete data=outlier_SD1; run;
%mend;

%macro outlier_MAD(data = ,  var= ,  by=, criteria = 3.5 , out= outlier_MAD );
%if %length(&by) ne 0 %then %do;
  proc sort data = &data; by &by; run;
%end;
proc stdize data=&data out=outlier_MAD1 sprefix=mad_ oprefix=ori_ method=mad;
  var &var.;
  %if %length(&by) ne 0 %then %do; by &by; %end;
run;
data &out.;
set outlier_MAD1;
mad_&var._abs=abs(0.6745 * mad_&var.);
Criteria_MAD=&criteria.;
if Criteria_MAD < mad_&var._abs then outlier_MADFL="Y"; else outlier_MADFL="N";
rename ori_&var.= &var.;
run;
proc delete data=outlier_MAD1; run;
%mend;

%macro outlier_IQR(data = ,  var= ,  by=,  out= outlier_IQR );
%if %length(&by) ne 0 %then %do;
  proc sort data = &data; by &by; run;
%end;
proc univariate data=&data noprint;
  var &var. ;
  %if %length(&by) ne 0 %then %do; by &by; %end;
  output out=_iqr_ q1=Q1 q3=Q3;
run;
data &out.;
  set &data;
  %if %length(&by) eq 0 %then %do; if _n_=1 then set _iqr_; %end;
  %if %length(&by) ne 0 %then %do;
    if 0 then set _iqr_;
    if _n_ = 1 then do;
      declare hash h1(dataset:"_iqr_");
      h1.definekey("&by"); h1.definedata("Q1","Q3"); h1.definedone();
    end;
    if h1.find() ne 0 then call missing(of Q1 Q3);
  %end;
  IQR = Q3 - Q1;
  Lower1_5 = Q1 - 1.5*IQR;  Upper1_5 = Q3 + 1.5*IQR;
  Lower3  = Q1 - 3*IQR;     Upper3  = Q3 + 3*IQR;
  if &var. < Lower1_5 or &var. > Upper1_5 then outlier_IQR1_5FL = "Y"; else outlier_IQR1_5FL = "N";
  if &var. < Lower3 or &var. > Upper3 then outlier_IQR3FL = "Y"; else outlier_IQR3FL = "N";
run;
proc delete data=_iqr_; run;
%mend;

%macro outlier_all3(data = , var= , by=, SD_criteria=3, MAD_criteria=3.5);
%outlier_SD(data=&data, var =&var,by =&by, criteria=&SD_criteria, out=outlier_&data._sd);
%outlier_MAD(data=outlier_&data._sd, var =&var,by =&by, criteria=&MAD_criteria,out=outlier_&data._mad);
%outlier_IQR(data=outlier_&data._mad, var =&var,by =&by,out=outlier_&data._iqr);
data outlier_&data._all3;
set outlier_&data._iqr;
drop std_&var. Criteria_SD mad_&var. Criteria_MAD Q3 Q1 IQR Lower1_5 Upper1_5 Lower3 Upper3 ;
run;

proc rank data=outlier_&data._all3 out=outlier_&data._all3 ties=dense;
var &var;
ranks asc_rank;
run;

proc rank data=outlier_&data._all3 out=outlier_&data._all3 descending ties=dense;
var &var;
ranks desc_rank;
run;


data outlier_&data._graph;
set  outlier_&data._all3;
 if outlier_SDFL ="Y" then  text=cats("SD");
 if outlier_MADFL ="Y" then  text=catx("/",text,"MAD");
 if outlier_IQR3FL ="Y" then  text=catx("/",text,"IQR3");
 if outlier_IQR1_5FL ="Y" and  outlier_IQR3FL ="N" then  text=catx("/",text,"IQR1.5");
dummy=1;
label dummy="SD: &SD_criteria. < |z|, MAD: &MAD_criteria <|z*|";
run;
 %if %length(&by) ne 0 %then %do;
proc sort data = outlier_&data._graph;
      by &by.;
run;
%end;
proc format;
 value dummy 1 =" ";
run;
proc sgplot data=outlier_&data._graph noautolegend;
  scatter x=dummy y=&var /  name="sp1"
              transparency=0.5 jitter markerattrs=(symbol=circle size=5) datalabel=text datalabelattrs=(color=red)
              ;
  vbox &var / category=dummy noFill noOutliers
              meanAttrs=(color=black symbol=diamondFilled);
 %if %length(&by) ne 0 %then %do;
      by &by.;
%end;

format dummy dummy.;
run;

ods select ExtremeObs;
proc univariate data=&data ;
  var &var. ;
  %if %length(&by) ne 0 %then %do;
   by &by;
  %end;
run;

%mend;

%outlier_all3(data=adsl, var=age);

title "Combined outlier review (all3): flag pattern by method";
proc print data=outlier_adsl_all3;
  where outlier_SDFL="Y" or outlier_MADFL="Y"
     or outlier_IQR1_5FL="Y" or outlier_IQR3FL="Y";
  var USUBJID AGE outlier_SDFL outlier_MADFL outlier_IQR1_5FL outlier_IQR3FL
      asc_rank desc_rank;
run;
