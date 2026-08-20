-- ============================================================
-- PROJECT 5 : RETAIL SALES DATA WAREHOUSE
-- STAR SCHEMA
-- COMPLETE EXECUTABLE SCRIPT
-- ============================================================


-- ============================================================
--  CREATE WAREHOUSE
-- ============================================================

CREATE WAREHOUSE P5_RETAIL_WH
WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE P5_RETAIL_WH;


-- ============================================================
--  CREATE DATABASE AND SCHEMAS
-- ============================================================

CREATE DATABASE P5_RETAIL_DB;

USE DATABASE P5_RETAIL_DB;

CREATE SCHEMA P5_STAGING;
CREATE SCHEMA P5_ANALYTICS;


-- ============================================================
--  CREATE FILE FORMAT
-- ============================================================

USE SCHEMA P5_STAGING;

CREATE FILE FORMAT P5_CSV_FORMAT
TYPE = 'CSV'
SKIP_HEADER = 1
FIELD_DELIMITER = ','
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
TRIM_SPACE = TRUE
EMPTY_FIELD_AS_NULL = TRUE;


-- ============================================================
--  CREATE INTERNAL STAGE
-- ============================================================

CREATE STAGE P5_CSV_STAGE
FILE_FORMAT = P5_CSV_FORMAT;


-- ============================================================
--  CREATE STAGING TABLES
-- ============================================================

CREATE TABLE P5_STG_CUSTOMERS (
    CUSTOMER_ID NUMBER,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(100),
    STATE VARCHAR(100),
    MEMBERSHIP VARCHAR(50)
);

CREATE TABLE P5_STG_PRODUCTS (
    PRODUCT_ID NUMBER,
    PRODUCT_NAME VARCHAR(100),
    CATEGORY VARCHAR(100),
    BRAND VARCHAR(100),
    PRICE NUMBER(12,2)
);

CREATE TABLE P5_STG_BRANCHES (
    BRANCH_ID NUMBER,
    BRANCH_NAME VARCHAR(150),
    CITY VARCHAR(100),
    STATE VARCHAR(100),
    REGION VARCHAR(50),
    MANAGER_NAME VARCHAR(100)
);

CREATE TABLE P5_STG_CALENDAR (
    DATE_ID NUMBER,
    DATE DATE,
    DAY NUMBER,
    DAY_NAME VARCHAR(20),
    WEEK_NO NUMBER,
    MONTH VARCHAR(20),
    QUARTER VARCHAR(10),
    YEAR NUMBER,
    IS_WEEKEND VARCHAR(10)
);

CREATE TABLE P5_STG_SALES (
    SALE_ID NUMBER,
    CUSTOMER_ID NUMBER,
    PRODUCT_ID NUMBER,
    BRANCH_ID NUMBER,
    DATE_ID NUMBER,
    QUANTITY NUMBER,
    TOTAL_AMOUNT NUMBER(12,2)
);


-- ============================================================
-- 7. CHECK STAGE
-- ============================================================

LIST @P5_CSV_STAGE;

-- 8. LOAD CSV FILES

COPY INTO P5_STG_CUSTOMERS
FROM @P5_CSV_STAGE/customers.csv
FILE_FORMAT = P5_CSV_FORMAT;

COPY INTO P5_STG_PRODUCTS
FROM @P5_CSV_STAGE/products.csv
FILE_FORMAT = P5_CSV_FORMAT;

COPY INTO P5_STG_BRANCHES
FROM @P5_CSV_STAGE/branches.csv
FILE_FORMAT = P5_CSV_FORMAT;

COPY INTO P5_STG_CALENDAR
FROM @P5_CSV_STAGE/calendar.csv
FILE_FORMAT = P5_CSV_FORMAT;

COPY INTO P5_STG_SALES
FROM @P5_CSV_STAGE/sales.csv
FILE_FORMAT = P5_CSV_FORMAT;


-- ============================================================
-- 9. CREATE DIMENSION TABLES
-- ============================================================

USE SCHEMA P5_ANALYTICS;

