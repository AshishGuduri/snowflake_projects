-- 1.Create Warehouse ENTERPRISE_WH
CREATE WAREHOUSE ENTERPRISE_WH;

-- 2.Create Database ENTERPRISE_DB
CREATE DATABASE ENTERPRISE_DB;

-- 3.Create Schema SALES_SCHEMA
CREATE SCHEMA ENTERPRISE_DB.SALES_SCHEMA;

-- 4.Create CSV File Format
CREATE FILE FORMAT CSV_FILE
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1; 

-- 5.Create Internal Stage
CREATE STAGE PROJECT_3 FILE_FORMAT = CSV_FILE;

-- 6.Upload all CSV files.
-- 7.Create all required tables.
CREATE TABLE branches(
    branch_id INT PRIMARY KEY,
    branch_name VARCHAR(50),
    state VARCHAR(50)
);

CREATE TABLE customers(
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(50),
    city VARCHAR(50),
    membership VARCHAR(50)
);

CREATE TABLE products(
    product_id INT PRIMARY KEY,
    product_name VARCHAR(50),
    category VARCHAR(50),
    price INT
);

CREATE TABLE sales(
    sale_id INT PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    product_id INT REFERENCES products(product_id),
    branch_id INT REFERENCES branches(branch_id),
    quantity INT,
    sale_date TIMESTAMP_NTZ,
    total_amount INT
);  

COPY INTO branches 
FROM @PROJECT_3/branches.csv;

COPY INTO customers 
FROM @PROJECT_3/customers.csv;

COPY INTO products 
FROM @PROJECT_3/products.csv;

-- 8.Load sales_history.csv into SALES table.
COPY INTO sales 
FROM @PROJECT_3/sales_history.csv;

-- 9.Verify the loaded records.
SELECT * FROM customers;
SELECT * FROM branches;
SELECT * FROM products;
SELECT * FROM sales;

-- 10.Create a Stream on the SALES table.
CREATE TABLE sales_new LIKE sales;
CREATE STREAM SALES_STREAM ON TABLE sales_new;

-- 11.Load new_sales.csv.
COPY INTO sales_new 
FROM @PROJECT_3/new_sales.csv;

-- 12.Display only newly inserted records using the Stream.
SELECT * FROM SALES_STREAM;

-- 13.Merge newly arrived records into the SALES table.
MERGE INTO sales AS tgt
USING SALES_STREAM AS src
    ON tgt.sale_id = src.sale_id
WHEN NOT MATCHED THEN
    INSERT (sale_id, customer_id, product_id, branch_id, quantity, sale_date, total_amount)
    VALUES(src.sale_id,src.customer_id, src.product_id,src.branch_id, src.quantity, src.sale_date, src.total_amount);

-- 14.Identify duplicate Sale IDs.
SELECT
    sale_id,
    COUNT(sale_id) AS Occurrences
FROM sales 
GROUP BY sale_id
HAVING COUNT(sale_id) > 1;

-- 15.Identify missing Customer IDs.
SELECT 
    customer_id
FROM sales s
WHERE NOT EXISTS(SELECT customer_id FROM customers c WHERE c.customer_id = s.customer_id);

-- 16.Display invalid Product IDs.
SELECT
    product_id 
FROM sales s
WHERE NOT EXISTS(SELECT product_id FROM products p WHERE p.product_id = s.product_id);

-- 17.Count total newly inserted records.
SELECT 
    COUNT(*) 
FROM sales
WHERE sale_id > 5;

-- 18.Delete one sales record.
DELETE FROM sales WHERE sale_id = 5;
SELECT * FROM SALES;

-- 19.Recover the deleted record using Time Travel.
INSERT INTO sales
SELECT * FROM sales AT (OFFSET=>-600)
MINUS
SELECT * FROM sales;

-- 20.Verify recovery.
SELECT * FROM sales WHERE sale_id = 5;

-- 21.Create a clone named: SALES_TEST
CREATE TABLE SALES_TEST CLONE sales;

-- 22.Display cloned records.
SELECT * FROM sales_test;

-- 23.Insert one new record into the clone.
INSERT INTO sales_test VALUES (11, 1, 101, 1, 1, '2026-07-11', 60000);

-- 24.Verify that the original SALES table remains unchanged.
SELECT COUNT(*) FROM sales;
SELECT COUNT(*) FROM sales_test;

