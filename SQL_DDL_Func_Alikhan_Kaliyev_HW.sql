--Task 1
CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS
SELECT 
	cat.name                                         AS category_name,
	SUM(pay.amount)::numeric(12,2)                   AS total_revenue,
	DATE_TRUNC('quarter', pay.payment_date)::date    AS quarter_start,
	EXTRACT(YEAR FROM pay.payment_date)::int         AS year
FROM public.payment         pay
INNER JOIN public.rental          rent ON rent.rental_id      = pay.rental_id
INNER JOIN public.inventory       inv  ON inv.inventory_id    = rent.inventory_id
INNER JOIN public.film_category   fcat ON fcat.film_id        = inv.film_id
INNER JOIN public.category        cat  ON cat.category_id     = fcat.category_id
WHERE DATE_TRUNC('quarter', pay.payment_date) = DATE_TRUNC('quarter', CURRENT_DATE)
GROUP BY 
	cat.name,
	DATE_TRUNC('quarter', pay.payment_date),
	EXTRACT(YEAR FROM pay.payment_date)
HAVING SUM(pay.amount) > 0
ORDER BY cat.name;

/*
Doesn't yield anything because we have only 2 quaters of 2017:
SELECT MIN(payment_date), MAX(payment_date)
FROM public.payment;
SELECT *
FROM public.sales_revenue_by_category_qtr;
*/



--Task 2
CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(
	p_date date DEFAULT CURRENT_DATE
)
RETURNS TABLE (
	category_name  text,
	total_revenue  numeric,
	quarter_start  date,
	year           int
)
LANGUAGE sql
AS
$$
SELECT cat.name                                         AS category_name,
       SUM(pay.amount)::numeric(12,2)                   AS total_revenue,
       DATE_TRUNC('quarter', pay.payment_date)::date    AS quarter_start,
       EXTRACT(YEAR FROM pay.payment_date)::int         AS year
FROM   public.payment         pay
INNER JOIN   public.rental          rent ON rent.rental_id      = pay.rental_id
INNER JOIN   public.inventory       inv  ON inv.inventory_id    = rent.inventory_id
INNER JOIN   public.film_category   fcat ON fcat.film_id        = inv.film_id
INNER JOIN   public.category        cat  ON cat.category_id     = fcat.category_id
WHERE  DATE_TRUNC('quarter', pay.payment_date) = DATE_TRUNC('quarter', p_date)
GROUP BY 
       cat.name,
       DATE_TRUNC('quarter', pay.payment_date),
       EXTRACT(YEAR FROM pay.payment_date)
HAVING SUM(pay.amount) > 0
ORDER BY cat.name;
$$;

/*
Task 2 validation
SELECT *
FROM public.get_sales_revenue_by_category_qtr('2017-03-01');
--yields results
*/



--Task 3
CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(
	p_countries text[]
)
RETURNS TABLE (
	country        text,
	film_title     text,
	rating         public.mpaa_rating,
	language       text,
	length         int,
	release_year   int
)
LANGUAGE plpgsql
AS
$$
DECLARE
	v_country     text;
	v_country_id  int;