CREATE TABLE P5_DIM_CUSTOMER (
    CUSTOMER_ID NUMBER PRIMARY KEY,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(100),
    STATE VARCHAR(100),
    MEMBERSHIP VARCHAR(50)
);

CREATE TABLE P5_DIM_PRODUCT (
    PRODUCT_ID NUMBER PRIMARY KEY,
    PRODUCT_NAME VARCHAR(100),
    CATEGORY VARCHAR(100),
    BRAND VARCHAR(100),
    PRICE NUMBER(12,2)
);

CREATE TABLE P5_DIM_BRANCH (
    BRANCH_ID NUMBER PRIMARY KEY,
    BRANCH_NAME VARCHAR(150),
    CITY VARCHAR(100),
    STATE VARCHAR(100),
    REGION VARCHAR(50),
    MANAGER_NAME VARCHAR(100)
);

CREATE TABLE P5_DIM_DATE (
    DATE_ID NUMBER PRIMARY KEY,
    DATE DATE,
    DAY NUMBER,
    DAY_NAME VARCHAR(20),
    WEEK_NO NUMBER,
    MONTH VARCHAR(20),
    QUARTER VARCHAR(10),
    YEAR NUMBER,
    IS_WEEKEND VARCHAR(10)
);


-- ============================================================
-- 10. CREATE FACT TABLE
-- ============================================================

CREATE TABLE P5_FACT_SALES (
    SALE_ID NUMBER PRIMARY KEY,

    CUSTOMER_ID NUMBER,
    PRODUCT_ID NUMBER,
    BRANCH_ID NUMBER,
    DATE_ID NUMBER,

    QUANTITY NUMBER,
    TOTAL_AMOUNT NUMBER(12,2),

    CONSTRAINT P5_FK_CUSTOMER
        FOREIGN KEY (CUSTOMER_ID)
        REFERENCES P5_DIM_CUSTOMER(CUSTOMER_ID),

    CONSTRAINT P5_FK_PRODUCT
        FOREIGN KEY (PRODUCT_ID)
        REFERENCES P5_DIM_PRODUCT(PRODUCT_ID),

    CONSTRAINT P5_FK_BRANCH
        FOREIGN KEY (BRANCH_ID)
        REFERENCES P5_DIM_BRANCH(BRANCH_ID),

    CONSTRAINT P5_FK_DATE
        FOREIGN KEY (DATE_ID)
        REFERENCES P5_DIM_DATE(DATE_ID)
);


-- ============================================================
-- 11. LOAD CUSTOMER DIMENSION
-- ============================================================

INSERT INTO P5_DIM_CUSTOMER (
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP
)
SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_CUSTOMERS;


-- ============================================================
-- 12. LOAD PRODUCT DIMENSION
-- ============================================================

INSERT INTO P5_DIM_PRODUCT (
    PRODUCT_ID,
    PRODUCT_NAME,
    CATEGORY,
    BRAND,
    PRICE
)
SELECT
    PRODUCT_ID,
    PRODUCT_NAME,
    CATEGORY,
    BRAND,
    PRICE
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_PRODUCTS;


-- ============================================================
-- 13. LOAD BRANCH DIMENSION
-- ============================================================

INSERT INTO P5_DIM_BRANCH (
    BRANCH_ID,
    BRANCH_NAME,
    CITY,
    STATE,
    REGION,
    MANAGER_NAME
)
SELECT
    BRANCH_ID,
    BRANCH_NAME,
    CITY,
    STATE,
    REGION,
    MANAGER_NAME
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_BRANCHES;


-- ============================================================
-- 14. LOAD DATE DIMENSION
-- ============================================================

INSERT INTO P5_DIM_DATE (
    DATE_ID,
    DATE,
    DAY,
    DAY_NAME,
    WEEK_NO,
    MONTH,
    QUARTER,
    YEAR,
    IS_WEEKEND
)
SELECT
    DATE_ID,
    DATE,
    DAY,
    DAY_NAME,
    WEEK_NO,
    MONTH,
    QUARTER,
    YEAR,
    IS_WEEKEND
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_CALENDAR;


