/*This tutorial walks thru the steps for calculating the proportion of days covered using SQL.
The proportion of days covered (PDC) is a method for calculating medication adherence. 
It involves identifying days covered based upon the date of service and days supply using prescription claims data. 
The methodology adjusts the start date for overlapping fills of the same medication. 
This makes sense because patients often come into the pharmacy to pickup their drugs a few days early so they do not run out of supply.

PDC is a more conservative estimate when patient switches between medications in the same class or concurrently uses more than one medication in a class. 
For most drug classes, a PDC ≥80% is considered adherent.
  
I am going to use common table expressions, or CTEs, to walk thru the various steps in the code. 
These are really handy as you can define a temporary table of sorts that can be reused throughout a single query.
CTEs are defined using a WITH clause. Note that the steps below can be rewritten as a single query with nested subqueries.
  
Also, you will see that I use window functions throughout my code. They are very powerful and love using them in my code. 
If not familiar, PostgreSQL's documentation does an excellent job of introducing the concept of window functions:

"A window function performs a calculation across a set of table rows that are somehow related to the current row. 
This is comparable to the type of calculation that can be done with an aggregate function. 
But unlike regular aggregate functions, use of a window function does not cause rows to become grouped into a single output row — the rows retain their separate identities. 
Behind the scenes, the window function is able to access more than just the current row of the query result..."

"A window function call always contains an OVER clause directly following the window function's name and argument(s). 
This is what syntactically distinguishes it from a regular function or aggregate function. 
The OVER clause determines exactly how the rows of the query are split up for processing by the window function. 
The PARTITION BY list within OVER specifies dividing the rows into groups, or partitions, that share the same values of the PARTITION BY expression(s). 
For each row, the window function is computed across the rows that fall into the same partition as the current row."

"You can also control the order in which rows are processed by window functions using ORDER BY within OVER..."

Note that SQL can vary from implementation to implementation so may need to be adapted for your database.
For the code below, I used MS SQL Server 2019. If you don't have MS SQL Servier, you can try out the code in an online code runner such as SQLize.*/

/*First, I need to create some data to work with for the tutorial.
I create a table for the NDCs and their attributes. 
Note that the drug column is used for identifying overlapping days supply with the same drug. Combination products with multiple target drugs should have multiple rows for each fill with one per target medication.*/

CREATE TABLE ndc_list(drug VARCHAR(32), code CHAR(11), description TEXT);
INSERT INTO ndc_list
SELECT 'LISINOPRIL', '00172375980', 'Lisinopril Tab 10 MG' UNION ALL
SELECT 'LISINOPRIL', '43063048290', 'Lisinopril & Hydrochlorothiazide Tab 10-12.5 MG' UNION ALL
SELECT 'LOSARTAN', '00006095231', 'Losartan Potassium Tab 50 MG';

/*I create a table with all dates in the measurement year. We will use this when counting the days covered by each prescription. More on that in a later...*/

CREATE TABLE dates (dt DATE);
INSERT INTO dates
SELECT
  DATEADD(day, n - 1, '2022-01-01') 
FROM (
  SELECT
	TOP (DATEDIFF(DAY, '2022-01-01', '2022-12-31') + 1) n = ROW_NUMBER() OVER (ORDER BY [object_id]) FROM sys.all_objects
  ) n;

/*Lastly, I create a table with prescription claims for various test scenarios:
-The SAMEDRUG patient includes overlapping fills of the same drug.
-The DIFFDRUG patient includes overlapping fills of different drugs.
-The NONADH patient has a PDC < 80% and not counted as adherent.
-The COMBPROD patient includes overlapping fills between a single ingredient product and a combination product with the same target drug.
-The CONCUSE patient has concurrent use of 2 different drugs (i.e., overlapping days supply of different drugs for ≥ 30 days).
-The IPSD patient's first fill in not 1/1 so the treatment period is not 365 days.
-The MEASYR patient has days supply that extends beyond the end of the measurement year.*/

