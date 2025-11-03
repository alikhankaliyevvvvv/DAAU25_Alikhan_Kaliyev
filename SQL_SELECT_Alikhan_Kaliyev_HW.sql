/*
TASK 1.1 - Animation movies released between 2017 and 2019
Requirement: show all animation movies with rate > 1, sorted alphabetically
Solution type: JOIN
Business logic interpretation:
- Category 'Animation'
- Release year between 2017 and 2019
- Rental rate greater than 1
- Ordered by title ASC
*/

--JOINS

SELECT 
    f.title                 AS movie_title,
    f.release_year          AS release_year,
    f.rental_rate           AS rental_rate,
    c.name                  AS category_name
FROM public.film                AS f
INNER JOIN public.film_category AS fc ON f.film_id = fc.film_id
INNER JOIN public.category      AS c  ON fc.category_id = c.category_id
WHERE
    c.name = 'Animation' AND
    f.release_year BETWEEN 2017 AND 2019 AND
    f.rental_rate > 1
ORDER BY
    f.title ASC;

/*
Pros: clear readability (joins are simple to understand), easy to change, 
Cons: triple join (harder to execute with bigger tables), not the fastest (considering theory, CTE is faster)
*/

--SUBQUERY

SELECT 
    f.title         AS movie_title,
    f.release_year  AS release_year,
    f.rental_rate   AS rental_rate
FROM public.film AS f
WHERE
    f.film_id IN (
        SELECT fc.film_id
        FROM public.film_category  AS fc
        INNER JOIN public.category AS c ON fc.category_id = c.category_id
        WHERE c.name = 'Animation'
    )
    AND f.release_year BETWEEN 2017 AND 2019 AND 
    f.rental_rate > 1
ORDER BY
    f.title ASC;

/*
Pros: still easy to do and understand, isolated category picking
Cons: Less effective with more data
*/

--CTE Solution

WITH animation_films AS (
    SELECT 
        fc.film_id
    FROM public.film_category  AS fc
    INNER JOIN public.category AS c ON fc.category_id = c.category_id
    WHERE c.name = 'Animation'
)
SELECT 
    f.title         AS movie_title,
    f.release_year  AS release_year,
    f.rental_rate   AS rental_rate
FROM public.film 		   AS f
INNER JOIN animation_films AS af ON f.film_id = af.film_id
WHERE
    f.release_year BETWEEN 2017 AND 2019 AND 
    f.rental_rate > 1
ORDER BY
    f.title ASC;

/*
Pros: Structured, expandable
Cons: For easy tasks, kinda too complicated
*/


/*
TASK 1.2 - Store revenue after March 2017
Requirement: calculate total revenue earned by each rental store since April 2017
Solution type: JOIN with aggregation
Business logic interpretation:
- Include all rentals after 2017-03-31
- Calculate SUM(payment.amount) as revenue
- Combine address and address2 into one column
- Group by store
- Sort by revenue DESC
*/

--JOINS

SELECT 
    s.store_id                                           AS store_id,
    (a.address || ' ' || COALESCE(a.address2, ''))       AS full_address,
    SUM(p.amount)                                        AS total_revenue
FROM public.store           AS s
INNER JOIN public.staff     AS st ON s.store_id = st.store_id
INNER JOIN public.payment   AS p  ON st.staff_id = p.staff_id
INNER JOIN public.address   AS a  ON s.address_id = a.address_id
WHERE
    p.payment_date > '2017-03-31'
GROUP BY
    s.store_id,
    a.address,
    a.address2
ORDER BY
    total_revenue DESC;

/*
Pros: simple and readable, logic clear by joins
Cons: SUM might double-count if staff-store relation changes in future
*/


--SUBQUERY

SELECT 
    s.store_id                           AS store_id,
    (a.address || ' ' || COALESCE(a.address2, '')) AS full_address,
    (
        SELECT SUM(p.amount)
        FROM public.payment AS p
        INNER JOIN public.staff AS st ON p.staff_id = st.staff_id
        WHERE st.store_id = s.store_id
          AND p.payment_date > '2017-03-31'
    ) AS total_revenue