-- ============================================================
-- 15. LOAD FACT TABLE
-- ============================================================

INSERT INTO P5_FACT_SALES (
    SALE_ID,
    CUSTOMER_ID,
    PRODUCT_ID,
    BRANCH_ID,
    DATE_ID,
    QUANTITY,
    TOTAL_AMOUNT
)
SELECT
    SALE_ID,
    CUSTOMER_ID,
    PRODUCT_ID,
    BRANCH_ID,
    DATE_ID,
    QUANTITY,
    TOTAL_AMOUNT
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_SALES;



-- ============================================================
-- 16. VERIFY ROW COUNTS
-- ============================================================

SELECT 'STG_CUSTOMERS' AS TABLE_NAME,
       COUNT(*) AS ROW_COUNT
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_CUSTOMERS

UNION ALL

SELECT 'STG_PRODUCTS',
       COUNT(*)
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_PRODUCTS

UNION ALL

SELECT 'STG_BRANCHES',
       COUNT(*)
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_BRANCHES

UNION ALL

SELECT 'STG_CALENDAR',
       COUNT(*)
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_CALENDAR

UNION ALL

SELECT 'STG_SALES',
       COUNT(*)
FROM P5_RETAIL_DB.P5_STAGING.P5_STG_SALES

UNION ALL

SELECT 'DIM_CUSTOMER',
       COUNT(*)
FROM P5_DIM_CUSTOMER

UNION ALL

SELECT 'DIM_PRODUCT',
       COUNT(*)
FROM P5_DIM_PRODUCT

UNION ALL

SELECT 'DIM_BRANCH',
       COUNT(*)
FROM P5_DIM_BRANCH

UNION ALL

SELECT 'DIM_DATE',
       COUNT(*)
FROM P5_DIM_DATE

UNION ALL

SELECT 'FACT_SALES',
       COUNT(*)
FROM P5_FACT_SALES;


-- ============================================================
-- 17. DISPLAY DIMENSION DATA
-- ============================================================

SELECT *
FROM P5_DIM_CUSTOMER
ORDER BY CUSTOMER_ID;

SELECT *
FROM P5_DIM_PRODUCT
ORDER BY PRODUCT_ID;

SELECT *
FROM P5_DIM_BRANCH
ORDER BY BRANCH_ID;

SELECT *
FROM P5_DIM_DATE
ORDER BY DATE_ID;

SELECT *
FROM P5_FACT_SALES
ORDER BY SALE_ID;


-- ============================================================
-- 18. DUPLICATE KEY VALIDATION
-- ============================================================

SELECT
    CUSTOMER_ID,
    COUNT(*) AS RECORD_COUNT
FROM P5_DIM_CUSTOMER
GROUP BY CUSTOMER_ID
HAVING COUNT(*) > 1;

SELECT
    PRODUCT_ID,
    COUNT(*) AS RECORD_COUNT
FROM P5_DIM_PRODUCT
GROUP BY PRODUCT_ID
HAVING COUNT(*) > 1;

SELECT
    BRANCH_ID,
    COUNT(*) AS RECORD_COUNT
FROM P5_DIM_BRANCH
GROUP BY BRANCH_ID
HAVING COUNT(*) > 1;

SELECT
    DATE_ID,
    COUNT(*) AS RECORD_COUNT
FROM P5_DIM_DATE
GROUP BY DATE_ID
HAVING COUNT(*) > 1;

SELECT
    SALE_ID,
    COUNT(*) AS RECORD_COUNT
FROM P5_FACT_SALES
GROUP BY SALE_ID
HAVING COUNT(*) > 1;


-- ============================================================
-- 19. ORPHAN CUSTOMER CHECK
-- ============================================================

SELECT F.*
FROM P5_FACT_SALES F
LEFT JOIN P5_DIM_CUSTOMER C
    ON F.CUSTOMER_ID = C.CUSTOMER_ID
WHERE C.CUSTOMER_ID IS NULL;


