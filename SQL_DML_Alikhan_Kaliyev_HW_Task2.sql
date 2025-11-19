SET search_path TO public;

-- Step 1.
CREATE TABLE IF NOT EXISTS public.table_to_delete AS
SELECT
    'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::INT) AS x;

/*
Statistics 1:
Updated Rows	10000000
Execute time	20s
Start time	Mon Nov 10 22:01:05 QYZT 2025
Finish time	Mon Nov 10 22:01:26 QYZT 2025
*/

-- Step 2.
SELECT
    table_schema,
    table_name,
    row_estimate,
    pg_size_pretty(total_bytes) AS total,
    pg_size_pretty(index_bytes) AS index_size,
    pg_size_pretty(toast_bytes) AS toast_size,
    pg_size_pretty(table_bytes) AS table_size
FROM (
         SELECT *,
                total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
         FROM (
                  SELECT
                      c.oid,
                      nspname AS table_schema,
                      relname AS table_name,
                      c.reltuples AS row_estimate,
                      pg_total_relation_size(c.oid) AS total_bytes,
                      pg_indexes_size(c.oid)       AS index_bytes,
                      pg_total_relation_size(reltoastrelid) AS toast_bytes
                  FROM pg_class c
                           LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                  WHERE relkind = 'r'
              ) a
     ) a
WHERE table_name LIKE '%table_to_delete%';
-- 575 MB total


-- Step 3.
DELETE FROM public.table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string', '')::INT % 3 = 0;

-- a) Execute time	8.4s

SELECT
    table_schema,
    table_name,
    row_estimate,
    pg_size_pretty(total_bytes) AS total,
    pg_size_pretty(index_bytes) AS index_size,
    pg_size_pretty(toast_bytes) AS toast_size,
    pg_size_pretty(table_bytes) AS table_size
FROM (
         SELECT *,
                total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
         FROM (
                  SELECT
                      c.oid,
                      nspname AS table_schema,
                      relname AS table_name,
                      c.reltuples AS row_estimate,
                      pg_total_relation_size(c.oid) AS total_bytes,
                      pg_indexes_size(c.oid)       AS index_bytes,
                      pg_total_relation_size(reltoastrelid) AS toast_bytes
                  FROM pg_class c
                           LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                  WHERE relkind = 'r'
              ) a
     ) a
WHERE table_name LIKE '%table_to_delete%';

-- b) it uses same space, as before the delete. The reason - we only make our tuples dead, so they still consume space

-- Step 3c. Run VACUUM FULL VERBOSE to reclaim space
VACUUM FULL VERBOSE public.table_to_delete;
/*
d)"After VACUUM FULL" sizes: 574 MB
Only 1 MB difference
So VACUUM did some job, but difference is slight, because we have very simple table
and our delete and vacuum process yield not such different results, with some space still 
being occupied even after both operations, even though we deleted 1/3
*/

-- Step 3e. Recreate the table for TRUNCATE test
DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT
    'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::INT) AS x;

-- Step 4. Perform TRUNCATE and compare
TRUNCATE TABLE public.table_to_delete;
/*
a) Execute time	0.0s
b) 8.4s difference, with truncate being faster (insanely faster)
c) total: 8192 bytes
*/

/*
 Step 5. Report results
a) Space consumption of table_to_delete before and after each operation:
     - After creation - 575 MB
     - After DELETE - 575 MB
     - After VACUUM FULL - 574 MB
     - After TRUNCATE - ~0 MB
b) Duration of each operation (DELETE, VACUUM, TRUNCATE): 8.4s, 14s, 0.0s respectively
*/