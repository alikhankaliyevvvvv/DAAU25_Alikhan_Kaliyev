--Create user with login only
CREATE USER rentaluser
WITH
LOGIN
PASSWORD 'rentalpassword';

--Allow DB connection only
GRANT CONNECT
ON DATABASE dvdrental
TO rentaluser;

--Grant SELECT on customer table
GRANT SELECT
ON TABLE public.customer
TO rentaluser;

--Test select permission
SELECT cu.customer_id,
cu.first_name,
cu.last_name
FROM public.customer AS cu;

--Create user group role
CREATE ROLE rental;

--Add user to group
GRANT rental TO rentaluser;

--Grant INSERT, UPDATE on rental table
GRANT INSERT,
UPDATE
ON TABLE public.rental
TO rental;

--For INSERT to be granted
GRANT USAGE,
      SELECT
ON SEQUENCE public.rental_rental_id_seq
TO rental;

--Chain of FK for UPDATE to work
GRANT SELECT 
ON TABLE public.rental 
TO rental;

GRANT SELECT
ON TABLE public.inventory
TO rental;

GRANT SELECT
ON TABLE public.customer
TO rental;

GRANT SELECT
ON TABLE public.staff
TO rental;


--And LOGIN
ALTER ROLE rental WITH LOGIN;

--Test INSERT under role
SET ROLE rentaluser;
SET ROLE rental;

INSERT INTO public.rental (
rental_date,
inventory_id,
customer_id,
staff_id
)
VALUES (
NOW(),
1,
1,
1
);
SELECT currval('public.rental_rental_id_seq');

--Test UPDATE under role
UPDATE public.rental AS rn
SET return_date = NOW()
WHERE rn.rental_id = 3;

RESET ROLE;

--Revoke INSERT from group
REVOKE INSERT
ON TABLE public.rental
FROM rental;

--Test denied INSERT
SET ROLE rentaluser;

INSERT INTO public.rental (
rental_date,
inventory_id,
customer_id,
staff_id
)
VALUES (
NOW(),
1,
1,
1
);

RESET ROLE;

--Create personalized customer role
--Customer must have rental and payment history
SELECT cu.customer_id,
cu.first_name,
cu.last_name
FROM public.customer AS cu
JOIN public.rental AS rn ON rn.customer_id = cu.customer_id
JOIN public.payment AS pm ON pm.customer_id = cu.customer_id
LIMIT 1;

--Example chosen customer (replace ids if needed)
--Suppose result: customer_id = 459, Tommy Collazo

CREATE ROLE client_Tommy_Collazo
WITH
LOGIN
PASSWORD 'clientpass';

--Grant CONNECT only
GRANT CONNECT
ON DATABASE dvdrental
TO client_Tommy_Collazo;



--Task 3

--Enable RLS
ALTER TABLE public.rental
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payment
    ENABLE ROW LEVEL SECURITY;

--Force RLS for consistency
ALTER TABLE public.rental
    FORCE ROW LEVEL SECURITY;

ALTER TABLE public.payment
    FORCE ROW LEVEL SECURITY;


--Customer: Tommy Collazo (customer_id = 459)
--Role: client_Tommy_Collazo

--Grant selects
GRANT SELECT ON public.customer TO client_Tommy_Collazo;
GRANT SELECT ON public.inventory TO client_Tommy_Collazo;
GRANT SELECT ON public.staff TO client_Tommy_Collazo;
GRANT SELECT ON public.rental TO client_Tommy_Collazo;
GRANT SELECT ON public.payment TO client_Tommy_Collazo;

--RLS policy for rental (SELECT)
CREATE POLICY rental_policy_client_Tommy_Collazo
ON public.rental
FOR SELECT
TO client_Tommy_Collazo
USING (customer_id = 459);

--RLS policy for payment (SELECT)
CREATE POLICY payment_policy_client_Tommy_Collazo
ON public.payment
FOR SELECT
TO client_Tommy_Collazo
USING (customer_id = 459);

ALTER TABLE public.customer ENABLE ROW LEVEL SECURITY;

CREATE POLICY customer_policy_client_Tommy_Collazo
ON public.customer
FOR SELECT
TO client_Tommy_Collazo
USING (customer_id = 459);

SET ROLE client_Tommy_Collazo;

--Test under client_Tommy_Collazo
SELECT *
FROM public.rental;

SELECT *
FROM public.payment;

RESET ROLE