-- ============================================================
-- 20. ORPHAN PRODUCT CHECK
-- ============================================================

SELECT F.*
FROM P5_FACT_SALES F
LEFT JOIN P5_DIM_PRODUCT P
    ON F.PRODUCT_ID = P.PRODUCT_ID
WHERE P.PRODUCT_ID IS NULL;


-- ============================================================
-- 21. ORPHAN BRANCH CHECK
-- ============================================================

SELECT F.*
FROM P5_FACT_SALES F
LEFT JOIN P5_DIM_BRANCH B
    ON F.BRANCH_ID = B.BRANCH_ID
WHERE B.BRANCH_ID IS NULL;


-- ============================================================
-- 22. ORPHAN DATE CHECK
-- ============================================================

SELECT F.*
FROM P5_FACT_SALES F
LEFT JOIN P5_DIM_DATE D
    ON F.DATE_ID = D.DATE_ID
WHERE D.DATE_ID IS NULL;


-- ============================================================
-- 23. CUSTOMER -> FACT RELATIONSHIP
-- ============================================================

SELECT
    C.CUSTOMER_ID,
    C.CUSTOMER_NAME,
    COUNT(F.SALE_ID) AS SALES_COUNT
FROM P5_DIM_CUSTOMER C
LEFT JOIN P5_FACT_SALES F
    ON C.CUSTOMER_ID = F.CUSTOMER_ID
GROUP BY
    C.CUSTOMER_ID,
    C.CUSTOMER_NAME
ORDER BY C.CUSTOMER_ID;


-- ============================================================
-- 24. PRODUCT -> FACT RELATIONSHIP
-- ============================================================

SELECT
    P.PRODUCT_ID,
    P.PRODUCT_NAME,
    COUNT(F.SALE_ID) AS SALES_COUNT
FROM P5_DIM_PRODUCT P
LEFT JOIN P5_FACT_SALES F
    ON P.PRODUCT_ID = F.PRODUCT_ID
GROUP BY
    P.PRODUCT_ID,
    P.PRODUCT_NAME
ORDER BY P.PRODUCT_ID;


-- ============================================================
-- 25. BRANCH -> FACT RELATIONSHIP
-- ============================================================

SELECT
    B.BRANCH_ID,
    B.BRANCH_NAME,
    COUNT(F.SALE_ID) AS SALES_COUNT
FROM P5_DIM_BRANCH B
LEFT JOIN P5_FACT_SALES F
    ON B.BRANCH_ID = F.BRANCH_ID
GROUP BY
    B.BRANCH_ID,
    B.BRANCH_NAME
ORDER BY B.BRANCH_ID;


-- ============================================================
-- 26. DATE -> FACT RELATIONSHIP
-- ============================================================

SELECT
    D.DATE_ID,
    D.DATE,
    COUNT(F.SALE_ID) AS SALES_COUNT
FROM P5_DIM_DATE D
LEFT JOIN P5_FACT_SALES F
    ON D.DATE_ID = F.DATE_ID
GROUP BY
    D.DATE_ID,
    D.DATE
ORDER BY D.DATE_ID;


-- ============================================================
-- 27. COMPLETE STAR SCHEMA JOIN
-- ============================================================

SELECT
    F.SALE_ID,

    C.CUSTOMER_NAME,
    C.CITY AS CUSTOMER_CITY,
    C.STATE AS CUSTOMER_STATE,
    C.MEMBERSHIP,

    P.PRODUCT_NAME,
    P.CATEGORY,
    P.BRAND,
    P.PRICE,

    B.BRANCH_NAME,
    B.CITY AS BRANCH_CITY,
    B.STATE AS BRANCH_STATE,
    B.REGION,
    B.MANAGER_NAME,

    D.DATE,
    D.DAY,
    D.DAY_NAME,
    D.WEEK_NO,
    D.MONTH,
    D.QUARTER,
    D.YEAR,
    D.IS_WEEKEND,

    F.QUANTITY,
    F.TOTAL_AMOUNT

FROM P5_FACT_SALES F