-- 25.Create a Task that automatically performs incremental loading every day.
CREATE TASK loading
    WAREHOUSE = 'ENTERPRISE_WH'
    SCHEDULE = '1440 MINUTE'
AS 
    MERGE INTO sales AS tgt
    USING SALES_STREAM AS src
        ON tgt.sale_id = src.sale_id
    WHEN NOT MATCHED THEN
        INSERT (sale_id, customer_id, product_id, branch_id, quantity, sale_date, total_amount)
        VALUES(src.sale_id,src.customer_id, src.product_id,src.branch_id, src.quantity, src.sale_date, src.total_amount);

-- 26.Resume the Task.
ALTER TASK loading RESUME;

-- 27.Verify Task execution.
SHOW TASKS;

-- Generate
-- 28.Customer Revenue Report
SELECT
    c.customer_id,
    c.customer_name AS "Customer Name",
    SUM(s.total_amount) AS "Revenue"
FROM customers c
JOIN sales s
    ON s.customer_id = c.customer_id
GROUP BY 
    c.customer_id,
    c.customer_name
ORDER BY "Revenue" DESC;

-- 29.Branch Revenue Report
SELECT
    b.branch_id,
    b.branch_name AS "Branch Name",
    SUM(s.total_amount) AS "Revenue"
FROM branches b
JOIN sales s
    ON s.branch_id = b.branch_id
GROUP BY 
    b.branch_id,
    b.branch_name
ORDER BY "Revenue" DESC;

-- 30.Product Revenue Report
SELECT
    p.product_id,
    p.product_name AS "Product Name",
    SUM(s.total_amount) AS "Revenue"
FROM products p
JOIN sales s
    ON s.product_id = p.product_id
GROUP BY 
    p.product_name,
    p.product_id
ORDER BY "Revenue" DESC;

-- 31.Monthly Revenue Report
SELECT  
    MONTHNAME(s.sale_date) AS "MONTH",
    SUM(s.total_amount) AS Revenue
FROM sales s
GROUP BY MONTHNAME(s.sale_date)
ORDER BY Revenue DESC;

-- 32.Highest Revenue Customer
SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS "Revenue"
FROM sales s
JOIN customers c
    ON s.customer_id = c.customer_id
GROUP BY c.customer_name, c.customer_id
ORDER BY "Revenue" DESC
LIMIT 1;

-- 33.Highest Revenue Branch
SELECT 
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS "Revenue"
FROM Sales s
JOIN branches b
    ON s.branch_id = b.branch_id
GROUP BY 
    b.branch_id,
    b.branch_name
ORDER BY "Revenue" DESC
LIMIT 1;

-- 34.Top Five Products
SELECT
    p.product_id,
    p.product_name,
    SUM(s.total_amount) AS "Revenue",
    SUM(s.quantity) AS "Quantity",
    RANK() OVER (ORDER BY SUM(s.total_amount) DESC, SUM(s.quantity) DESC) AS "Rnk"
FROM products p
JOIN sales s
    ON p.product_id = s.product_id
GROUP BY p.product_id, p.product_name
ORDER BY "Rnk" ASC
LIMIT 5;

-- 35.Customer Purchase Frequency
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(sale_id) AS "Purchase Frequency"
FROM customers c
JOIN sales s
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.customer_name;

-- 36.Running Revenue
SELECT
    s.sale_id,
    s.sale_date,
    SUM(s.total_amount) OVER(ORDER BY s.sale_date) AS "Running Revenue"
FROM sales s
ORDER BY s.sale_date;

-- 37.Customer Ranking
SELECT
    c.customer_id,
    c.customer_name,
    RANK() OVER(ORDER BY SUM(s.total_amount) DESC) AS rnk
FROM customers c
JOIN sales s
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name;

-- 38.Create View: CUSTOMER_REVENUE
CREATE VIEW CUSTOMER_REVENUE AS
SELECT c.customer_id, c.customer_name, SUM(s.total_amount) AS "Revenue"
FROM customers c JOIN sales s ON s.customer_id = c.customer_id
GROUP BY c.customer_id,c.customer_name;

-- 39.Create Materialized View: BRANCH_REVENUE
CREATE MATERIALIZED VIEW BRANCH_REVENUE AS
SELECT s.branch_id, SUM(s.total_amount) AS "Revenue"
FROM sales s
GROUP BY s.branch_id;

-- 40.Display data from both Views.
SELECT * FROM CUSTOMER_REVENUE;
SELECT * FROM BRANCH_REVENUE;
