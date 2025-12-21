WITH sales_agg AS (
	SELECT
		co.country_region,
		t.calendar_year,
		ch.channel_desc,
		SUM(sa.amount_sold)                              AS amount_sold
	FROM sh.sales      sa
	INNER JOIN sh.times     t  ON t.time_id     = sa.time_id
	INNER JOIN sh.channels  ch ON ch.channel_id = sa.channel_id
	INNER JOIN sh.customers cu ON cu.cust_id    = sa.cust_id
	INNER JOIN sh.countries co ON co.country_id = cu.country_id
	WHERE t.calendar_year BETWEEN 1998 AND 2001
	  AND co.country_region IN ('Americas', 'Asia', 'Europe')
	GROUP BY
		co.country_region,
		t.calendar_year,
		ch.channel_desc
),

sales_pct AS (
	SELECT
		country_region,
		calendar_year,
		channel_desc,
		amount_sold,

		ROUND(
			amount_sold
			/ SUM(amount_sold) OVER (
				PARTITION BY country_region, calendar_year
				ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
			) * 100,
			2
		)                                                AS pct_by_channels
	FROM sales_agg
),

sales_with_prev AS (
	SELECT
		country_region,
		calendar_year,
		channel_desc,
		amount_sold,
		pct_by_channels,

		LAG(pct_by_channels) OVER (
			PARTITION BY country_region, channel_desc
			ORDER BY calendar_year
			ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING
		)                                                AS pct_previous_period
	FROM sales_pct
)

SELECT
	country_region,
	calendar_year,
	channel_desc,
	amount_sold,
	pct_by_channels         AS "% BY CHANNELS",
	pct_previous_period     AS "% PREVIOUS PERIOD",
	ROUND(
		pct_by_channels - pct_previous_period,
		2
	)                        AS "% DIFF"
FROM sales_with_prev
WHERE calendar_year BETWEEN 1999 AND 2001
ORDER BY
	country_region,
	calendar_year,
	channel_desc;



WITH daily_sales AS (
	SELECT
		t.calendar_week_number,
		t.time_id::date                      AS time_id,
		t.day_name,
		SUM(sa.amount_sold)                  AS sales
	FROM sh.sales sa
	INNER JOIN sh.times t
		ON t.time_id = sa.time_id
	WHERE t.calendar_year = 1999
	  AND t.calendar_week_number IN (49, 50, 51)
	GROUP BY
		t.calendar_week_number,
		t.time_id,
		t.day_name
),

base_calc AS (
	SELECT
		calendar_week_number,
		time_id,
		day_name,
		sales,

		-- cumulative sum per week
		SUM(sales) OVER (
			PARTITION BY calendar_week_number
			ORDER BY time_id
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
		)                                       AS cum_sum,

		-- helper values for centered logic
		SUM(sales) OVER (
			ORDER BY time_id
			ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING
		)                                       AS sum_mon,

		COUNT(*) OVER (
			ORDER BY time_id
			ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING
		)                                       AS cnt_mon,

		SUM(sales) OVER (
			ORDER BY time_id
			ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING
		)                                       AS sum_fri,

		COUNT(*) OVER (
			ORDER BY time_id
			ROWS BETWEEN 1 PRECEDING AND 2 FOLLOWING
		)                                       AS cnt_fri,

		SUM(sales) OVER (
			ORDER BY time_id
			ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
		)                                       AS sum_std,

		COUNT(*) OVER (
			ORDER BY time_id
			ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
		)                                       AS cnt_std
	FROM daily_sales
)

SELECT
	calendar_week_number,
	time_id,
	day_name,
	sales,
	cum_sum,

	ROUND(
		CASE
			WHEN day_name = 'Monday'
				THEN sum_mon / cnt_mon
			WHEN day_name = 'Friday'
				THEN sum_fri / cnt_fri
			ELSE
				sum_std / cnt_std
		END,
		2
	) AS centered_3_day_avg

FROM base_calc
ORDER BY
	calendar_week_number,
	time_id;

/*
ROWS is used because the calculation that depends on the exact order of rows. Each row is counted one by one, even if multiple rows have the same value
 */

SELECT
    ch.channel_desc,
    t.calendar_year,
    t.time_id,
    SUM(sa.amount_sold) AS daily_sales,

    SUM(SUM(sa.amount_sold)) OVER (
        PARTITION BY ch.channel_desc, t.calendar_year
        ORDER BY t.time_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_sales_by_channel
FROM sh.sales sa
JOIN sh.channels ch ON ch.channel_id = sa.channel_id
JOIN sh.times t     ON t.time_id     = sa.time_id
WHERE t.calendar_year = 1999
GROUP BY
    ch.channel_desc,
    t.calendar_year,
    t.time_id
ORDER BY
    ch.channel_desc,
    t.time_id;
    
/*
RANGE is used because the calculation depends on values, like dates or numbers. All rows with values inside the range are included and not just as a fixed number of rows   
*/
    
SELECT
    t.time_id,
    SUM(sa.amount_sold) AS daily_sales,

    SUM(SUM(sa.amount_sold)) OVER (
        ORDER BY t.time_id
        RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
    ) AS last_7_days_sales
FROM sh.sales sa
JOIN sh.times t ON t.time_id = sa.time_id
WHERE t.calendar_year = 1999
GROUP BY
    t.time_id
ORDER BY
    t.time_id;
    
/*
GROUPS is used because rows with the same ORDER BY value should be treated as one group. This prevents splitting rows that have the same rank or value
*/
    
SELECT
    p.prod_category,
    p.prod_list_price,
    SUM(sa.amount_sold) AS category_sales,

    SUM(SUM(sa.amount_sold)) OVER (
        ORDER BY p.prod_list_price
        GROUPS BETWEEN CURRENT ROW AND 1 FOLLOWING
    ) AS current_and_next_price_group_sales
FROM sh.sales sa
JOIN sh.products p ON p.prod_id = sa.prod_id
WHERE p.prod_list_price IS NOT NULL
GROUP BY
    p.prod_category,
    p.prod_list_price
ORDER BY
    p.prod_list_price;