JOIN P5_DIM_CUSTOMER C
    ON F.CUSTOMER_ID = C.CUSTOMER_ID

JOIN P5_DIM_PRODUCT P
    ON F.PRODUCT_ID = P.PRODUCT_ID

JOIN P5_DIM_BRANCH B
    ON F.BRANCH_ID = B.BRANCH_ID

JOIN P5_DIM_DATE D
    ON F.DATE_ID = D.DATE_ID

ORDER BY F.SALE_ID;


-- ============================================================
-- 28. CUSTOMER-WISE SALES
-- ============================================================

SELECT
    C.CUSTOMER_ID,
    C.CUSTOMER_NAME,
    SUM(F.QUANTITY) AS TOTAL_QUANTITY,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_SALES
FROM P5_FACT_SALES F
JOIN P5_DIM_CUSTOMER C
    ON F.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY
    C.CUSTOMER_ID,
    C.CUSTOMER_NAME
ORDER BY TOTAL_SALES DESC;


-- ============================================================
-- 29. PRODUCT-WISE REVENUE
-- ============================================================

SELECT
    P.PRODUCT_ID,
    P.PRODUCT_NAME,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_PRODUCT P
    ON F.PRODUCT_ID = P.PRODUCT_ID
GROUP BY
    P.PRODUCT_ID,
    P.PRODUCT_NAME
ORDER BY TOTAL_REVENUE DESC;


-- ============================================================
-- 30. BRANCH-WISE REVENUE
-- ============================================================

SELECT
    B.BRANCH_ID,
    B.BRANCH_NAME,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_BRANCH B
    ON F.BRANCH_ID = B.BRANCH_ID
GROUP BY
    B.BRANCH_ID,
    B.BRANCH_NAME
ORDER BY TOTAL_REVENUE DESC;


-- ============================================================
-- 31. STATE-WISE REVENUE
-- ============================================================

SELECT
    B.STATE,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_BRANCH B
    ON F.BRANCH_ID = B.BRANCH_ID
GROUP BY B.STATE
ORDER BY TOTAL_REVENUE DESC;


-- ============================================================
-- 32. MONTHLY REVENUE
-- ============================================================

SELECT
    D.YEAR,
    D.MONTH,
    SUM(F.TOTAL_AMOUNT) AS MONTHLY_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_DATE D
    ON F.DATE_ID = D.DATE_ID
GROUP BY
    D.YEAR,
    D.MONTH
ORDER BY
    D.YEAR,
    D.MONTH;


-- ============================================================
-- 33. QUARTERLY REVENUE
-- ============================================================

SELECT
    D.YEAR,
    D.QUARTER,
    SUM(F.TOTAL_AMOUNT) AS QUARTERLY_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_DATE D
    ON F.DATE_ID = D.DATE_ID
GROUP BY
    D.YEAR,
    D.QUARTER
ORDER BY
    D.YEAR,
    D.QUARTER;


-- ============================================================
-- 34. TOP 10 CUSTOMERS
-- ============================================================

SELECT
    C.CUSTOMER_ID,
    C.CUSTOMER_NAME,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_CUSTOMER C
    ON F.CUSTOMER_ID = C.CUSTOMER_ID
GROUP BY
    C.CUSTOMER_ID,
    C.CUSTOMER_NAME
ORDER BY TOTAL_REVENUE DESC
LIMIT 10;


-- ============================================================
-- 35. TOP 10 PRODUCTS
-- ============================================================

SELECT
    P.PRODUCT_ID,
    P.PRODUCT_NAME,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_PRODUCT P
    ON F.PRODUCT_ID = P.PRODUCT_ID
GROUP BY
    P.PRODUCT_ID,
    P.PRODUCT_NAME
ORDER BY TOTAL_REVENUE DESC
LIMIT 10;


-- ============================================================
-- 36. TOP 10 PERFORMING BRANCHES
-- ============================================================

SELECT
    B.BRANCH_ID,
    B.BRANCH_NAME,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_BRANCH B
    ON F.BRANCH_ID = B.BRANCH_ID
