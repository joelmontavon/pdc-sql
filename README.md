Calculating the Proportion of Days Covered using SAS
====================================================

The proportion of days covered (PDC) is a method for calculating medication adherence. It involves identifying days covered based upon the date of service and days supply using prescription claims data. The methodology adjusts the start date for overlapping fills of the same medication. This makes sense because patients often come into the pharmacy to pickup their drugs a few days early so they do not run out of supply.

PDC is a more conservative estimate when patient switches between medications in the same class or concurrently uses more than one medication in a class. For most drug classes, a PDC ≥80% is considered adherent.

    /*Set measurement year start and end dates*/
    %let start_dt='01jan2022'd;
    %let end_dt='31dec2022'd;
    

This code converts these dates to days from epoch. SAS uses 1/1/1960 as the epoch. The %sysfunc() macro function allows use of data step functions outside of a data step. Note that character values (i.e., strings) do not need to be enclosed with quotation marks. Basically, we extract the portion of the date inside the quotes using the substr() function. Then, we convert the date to a number using the inputn() function. In the steps below, we will use these macro variables to set the indexes of our arrays to reflect the days in the measurement year.

    %let start_day_nbr=%sysfunc(inputn(%sysfunc(substr(&start_dt, 2, 9)), date9.), 8.);
    %let end_day_nbr=%sysfunc(inputn(%sysfunc(substr(&end_dt, 2, 9)), date9.), 8.);
    

This code creates prescription claims for the following test scenarios:

*   The SAMEDRUG patient includes overlapping fills of the same drug.
*   The DIFFDRUG patient includes overlapping fills of different drugs.
*   The NONADH patient has a PDC < 80% and not counted as adherent.
*   The COMBPROD patient includes overlapping fills between a single ingredient product and a combination product with the same target drug. _Note that the drug column only includes the target medication. Combination products with multiple target drugs should have multiple rows for each fill with one per target medication._
*   The CONCUSE patient has concurrent use of 2 different drugs (i.e., overlapping days supply of different drugs for >= 30 days).

```
    data rx_clms;
    	format pt_id $10. drug $32. date_of_service date. days_sup 4.;
    	pt_id = 'SAMEDRUG'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='01jan2022'd; days_sup = 90; output;
    	pt_id = 'SAMEDRUG'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='25mar2022'd; days_sup = 90; output;
    	pt_id = 'SAMEDRUG'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='05jul2022'd; days_sup = 90; output;
    	pt_id = 'SAMEDRUG'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='25sep2022'd; days_sup = 90; output;
    	pt_id = 'DIFFDRUG'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='01jan2022'd; days_sup = 90; output;
    	pt_id = 'DIFFDRUG'; drug_name = 'LOSARTAN 25 MG TABS'; drug = 'LOSARTAN'; date_of_service='25mar2022'd; days_sup = 90; output;
    	pt_id = 'DIFFDRUG'; drug_name = 'LOSARTAN 25 TABS'; drug = 'LOSARTAN'; date_of_service='05jul2022'd; days_sup = 90; output;
    	pt_id = 'DIFFDRUG'; drug_name = 'LOSARTAN 25 MG TABS'; drug = 'LOSARTAN'; date_of_service='25sep2022'd; days_sup = 90; output;
    	pt_id = 'NONADH'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='01jan2022'd; days_sup = 90; output;
    	pt_id = 'NONADH'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='25mar2022'd; days_sup = 90; output;
    	pt_id = 'NONADH'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='25sep2022'd; days_sup = 90; output;
    	pt_id = 'COMBPROD'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='01jan2022'd; days_sup = 90; output;
    	pt_id = 'COMBPROD'; drug_name = 'LISINOPRIL 10 MG / HYDROCHLOROTHIAZIDE 12.5 MG TABS'; drug = 'LISINOPRIL'; date_of_service='25mar2022'd; days_sup = 90; output;
    	pt_id = 'COMBPROD'; drug_name = 'LISINOPRIL 10 MG / HYDROCHLOROTHIAZIDE 12.5 MG TABS'; drug = 'LISINOPRIL'; date_of_service='05jul2022'd; days_sup = 90; output;
    	pt_id = 'COMBPROD'; drug_name = 'LISINOPRIL 10 MG / HYDROCHLOROTHIAZIDE 12.5 MG TABS'; drug = 'LISINOPRIL'; date_of_service='25sep2022'd; days_sup = 90; output;
    	pt_id = 'CONCUSE'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='01jan2022'd; days_sup = 90; output;
    	pt_id = 'CONCUSE'; drug_name = 'LISINOPRIL 10 MG TABS'; drug = 'LISINOPRIL'; date_of_service='25mar2022'd; days_sup = 90; output;
    	pt_id = 'CONCUSE'; drug_name = 'LOSARTAN 25 MG TABS'; drug = 'LOSARTAN'; date_of_service='25mar2022'd; days_sup = 90; output;
    	pt_id = 'CONCUSE'; drug_name = 'LOSARTAN 25 MG TABS'; drug = 'LOSARTAN'; date_of_service='05jul2022'd; days_sup = 90; output;
    	pt_id = 'CONCUSE'; drug_name = 'LOSARTAN 25 MG TABS'; drug = 'LOSARTAN'; date_of_service='25sep2022'd; days_sup = 90; output;
    run;
```    

