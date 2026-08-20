CREATE WAREHOUSE RETAIL_WH
WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

CREATE DATABASE RETAIL_DB;

CREATE SCHEMA RETAIL_DB.SALES_SCHEMA;

USE WAREHOUSE RETAIL_WH;

USE DATABASE RETAIL_DB;

USE SCHEMA SALES_SCHEMA;

SELECT CURRENT_WAREHOUSE();

SELECT CURRENT_DATABASE();

SELECT CURRENT_SCHEMA();

CREATE FILE FORMAT CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1;

CREATE STAGE RETAIL_STAGE
FILE_FORMAT = CSV_FORMAT;

LIST @RETAIL_STAGE;

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
    city VARCHAR(50)
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

COPY INTO CUSTOMERS
FROM @RETAIL_STAGE/customers.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO PRODUCTS
FROM @RETAIL_STAGE/products.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO BRANCHES
FROM @RETAIL_STAGE/branches.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO SALES
FROM @RETAIL_STAGE/sales2.csv
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT);

SELECT *
FROM CUSTOMERS;

SELECT *
FROM PRODUCTS;

SELECT *
FROM BRANCHES;

SELECT *
FROM SALES;

SELECT
    SUM(total_amount) AS total_revenue
FROM SALES;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_spending DESC;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_sales
FROM BRANCHES b
INNER JOIN SALES s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_sales DESC;

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
    p.category,
    SUM(s.total_amount) AS total_revenue
FROM PRODUCTS p
INNER JOIN SALES s
    ON p.product_id = s.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_sales
FROM BRANCHES b
INNER JOIN SALES s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_sales DESC
LIMIT 1;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_spending DESC
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
LIMIT 3;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_spending DESC
LIMIT 3;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending,
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

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_sales,
    RANK() OVER (
        ORDER BY SUM(s.total_amount) DESC
    ) AS branch_rank
FROM BRANCHES b
INNER JOIN SALES s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY branch_rank;

SELECT
    category,
    product_name,
    total_revenue
FROM (
    SELECT
        p.category,
        p.product_name,
        SUM(s.total_amount) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.category
            ORDER BY SUM(s.total_amount) DESC
        ) AS row_num
    FROM PRODUCTS p
    INNER JOIN SALES s
        ON p.product_id = s.product_id
    GROUP BY
        p.category,
        p.product_name
)
WHERE row_num = 1;

SELECT
    sale_id,
    sale_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sales
FROM SALES
ORDER BY sale_date;

SELECT
    sale_id,
    sale_date,
    total_amount,
    AVG(total_amount) OVER () AS average_sale_amount
FROM SALES
ORDER BY sale_date;

WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(s.total_amount) AS total_spending
    FROM CUSTOMERS c
    INNER JOIN SALES s
        ON c.customer_id = s.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
)
SELECT *
FROM customer_sales
ORDER BY total_spending DESC;

WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(s.total_amount) AS total_spending
    FROM CUSTOMERS c
    INNER JOIN SALES s
        ON c.customer_id = s.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
),
average_sales AS (
    SELECT
        AVG(total_spending) AS average_spending
    FROM customer_sales
)
SELECT
    cs.customer_id,
    cs.customer_name,
    cs.total_spending
FROM customer_sales cs
CROSS JOIN average_sales av
WHERE cs.total_spending > av.average_spending
ORDER BY cs.total_spending DESC;

CREATE OR REPLACE VIEW SALES_REPORT AS
SELECT
    s.sale_id,
    c.customer_name,
    p.product_name,
    p.category,
    b.branch_name,
    s.quantity,
    s.sale_date,
    s.total_amount
FROM SALES s
INNER JOIN CUSTOMERS c
    ON s.customer_id = c.customer_id
INNER JOIN PRODUCTS p
    ON s.product_id = p.product_id
INNER JOIN BRANCHES b
    ON s.branch_id = b.branch_id;

SELECT *
FROM SALES_REPORT;

CREATE OR REPLACE VIEW TOP_CUSTOMERS AS
SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name;

SELECT *
FROM TOP_CUSTOMERS
ORDER BY total_spending DESC
LIMIT 3;