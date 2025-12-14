/*  
Task 1
Need to:
1) List the top 5 customers for each channel
2) Calculate a key performance indicator (KPI) called 'sales_percentage,' which represents the percentage of a customer's sales 
relative to the total sales within their respective channel

Format of columns:: 
Display the total sales amount with two decimal places
Display the sales percentage with four decimal places and include the percent sign (%) at the end
Display the result for each channel in descending order of sales

Aggregation (SUM) is used to calculate total sales per customer within each channel
Window functions are used to calculate the total sales per channel 
DENSE_RANK() is used to rank customers with allowing customers with equal sales values to have same rank
Filtering by rank is used to retrieve only the top 5 customers per channel
*/

WITH customer_channel_sales AS (
	SELECT
		ch.channel_id,
		ch.channel_desc,
		cu.cust_id,
		cu.cust_first_name,
		cu.cust_last_name,
		SUM(sa.amount_sold)                         AS customer_sales_amt,
		SUM(SUM(sa.amount_sold)) OVER (
			PARTITION BY ch.channel_id
		)                                           AS channel_total_sales_amt,
		DENSE_RANK() OVER (
			PARTITION BY ch.channel_id
			ORDER BY SUM(sa.amount_sold) DESC
		)                                           AS sales_rank
	FROM sh.sales sa
	INNER JOIN sh.customers cu
		ON sa.cust_id    = cu.cust_id
	INNER JOIN sh.channels ch
		ON sa.channel_id = ch.channel_id
	GROUP BY
		ch.channel_id,
		ch.channel_desc,
		cu.cust_id,
		cu.cust_first_name,
		cu.cust_last_name
)

SELECT
	channel_desc,
	cust_id,
	cust_first_name,
	cust_last_name,
	ROUND(customer_sales_amt, 2)                                       AS total_sales_amt,
	TO_CHAR(
		ROUND(
			(customer_sales_amt / channel_total_sales_amt) * 100,
			4
		),
		'FM999999990.0000'
	) || '%'                                                           AS sales_percentage
FROM customer_channel_sales
WHERE sales_rank <= 5
ORDER BY
	channel_desc,
	customer_sales_amt DESC;



/*  
Task 2
Need to:
1) Retreive total sales for all products in the !!Photo category!! in the !!Asian!! region for the year !!2000!!

Format of columns:
Display the sales amount with two decimal places
Display the result in descending order of 'YEAR_SUM'
For this report, consider exploring the use of the crosstab function. Additional details and guidance can be found at this link

Aggregation (SUM) is used to calculate total sales for products
The crosstab function is used to change how data outputs for the better report form (with quaters as from example, is it ok?)
A window function (SUM OVER) is used to calculate the overall yearly total (YEAR_SUM)
*/

--RUN ONCE:
--CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT *
FROM pg_extension
WHERE extname = 'tablefunc'; --check that works

SELECT
	ct.prod_name,
	ROUND(ct.q1, 2)                                   AS q1,
	ROUND(ct.q2, 2)                                   AS q2,
	ROUND(ct.q3, 2)                                   AS q3,
	ROUND(ct.q4, 2)                                   AS q4,
	ROUND(
		COALESCE(ct.q1, 0) +
		COALESCE(ct.q2, 0) +
		COALESCE(ct.q3, 0) +
		COALESCE(ct.q4, 0),
		2
	)                                                 AS year_sum
FROM crosstab (
	$$
	SELECT
		pr.prod_name,
		t.calendar_quarter_number,
		SUM(sa.amount_sold) AS sales_amt
	FROM sh.sales sa
	INNER JOIN sh.products pr
		ON sa.prod_id = pr.prod_id
	INNER JOIN sh.customers cu
		ON sa.cust_id = cu.cust_id
	INNER JOIN sh.countries co
		ON cu.country_id = co.country_id
	INNER JOIN sh.times t
		ON sa.time_id = t.time_id
	WHERE pr.prod_category        = 'Photo' AND
	      co.country_region       = 'Asia' AND
	      t.calendar_year         = 2000
	GROUP BY
		pr.prod_name,
		t.calendar_quarter_number
	ORDER BY
		pr.prod_name,
		t.calendar_quarter_number
	$$,
	$$
	SELECT 1 UNION ALL
	SELECT 2 UNION ALL
	SELECT 3 UNION ALL
	SELECT 4
	$$
) AS ct (
	prod_name VARCHAR,
	q1        NUMERIC,
	q2        NUMERIC,
	q3        NUMERIC,
	q4        NUMERIC
)
ORDER BY
	year_sum DESC;