FROM public.store AS s
INNER JOIN public.address AS a ON s.address_id = a.address_id
ORDER BY
    total_revenue DESC;

/*
Pros: self-contained and intuitive
Cons: correlated subquery (less efficient on large data)
*/


--CTE Solution

WITH payments_after_2017 AS (
    SELECT 
        st.store_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment AS p
    INNER JOIN public.staff AS st ON p.staff_id = st.staff_id
    WHERE
        p.payment_date > '2017-03-31'
    GROUP BY
        st.store_id
)
SELECT 
    s.store_id                                       AS store_id,
    (a.address || ' ' || COALESCE(a.address2, ''))   AS full_address,
    pa.total_revenue                                 AS total_revenue
FROM public.store AS s
INNER JOIN public.address      AS a  ON s.address_id = a.address_id
INNER JOIN payments_after_2017 AS pa ON s.store_id = pa.store_id
ORDER BY
    pa.total_revenue DESC;

/*
Pros: very readable, logic split into clear parts
Cons: slightly verbose for a simple aggregation
*/



/*
TASK 1.3 - Top-5 actors by number of movies (released after 2015)
Requirement: show top 5 actors by number of movies they took part in, released after 2015
Solution type: JOIN / SUBQUERY / CTE
Business logic interpretation:
- Include only films released after 2015
- Count how many movies each actor participated in
- Sort by number_of_movies DESC
- Limit to 5 actors
- Columns: first_name, last_name, number_of_movies
*/

--JOINS

SELECT 
    a.first_name               AS first_name,
    a.last_name                AS last_name,
    COUNT(fa.film_id)          AS number_of_movies
FROM public.actor              AS a
INNER JOIN public.film_actor   AS fa ON a.actor_id = fa.actor_id
INNER JOIN public.film         AS f  ON fa.film_id = f.film_id
WHERE
    f.release_year > 2015
GROUP BY
    a.first_name,
    a.last_name
ORDER BY
    number_of_movies DESC
LIMIT 5;

/*
Pros: clear and efficient, simple aggregation
Cons: not modular — harder to reuse logic
*/


--SUBQUERY

SELECT 
    a.first_name                AS first_name,
    a.last_name                 AS last_name,
    (
        SELECT COUNT(fa.film_id)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f ON fa.film_id = f.film_id
        WHERE 
            fa.actor_id = a.actor_id AND
            f.release_year > 2015
    ) AS number_of_movies
FROM public.actor AS a
ORDER BY
    number_of_movies DESC
LIMIT 5;

/*
Pros: straightforward logic, readable isolation of filtering logic
Cons: correlated subquery may slow down on large datasets
*/


--CTE Solution

WITH films_after_2015 AS (
    SELECT 
        f.film_id
    FROM public.film AS f
    WHERE
        f.release_year > 2015
),
actor_movie_count AS (
    SELECT 
        fa.actor_id,
        COUNT(fa.film_id) AS number_of_movies
    FROM public.film_actor AS fa
    INNER JOIN films_after_2015 AS f15 ON fa.film_id = f15.film_id
    GROUP BY
        fa.actor_id
)
SELECT 
    a.first_name          AS first_name,
    a.last_name           AS last_name,
    amc.number_of_movies  AS number_of_movies
FROM public.actor AS a
INNER JOIN actor_movie_count 	AS amc ON a.actor_id = amc.actor_id
ORDER BY
    amc.number_of_movies DESC
LIMIT 5;

/*
Pros: modular, clean separation of logic, easy to expand
Cons: slightly more verbose for such a small query
*/



/*
TASK 1.4 - Number of Drama, Travel, and Documentary movies per year
Requirement: show number of movies per year for genres Drama, Travel, and Documentary
Solution type: JOIN / SUBQUERY / CTE
Business logic interpretation:
- Include only categories 'Drama', 'Travel', and 'Documentary'
- Count number of films per category and per year
- Show columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies
- Handle NULL values (if a genre missing in a given year, show 0)
- Sort by release_year DESC
*/

