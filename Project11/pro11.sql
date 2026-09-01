/* ============================================================
   PROJECT 11: Enterprise Customer MDM - Hybrid SCD Strategies

   KEY DESIGN POINT (see chat explanation): CITY, PREVIOUS_CITY,
   STATE, CURRENT_MEMBERSHIP, and PREVIOUS_MEMBERSHIP are synced
   to the SAME value across every row of a customer - old and new
   alike - every time that customer changes. Only
   HISTORICAL_MEMBERSHIP and SEGMENT genuinely vary by row/time
   period. Point-in-time queries MUST read HISTORICAL_MEMBERSHIP,
   never CURRENT_MEMBERSHIP, or they'll return today's answer
   instead of the answer as of the queried date.
   ============================================================ */

/* ---------- TASK 1: Environment ---------- */

CREATE OR REPLACE WAREHOUSE HYBRID_SCD_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

CREATE OR REPLACE DATABASE HYBRID_SCD_DB;

CREATE OR REPLACE SCHEMA HYBRID_SCD_DB.CUSTOMER_SCHEMA;

USE WAREHOUSE HYBRID_SCD_WH;
USE DATABASE HYBRID_SCD_DB;
USE SCHEMA CUSTOMER_SCHEMA;

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = 'CSV'
  SKIP_HEADER = 1
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"';

CREATE OR REPLACE STAGE HYBRID_SCD_STAGE
  FILE_FORMAT = CSV_FORMAT;

-- Upload customers_initial.csv and customer_updates.csv via:
-- Catalog -> HYBRID_SCD_DB -> CUSTOMER_SCHEMA -> Stages
-- -> HYBRID_SCD_STAGE -> "+ Files"

LIST @HYBRID_SCD_STAGE;

CREATE OR REPLACE TABLE STG_CUSTOMERS_INITIAL (
  customer_id   INT,
  customer_name VARCHAR(100),
  city          VARCHAR(50),
  state         VARCHAR(50),
  membership    VARCHAR(30),
  segment       VARCHAR(30)
);
COPY INTO STG_CUSTOMERS_INITIAL
  FROM @HYBRID_SCD_STAGE/customers_initial.csv FILE_FORMAT=(FORMAT_NAME=CSV_FORMAT);

CREATE OR REPLACE TABLE CUSTOMER_UPDATES (
  customer_id     INT,
  customer_name   VARCHAR(100),
  city            VARCHAR(50),
  state           VARCHAR(50),
  membership      VARCHAR(30),
  segment         VARCHAR(30),
  effective_date  DATE
);
COPY INTO CUSTOMER_UPDATES
  FROM @HYBRID_SCD_STAGE/customer_updates.csv FILE_FORMAT=(FORMAT_NAME=CSV_FORMAT);

/* ---------- TASK 2: Hybrid Dimension Table ---------- */

CREATE OR REPLACE TABLE DIM_CUSTOMER_HYBRID (
  customer_key            INT AUTOINCREMENT START 1 INCREMENT 1,
  customer_id             INT,
  customer_name           VARCHAR(100),
  city                    VARCHAR(50),
  previous_city           VARCHAR(50),
  state                   VARCHAR(50),
  current_membership      VARCHAR(30),
  previous_membership     VARCHAR(30),
  historical_membership   VARCHAR(30),
  segment                 VARCHAR(30),
  effective_date          DATE,
  expiry_date             DATE,
  is_current              BOOLEAN
);

/* ---------- TASK 3: Load Initial Data ---------- */

INSERT INTO DIM_CUSTOMER_HYBRID
  (customer_id, customer_name, city, previous_city, state,
   current_membership, previous_membership, historical_membership,
   segment, effective_date, expiry_date, is_current)
SELECT
  customer_id, customer_name, city,
  NULL                 AS previous_city,
  state,
  membership           AS current_membership,
  NULL                 AS previous_membership,
  membership           AS historical_membership,
  segment,
  '2026-01-01'::DATE   AS effective_date,
  '9999-12-31'::DATE   AS expiry_date,
  TRUE                 AS is_current
FROM STG_CUSTOMERS_INITIAL;

SELECT 'Initial Hybrid Dimension Data Loaded Successfully' AS status,
       COUNT(*)                   AS total_records,
       SUM(IFF(is_current, 1, 0)) AS current_records
FROM DIM_CUSTOMER_HYBRID;   -- expect Total = 5, Current = 5

-- TASK 4: Display initial state
SELECT
  customer_id, customer_name, city, previous_city, state,
  current_membership, previous_membership, historical_membership,
  segment, effective_date, expiry_date, is_current
FROM DIM_CUSTOMER_HYBRID
ORDER BY customer_id;

/* ============================================================
   TASK 5: Apply Hybrid Updates for Customers 101, 103, 104
   ============================================================ */

