/*
--Creating DB
CREATE DATABASE museum_db;
*/



--Connected to museum_db
CREATE SCHEMA IF NOT EXISTS museum;
SET search_path TO museum;



--Informational Tables block: (Don't have any FK, are FK for other relations)
--Artist: contains info on artists whos works being shown in museum
CREATE TABLE IF NOT EXISTS museum.artist (
	artist_id          INTEGER GENERATED ALWAYS AS IDENTITY,
	artist_first_name  VARCHAR(100) NOT NULL,
	artist_last_name   VARCHAR(100),
	artist_birth_date  DATE,
	artist_death_date  DATE,
	artist_country     VARCHAR(100),
	artist_full_name   TEXT GENERATED ALWAYS AS
		(btrim(artist_first_name || ' ' || COALESCE(artist_last_name, ''))) STORED,

	CONSTRAINT pk_artist_artist_id PRIMARY KEY (artist_id)
);


--Type: conatins data about types of items, that is, picture, art, sculpure etc
CREATE TABLE IF NOT EXISTS museum.type (
	type_id          INTEGER GENERATED ALWAYS AS IDENTITY,
	type_name        VARCHAR(100) NOT NULL,
	type_description TEXT,

	CONSTRAINT pk_type_type_id PRIMARY KEY (type_id),
	CONSTRAINT uq_type_type_name UNIQUE (type_name)
);


--Role: defines roles assigned to employees when working on exhibitions (e.g., curator, organizer, cleaner :D)
CREATE TABLE IF NOT EXISTS museum.role (
	role_id   INTEGER GENERATED ALWAYS AS IDENTITY,
	role_name VARCHAR(100) NOT NULL,

	CONSTRAINT pk_role_role_id PRIMARY KEY (role_id),
	CONSTRAINT uq_role_role_name UNIQUE (role_name)
);


--Storage: represents physical storage locations for items when they are not on exhibition
CREATE TABLE IF NOT EXISTS museum.storage (
	storage_id    INTEGER GENERATED ALWAYS AS IDENTITY,
	storage_room  VARCHAR(50),
	storage_shelf VARCHAR(50),
	storage_box   VARCHAR(50),
	storage_notes TEXT,

	CONSTRAINT pk_storage_storage_id PRIMARY KEY (storage_id)
);


--Status: defines the condition or state of an item or inventory record (e.g., On display, In storage)
CREATE TABLE IF NOT EXISTS museum.status (
	status_id   INTEGER GENERATED ALWAYS AS IDENTITY,
	status_name VARCHAR(100) NOT NULL,

	CONSTRAINT pk_status_status_id PRIMARY KEY (status_id),
	CONSTRAINT uq_status_status_name UNIQUE (status_name)
);



--Main relations, might have FK from informational tables or to each other:
--Exhibition: holds data about museum exhibitions, including title, dates, and whether it is online
CREATE TABLE IF NOT EXISTS museum.exhibition (
	exhibition_id          INTEGER GENERATED ALWAYS AS IDENTITY,
	exhibition_title       VARCHAR(200) NOT NULL,
	exhibition_description TEXT,
	exhibition_start_date  DATE,
	exhibition_end_date    DATE,
	exhibition_is_online   BOOLEAN NOT NULL DEFAULT FALSE,

	CONSTRAINT pk_exhibition_exhibition_id PRIMARY KEY (exhibition_id)
);


--Employee: contains information about museum staff members
CREATE TABLE IF NOT EXISTS museum.employee (
	employee_id         INTEGER GENERATED ALWAYS AS IDENTITY,
	employee_first_name VARCHAR(100) NOT NULL,
	employee_last_name  VARCHAR(100) NOT NULL,
	employee_email      VARCHAR(255),
	employee_phone      VARCHAR(50),

	CONSTRAINT pk_employee_employee_id PRIMARY KEY (employee_id),
	CONSTRAINT uq_employee_email UNIQUE (employee_email)
);


--Visitor: represents people who visit the museum and attend exhibitions
CREATE TABLE IF NOT EXISTS museum.visitor (
	visitor_id         INTEGER GENERATED ALWAYS AS IDENTITY,
	visitor_first_name VARCHAR(100),
	visitor_last_name  VARCHAR(100),

	CONSTRAINT pk_visitor_visitor_id PRIMARY KEY (visitor_id)
);


--Item: represents a museum object or artwork such as a painting, sculpture, artifact, etc.
CREATE TABLE IF NOT EXISTS museum.item (
	item_id               INTEGER GENERATED ALWAYS AS IDENTITY,
	item_title            VARCHAR(255),
	item_description      TEXT,

	item_creation_date    VARCHAR(50),

	type_id               INTEGER,  -- FK → type.type_id

	item_provenance       TEXT,
	item_acquisition_date DATE,
	item_value_estimate   NUMERIC(12, 2),
	item_is_on_display    BOOLEAN NOT NULL DEFAULT FALSE,

	CONSTRAINT pk_item_item_id PRIMARY KEY (item_id),
	CONSTRAINT fk_item_type_id
		FOREIGN KEY (type_id)
		REFERENCES museum.type (type_id)
);


--Inventory: tracks storage, quantity, condition, and status of each item in the museum
CREATE TABLE IF NOT EXISTS museum.inventory (
	inventory_id         INTEGER GENERATED ALWAYS AS IDENTITY,
	item_id              INTEGER NOT NULL,   -- FK → item.item_id
	storage_id           INTEGER,           -- NULL, for case when shown, not in storage
	inventory_quantity   INTEGER NOT NULL DEFAULT 1,
	inventory_condition  VARCHAR(100),
	inventory_last_checked DATE,
	status_id            INTEGER NOT NULL,  -- FK → status.status_id

	CONSTRAINT pk_inventory_inventory_id PRIMARY KEY (inventory_id),

	CONSTRAINT fk_inventory_item_id
		FOREIGN KEY (item_id)
		REFERENCES museum.item (item_id),

	CONSTRAINT fk_inventory_storage_id
		FOREIGN KEY (storage_id)
		REFERENCES museum.storage (storage_id),

	CONSTRAINT fk_inventory_status_id
		FOREIGN KEY (status_id)
		REFERENCES museum.status (status_id)
);


--Visit: records visitor attendance at exhibitions and museum visits with timestamps
CREATE TABLE IF NOT EXISTS museum.visit (
	visit_id      INTEGER GENERATED ALWAYS AS IDENTITY,
	visitor_id    INTEGER NOT NULL,  -- FK → visitor.visitor_id
	exhibition_id INTEGER,           -- FK → exhibition.exhibition_id (может быть NULL)
	visit_date    TIMESTAMP NOT NULL,

	CONSTRAINT pk_visit_visit_id PRIMARY KEY (visit_id),

	CONSTRAINT fk_visit_visitor_id
		FOREIGN KEY (visitor_id)
		REFERENCES museum.visitor (visitor_id),

	CONSTRAINT fk_visit_exhibition_id
		FOREIGN KEY (exhibition_id)
		REFERENCES museum.exhibition (exhibition_id)
);



--Bridge Relations, connecting MANY-TO-MANY
CREATE TABLE IF NOT EXISTS museum.item_artist (
	item_id   INTEGER NOT NULL,  -- FK → item.item_id
	artist_id INTEGER NOT NULL,  -- FK → artist.artist_id

	CONSTRAINT pk_item_artist_item_id_artist_id
		PRIMARY KEY (item_id, artist_id),

	CONSTRAINT fk_item_artist_item_id
		FOREIGN KEY (item_id)
		REFERENCES museum.item (item_id),

	CONSTRAINT fk_item_artist_artist_id
		FOREIGN KEY (artist_id)
		REFERENCES museum.artist (artist_id)
);


CREATE TABLE IF NOT EXISTS museum.exhibition_employee (
	exhibition_id INTEGER NOT NULL,  -- FK → exhibition.exhibition_id
	employee_id   INTEGER NOT NULL,  -- FK → employee.employee_id
	role_id       INTEGER NOT NULL,  -- FK → role.role_id

	CONSTRAINT pk_exhibition_employee_exhibition_id_employee_id
		PRIMARY KEY (exhibition_id, employee_id),

	CONSTRAINT fk_exhibition_employee_exhibition_id
		FOREIGN KEY (exhibition_id)
		REFERENCES museum.exhibition (exhibition_id),

	CONSTRAINT fk_exhibition_employee_employee_id
		FOREIGN KEY (employee_id)
		REFERENCES museum.employee (employee_id),

	CONSTRAINT fk_exhibition_employee_role_id
		FOREIGN KEY (role_id)
		REFERENCES museum.role (role_id)
);


CREATE TABLE IF NOT EXISTS museum.exhibition_item (
	exhibition_id INTEGER NOT NULL,  -- FK → exhibition.exhibition_id
	item_id       INTEGER NOT NULL,  -- FK → item.item_id

	CONSTRAINT pk_exhibition_item_exhibition_id_item_id
		PRIMARY KEY (exhibition_id, item_id),

	CONSTRAINT fk_exhibition_item_exhibition_id
		FOREIGN KEY (exhibition_id)
		REFERENCES museum.exhibition (exhibition_id),

	CONSTRAINT fk_exhibition_item_item_id
		FOREIGN KEY (item_id)
		REFERENCES museum.item (item_id)
);



--Checks:
-- 1. Number of items can't be negative
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_inventory_quantity_non_negative'
    ) THEN
        ALTER TABLE museum.inventory
            ADD CONSTRAINT ck_inventory_quantity_non_negative
            CHECK (inventory_quantity >= 0);
    END IF;