--JOINS

SELECT 
    f.release_year                                    AS release_year,
    SUM(CASE WHEN c.name = 'Drama'        THEN 1 ELSE 0 END)         AS number_of_drama_movies,
    SUM(CASE WHEN c.name = 'Travel'       THEN 1 ELSE 0 END)         AS number_of_travel_movies,
    SUM(CASE WHEN c.name = 'Documentary'  THEN 1 ELSE 0 END)         AS number_of_documentary_movies
FROM public.film                 AS f
INNER JOIN public.film_category  AS fc ON f.film_id      = fc.film_id
INNER JOIN public.category       AS c  ON fc.category_id = c.category_id
WHERE
    c.name IN ('Drama', 'Travel', 'Documentary')
GROUP BY
    f.release_year
ORDER BY
    f.release_year DESC;

/*
Pros: compact and clear, easy to understand
Cons: if category data incomplete, missing years might appear empty
*/


--SUBQUERY

SELECT 
    fy.release_year                                   AS release_year,
    COALESCE((
        SELECT COUNT(*) 
        FROM public.film_category AS fc
        INNER JOIN public.film AS f ON fc.film_id = f.film_id
        INNER JOIN public.category AS c ON fc.category_id = c.category_id
        WHERE c.name = 'Drama' AND f.release_year = fy.release_year
    ), 0)                                             AS number_of_drama_movies,
    COALESCE((
        SELECT COUNT(*) 
        FROM public.film_category AS fc
        INNER JOIN public.film AS f ON fc.film_id = f.film_id
        INNER JOIN public.category AS c ON fc.category_id = c.category_id
        WHERE c.name = 'Travel' AND f.release_year = fy.release_year
    ), 0)                                             AS number_of_travel_movies,
    COALESCE((
        SELECT COUNT(*) 
        FROM public.film_category AS fc
        INNER JOIN public.film AS f ON fc.film_id = f.film_id
        INNER JOIN public.category AS c ON fc.category_id = c.category_id
        WHERE c.name = 'Documentary' AND f.release_year = fy.release_year
    ), 0)                                             AS number_of_documentary_movies
FROM (
    SELECT DISTINCT release_year
    FROM public.film
) AS fy
ORDER BY
    fy.release_year DESC;

/*
Pros: easy to follow, each category isolated
Cons: multiple subqueries per year — inefficient on large datasets
*/


--CTE Solution

WITH categorized_films AS (
    SELECT 
        f.release_year,
        c.name AS category_name
    FROM public.film AS f
    INNER JOIN public.film_category AS fc ON f.film_id      = fc.film_id
    INNER JOIN public.category      AS c  ON fc.category_id = c.category_id
    WHERE
        c.name IN ('Drama', 'Travel', 'Documentary')
),
aggregated AS (
    SELECT 
        release_year,
        SUM(CASE WHEN category_name = 'Drama'        THEN 1 ELSE 0 END) AS number_of_drama_movies,
        SUM(CASE WHEN category_name = 'Travel'       THEN 1 ELSE 0 END) AS number_of_travel_movies,
        SUM(CASE WHEN category_name = 'Documentary'  THEN 1 ELSE 0 END) AS number_of_documentary_movies
    FROM categorized_films
    GROUP BY release_year
)
SELECT 
    release_year,
    COALESCE(number_of_drama_movies, 0)        AS number_of_drama_movies,
    COALESCE(number_of_travel_movies, 0)       AS number_of_travel_movies,
    COALESCE(number_of_documentary_movies, 0)  AS number_of_documentary_movies
FROM aggregated
ORDER BY
    release_year DESC;

/*
Pros: very readable and expandable, ideal for multi-step logic
Cons: slightly verbose, but best suited for maintainability
*/



