-- Step 1. Insert 3 favorite movies into public.film

INSERT INTO public.film
(
    title,
    description,
    release_year,
    language_id,
    rental_duration,
    rental_rate,
    length,
    replacement_cost,
    rating,
    last_update,
    fulltext
)
SELECT
    'Ender''s Game'                                       AS title,
    'Young Ender Wiggin is recruited by the International Military to lead the fight against the Formics.' AS description,
    2013                                                  AS release_year,
    (SELECT language_id FROM public.language WHERE name = 'English' LIMIT 1) AS language_id,
    7                                                     AS rental_duration,
    4.99                                                  AS rental_rate,
    114                                                   AS length,
    19.99                                                 AS replacement_cost,
    'PG-13'                                               AS rating,
    CURRENT_DATE                                          AS last_update,
    TO_TSVECTOR('english', 'Ender''s Game Young Ender Wiggin') AS fulltext
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE f.title = 'Ender''s Game'
)
RETURNING film_id, title;

COMMIT;

INSERT INTO public.film
(
    title,
    description,
    release_year,
    language_id,
    rental_duration,
    rental_rate,
    length,
    replacement_cost,
    rating,
    last_update,
    fulltext
)
SELECT
    'Ready Player One',
    'When the creator of a virtual reality world dies, he leaves behind a contest for his fortune.',
    2018,
    (SELECT language_id FROM public.language WHERE name = 'English' LIMIT 1),
    14,
    9.99,
    140,
    19.99,
    'PG-13',
    CURRENT_DATE,
    TO_TSVECTOR('english', 'Ready Player One Virtual World Contest')
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE f.title = 'Ready Player One'
)
RETURNING film_id, title;

COMMIT;

INSERT INTO public.film
(
    title,
    description,
    release_year,
    language_id,
    rental_duration,
    rental_rate,
    length,
    replacement_cost,
    rating,
    last_update,
    fulltext
)
SELECT
    'The Gentlemen',
    'An American expat tries to sell off his profitable marijuana empire in London, triggering plots and schemes.',
    2019,
    (SELECT language_id FROM public.language WHERE name = 'English' LIMIT 1),
    21,
    19.99,
    113,
    19.99,
    'R',
    CURRENT_DATE,
    TO_TSVECTOR('english', 'The Gentlemen Marijuana London')
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE f.title = 'The Gentlemen'
)
RETURNING film_id, title;
-- Returning empty as we alredy created them (If not first run ofcourse) thus we don't make duplicates
COMMIT;


-- Step 2. Insert 6 real actors into public.actor

WITH new_actors AS (
    SELECT UNNEST(ARRAY[
        'Asa Butterfield',
        'Harrison Ford',
        'Tye Sheridan',
        'Olivia Cooke',
        'Matthew McConaughey',
        'Charlie Hunnam'
    ]) AS fullname
)
INSERT INTO public.actor
(
    first_name,
    last_name,
    last_update
)
SELECT
    SPLIT_PART(fullname, ' ', 1) AS first_name,
    SPLIT_PART(fullname, ' ', 2) AS last_name,
    CURRENT_DATE                 AS last_update
FROM new_actors na
WHERE NOT EXISTS (
    SELECT 1
    FROM public.actor a
    WHERE a.first_name = SPLIT_PART(na.fullname, ' ', 1)
      AND a.last_name  = SPLIT_PART(na.fullname, ' ', 2)
)
RETURNING actor_id, first_name, last_name;

COMMIT;


-- Step 3. Link each film with its real actors in public.film_actor

-- Ender’s Game
INSERT INTO public.film_actor
(
    actor_id,
    film_id,
    last_update
)
SELECT
    a.actor_id,
    f.film_id,
    CURRENT_DATE AS last_update
FROM public.actor a
JOIN public.film f ON f.title = 'Ender''s Game'
WHERE (a.first_name, a.last_name) IN (('Asa', 'Butterfield'), ('Harrison', 'Ford'))
  AND NOT EXISTS (
        SELECT 1 FROM public.film_actor fa
        WHERE fa.actor_id = a.actor_id
          AND fa.film_id  = f.film_id
    )
RETURNING actor_id, film_id;

COMMIT;

-- Ready Player One
INSERT INTO public.film_actor
(
    actor_id,
    film_id,
    last_update
)
SELECT
    a.actor_id,
    f.film_id,
    CURRENT_DATE
FROM public.actor a
JOIN public.film f ON f.title = 'Ready Player One'
WHERE (a.first_name, a.last_name) IN (('Tye', 'Sheridan'), ('Olivia', 'Cooke'))
  AND NOT EXISTS (
        SELECT 1 FROM public.film_actor fa
        WHERE fa.actor_id = a.actor_id
          AND fa.film_id  = f.film_id
    )
RETURNING actor_id, film_id;

COMMIT;

-- The Gentlemen
INSERT INTO public.film_actor
(
    actor_id,
    film_id,
    last_update
)
SELECT
    a.actor_id,
    f.film_id,
    CURRENT_DATE