END$$;

-- 2. Item value estimate can't be negative
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_item_value_non_negative'
    ) THEN
        ALTER TABLE museum.item
            ADD CONSTRAINT ck_item_value_non_negative
            CHECK (item_value_estimate IS NULL OR item_value_estimate >= 0);
    END IF;
END$$;


-- 3. Exhibition ends NOT EARLIER than it begins
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_exhibition_dates_valid'
    ) THEN
        ALTER TABLE museum.exhibition
            ADD CONSTRAINT ck_exhibition_dates_valid
            CHECK (
                exhibition_end_date IS NULL
                OR exhibition_start_date IS NULL
                OR exhibition_end_date >= exhibition_start_date
            );
    END IF;
END$$;


-- 4. Date of visit not agter 1st January 2024
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_visit_date_after_2024'
    ) THEN
        ALTER TABLE museum.visit
            ADD CONSTRAINT ck_visit_date_after_2024
            CHECK (visit_date >= TIMESTAMP '2024-01-01 00:00:00');
    END IF;
END$$;


-- 5. Date of item accquire not after 1st January 2024
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_item_acquisition_date_after_2024'
    ) THEN
        ALTER TABLE museum.item
            ADD CONSTRAINT ck_item_acquisition_date_after_2024
            CHECK (item_acquisition_date IS NULL OR item_acquisition_date >= DATE '2024-01-01');
    END IF;