/*
TASK 2.1 - Top 3 employees by revenue in 2017
Requirement: show which 3 employees generated the most revenue in 2017
Solution type: JOIN / SUBQUERY / CTE
Business logic interpretation:
- Only payments with payment_date in 2017
- Each payment is linked to the staff who processed it
- Staff can work in different stores; show the last known store (based on latest payment)
- Columns: staff_id, first_name, last_name, store_id, total_revenue
*/

--JOINS

SELECT 
    st.staff_id                                  AS staff_id,
    st.first_name                                AS first_name,
    st.last_name                                 AS last_name,
    (
        SELECT s.store_id
        FROM public.store AS s
        INNER JOIN public.staff AS st2 ON s.store_id = st2.store_id
        WHERE st2.staff_id = st.staff_id
        ORDER BY st2.last_update DESC
        LIMIT 1
    )                                            AS store_id,
    SUM(p.amount)                                AS total_revenue
FROM public.payment  AS p
INNER JOIN public.staff AS st
    ON p.staff_id = st.staff_id
WHERE 
    EXTRACT(YEAR FROM p.payment_date) = 2017
GROUP BY
    st.staff_id, st.first_name, st.last_name
ORDER BY
    total_revenue DESC
LIMIT 3;

/*
Pros: straightforward aggregation, simple filtering
Cons: small subquery for last store per staff (but readable)
*/


--SUBQUERY

SELECT 
    staff_id,
    first_name,
    last_name,
    (
        SELECT s.store_id
        FROM public.store AS s
        INNER JOIN public.staff AS st2 ON s.store_id = st2.store_id
        WHERE st2.staff_id = staff.staff_id
        ORDER BY st2.last_update DESC
        LIMIT 1
    ) AS store_id,
    total_revenue
FROM (
    SELECT 
        st.staff_id,
        st.first_name,
        st.last_name,
        SUM(p.amount) AS total_revenue
    FROM public.payment AS p
    INNER JOIN public.staff AS st ON p.staff_id = st.staff_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY st.staff_id, st.first_name, st.last_name
) AS staff
ORDER BY
    total_revenue DESC
LIMIT 3;

/*
Pros: nested approach makes logic clearer
Cons: double aggregation nesting, slightly less performant
*/


--CTE Solution

WITH staff_revenue_2017 AS (
    SELECT 
        st.staff_id,
        st.first_name,
        st.last_name,
        SUM(p.amount) AS total_revenue
    FROM public.payment AS p
    INNER JOIN public.staff AS st ON p.staff_id = st.staff_id
    WHERE 
        EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY 
        st.staff_id, st.first_name, st.last_name
),
last_store AS (
    SELECT DISTINCT ON (st.staff_id)
        st.staff_id,
        st.store_id
    FROM public.staff AS st
    ORDER BY 
        st.staff_id,
        st.last_update DESC
)
SELECT 
    sr.staff_id,
    sr.first_name,
    sr.last_name,
    ls.store_id,
    sr.total_revenue
FROM staff_revenue_2017 AS sr
INNER JOIN last_store AS ls ON sr.staff_id = ls.staff_id
ORDER BY
    sr.total_revenue DESC
LIMIT 3;

/*
Pros: clean modular design, best readability
Cons: slightly verbose for simple analytics
*/



/*
TASK 2.2 - Top 5 most rented movies and expected audience age
Requirement: show which 5 movies were rented the most and the expected audience age based on MPAA rating
Solution type: JOIN / SUBQUERY / CTE
Business logic interpretation:
- Count number of rentals per film
- Sort descending and limit to top 5
- Include Motion Picture Association rating to estimate audience age
- Expected age mapping (approximation):
    G     →  All Ages (~6)
    PG    →  10+
    PG-13 →  13+
    R     →  17+
    NC-17 →  18+
- Columns: title, number_of_rentals, rating, expected_age
*/

--JOINS

SELECT 
    f.title                                     AS movie_title,
    f.rating                                    AS rating,
    COUNT(r.rental_id)                          AS number_of_rentals,
    CASE 
        WHEN f.rating = 'G'      THEN '6+'
        WHEN f.rating = 'PG'     THEN '10+'
        WHEN f.rating = 'PG-13'  THEN '13+'
        WHEN f.rating = 'R'      THEN '17+'
        WHEN f.rating = 'NC-17'  THEN '18+'
        ELSE 'Unknown'
    END                                         AS expected_age