-- Step 1: Expire the active version for each changed customer.
-- Values on this row are NOT touched here - Step 3 will sync them.
UPDATE DIM_CUSTOMER_HYBRID t
SET
  expiry_date = DATEADD(day, -1, u.effective_date),
  is_current  = FALSE
FROM CUSTOMER_UPDATES u
WHERE t.customer_id = u.customer_id
  AND t.is_current = TRUE;

-- Step 2: Insert the new active version. previous_city and
-- previous_membership are captured here from the row just
-- expired above; historical_membership and segment are this
-- row's own true point-in-time values.
INSERT INTO DIM_CUSTOMER_HYBRID
  (customer_id, customer_name, city, previous_city, state,
   current_membership, previous_membership, historical_membership,
   segment, effective_date, expiry_date, is_current)
SELECT
  u.customer_id, u.customer_name,
  u.city                     AS city,
  old.city                   AS previous_city,
  u.state                    AS state,
  u.membership                AS current_membership,
  old.current_membership      AS previous_membership,
  u.membership                AS historical_membership,
  u.segment,
  u.effective_date,
  '9999-12-31'::DATE          AS expiry_date,
  TRUE                        AS is_current
FROM CUSTOMER_UPDATES u
JOIN DIM_CUSTOMER_HYBRID old
  ON old.customer_id = u.customer_id
  AND old.is_current = FALSE
  AND old.expiry_date = DATEADD(day, -1, u.effective_date);

-- Step 3: Synchronize the "global" attributes (city, previous_city,
-- state, current_membership, previous_membership) across BOTH the
-- old and new rows for each changed customer. This is what makes
-- the just-expired row display today's city/membership instead of
-- what was true back when that row was created - by design (see
-- the note at the top of this script). segment and
-- historical_membership are deliberately left untouched here.
UPDATE DIM_CUSTOMER_HYBRID t
SET
  city                 = nv.city,
  previous_city        = ov.city,
  state                = nv.state,
  current_membership   = nv.membership,
  previous_membership  = ov.membership
FROM
  (SELECT customer_id, city, state, current_membership AS membership
   FROM DIM_CUSTOMER_HYBRID WHERE is_current = TRUE)  nv,
  (SELECT customer_id, city, current_membership AS membership
   FROM DIM_CUSTOMER_HYBRID WHERE is_current = FALSE) ov
WHERE t.customer_id = nv.customer_id
  AND t.customer_id = ov.customer_id;
-- The double-join on customer_id naturally limits this to only
-- customers who have BOTH a current and a historical row - i.e.
-- exactly 101, 103, 104. Customers 102 and 105 (single row, no
-- historical version) are untouched.

SELECT 'Hybrid SCD Updates Applied Successfully' AS status,
       COUNT(*)                            AS total_records,
       SUM(IFF(is_current, 1, 0))          AS current_records,
       SUM(IFF(NOT is_current, 1, 0))      AS historical_records
FROM DIM_CUSTOMER_HYBRID;   -- expect 8, 5, 3

/* ---------- TASK 6: Display Complete Dimension History ---------- */

SELECT
  customer_id, customer_name, city, previous_city, state,
  current_membership, previous_membership, historical_membership,
  segment, effective_date, expiry_date, is_current
FROM DIM_CUSTOMER_HYBRID
ORDER BY customer_id, effective_date;

/* ---------- TASK 7: Active Customer Report ---------- */

SELECT
  customer_id, customer_name, city, previous_city, state,
  current_membership, previous_membership, segment
FROM DIM_CUSTOMER_HYBRID
WHERE is_current = TRUE
ORDER BY customer_id;

/* ---------- TASK 8: Point-in-Time Historical Query ----------
   Reads HISTORICAL_MEMBERSHIP, not CURRENT_MEMBERSHIP - see the
   note at the top of this script for why that distinction matters
   here specifically. ---------- */

SELECT
  customer_id, customer_name, city, historical_membership, segment,
  effective_date, expiry_date
FROM DIM_CUSTOMER_HYBRID
WHERE customer_id = 101
  AND '2026-03-15' BETWEEN effective_date AND expiry_date;

/* ---------- TASK 9: Metric Validation ---------- */

SELECT 'TOTAL RECORD COUNT' AS metric, COUNT(*) AS value
FROM DIM_CUSTOMER_HYBRID
UNION ALL
SELECT 'CURRENT RECORD COUNT', SUM(IFF(is_current, 1, 0))
FROM DIM_CUSTOMER_HYBRID
UNION ALL
SELECT 'HISTORICAL RECORD COUNT', SUM(IFF(NOT is_current, 1, 0))
FROM DIM_CUSTOMER_HYBRID;
-- expect 8 / 5 / 3

/* ============================================================
   CLEANUP (run only after you're fully done + have screenshots)
   ============================================================
-- DROP DATABASE IF EXISTS HYBRID_SCD_DB;
-- DROP WAREHOUSE IF EXISTS HYBRID_SCD_WH;
*/