END$$;


-- 6. Only one of 4 statuses, can be removed
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_status_name_allowed'
    ) THEN
        ALTER TABLE museum.status
            ADD CONSTRAINT ck_status_name_allowed
            CHECK (status_name IN ('On display', 'In storage', 'On loan', 'Under restoration'));
    END IF;
END$$;


-- 7. Date of death NOT EARLIER than date of birth
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_artist_life_dates'
    ) THEN
        ALTER TABLE museum.artist
            ADD CONSTRAINT ck_artist_life_dates
            CHECK (
                artist_death_date IS NULL
                OR artist_birth_date IS NULL
                OR artist_death_date >= artist_birth_date
            );
    END IF;
END$$;



--DML Part:
TRUNCATE TABLE
    museum.exhibition_item,
    museum.exhibition_employee,
    museum.item_artist,
    museum.visit,
    museum.inventory,
    museum.item,
    museum.exhibition,
    museum.visitor,
    museum.employee,
    museum.storage,
    museum.status,
    museum.role,
    museum.type,
    museum.artist
RESTART IDENTITY CASCADE;
--Type
INSERT INTO museum.type (type_name, type_description)
VALUES
('Painting', 'Work created with paint on canvas'),
('Sculpture', 'Three-dimensional artwork'),
('Photography', 'Photographic print'),
('Installation', 'Large-scale conceptual installation'),
('Drawing', 'Graphite or ink on paper'),
('Digital Art', 'Computer-generated artwork')
ON CONFLICT DO NOTHING;