FROM public.film              AS f
INNER JOIN public.inventory   AS i ON f.film_id      = i.film_id
INNER JOIN public.rental      AS r ON i.inventory_id = r.inventory_id
GROUP BY 
    f.title, f.rating
ORDER BY 
    number_of_rentals DESC
LIMIT 5;

/*
Pros: direct and efficient, easy to expand
Cons: none significant, classic pattern
*/


--SUBQUERY

SELECT 
    f.title                         AS movie_title,
    f.rating                        AS rating,
    (
        SELECT COUNT(*)
        FROM public.rental AS r
        INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
        WHERE i.film_id = f.film_id
    )                               AS number_of_rentals,
    CASE 
        WHEN f.rating = 'G'      THEN '6+'
        WHEN f.rating = 'PG'     THEN '10+'
        WHEN f.rating = 'PG-13'  THEN '13+'
        WHEN f.rating = 'R'      THEN '17+'
        WHEN f.rating = 'NC-17'  THEN '18+'
        ELSE 'Unknown'
    END                             AS expected_age
FROM public.film AS f
ORDER BY
    number_of_rentals DESC
LIMIT 5;

/*
Pros: intuitive, category calculation isolated
Cons: correlated subquery per film (slower)
*/


--CTE Solution

WITH rental_counts AS (
    SELECT 
        i.film_id,
        COUNT(r.rental_id) AS number_of_rentals
    FROM public.rental AS r
    INNER JOIN public.inventory AS i ON r.inventory_id = i.inventory_id
    GROUP BY i.film_id
)
SELECT 
    f.title                         AS movie_title,
    f.rating                        AS rating,
    rc.number_of_rentals            AS number_of_rentals,
    CASE 
        WHEN f.rating = 'G'      THEN '6+'
        WHEN f.rating = 'PG'     THEN '10+'
        WHEN f.rating = 'PG-13'  THEN '13+'
        WHEN f.rating = 'R'      THEN '17+'
        WHEN f.rating = 'NC-17'  THEN '18+'
        ELSE 'Unknown'
    END                             AS expected_age
FROM public.film AS f
INNER JOIN rental_counts AS rc ON f.film_id = rc.film_id
ORDER BY
    rc.number_of_rentals DESC
LIMIT 5;

/*
Pros: modular and scalable, best suited for reuse
Cons: slightly overengineered for simple count
*/


/*
TASK 3.V1 - Actors inactivity based on gap between latest release_year and current year
Requirement: show for each actor the number of years since their last released movie
Solution type: JOIN / SUBQUERY / CTE
Business logic interpretation:
- Find max(release_year) for each actor
- Compare with current year (EXTRACT(YEAR FROM CURRENT_DATE))
- Columns: first_name, last_name, last_movie_year, inactivity_years
*/

--JOINS

SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    MAX(f.release_year)                              AS last_movie_year,
    EXTRACT(YEAR FROM CURRENT_DATE) - MAX(f.release_year) AS inactivity_years
FROM public.actor AS a
INNER JOIN public.film_actor AS fa ON a.actor_id = fa.actor_id
INNER JOIN public.film       AS f  ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY inactivity_years DESC;

/*
Pros: simple aggregation, very readable
Cons: direct table scan (can be slow on huge dataset)
*/


--SUBQUERY