BEGIN
	IF p_countries IS NULL OR array_length(p_countries, 1) IS NULL THEN
		RAISE EXCEPTION 'Parameter p_countries cannot be null or empty';
	END IF;

	FOREACH v_country IN ARRAY p_countries
	LOOP
		SELECT co.country_id
		INTO   v_country_id
		FROM   public.country co
		WHERE  co.country = v_country
		LIMIT  1;

		IF v_country_id IS NULL THEN
			RAISE EXCEPTION 'Country "%" not found in public.country', v_country;
		END IF;

		RETURN QUERY
		WITH film_rents AS (
			SELECT fi.film_id,
			       fi.title                                  AS film_title,
			       fi.rating                                 AS rating,
			       lang.name::text                           AS language,
			       fi.length::int                            AS length,
			       fi.release_year::int                      AS release_year,
			       COUNT(r.rental_id)::bigint                AS rentals_count
			FROM   public.rental    r
			INNER JOIN   public.inventory inv   ON inv.inventory_id  = r.inventory_id
			INNER JOIN   public.film      fi    ON fi.film_id         = inv.film_id
			INNER JOIN   public.language  lang  ON lang.language_id   = fi.language_id
			INNER JOIN   public.customer  cu    ON cu.customer_id      = r.customer_id
			INNER JOIN   public.address   ad    ON ad.address_id       = cu.address_id
			INNER JOIN   public.city      ci    ON ci.city_id          = ad.city_id
			WHERE  ci.country_id = v_country_id
			GROUP BY 
			       fi.film_id,
			       fi.title,
			       fi.rating,
			       lang.name,
			       fi.length,
			       fi.release_year
		)
		SELECT v_country                    AS country,
		       fr.film_title                AS film_title,
		       fr.rating                    AS rating,
		       fr.language                  AS language,
		       fr.length                    AS length,
		       fr.release_year              AS release_year
		FROM   film_rents fr
		ORDER BY fr.rentals_count DESC, fr.film_title
		LIMIT  1;
	END LOOP;

	RETURN;
END;
$$;

/* 
Task 3 Validation
SELECT *
FROM public.most_popular_films_by_countries(ARRAY['Afghanistan', 'Brazil', 'United States']);
*/



--Task 4
CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(
	p_title_pattern text
)
RETURNS TABLE (
	row_num        int,
	film_title     text,
	language_name  text,
	customer_name  text,
	rental_date    timestamptz
)
LANGUAGE plpgsql
AS
$$
BEGIN
	IF p_title_pattern IS NULL OR LENGTH(TRIM(p_title_pattern)) = 0 THEN
		RAISE EXCEPTION 'Parameter p_title_pattern cannot be null or empty';
	END IF;

	RETURN QUERY
	WITH matched_films AS (
		SELECT fi.film_id,
		       fi.title                                  AS film_title,
		       lang.name::text                           AS language_name
		FROM   public.film      fi
		INNER JOIN   public.language  lang ON lang.language_id = fi.language_id
		WHERE  fi.title ILIKE p_title_pattern
	),
	inv_status AS (
		SELECT mf.film_id,
		       mf.film_title,
		       mf.language_name,
		       inv.inventory_id
		FROM   matched_films mf
		INNER JOIN   public.inventory inv ON inv.film_id = mf.film_id
		WHERE  NOT EXISTS (
				SELECT 1
				FROM   public.rental r
				WHERE  r.inventory_id = inv.inventory_id
				AND    r.return_date IS NULL
			)
	),
	last_rental AS (
		SELECT invs.film_id,
		       invs.film_title,
		       invs.language_name,
		       cu.first_name || ' ' || cu.last_name       AS customer_name,
		       r.return_date                              AS rental_date,
		       ROW_NUMBER() OVER (ORDER BY invs.film_title, r.return_date)::int AS rn
		FROM   inv_status invs
		INNER JOIN   public.rental r       ON r.inventory_id  = invs.inventory_id
		INNER JOIN   public.customer cu    ON cu.customer_id   = r.customer_id
		WHERE  r.return_date IS NOT NULL
	)
	SELECT lr.rn            AS row_num,
	       lr.film_title    AS film_title,
	       lr.language_name AS language_name,
	       lr.customer_name AS customer_name,
	       lr.rental_date   AS rental_date
	FROM   last_rental lr
	ORDER  BY lr.rn;

	IF NOT FOUND THEN
		RAISE NOTICE 'No film was found, sorry :(';
	END IF;

	RETURN;
END;
$$;

/*
Validation
--Result
SELECT *
FROM public.films_in_stock_by_title('%love%');
--No result
SELECT *
FROM public.films_in_stock_by_title('%maggot%');
*/



--Task 5
--Adding Klingon ??, can be omitted but function will raise error
INSERT INTO public.language (name)
VALUES ('Klingon');

--Function itself
CREATE OR REPLACE FUNCTION public.new_movie(
	p_title         text,
	p_release_year  int  DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
	p_language_name text DEFAULT 'Klingon'
)
RETURNS int
LANGUAGE plpgsql
AS
$$
DECLARE
	v_language_id    int;
	v_existing_count int;
	v_new_film_id    int;