GROUP BY
    B.BRANCH_ID,
    B.BRANCH_NAME
ORDER BY TOTAL_REVENUE DESC
LIMIT 10;


-- ============================================================
-- 37. CATEGORY-WISE REVENUE
-- ============================================================

SELECT
    P.CATEGORY,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_PRODUCT P
    ON F.PRODUCT_ID = P.PRODUCT_ID
GROUP BY P.CATEGORY
ORDER BY TOTAL_REVENUE DESC;


-- ============================================================
-- 38. CUSTOMER PURCHASE TREND
-- ============================================================

SELECT
    C.CUSTOMER_ID,
    C.CUSTOMER_NAME,
    D.DATE,
    SUM(F.QUANTITY) AS QUANTITY_PURCHASED,
    SUM(F.TOTAL_AMOUNT) AS REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_CUSTOMER C
    ON F.CUSTOMER_ID = C.CUSTOMER_ID
JOIN P5_DIM_DATE D
    ON F.DATE_ID = D.DATE_ID
GROUP BY
    C.CUSTOMER_ID,
    C.CUSTOMER_NAME,
    D.DATE
ORDER BY
    C.CUSTOMER_ID,
    D.DATE;


-- ============================================================
-- 39. PRODUCT PERFORMANCE
-- ============================================================

SELECT
    P.PRODUCT_ID,
    P.PRODUCT_NAME,
    P.CATEGORY,
    P.BRAND,
    SUM(F.QUANTITY) AS UNITS_SOLD,
    COUNT(DISTINCT F.SALE_ID) AS TRANSACTIONS,
    SUM(F.TOTAL_AMOUNT) AS REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_PRODUCT P
    ON F.PRODUCT_ID = P.PRODUCT_ID
GROUP BY
    P.PRODUCT_ID,
    P.PRODUCT_NAME,
    P.CATEGORY,
    P.BRAND
ORDER BY REVENUE DESC;


-- ============================================================
-- 40. BRANCH PERFORMANCE
-- ============================================================

SELECT
    B.BRANCH_ID,
    B.BRANCH_NAME,
    B.CITY,
    B.STATE,
    B.REGION,
    SUM(F.QUANTITY) AS UNITS_SOLD,
    COUNT(DISTINCT F.SALE_ID) AS TRANSACTIONS,
    SUM(F.TOTAL_AMOUNT) AS REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_BRANCH B
    ON F.BRANCH_ID = B.BRANCH_ID
GROUP BY
    B.BRANCH_ID,
    B.BRANCH_NAME,
    B.CITY,
    B.STATE,
    B.REGION
ORDER BY REVENUE DESC;


-- ============================================================
-- 41. REGIONAL SALES ANALYSIS
-- ============================================================

SELECT
    B.REGION,
    SUM(F.QUANTITY) AS TOTAL_QUANTITY,
    SUM(F.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_BRANCH B
    ON F.BRANCH_ID = B.BRANCH_ID
GROUP BY B.REGION
ORDER BY TOTAL_REVENUE DESC;


-- ============================================================
-- 42. SALES TREND ANALYSIS
-- ============================================================

SELECT
    D.DATE,
    SUM(F.QUANTITY) AS DAILY_QUANTITY,
    SUM(F.TOTAL_AMOUNT) AS DAILY_REVENUE
FROM P5_FACT_SALES F
JOIN P5_DIM_DATE D
    ON F.DATE_ID = D.DATE_ID
GROUP BY D.DATE
ORDER BY D.DATE;


-- ============================================================
-- 43. FINAL OBJECT CHECK
-- ============================================================

SHOW TABLES IN SCHEMA P5_RETAIL_DB.P5_STAGING;

SHOW TABLES IN SCHEMA P5_RETAIL_DB.P5_ANALYTICS;

SHOW STAGES IN SCHEMA P5_RETAIL_DB.P5_STAGING;

SHOW FILE FORMATS IN SCHEMA P5_RETAIL_DB.P5_STAGING;