--Role
INSERT INTO museum.role (role_name)
VALUES
('Curator'),
('Guide'),
('Organizer'),
('Restorer'),
('Archivist'),
('Security')
ON CONFLICT DO NOTHING;

--Status
--Limited to 4, for my check	
INSERT INTO museum.status (status_name)
VALUES
('On display'),
('In storage'),
('On loan'),
('Under restoration')
ON CONFLICT DO NOTHING;

--Storage
INSERT INTO museum.storage (storage_room, storage_shelf, storage_box, storage_notes)
VALUES
('Room A', 'Shelf 1', 'Box 1', 'Climate controlled'),
('Room A', 'Shelf 2', 'Box 3', 'Fragile'),
('Room B', 'Shelf 1', 'Box 2', 'Handle with gloves'),
('Room C', 'Shelf 4', 'Box 9', 'Heavy items'),
('Room C', 'Shelf 2', 'Box 7', 'Monitor humidity'),
('Room D', 'Shelf 3', 'Box 11', 'Special collection');

--Artist
INSERT INTO museum.artist (
    artist_first_name, artist_last_name, artist_birth_date, artist_death_date, artist_country
)
VALUES
('Pablo', 'Picasso', '1881-10-25', '1973-04-08', 'Spain'),
('Frida', 'Kahlo', '1907-07-06', '1954-07-13', 'Mexico'),
('Claude', 'Monet', '1840-11-14', '1926-12-05', 'France'),
('Salvador', 'Dali', '1904-05-11', '1989-01-23', 'Spain'),
('Ai', 'Weiwei', '1957-08-28', NULL, 'China'),
('Yayoi', 'Kusama', '1929-03-22', NULL, 'Japan');

--Employee
INSERT INTO museum.employee (employee_first_name, employee_last_name, employee_email, employee_phone)
VALUES
('John', 'Smith', 'john.smith@museum.com', '+12345001'),
('Emily', 'Clark', 'emily.clark@museum.com', '+12345002'),
('Robert', 'Miller', 'robert.miller@museum.com', '+12345003'),
('Anna', 'Hughes', 'anna.hughes@museum.com', '+12345004'),
('Michael', 'Turner', 'michael.turner@museum.com', '+12345005'),
('Sarah', 'Lopez', 'sarah.lopez@museum.com', '+12345006');

--Visitor
INSERT INTO museum.visitor (visitor_first_name, visitor_last_name)
VALUES
('Liam', 'Johnson'),
('Emma', 'Brown'),
('Noah', 'Wilson'),
('Olivia', 'Taylor'),
('Ethan', 'Anderson'),
('Sophia', 'Martinez');

--Exhibition
INSERT INTO museum.exhibition (
    exhibition_title, exhibition_description, exhibition_start_date, exhibition_end_date, exhibition_is_online
)
VALUES
('Modern Light', 'Exploration of modern shapes', NOW() - INTERVAL '70 days', NOW() - INTERVAL '40 days', FALSE),
('Silent Forms', 'Minimalist sculpture', NOW() - INTERVAL '55 days', NOW() - INTERVAL '20 days', FALSE),
('Visions of Code', 'Digital art exhibition', NOW() - INTERVAL '50 days', NULL, TRUE),
('Reflections', 'Photography retrospective', NOW() - INTERVAL '80 days', NOW() - INTERVAL '10 days', FALSE),
('Parallel Worlds', 'Mixed media installation', NOW() - INTERVAL '30 days', NULL, TRUE),
('Symmetry & Chaos', 'Experimental works', NOW() - INTERVAL '25 days', NOW() - INTERVAL '5 days', FALSE);


-- Item  (NO hardcoded type_id)
INSERT INTO museum.item (
    item_title, item_description, item_creation_date, type_id,
    item_provenance, item_acquisition_date, item_value_estimate, item_is_on_display
)
VALUES
('Blue Horizon', 'Large acrylic painting', '1998',
    (SELECT type_id FROM museum.type WHERE type_name='Painting'),
 'Private collector', NOW() - INTERVAL '60 days', 50000, TRUE),

