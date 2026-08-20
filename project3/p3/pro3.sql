CREATE WAREHOUSE ENTERPRISE_WH
WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

CREATE DATABASE ENTERPRISE_DB;

CREATE SCHEMA ENTERPRISE_DB.SALES_SCHEMA;

USE WAREHOUSE ENTERPRISE_WH;

USE DATABASE ENTERPRISE_DB;

USE SCHEMA SALES_SCHEMA;

CREATE FILE FORMAT CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1;

CREATE STAGE ENTERPRISE_STAGE
FILE_FORMAT = CSV_FORMAT;

LIST @ENTERPRISE_STAGE;

CREATE TABLE CUSTOMERS (
    customer_id NUMBER,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    membership VARCHAR(20)
);

CREATE TABLE PRODUCTS (
    product_id NUMBER,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price NUMBER(10,2)
);

CREATE TABLE BRANCHES (
    branch_id NUMBER,
    branch_name VARCHAR(100),
    state VARCHAR(50)
);

CREATE OR REPLACE TABLE SALES (
    sale_id NUMBER,
    customer_id NUMBER,
    product_id NUMBER,
    branch_id NUMBER,
    quantity NUMBER,
    sale_date DATE,
    total_amount NUMBER(10,2)
);

CREATE TABLE NEW_SALES_STAGING (
    sale_id NUMBER,
    customer_id NUMBER,
    product_id NUMBER,
    branch_id NUMBER,
    quantity NUMBER,
    sale_date DATE,
    total_amount NUMBER(10,2)
);

COPY INTO CUSTOMERS
FROM @ENTERPRISE_STAGE/customers.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO PRODUCTS
FROM @ENTERPRISE_STAGE/products.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO BRANCHES
FROM @ENTERPRISE_STAGE/branches.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO SALES
FROM @ENTERPRISE_STAGE/sales_history.csv
FILE_FORMAT = CSV_FORMAT;

SELECT * FROM SALES
ORDER BY sale_id;

SELECT COUNT(*) AS customer_count
FROM CUSTOMERS;

SELECT COUNT(*) AS product_count
FROM PRODUCTS;

SELECT COUNT(*) AS branch_count
FROM BRANCHES;

SELECT COUNT(*) AS sales_count
FROM SALES;

CREATE OR REPLACE STREAM SALES_STREAM
ON TABLE SALES;

COPY INTO NEW_SALES_STAGING
FROM @ENTERPRISE_STAGE/new_sales.csv
FILE_FORMAT = CSV_FORMAT;

SELECT *
FROM NEW_SALES_STAGING
ORDER BY sale_id;

SELECT COUNT(*) AS new_records
FROM NEW_SALES_STAGING;

SELECT
    sale_id,
    COUNT(*) AS record_count
FROM NEW_SALES_STAGING
GROUP BY sale_id
HAVING COUNT(*) > 1;

SELECT
    n.sale_id,
    n.customer_id
FROM NEW_SALES_STAGING n
LEFT JOIN CUSTOMERS c
    ON n.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT
    n.sale_id,
    n.product_id
FROM NEW_SALES_STAGING n
LEFT JOIN PRODUCTS p
    ON n.product_id = p.product_id
WHERE p.product_id IS NULL;

MERGE INTO SALES AS target
USING NEW_SALES_STAGING AS source
ON target.sale_id = source.sale_id

WHEN MATCHED THEN
    UPDATE SET
        target.customer_id = source.customer_id,
        target.product_id = source.product_id,
        target.branch_id = source.branch_id,
        target.quantity = source.quantity,
        target.sale_date = source.sale_date,
        target.total_amount = source.total_amount

WHEN NOT MATCHED THEN
    INSERT (
        sale_id,
        customer_id,
        product_id,
        branch_id,
        quantity,
        sale_date,
        total_amount
    )
    VALUES (
        source.sale_id,
        source.customer_id,
        source.product_id,
        source.branch_id,
        source.quantity,
        source.sale_date,
        source.total_amount
    );

SELECT *
FROM SALES
ORDER BY sale_id;

SELECT COUNT(*) AS total_sales
FROM SALES;

SELECT
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount,
    METADATA$ACTION,
    METADATA$ISUPDATE
FROM SALES_STREAM
WHERE METADATA$ACTION = 'INSERT';

SELECT
    sale_id,
    COUNT(*) AS record_count
FROM SALES
GROUP BY sale_id
HAVING COUNT(*) > 1;

SELECT
    s.sale_id,
    s.customer_id
FROM SALES s
LEFT JOIN CUSTOMERS c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT
    s.sale_id,
    s.product_id
