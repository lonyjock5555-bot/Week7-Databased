-- ==========================================
-- HANDS-ON LAB: AUDIT LOGGING, CATEGORY TREES,
-- AND SAFE MIGRATIONS
-- ==========================================

-- STEP 1: BUILD A REUSABLE AUDIT LOG

CREATE TABLE audit_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tbl TEXT,
    op TEXT,
    old_row JSONB,
    new_row JSONB,
    changed_by TEXT DEFAULT current_user,
    at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log(tbl, op, old_row, new_row)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
    );

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit
AFTER INSERT OR UPDATE OR DELETE
ON students
FOR EACH ROW
EXECUTE FUNCTION audit();


-- STEP 2: WATCH THE AUDIT LOG WORK

UPDATE students
SET name = 'Kofi M.'
WHERE id = 1;

DELETE FROM students
WHERE id = 3;

SELECT
    tbl,
    op,
    old_row->>'name' AS was,
    new_row->>'name' AS now,
    changed_by,
    at
FROM audit_log
ORDER BY at DESC;


-- STEP 3: MODEL A CATEGORY TREE

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name TEXT,
    parent_id INT REFERENCES categories(id)
);

INSERT INTO categories (name, parent_id) VALUES
    ('Electronics', NULL),
    ('Computers', 1),
    ('Laptops', 2),
    ('Phones', 1);

WITH RECURSIVE tree AS (
    SELECT id, name, parent_id, 0 AS depth
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.id, c.name, c.parent_id, t.depth + 1
    FROM categories c
    JOIN tree t ON c.parent_id = t.id
)
SELECT
    repeat('  ', depth) || name AS tree
FROM tree
ORDER BY depth, name;


-- STEP 4: RUN VERSIONED MIGRATIONS WITH FLYWAY

-- Create these migration files:
-- V1__core_tables.sql
-- V2__audit_log.sql
-- V3__categories.sql

-- Run these commands in the terminal:
-- flyway -url=jdbc:postgresql://localhost/bootcamp -user=postgres migrate
-- flyway info


-- STEP 5: APPLY LEAST-PRIVILEGE SECURITY

CREATE ROLE app_read;
CREATE ROLE app_write;

GRANT CONNECT ON DATABASE bootcamp TO app_read, app_write;

GRANT USAGE ON SCHEMA public TO app_read, app_write;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_read;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public TO app_write;

CREATE USER api
LOGIN PASSWORD 'strong-secret'
IN ROLE app_write;


-- ==========================================
-- WRAP-UP
-- ==========================================

-- 1. Built a reusable audit logging system.
-- 2. Tracked database changes using triggers.
-- 3. Created hierarchical categories using recursive CTEs.
-- 4. Applied versioned schema migrations using Flyway.
-- 5. Implemented least-privilege database security.