SELECT 
    a.actor_id,
    a.first_name,
    a.last_name,
    (
        SELECT MAX(f.release_year)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f ON fa.film_id = f.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS last_movie_year,
    EXTRACT(YEAR FROM CURRENT_DATE) - (
        SELECT MAX(f.release_year)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f ON fa.film_id = f.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS inactivity_years
FROM public.actor AS a
ORDER BY inactivity_years DESC;

/*
Pros: isolates each actor's history in subquery
Cons: many subqueries, less efficient on large tables
*/


--CTE Solution

WITH actor_latest_movie AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        MAX(f.release_year) AS last_movie_year
    FROM public.actor AS a
    INNER JOIN public.film_actor AS fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film 		 AS f  ON fa.film_id = f.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT 
    actor_id,
    first_name,
    last_name,
    last_movie_year,
    EXTRACT(YEAR FROM CURRENT_DATE) - last_movie_year AS inactivity_years
FROM actor_latest_movie
ORDER BY inactivity_years DESC;

/*
Pros: clean, extendable, easy to reuse
Cons: for this simple task, adds one extra step
*/


/*
TASK 3.V2 - Actors inactivity based on gaps between sequential films
Requirement: calculate the largest gap (in years) between two consecutive release years per actor
Solution type: JOIN / SUBQUERY / CTE
Business logic interpretation:
- Each actor can have multiple films
- We need to find the biggest difference in years between any two of their films
- Only release_years are used
- Return: actor_id, first_name, last_name, max_gap_years
- Sort by max_gap_years DESC
- No window functions are allowed
*/


--JOIN SOLUTION

SELECT 
    a.actor_id                       AS actor_id,
    a.first_name                     AS first_name,
    a.last_name                      AS last_name,
    MAX(ABS(f1.release_year - f2.release_year)) AS max_gap_years
FROM public.actor AS a
INNER JOIN public.film_actor AS fa1 ON a.actor_id  = fa1.actor_id
INNER JOIN public.film 		 AS f1  ON fa1.film_id = f1.film_id
INNER JOIN public.film_actor AS fa2 ON a.actor_id  = fa2.actor_id
INNER JOIN public.film 		 AS f2  ON fa2.film_id = f2.film_id
WHERE
    f1.release_year < f2.release_year
GROUP BY
    a.actor_id,
    a.first_name,
    a.last_name
ORDER BY
    max_gap_years DESC;

/*
Pros: clear, no window functions, uses standard JOIN logic
Cons: expensive (self-join on large film sets), duplicates filtered by condition
*/


--SUBQUERY SOLUTION

SELECT 
    a.actor_id               AS actor_id,
    a.first_name             AS first_name,
    a.last_name              AS last_name,
    (
        SELECT 
            MAX(ABS(f1.release_year - f2.release_year))
        FROM public.film_actor AS fa1
        INNER JOIN public.film 		 AS f1  ON fa1.film_id  = f1.film_id
        INNER JOIN public.film_actor AS fa2 ON fa1.actor_id = fa2.actor_id
        INNER JOIN public.film 		 AS f2  ON fa2.film_id  = f2.film_id
        WHERE
            fa1.actor_id = a.actor_id AND
            f1.release_year < f2.release_year
    ) AS max_gap_years
FROM public.actor AS a
ORDER BY
    max_gap_years DESC;

/*
Pros: simpler logic, self-contained per actor
Cons: correlated subquery (executed per actor), slower on big tables
*/


--CTE SOLUTION

WITH actor_films AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        f.release_year
    FROM public.actor AS a  
    INNER JOIN public.film_actor AS fa ON a.actor_id   = fa.actor_id
    INNER JOIN public.film 		 AS f  ON fa.film_id   = f.film_id
),
actor_gaps AS (
    SELECT 
        af1.actor_id,
        af1.first_name,
        af1.last_name,
        ABS(af1.release_year - af2.release_year) AS year_gap
    FROM actor_films AS af1
    INNER JOIN actor_films 	     AS af2 ON af1.actor_id = af2.actor_id
       AND af1.release_year < af2.release_year
)
SELECT 
    actor_id,
    first_name,
    last_name,
    MAX(year_gap) AS max_gap_years
FROM actor_gaps
GROUP BY
    actor_id,
    first_name,
    last_name
ORDER BY
    max_gap_years DESC;

/*
Pros: structured and modular, reusable for further analysis
Cons: less performant (two-level self-join), but clean and fully compliant
*/