FROM SALES s
LEFT JOIN PRODUCTS p
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS new_sales_count
FROM NEW_SALES_STAGING;

SELECT *
FROM SALES
ORDER BY sale_id;

DELETE FROM SALES
WHERE sale_id = 10;

SELECT *
FROM SALES
WHERE sale_id = 10;

SELECT *
FROM SALES
AT (
    STATEMENT => '01c67186-000d-e91f-0001-78da000e829e'
)
WHERE sale_id = 10;

SELECT *
FROM SALES
AT (
    TIMESTAMP => '2026-08-16 22:26:17.000 -0700'::TIMESTAMP_TZ
)
WHERE sale_id = 10;

INSERT INTO SALES
SELECT *
FROM SALES
AT (
    STATEMENT => '01c67186-000d-e91f-0001-78da000e829e'
)
WHERE sale_id = 10;

SELECT *
FROM SALES
WHERE sale_id = 10;

CREATE TABLE SALES_TEST
CLONE SALES;

SELECT *
FROM SALES_TEST
ORDER BY sale_id;

INSERT INTO SALES_TEST (
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount
)
VALUES (
    999,
    1,
    101,
    1,
    1,
    '2026-07-20',
    60000
);

SELECT *
FROM SALES_TEST
WHERE sale_id = 999;

CREATE OR REPLACE TASK DAILY_INCREMENTAL_LOAD
WAREHOUSE = ENTERPRISE_WH
SCHEDULE = 'USING CRON 0 1 * * * UTC'
AS
MERGE INTO SALES AS target
USING NEW_SALES_STAGING AS source
ON target.sale_id = source.sale_id

WHEN MATCHED THEN
    UPDATE SET
        target.customer_id = source.customer_id,
        target.product_id = source.product_id,
        target.branch_id = source.branch_id,
        target.quantity = source.quantity,
        target.sale_date = source.sale_date,
        target.total_amount = source.total_amount

WHEN NOT MATCHED THEN
    INSERT (
        sale_id,
        customer_id,
        product_id,
        branch_id,
        quantity,
        sale_date,
        total_amount
    )
    VALUES (
        source.sale_id,
        source.customer_id,
        source.product_id,
        source.branch_id,
        source.quantity,
        source.sale_date,
        source.total_amount
    );

ALTER TASK DAILY_INCREMENTAL_LOAD RESUME;

EXECUTE TASK DAILY_INCREMENTAL_LOAD;

SELECT *
FROM SALES
ORDER BY sale_id;

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'DAILY_INCREMENTAL_LOAD'
    )
)
ORDER BY SCHEDULED_TIME DESC;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_revenue
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_revenue DESC;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_revenue
FROM BRANCHES b
INNER JOIN SALES s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_revenue DESC;

SELECT
    p.product_id,
    p.product_name,
    SUM(s.total_amount) AS total_revenue
FROM PRODUCTS p
INNER JOIN SALES s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC;

SELECT
    DATE_TRUNC('MONTH', sale_date) AS sales_month,
    SUM(total_amount) AS monthly_revenue
FROM SALES
GROUP BY DATE_TRUNC('MONTH', sale_date)
ORDER BY sales_month;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_revenue
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_revenue DESC
LIMIT 1;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_revenue
FROM BRANCHES b
INNER JOIN SALES s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_revenue DESC
LIMIT 1;

SELECT
    p.product_id,
    p.product_name,
    SUM(s.total_amount) AS total_revenue
FROM PRODUCTS p
INNER JOIN SALES s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC
LIMIT 5;

SELECT
    c.customer_id,
    c.customer_name,
    COUNT(s.sale_id) AS purchase_count
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY purchase_count DESC;

SELECT
    sale_id,
    sale_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM SALES
ORDER BY sale_date;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_revenue,
    RANK() OVER (
        ORDER BY SUM(s.total_amount) DESC
    ) AS customer_rank
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY customer_rank;

CREATE OR REPLACE VIEW CUSTOMER_REVENUE AS
SELECT
    c.customer_id,
    c.customer_name,
    c.city,
    c.membership,
    SUM(s.total_amount) AS total_revenue
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.city,
    c.membership;

SELECT *
FROM CUSTOMER_REVENUE
ORDER BY total_revenue DESC;

CREATE OR REPLACE MATERIALIZED VIEW BRANCH_REVENUE AS
SELECT
    branch_id,
    SUM(total_amount) AS total_revenue
FROM SALES
GROUP BY branch_id;

SELECT
    br.branch_id,
    b.branch_name,
    b.state,
    br.total_revenue
FROM BRANCH_REVENUE br
INNER JOIN BRANCHES b
    ON br.branch_id = b.branch_id
ORDER BY br.total_revenue DESC;