To calculate the PDC, we first identify the days covered by each medication. For overlapping fills of the same drug, we assume that the patient will finish his/her current fill before starting the refill. For overlapping fills of different drug, we assume that the patient will start his/her new medication right away. So, we need to adjust for overlapping days supply for fills of the same drug but not of different drugs. To accomplish this, we need two arrays. The drug level array will capture the days covered adjusting for overlapping days supply of the same drug. The patient level array will capture days covered across all of the patient's drugs without adjusting for overlapping days supply for different drugs.

    
    /*Sort the data for the group by in next step*/
    proc sort data=rx_clms;
    	by pt_id drug;
    run;
    
    data days_covered (drop=drug_name drug date_of_service days_sup i j);
    	set rx_clms;
    	by pt_id drug;
		/*The array indexes are set to reflect the days in the measurement year*/
    	array days_covered_drug[&start_day_nbr : &end_day_nbr] _temporary_;
    	array days_covered_pt[&start_day_nbr : &end_day_nbr] days_covered_pt&start_day_nbr - days_covered_pt&end_day_nbr;
    	retain days_covered_pt&start_day_nbr - days_covered_pt&end_day_nbr;
    
    	/*Reset the patient level array for each patient*/
    	if first.pt_id then do;
    		do i = &start_day_nbr to &end_day_nbr;
    			days_covered_pt[i] = 0;
    		end;
    	end;
    	/*Reset the drug level array for each patient and drug*/
    	if first.drug then do;
    		do i = &start_day_nbr to &end_day_nbr;
    			days_covered_drug[i] = 0;
    		end;
    	end;
    	
    	/*Increment the index of the drug level array for each day covered*/
    	/*We use the i and j variables to keep track of the days supply used and the date within the measurement year, respectively*/
    	i = 0;
    	j = date_of_service;
    	/*The loop stops when we have used up all of the supply or we reach the end of the measurement year*/
    	do while (i < days_sup and j <= &end_day_nbr); 
    		/*If the day is not already covered, we increment the index of the drug level array*/
    		/*Otherwise, we just skip over it.*/
    		if days_covered_drug[j] = 0 then do;
    			/*Increment the index of the drug level array*/
    			days_covered_drug[j] = 1;
    			/*Increment variable tracking the days supply used*/
    			i + 1;
    		end;
    		/*Increment to the next day in the measurement year*/
    		j + 1;
    	end;
    
    	/*For the last fill, increment the index of the patient level array for any index in the drug level array that has been incremented*/
    	if last.drug then do;
    		do i = &start_day_nbr to &end_day_nbr;
    			if days_covered_drug[i] = 1 then days_covered_pt[i] + 1;
    		end;
    	end;
    
    	/*Output the last row for each patient*/
    	if last.pt_id then output;
    run;
    

Now, we have everything we need to calculate the PDC. PDC is simply the total days covered divided by the total the days in the treatment period. The treatment period typically starts with the patient's first fill during the measurement year. And, the treatement typically ends with the end of the measurement year (or disenrollment/death). In our examples, we have assumed that the patients have not disenrolled or passed during the measurement year. For most drug classes, PDC >= 80% is classified as adherent.

    data pdc (drop=days_covered_pt&start_day_nbr - days_covered_pt&end_day_nbr i j);
    	set days_covered;
    	format pdc percent8.2;
    	array days_covered[&start_day_nbr : &end_day_nbr] days_covered_pt&start_day_nbr - days_covered_pt&end_day_nbr;
    	
    	tot_days_in_tx_prd = 0;
    	tot_days_covered = 0;
    
    	/*i tracks if the patient has reached the first day in the treatment period yet.*/
    	i = 0;
    	/*Loop thru the days in the measurement year*/
    	do j = &start_day_nbr to &end_day_nbr;
    		/*Count the days covered*/
    		if days_covered[j] >= 1 then do;
    			tot_days_covered + 1;
    			/*i is set to 1 with the first day covered*/
    			i = 1;
    		end;
    		/*The total days in the treatment period will only increment after we have reached the first day covered*/
    		tot_days_in_tx_prd + i;
    	end;
    	pdc = round(tot_days_covered/tot_days_in_tx_prd, 0.0001);
    	if pdc >= 0.8 then numerator = 1;
    		else numerator = 0;
    run;
    

A similar approach can be used for identifying concurrent use of multiple medications. Below, we identify patients with concurrent use of >= 2 drugs for 30 or more days. _Note that measures looking at concurrent use do not alway adjust for overlapping days supply of the same drug._

    
    data concurrent_use (drop=days_covered_pt&start_day_nbr - days_covered_pt&end_day_nbr i j);
    	set days_covered;
    	array days_covered[&start_day_nbr : &end_day_nbr] days_covered_pt&start_day_nbr - days_covered_pt&end_day_nbr;
    	
    	tot_days_concurrent_use = 0;
    
    	/*Loop thru the days in the measurement year*/
    	do j = &start_day_nbr to &end_day_nbr;
    		/*Count days with concurrent use (e.g., >= 2 drugs on each day in the measurement year)*/
    		if days_covered[j] >= 2 then do;
    			tot_days_concurrent_use + 1;
    		end;
    	end;
    	/*Count in numerator if concurrent use of >= 30 days*/
    	if tot_days_concurrent_use >= 30 then numerator = 1;
    		else numerator = 0;
    run;