/*  
Task 3
Need to:
1) Retrieve customers ranked among the top 300 by TOTAL sales separately for the years 1998, 1999, and 2001
2) Combine customers who ranked in the top 300 in at least one of these years
3) Categorize the selected customers based on their SALES CHANNELS
4) Perform separate sales calculations for each sales channel
5) Include in the report only purchases made on the channel specified

Format of columns:
- Display total sales with two decimal places

Aggregation (SUM) is used to calculate total sales
Window functions are used to rank customers by total sales separately for each year
Final aggregation is used at the customer and channel level, so that only channel purchases are counted

This one is complex, i am not sure i got it right:
1) take each year, find its top-300 via counting sum for each client and ranking them using DENSE_RANK, top is not apllying yet
2) take all these clients and make 'union' of all 3 years, all 3 top lists. Top is assured using <= 300, but due to this system, we have far more clients in output for no
3) group by client, channel. Example: if client was in top in 1998, in total calculations he will have sum of category for every other year too
So in final view we have sum = all sales of the customer per channel, and orderin in the channel by this sum
As we first have customers from top-300 of some year, at the end we will compute sum be categories, not total, so we will have far more rows than at the start
*/

WITH yearly_ranked_customers AS (
	SELECT
		t.calendar_year,
		cu.cust_id,
		DENSE_RANK() OVER (
			PARTITION BY t.calendar_year
			ORDER BY SUM(sa.amount_sold) DESC
		)                                           AS sales_rank
	FROM sh.sales sa
	INNER JOIN sh.times t
		ON sa.time_id = t.time_id
	INNER JOIN sh.customers cu
		ON sa.cust_id = cu.cust_id
	WHERE t.calendar_year IN (1998, 1999, 2001)
	GROUP BY
		t.calendar_year,
		cu.cust_id
),

top_customers AS (
	SELECT DISTINCT
		cust_id
	FROM yearly_ranked_customers
	WHERE sales_rank <= 300
)

SELECT
	ch.channel_desc,
	cu.cust_id,
	cu.cust_last_name,
	cu.cust_first_name,
	ROUND(SUM(sa.amount_sold), 2)                  AS amount_sold
FROM top_customers tc
INNER JOIN sh.customers cu
	ON tc.cust_id = cu.cust_id
INNER JOIN sh.sales sa
	ON sa.cust_id = cu.cust_id
INNER JOIN sh.times t
	ON sa.time_id = t.time_id
INNER JOIN sh.channels ch
	ON sa.channel_id = ch.channel_id
WHERE t.calendar_year IN (1998, 1999, 2001)
GROUP BY
	ch.channel_desc,
	cu.cust_id,
	cu.cust_last_name,
	cu.cust_first_name
ORDER BY
	ch.channel_desc,
	amount_sold DESC;



/*  
Task 4
Need to:
1) Generate a sales report for January, February, and March of 2000
2) Only Europe and Americas regions.

Format:
1) Display the result by months and by product category in alphabetical order.
2) Europe and America SEPARATELY (From sample)

Aggregation (SUM) is used to calculate total sales amounts
Conditional aggregation is used to calculate separate totals for Europe and Americas
Filtering by year, month, and region before aggreagation
The final output is ordered by calendar month and product category in alphabetical order
*/

SELECT
	t.calendar_month_desc,
	pr.prod_category,
	ROUND(
		SUM(sa.amount_sold) FILTER (
			WHERE co.country_region = 'Americas'
		),
		2
	)                                           AS americas_sales,
	ROUND(
		SUM(sa.amount_sold) FILTER (
			WHERE co.country_region = 'Europe'
		),
		2
	)                                           AS europe_sales
FROM sh.sales sa
INNER JOIN sh.times t
	ON sa.time_id = t.time_id
INNER JOIN sh.products pr
	ON sa.prod_id = pr.prod_id
INNER JOIN sh.customers cu
	ON sa.cust_id = cu.cust_id
INNER JOIN sh.countries co
	ON cu.country_id = co.country_id
WHERE t.calendar_year           = 2000 AND
      t.calendar_month_number IN (1, 2, 3) AND
      co.country_region       IN ('Americas', 'Europe')
GROUP BY
	t.calendar_month_desc,
	t.calendar_month_number,
	pr.prod_category
ORDER BY
	t.calendar_month_number,
	pr.prod_category;