BEGIN
	IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
		RAISE EXCEPTION 'Movie title cannot be null or empty';
	END IF;

	-- find language ID
	SELECT lang.language_id
	INTO   v_language_id
	FROM   public.language lang
	WHERE  TRIM(lang.name) = TRIM(p_language_name)
	LIMIT  1;

	IF v_language_id IS NULL THEN
		RAISE EXCEPTION 'Language "%" does not exist in public.language', p_language_name;
	END IF;

	-- prevent duplicates: same title + same language
	SELECT COUNT(1)
	INTO   v_existing_count
	FROM   public.film fi
	WHERE  TRIM(LOWER(fi.title)) = TRIM(LOWER(p_title))
	AND    fi.language_id        = v_language_id;

	IF v_existing_count > 0 THEN
		RAISE EXCEPTION 'A film with title "%" already exists for language "%"', p_title, p_language_name;
	END IF;

	-- insert new film
	INSERT INTO public.film (
		title,
		description,
		release_year,
		language_id,
		rental_duration,
		rental_rate,
		replacement_cost,
		last_update,
		fulltext
	)
	VALUES (
		p_title,
		NULL,
		p_release_year,
		v_language_id,
		3,
		4.99,
		19.99,
		NOW(),
		to_tsvector('english', p_title)
	)
	RETURNING film_id INTO v_new_film_id;

	IF v_new_film_id IS NULL THEN
		RAISE EXCEPTION 'Failed to insert new film "%" due to unknown error', p_title;
	END IF;

	RETURN v_new_film_id;
END;
$$;


SELECT public.new_movie('The Blade of Qo''noS');
SELECT public.new_movie('New Action Film', 2024, 'English');
SELECT public.new_movie('Romantic Saga', NULL, 'French');

RESET ROLE;
SELECT current_user; --Task 6 extra validation