('Stone Echo', 'Marble sculpture', '1975',
    (SELECT type_id FROM museum.type WHERE type_name='Sculpture'),
 'Estate donation', NOW() - INTERVAL '80 days', 120000, FALSE),

('Silent River', 'Fine art photograph', '2019',
    (SELECT type_id FROM museum.type WHERE type_name='Photography'),
 'Artist donation', NOW() - INTERVAL '40 days', 7000, TRUE),

('Ink Memory', 'Ink on paper', '2005',
    (SELECT type_id FROM museum.type WHERE type_name='Drawing'),
 'Auction purchase', NOW() - INTERVAL '25 days', 15000, FALSE),

('Digital Bloom', 'Generative artwork', '2023',
    (SELECT type_id FROM museum.type WHERE type_name='Digital Art'),
 'Artist commission', NOW() - INTERVAL '10 days', 20000, TRUE),

('Golden Branch', 'Bronze sculpture', '1988',
    (SELECT type_id FROM museum.type WHERE type_name='Sculpture'),
 'Museum acquisition', NOW() - INTERVAL '15 days', 25000, FALSE);


-- Inventory (NO hardcoded status_id or storage_id)
INSERT INTO museum.inventory (
    item_id, storage_id, inventory_quantity, inventory_condition,
    inventory_last_checked, status_id
)
VALUES
(
    1,
    NULL,
    1,
    'Excellent',
    NOW() - INTERVAL '10 days',
    (SELECT status_id FROM museum.status WHERE status_name='On display')
),
(
    2,
    1,
    1,
    'Good',
    NOW() - INTERVAL '5 days',
    (SELECT status_id FROM museum.status WHERE status_name='In storage')
),
(
    3,
    NULL,
    1,
    'Excellent',
    NOW() - INTERVAL '20 days',
    (SELECT status_id FROM museum.status WHERE status_name='On display')
),
(
    4,
    3,
    1,
    'Fragile',
    NOW() - INTERVAL '15 days',
    (SELECT status_id FROM museum.status WHERE status_name='Under restoration')
),
(
    5,
    NULL,
    1,
    'Excellent',
    NOW() - INTERVAL '3 days',
    (SELECT status_id FROM museum.status WHERE status_name='On display')
),
(
    6,
    4,
    1,
    'Good',
    NOW() - INTERVAL '7 days',
    (SELECT status_id FROM museum.status WHERE status_name='In storage')
);


-- Visit (these IDs are safe because visitors/exhibitions inserted sequentially)
INSERT INTO museum.visit (visitor_id, exhibition_id, visit_date)
VALUES
(1, 1, NOW() - INTERVAL '68 days'),
(2, 1, NOW() - INTERVAL '66 days'),
(3, 2, NOW() - INTERVAL '30 days'),
(4, 3, NOW() - INTERVAL '20 days'),
(5, 4, NOW() - INTERVAL '9 days'),
(6, 6, NOW() - INTERVAL '4 days');


-- Item_Artist
INSERT INTO museum.item_artist (item_id, artist_id)
VALUES
(1, 1),
(2, 3),
(3, 4),
(4, 2),
(5, 5),
(6, 6);


-- Exhibition_Employee (role resolved by name)
INSERT INTO museum.exhibition_employee (exhibition_id, employee_id, role_id)
VALUES
(1, 1, (SELECT role_id FROM museum.role WHERE role_name='Curator')),
(2, 2, (SELECT role_id FROM museum.role WHERE role_name='Organizer')),
(3, 3, (SELECT role_id FROM museum.role WHERE role_name='Guide')),
(4, 4, (SELECT role_id FROM museum.role WHERE role_name='Curator')),
(5, 5, (SELECT role_id FROM museum.role WHERE role_name='Restorer')),
(6, 6, (SELECT role_id FROM museum.role WHERE role_name='Archivist'));


-- Exhibition_Item
INSERT INTO museum.exhibition_item (exhibition_id, item_id)
VALUES
(1, 1),
(2, 2),
(3, 5),
(4, 3),
(5, 4),
(6, 6);



