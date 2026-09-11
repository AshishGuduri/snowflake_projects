CREATE WAREHOUSE KIMBALL;

CREATE DATABASE KIMBALL_DB;

CREATE SCHEMA KIMBALL_SCHEMA;

CREATE FILE FORMAT CSV_FILE
    FIELD_DELIMITER = ','
    TYPE = 'CSV'
    SKIP_HEADER = 1;
    
CREATE STAGE PROJECT_4 FILE_FORMAT = CSV_FILE;

-- Dimension tables first (no dependencies)

CREATE TABLE DIM_CUSTOMER (
    Customer_ID    NUMBER PRIMARY KEY,
    Customer_Name  VARCHAR(100),
    City           VARCHAR(50),
    State          VARCHAR(50),
    Membership     VARCHAR(20)
);

CREATE TABLE DIM_PRODUCT (
    Product_ID     NUMBER PRIMARY KEY,
    Product_Name   VARCHAR(100),
    Category       VARCHAR(50),
    Brand          VARCHAR(50),
    Price          NUMBER(10,2)
);

CREATE TABLE DIM_BRANCH (
    Branch_ID      NUMBER PRIMARY KEY,
    Branch_Name    VARCHAR(100),
    City           VARCHAR(50),
    State          VARCHAR(50)
);

CREATE TABLE DIM_DATE (
    Date_ID        NUMBER PRIMARY KEY,
    Date           DATE,
    Month          VARCHAR(20),
    Quarter        VARCHAR(5),
    Year           NUMBER(4)
);

-- Fact table last (depends on all four dimensions)

CREATE TABLE FACT_SALES (
    Sale_ID        NUMBER PRIMARY KEY,
    Customer_ID    NUMBER REFERENCES DIM_CUSTOMER(Customer_ID),
    Product_ID     NUMBER REFERENCES DIM_PRODUCT(Product_ID),
    Branch_ID      NUMBER REFERENCES DIM_BRANCH(Branch_ID),
    Date_ID        NUMBER REFERENCES DIM_DATE(Date_ID),
    Quantity       NUMBER,
    Total_Amount   NUMBER(12,2)
);

COPY INTO DIM_CUSTOMER 
FROM @PROJECT_4/customers.csv;

COPY INTO DIM_PRODUCT
FROM @Project_4/products.csv;

COPY INTO DIM_BRANCH(branch_id, branch_name, city, state)
FROM (
    SELECT $1, $2, $3, $4
    FROM @project_4/branches.csv
);

COPY INTO DIM_DATE(date_id, date, month, quarter, year)
FROM (
    SELECT $1, $2, $6, $7, $8
    FROM @project_4/calendar.csv
);

COPY INTO FACT_SALES
FROM @project_4/sales.csv;

SELECT * FROM DIM_CUSTOMER;
SELECT * FROM DIM_PRODUCT;
SELECT * FROM DIM_BRANCH;
SELECT * FROM DIM_DATE;
SELECT * FROM FACT_SALES;

-- Customer Revenue Report
SELECT 
    c.customer_id,
    c.customer_name,
    COALESCE(SUM(s.total_amount),0) AS Revenue
FROM DIM_CUSTOMER c
LEFT JOIN FACT_SALES s
    ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY Revenue DESC;

-- Product Revenue Report
SELECT  
    p.product_id,
    p.product_name,
    COALESCE(SUM(s.total_amount), 0) AS Revenue
FROM DIM_PRODUCT p
LEFT JOIN FACT_SALES s
    ON p.product_id = s.product_id
GROUP BY p.product_id, p.product_name
ORDER BY Revenue DESC;

-- Branch Performance Report
SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS Revenue,
    SUM(s.quantity) AS Quantity_Sold,
    COUNT(s.sale_id) AS Number_of_transcations
FROM DIM_BRANCH b
JOIN FACT_SALES s
    ON b.branch_id = s.branch_id
GROUP BY b.branch_id, b.branch_name
ORDER BY Revenue DESC, Quantity_Sold DESC, Number_of_transcations DESC;

-- Monthly Revenue Report
SELECT
    d.month,
    d.year,
    SUM(s.total_amount) AS Revenue
FROM dim_date d
JOIN fact_sales s
    ON d.date_id = s.date_id
GROUP BY d.month, d.year
ORDER BY d.year, MIN(d.month);

-- State-wise Sales Report
SELECT
    b.state,
    SUM(s.total_amount) AS Revenue
FROM dim_branch b
JOIN fact_sales s
    ON b.branch_id = s.branch_id
GROUP BY b.state
ORDER BY Revenue DESC;

-- Category-wise Revenue Report
SELECT
    p.category,
    SUM(s.total_amount) AS Revenue
FROM DIM_PRODUCT p 
JOIN FACT_SALES s
    ON p.product_id = s.product_id
GROUP BY p.category
ORDER BY Revenue DESC;

-- Top Customers
WITH top_customers AS(
    SELECT 
        c.customer_id,
        c.customer_name,
        SUM(s.total_amount) AS Spending,
        RANK() OVER(ORDER BY SUM(s.total_amount) DESC) AS rnk
    FROM dim_customer c
    JOIN fact_sales s
        ON c.customer_id = s.customer_id
    GROUP BY c.customer_id, c.customer_name
)
SELECT customer_id, customer_name, Spending 
FROM top_customers
WHERE rnk <= 10
ORDER BY rnk;

-- Top Products
WITH top_products AS(
    SELECT 
        p.product_id,
        p.product_name,
        SUM(s.total_amount) AS Revenue,
        RANK() OVER(ORDER BY SUM(s.total_amount) DESC) AS rnk
    FROM DIM_PRODUCT p
    JOIN FACT_SALES s 
        ON p.product_id = s.product_id
    GROUP BY p.product_id, p.product_name
)
SELECT product_id,product_name, Revenue 
FROM top_products 
WHERE rnk <=10
ORDER BY rnk;

-- Sales Trend Analysis
SELECT
    d.date,
    SUM(s.total_amount) AS Revenue
FROM DIM_DATE d
JOIN FACT_SALES s
    ON d.date_id = s.date_id
GROUP BY d.date
ORDER BY d.date;