-- inventory_in_stock
-- Returns TRUE if inventory item is available, FALSE otherwise
CREATE OR REPLACE FUNCTION public.inventory_in_stock(
	p_inventory_id INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$$
DECLARE
	v_total_rentals INTEGER;
	v_open_rentals  INTEGER;
BEGIN
	SELECT COUNT(r.rental_id)
	INTO   v_total_rentals
	FROM   public.rental r
	WHERE  r.inventory_id = p_inventory_id;

	IF v_total_rentals = 0 THEN
		RETURN TRUE;
	END IF;

	SELECT COUNT(r.rental_id)
	INTO   v_open_rentals
	FROM   public.rental r
	WHERE  r.inventory_id = p_inventory_id AND
	       r.return_date IS NULL;

	RETURN v_open_rentals = 0;
END;
$$;


-- film_in_stock
-- Returns inventory IDs for a film in a store that are in stock
CREATE OR REPLACE FUNCTION public.film_in_stock(
	p_film_id  INTEGER,
	p_store_id INTEGER
)
RETURNS SETOF INTEGER
LANGUAGE sql
AS
$$
SELECT inv.inventory_id
FROM   public.inventory inv
WHERE  inv.film_id  = p_film_id AND
       inv.store_id = p_store_id AND
       public.inventory_in_stock(inv.inventory_id);
$$;


-- film_not_in_stock
-- Logical negation of film_in_stock, functionally redundant
CREATE OR REPLACE FUNCTION public.film_not_in_stock(
	p_film_id  INTEGER,
	p_store_id INTEGER
)
RETURNS SETOF INTEGER
LANGUAGE sql
AS
$$
SELECT inv.inventory_id
FROM   public.inventory inv
WHERE  inv.film_id  = p_film_id AND
       inv.store_id = p_store_id AND
       NOT public.inventory_in_stock(inv.inventory_id);
$$;


-- inventory_held_by_customer
-- Returns customer ID holding the inventory item, NULL if free
CREATE OR REPLACE FUNCTION public.inventory_held_by_customer(
	p_inventory_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS
$$
DECLARE
	v_customer_id INTEGER;
BEGIN
	SELECT r.customer_id
	INTO   v_customer_id
	FROM   public.rental r
	WHERE  r.inventory_id = p_inventory_id AND
	       r.return_date IS NULL
	LIMIT  1;

	RETURN v_customer_id;
END;
$$;


-- get_customer_balance
-- Calculates balance based on rentals, overdue fees, replacement cost and payments
CREATE OR REPLACE FUNCTION public.get_customer_balance(
	p_customer_id    INTEGER,
	p_effective_date TIMESTAMPTZ
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE
	v_rental_fees  NUMERIC := 0;
	v_overdue_fees NUMERIC := 0;
	v_payments     NUMERIC := 0;
BEGIN
	SELECT COALESCE(SUM(f.rental_rate), 0)
	INTO   v_rental_fees
	FROM   public.rental r
	INNER JOIN public.inventory inv ON inv.inventory_id = r.inventory_id
	INNER JOIN public.film f ON f.film_id = inv.film_id
	WHERE  r.customer_id = p_customer_id AND
	       r.rental_date <= p_effective_date;

	SELECT COALESCE(
		SUM(
			CASE
				WHEN r.return_date IS NULL THEN 0
				WHEN r.return_date - r.rental_date >
				     f.rental_duration * INTERVAL '2 day'
				THEN f.replacement_cost
				WHEN r.return_date - r.rental_date >
				     f.rental_duration * INTERVAL '1 day'
				THEN EXTRACT(
					DAY FROM (
						r.return_date - r.rental_date -
						f.rental_duration * INTERVAL '1 day'
					)
				)
				ELSE 0
			END
		), 0
	)
	INTO   v_overdue_fees
	FROM   public.rental r
	INNER JOIN public.inventory inv ON inv.inventory_id = r.inventory_id
	INNER JOIN public.film f ON f.film_id = inv.film_id
	WHERE  r.customer_id = p_customer_id AND
	       r.rental_date <= p_effective_date;

	SELECT COALESCE(SUM(p.amount), 0)
	INTO   v_payments
	FROM   public.payment p
	WHERE  p.customer_id = p_customer_id AND
	       p.payment_date <= p_effective_date;

	RETURN v_rental_fees + v_overdue_fees - v_payments;
END;
$$;


-- last_day
-- Returns last day of month for given timestamp
CREATE OR REPLACE FUNCTION public.last_day(
	p_date TIMESTAMPTZ
)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
STRICT
AS
$$
SELECT (date_trunc('month', p_date) + INTERVAL '1 month - 1 day')::DATE;
$$;


-- rewards_report
-- Returns customers who exceeded purchase count and amount in previous month
CREATE OR REPLACE FUNCTION public.rewards_report(
	min_monthly_purchases        INTEGER,
	min_dollar_amount_purchased NUMERIC
)
RETURNS SETOF public.customer
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE
	v_month_start DATE;
	v_month_end   DATE;
BEGIN
	IF min_monthly_purchases <= 0 THEN
		RAISE EXCEPTION 'Minimum monthly purchases must be > 0';
	END IF;

	IF min_dollar_amount_purchased <= 0 THEN
		RAISE EXCEPTION 'Minimum dollar amount must be > 0';
	END IF;

	v_month_start := date_trunc('month', CURRENT_DATE - INTERVAL '1 month');
	v_month_end   := v_month_start + INTERVAL '1 month - 1 day';

	RETURN QUERY
	SELECT c.customer_id,
	       c.store_id,
	       c.first_name,
	       c.last_name,
	       c.email,
	       c.address_id,
	       c.activebool,
	       c.create_date,
	       c.last_update,
	       c.active
	FROM   public.customer c
	INNER JOIN public.payment p ON p.customer_id = c.customer_id
	WHERE  p.payment_date BETWEEN v_month_start AND v_month_end
	GROUP BY
	       c.customer_id,
	       c.store_id,
	       c.first_name,
	       c.last_name,
	       c.email,
	       c.address_id,
	       c.activebool,
	       c.create_date,
	       c.last_update,
	       c.active
	HAVING SUM(p.amount) > min_dollar_amount_purchased AND
	       COUNT(p.payment_id) > min_monthly_purchases;
END;
$$;