--Functions part
--Update for specified id value in specified column
CREATE OR REPLACE FUNCTION museum.update_item_column(
    p_item_id INTEGER,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    sql TEXT;
BEGIN
    sql := format(
        'UPDATE museum.item
         SET %I = CAST($1 AS %s)
         WHERE item_id = $2',
        p_column_name,
        (SELECT data_type
         FROM information_schema.columns
         WHERE table_schema='museum'
           AND table_name='item'
           AND column_name=p_column_name)
    );

    EXECUTE sql USING p_new_value, p_item_id;
END;
$$;


/*
Example usage:
SELECT museum.update_item_column(1, 'item_title', 'New Title');
SELECT museum.update_item_column(3, 'item_value_estimate', '123000');
SELECT museum.update_item_column(5, 'item_is_on_display', 'false');
*/

--Adding new transaction (most suiting, visit relation)
CREATE OR REPLACE FUNCTION museum.add_visit_transaction(
    p_visitor_first_name TEXT,
    p_visitor_last_name  TEXT,
    p_exhibition_title   TEXT,
    p_visit_date         TIMESTAMP
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_visitor_id INTEGER;
    v_exhibition_id INTEGER;
BEGIN
    SELECT visitor_id INTO v_visitor_id
    FROM museum.visitor
    WHERE visitor_first_name = p_visitor_first_name
      AND visitor_last_name = p_visitor_last_name;

    IF v_visitor_id IS NULL THEN
        RAISE EXCEPTION 'Visitor "%" "%" not found', 
            p_visitor_first_name, p_visitor_last_name;
    END IF;

    SELECT exhibition_id INTO v_exhibition_id
    FROM museum.exhibition
    WHERE exhibition_title = p_exhibition_title;

    IF v_exhibition_id IS NULL THEN
        RAISE EXCEPTION 'Exhibition "%" not found', p_exhibition_title;
    END IF;

    INSERT INTO museum.visit(visitor_id, exhibition_id, visit_date)
    VALUES (v_visitor_id, v_exhibition_id, p_visit_date);

    RETURN format(
        'Visit successfully recorded: %s %s → %s at %s',
        p_visitor_first_name, p_visitor_last_name,
        p_exhibition_title, p_visit_date
    );
END;
$$;

/*
Example:
SELECT museum.add_visit_transaction(
    'Liam',
    'Johnson',
    'Modern Light',
    NOW()::timestamp
);
*/



--View for analysis:
/*
View looks for last quarter, outputs only its visits, removes surrogate keys, outputs new aggregations for analysis
 */
CREATE OR REPLACE VIEW museum.recent_quarter_analytics AS
WITH last_q AS (
    SELECT
        DATE_TRUNC('quarter', MAX(visit_date)) AS quarter_start
    FROM museum.visit
),
quarter_data AS (
    SELECT
        v.visit_date,
        vis.visitor_first_name,
        vis.visitor_last_name,
        e.exhibition_title
    FROM museum.visit v
    JOIN museum.visitor vis ON vis.visitor_id = v.visitor_id
    JOIN museum.exhibition e ON e.exhibition_id = v.exhibition_id
    JOIN last_q q ON v.visit_date >= q.quarter_start
                 AND v.visit_date < q.quarter_start + INTERVAL '3 months'
)
SELECT
    exhibition_title,
    COUNT(*) AS total_visits,
    COUNT(DISTINCT visitor_first_name || ' ' || visitor_last_name) AS unique_visitors,
    MIN(visit_date) AS first_visit,
    MAX(visit_date) AS last_visit
FROM quarter_data
GROUP BY exhibition_title
ORDER BY total_visits DESC;

--Summoning view
SELECT * FROM museum.recent_quarter_analytics;



--Creating role
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'manager'
    ) THEN
        CREATE ROLE manager
            LOGIN
            PASSWORD 'StrongPasswordHere'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOINHERIT;
    END IF;
END
$$;



--Give him only SELECT
GRANT USAGE ON SCHEMA museum TO manager;
GRANT SELECT ON ALL TABLES IN SCHEMA museum TO manager;

--Give privilage for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA museum
GRANT SELECT ON TABLES TO manager;


--Check
SET ROLE manager;

SELECT * FROM museum.item;
SELECT * FROM museum.exhibition;
SELECT * FROM museum.status;

UPDATE museum.item SET item_title = 'Hacked' WHERE item_id = 1;
--ERROR: permission denied

RESET ROLE;