CREATE TABLE rx_clms(pt_id VARCHAR(16), date_of_service DATE, ndc CHAR(11), days_supply INT);
INSERT INTO rx_clms
/*Overlapping fills same drug*/
SELECT 'SAMEDRUG', '2022-01-01', '00172375980', 90 UNION ALL
SELECT 'SAMEDRUG', '2022-03-25', '00172375980', 90 UNION ALL
SELECT 'SAMEDRUG', '2022-07-05', '00172375980', 90 UNION ALL
SELECT 'SAMEDRUG', '2022-09-25', '00172375980', 90 UNION ALL
/*Overlapping fills different drugs*/
SELECT 'DIFFDRUG', '2022-01-01', '00172375980', 90 UNION ALL
SELECT 'DIFFDRUG', '2022-03-25', '00006095231', 90 UNION ALL
SELECT 'DIFFDRUG', '2022-07-05', '00006095231', 90 UNION ALL
SELECT 'DIFFDRUG', '2022-09-25', '00006095231', 90 UNION ALL
/*Non-adherent*/
SELECT 'NONADH', '2022-01-01', '00172375980', 90 UNION ALL
SELECT 'NONADH', '2022-03-25', '00172375980', 90 UNION ALL
SELECT 'NONADH', '2022-09-25', '00172375980', 90 UNION ALL
/*Overlapping fills same ingredient*/
SELECT 'COMBPROD', '2022-01-01', '00172375980', 90 UNION ALL
SELECT 'COMBPROD', '2022-03-25', '43063048290', 90 UNION ALL
SELECT 'COMBPROD', '2022-07-05', '43063048290', 90 UNION ALL
SELECT 'COMBPROD', '2022-09-25', '43063048290', 90 UNION ALL
/*Concurrent use of multiple drugs*/
SELECT 'CONCUSE', '2022-01-01', '00172375980', 90 UNION ALL
SELECT 'CONCUSE', '2022-03-25', '00172375980', 90 UNION ALL
SELECT 'CONCUSE', '2022-03-25', '00006095231', 90 UNION ALL
SELECT 'CONCUSE', '2022-07-05', '00006095231', 90 UNION ALL
SELECT 'CONCUSE', '2022-09-25', '00006095231', 90 UNION ALL
/*Index prescription start date*/
SELECT 'IPSD', '2022-03-25', '00172375980', 90 UNION ALL
SELECT 'IPSD', '2022-07-05', '00172375980', 90 UNION ALL
SELECT 'IPSD', '2022-09-25', '00172375980', 90 UNION ALL
/*Days supply extends beyond end of measurement year*/
SELECT 'MEASYR', '2022-01-01', '00172375980', 90 UNION ALL
SELECT 'MEASYR', '2022-03-25', '00172375980', 90 UNION ALL
SELECT 'MEASYR', '2022-07-05', '00172375980', 90 UNION ALL
SELECT 'MEASYR', '2022-10-15', '00172375980', 90;

/*Step 1
Join the prescription claims with NDC list to pull in the drug. As mentioned above, the drug column is used for identifying overlapping days supply with the same drug.
Note the syntax for the WITH queries. The WITH queries are surrounded by parenthesis and separated by commas.
And, these WITH queries can be referenced in subsequent WITH queries or in the final query.*/

WITH rx_clms_dtl AS (
SELECT 
  rx_clms.*, 
  ndc_list.description, 
  ndc_list.drug 
FROM rx_clms 
  INNER JOIN ndc_list ON rx_clms.ndc = ndc_list.code 
WHERE 
  date_of_service BETWEEN '2022-01-01' AND '2022-12-31'
),

/*Step 2
To calculate the PDC, we need to be able to deal with both overlapping days supply for the same drug as well different drugs:

-For overlapping fills of the same drug, we assume that the patient will finish his/her current fill before starting the refill. 
-For overlapping fills of different drug, we assume that the patient will start his/her new medication right away. 

We need to adjust for overlapping days supply for fills of the same drug but not of different drugs. 
And, in the next few steps, we will focus on adjusting for overlapping days supply of the same drug. 
First, we determine the running days supply and first date of service for the patient and drug using the SUM() and MIN() window functions.
Note that the ORDER BY clause is used for the running total. 
Removing the ORDER BY clause gives you a completely different result. You'll get the total of all rows in the partition instead of the running total.*/

days_sup_ytd AS (
SELECT 
  *, 
  SUM(days_supply) OVER (PARTITION BY pt_id, drug ORDER BY date_of_service) AS days_sup_ytd, 
  MIN(date_of_service) OVER (PARTITION BY pt_id, drug) AS dos_first 
FROM rx_clms_dtl
),

/*Step 3
Calculate the running days supply prior to the claim using the LAG() window function.
Note that the ORDER BY clause in required for some window functions like LAG().*/

days_sup_ytd_prior AS (
SELECT 
  *, 
  COALESCE(LAG(days_sup_ytd) OVER (PARTITION BY pt_id, drug ORDER BY date_of_service), 0) AS days_sup_ytd_prior
FROM days_sup_ytd
),

/*Step 4
Calculate any remaining days supply prior to the claim by subtracting the last date with days supply prior to the claims from the date of service on the claim.
And, of course, the remaining days supply prior to the claim cannot be less than zero.*/

days_sup_rmng AS (
SELECT 
  *, 
  CASE WHEN DATEDIFF(DAY, DATEADD(DAY, days_sup_ytd_prior, dos_first), date_of_service) > 0 
	THEN DATEDIFF(DAY, DATEADD(DAY, days_sup_ytd_prior, dos_first), date_of_service) 
	ELSE 0 END AS days_sup_rmng 
FROM days_sup_ytd_prior
),