FROM public.actor a
JOIN public.film f ON f.title = 'The Gentlemen'
WHERE (a.first_name, a.last_name) IN (('Matthew', 'McConaughey'), ('Charlie', 'Hunnam'))
  AND NOT EXISTS (
        SELECT 1 FROM public.film_actor fa
        WHERE fa.actor_id = a.actor_id
          AND fa.film_id  = f.film_id
    )
RETURNING actor_id, film_id;

COMMIT;


-- Step 4. Insert favorite movies into any store's inventory (store_id = 1)

INSERT INTO public.inventory
(
    film_id,
    store_id,
    last_update
)
SELECT
    f.film_id,
    1               AS store_id,
    CURRENT_DATE    AS last_update
FROM public.film f
WHERE f.title IN ('Ender''s Game', 'Ready Player One', 'The Gentlemen')
  AND NOT EXISTS (
        SELECT 1 FROM public.inventory i
        WHERE i.film_id = f.film_id
          AND i.store_id = 1
    )
RETURNING inventory_id, film_id, store_id;

COMMIT;


/*
Step 5: update exactly one existing customer who meets the 43+ criteria
Using MIN() directly inside aggregate eliminates the multi-row problem. Otherwise it couldn't take any random one row out of 514 existing (checked in other sql script)
*/

UPDATE public.customer c
SET first_name  = 'Alikhan',
    last_name   = 'Kaliyev',
    email       = 'alikhan.kaliyev@example.com',
    address_id  = (
                      SELECT address_id
                      FROM public.address
                      ORDER BY RANDOM()
                      LIMIT 1
                  ),
    last_update = CURRENT_DATE
WHERE c.customer_id = (
                          SELECT MIN(c2.customer_id)
                          FROM public.customer c2
                          WHERE (
                                    SELECT COUNT(DISTINCT r.rental_id)
                                    FROM public.rental r
                                    WHERE r.customer_id = c2.customer_id
                                ) >= 43
                            AND (
                                    SELECT COUNT(DISTINCT p.payment_id)
                                    FROM public.payment p
                                    WHERE p.customer_id = c2.customer_id
                                ) >= 43
                      )
RETURNING *;

COMMIT;


/*
Step 6: remove all records related to this customer except Customer and Inventory. Used 2 seperate deletes as in one CTE they would produce error, as second error statement
wouldn't see anything
*/

-- Delete from payment
WITH target_customer AS (
    SELECT customer_id
    FROM public.customer
    WHERE first_name = 'Alikhan'
      AND last_name  = 'Kaliyev'
    ORDER BY customer_id
    LIMIT 1
)
DELETE FROM public.payment
WHERE customer_id = (SELECT customer_id FROM target_customer);

COMMIT;

-- Delete from rental
WITH target_customer AS (
    SELECT customer_id
    FROM public.customer
    WHERE first_name = 'Alikhan'
      AND last_name  = 'Kaliyev'
    ORDER BY customer_id
    LIMIT 1
)
DELETE FROM public.rental
WHERE customer_id = (SELECT customer_id FROM target_customer);

COMMIT;


-- Step 7. Insert rental records for favorite movies

WITH cust AS (
    SELECT customer_id, store_id
    FROM public.customer
    WHERE first_name = 'Alikhan'
      AND last_name  = 'Kaliyev'
    ORDER BY customer_id
    LIMIT 1
),
inv AS (
    SELECT inventory_id
    FROM public.inventory i
    JOIN public.film f ON i.film_id = f.film_id
    WHERE f.title IN ('Ender''s Game', 'Ready Player One', 'The Gentlemen')
)
INSERT INTO public.rental
(
    rental_date,
    inventory_id,
    customer_id,
    staff_id,
    last_update
)
SELECT
    CURRENT_TIMESTAMP AS rental_date,
    i.inventory_id,
    c.customer_id,
    1                 AS staff_id,
    CURRENT_DATE      AS last_update
FROM cust c
CROSS JOIN inv i
RETURNING rental_id, inventory_id, customer_id;

COMMIT;


-- Step 8. Insert payments for each rental in the first half of 2017. NOTE: Payment table has no last_update column.

INSERT INTO public.payment
(
    customer_id,
    staff_id,
    rental_id,
    amount,
    payment_date
)
SELECT
    r.customer_id,
    1                                       AS staff_id,
    r.rental_id,
    CASE
        WHEN f.title = 'Ender''s Game'     THEN 4.99
        WHEN f.title = 'Ready Player One'  THEN 9.99
        WHEN f.title = 'The Gentlemen'     THEN 19.99
        ELSE 9.99
    END                                    AS amount,
    '2017-05-01'::timestamptz             AS payment_date
FROM public.rental r
JOIN public.inventory i ON r.inventory_id = i.inventory_id
JOIN public.film f      ON i.film_id      = f.film_id
JOIN public.customer c  ON r.customer_id  = c.customer_id
WHERE c.first_name = 'Alikhan'
  AND c.last_name  = 'Kaliyev'
  AND f.title IN ('Ender''s Game', 'Ready Player One', 'The Gentlemen')
RETURNING payment_id, amount, payment_date;

COMMIT;