/*Step 5
Then, pull forward the remaining days supply from prior claims to subsequent claims.*/

days_sup_rmng_ytd AS (
SELECT 
  *, 
  MAX(days_sup_rmng) OVER (PARTITION BY pt_id, drug ORDER BY date_of_service) AS days_sup_rmng_ytd 
FROM days_sup_rmng
),

/*Step 6
Calculate the adjusted start date for the claim by adding the running days supply prior to the claim to any remaining days supply from prior claims 
and then adding to the first date of service for the drug.*/

dos_adj AS (
SELECT 
  *, 
  DATEADD(DAY, days_sup_ytd_prior + days_sup_rmng_ytd, dos_first) AS dos_adj
FROM days_sup_rmng_ytd
),

/*Step 7
Now, calculate the date of the last days supply for the claim by adding the days supply to the adjusted start date.
However, this need to be truncated if the days supply extends beyond the end of the measurement year.*/

date_last_dose AS (
SELECT 
  *, 
  CASE WHEN DATEADD(DAY, days_supply + 1, dos_adj) > '2022-12-31' THEN DATEDIFF(DAY, dos_adj, '2022-12-31') + 1 
	ELSE days_supply END AS days_sup_adj, 
  CASE WHEN DATEADD(DAY, days_supply + 1, dos_adj) > '2022-12-31' THEN '2022-12-31' 
	ELSE DATEADD(DAY, days_supply - 1, dos_adj) END AS date_last_dose 
FROM dos_adj
),

/*Step 8
Calculate the index prescription start date (IPSD) which is just the first fill during the measurement year.
This is used to calculate the days in the treatment period.*/

ipsd AS (
SELECT 
  *,
  MIN(date_of_service) OVER (PARTITION BY pt_id) AS ipsd
FROM date_last_dose
WHERE 
  days_sup_adj > 0
),

/*Step 9
Calculate the days in the treatment period by subtracting the IPSD from the last day in the measurement year.
This assumes individuals are continuously enrolled thru the end of the measurement year.
If an individual disenrolls (or dies) during the measurement year, the date of disenrollment (or death) should be used as the end of the treatment period.
So, you may need to modify this code to account for eligibility.*/

days_in_tx_period AS (
SELECT 
  *, 
  DATEDIFF(DAY, ipsd, '2022-12-31') + 1 AS days_in_tx_period 
FROM ipsd
),

/*Step 10
Perform a full join between the claims and dates limiting to dates between the adjusted date of service and date of last dose.
Use SELECT DISTINCT to return unique dates by patient and drug.
Then, count the unique drugs covered on each date for each patient.*/

drugs_covered AS (
SELECT 
  pt_id, 
  days_in_tx_period, 
  dt, 
  COUNT(*) AS drugs_covered 
FROM (SELECT DISTINCT 
	  pt_id, 
	  days_in_tx_period, 
	  drug, 
	  dt 
	FROM days_in_tx_period, dates 
	WHERE dt BETWEEN dos_adj AND date_last_dose) t1
GROUP BY 
  pt_id, 
  days_in_tx_period, 
  dt
),

/*Step 11
Calculate if covered by at covered by at least one drug on each day in the treatment period and then sum up the days covered.
Note that, for most PDC measures, we are looking if covered by at least one drug on each day in the treatment period.
There are some measures that look if covered by multiple drugs on each day in the treatment period. For those measures, this step could be modified. 
Also, if grouped differently, it would be possible to reuse this code to look for concurrent use of multiple drug classes.*/

days_covered AS (
SELECT 
  pt_id, 
  days_in_tx_period, 
  SUM(day_covered) AS days_covered 
FROM (SELECT 
	  *, 
	  CASE WHEN drugs_covered > 0 THEN 1 ELSE 0 END AS day_covered
	FROM drugs_covered) t1
GROUP BY 
  pt_id, 
  days_in_tx_period
),

/*Step 12
Calculate the PDC by dividing the days covered by the days in the measurement period and formatted as a percent.*/

pdc AS (SELECT 
  *, 
  FORMAT(CAST(days_covered AS FLOAT) / CAST(days_in_tx_period AS FLOAT), 'P') AS pdc 
FROM days_covered
)

/*Step 13
We are almost done. Now, we apply the PDC threshold of 80% to determine if the patient is adherent.
Note that the PDC threshold of 80% is used for most drug classes.
However, this step could be modified to use another threshold.
Also, for most implementations, they round the PDC to 4 decimal places.*/

SELECT
  *,
  CASE WHEN ROUND(CAST(days_covered AS FLOAT) / CAST(days_in_tx_period AS FLOAT), 4) >= 0.8 THEN 1 ELSE 0 END AS is_adherent
FROM pdc;