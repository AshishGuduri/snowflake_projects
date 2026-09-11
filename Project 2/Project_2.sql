CREATE WAREHOUSE "RETAIL_WH";

CREATE DATABASE "RETAIL_DB";

CREATE SCHEMA RETAIL_DB.SALES_SCHEMA;

CREATE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1;

CREATE STAGE NEW_STAGE FILE_FORMAT = CSV_FORMAT;

CREATE TABLE BRANCHES(
    branch_id INT PRIMARY KEY,
    branch_name VARCHAR(50),
    city VARCHAR(50)
);

CREATE TABLE CUSTOMERS(
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(50),
    city VARCHAR(50),
    membership VARCHAR(50)
);

CREATE TABLE PRODUCTS(
    product_id INT PRIMARY KEY,
    product_name VARCHAR(50),
    category VARCHAR(50),
    price INT
);

CREATE TABLE SALES(
    sale_id INT PRIMARY KEY,
    customer_id INT REFERENCES CUSTOMERS(customer_id),
    product_id INT REFERENCES PRODUCTS(product_id),
    branch_id INT REFERENCES BRANCHES(branch_id),
    quantity INT,
    sale_date TIMESTAMP_NTZ, 
    total_amount INT
);

COPY INTO BRANCHES 
FROM @NEW_STAGE/branches.csv;

COPY INTO CUSTOMERS 
FROM @NEW_STAGE/customers.csv;

COPY INTO PRODUCTS 
FROM @NEW_STAGE/products.csv;

COPY INTO SALES 
FROM @NEW_STAGE/sales.csv;

-- Display all branches.
SELECT * FROM branches;

-- Display all customers.
SELECT * FROM customers;

-- Display all products.
SELECT * FROM products;

-- Display all sales transactions.
SELECT * FROM sales;

-- Calculate total business revenue.
SELECT SUM(total_amount) AS "Total Business Revenue" FROM sales;

-- Generate customer-wise sales.
SELECT c.customer_id,SUM(s.total_amount) AS Total_sales FROM sales s JOIN customers c ON c.customer_id = s.customer_id GROUP BY c.customer_id ORDER BY Total_sales DESC;

-- Generate branch-wise sales.
SELECT b.branch_id,SUM(s.total_amount) AS Total_sales FROM sales s JOIN branches b ON b.branch_id=s.branch_id GROUP BY b.branch_id
ORDER BY Total_sales DESC;

-- Generate product-wise sales.
SELECT p.product_id,SUM(s.total_amount) AS Total_sales FROM sales s JOIN products p ON p.product_id=s.product_id GROUP BY p.product_id
ORDER BY Total_sales DESC;

-- Generate category-wise sales.
SELECT p.category,SUM(s.total_amount) AS Total_sales FROM sales s JOIN products p ON p.product_id=s.product_id GROUP BY p.category
ORDER BY Total_sales DESC;

-- Display the highest revenue branch.
SELECT b.branch_name,SUM(s.total_amount) AS "Total Revenue" FROM sales s JOIN branches b ON b.branch_id = s.branch_id GROUP BY b.branch_name ORDER BY "Total Revenue" DESC LIMIT 1;

-- Display the highest spending customer.
SELECT c.customer_name,SUM(s.total_amount) AS "Total Spending" FROM sales s JOIN customers c ON c.customer_id = s.customer_id GROUP BY c.customer_name ORDER BY "Total Spending" DESC LIMIT 1;

-- Display the top three products by revenue.
SELECT p.product_name, SUM(s.total_amount) AS "Total Revenue" FROM sales s JOIN products p ON p.product_id = s.product_id GROUP BY p.product_name ORDER BY "Total Revenue" DESC
LIMIT 3;

-- Display the top three customers by spending.
SELECT c.customer_name, SUM(s.total_amount) AS "Total Spending" FROM sales s JOIN customers c ON c.customer_id = s.customer_id GROUP BY c.customer_name ORDER BY "Total Spending" DESC LIMIT 3;

-- Rank customers based on total spending.
SELECT 
    c.customer_name,
    SUM(s.total_amount) AS "Total Spending",
    RANK() OVER(ORDER BY SUM(s.total_amount) DESC) AS Rank
FROM Sales s
JOIN Customers c
    ON s.customer_id = c.customer_id
GROUP BY c.customer_name;

-- Rank branches based on total sales.
SELECT
    b.branch_name AS "Branch Name",
    SUM(s.total_amount) AS "Total Sales",
    RANK() OVER(ORDER BY SUM(s.total_amount) DESC) AS RANK
FROM Sales s
JOIN Branches b
    ON s.branch_id = b.branch_id
GROUP BY b.branch_name
ORDER BY RANK;

-- Display the top-selling product in each category using ROW_NUMBER().
SELECT * FROM
(SELECT 
    p.category AS "Category",
    p.product_name AS "Product Name",
    SUM(s.quantity) AS total_qty,
    ROW_NUMBER() OVER(PARTITION BY p.category ORDER BY SUM(s.quantity) DESC) AS SALES
FROM Products p
JOIN Sales s
    ON p.product_id = s.product_id
GROUP BY p.product_name, p.category)
WHERE SALES = 1;

-- Calculate cumulative sales using SUM() OVER().
SELECT
    SUM(s.total_amount) OVER(ORDER BY s.sale_date) AS "Cumulative Sales"
FROM Sales s;

-- Calculate the average sale amount using AVG() OVER().
SELECT
    AVG(s.total_amount) OVER() AS "Average   Sales"
FROM Sales s;

-- Generate customer-wise revenue using a Common Table Expression (CTE).
WITH customer_revenue AS(
    SELECT
        c.customer_name AS "Customer Name",
        SUM(s.total_amount) AS "Total Sales"
    FROM customers c 
    JOIN sales s
        ON c.customer_id = s.customer_id
    GROUP BY c.customer_name
)
SELECT * FROM customer_revenue;

-- Display customers whose spending is greater than the average spending.
WITH spending AS(
    SELECT 
        c.customer_name AS "Customer Name",
        SUM(s.total_amount) AS "Spending"
    FROM customers c
    JOIN sales s 
        ON c.customer_id = s.customer_id
    GROUP BY c.customer_name
)
SELECT * 
FROM spending
WHERE "Spending" > (SELECT AVG("Spending") FROM spending);

-- Create a View named SALES_REPORT.
CREATE OR REPLACE VIEW SALES_REPORT AS
SELECT s.sale_id, c.customer_name, p.product_name, b.branch_name, s.quantity, s.total_amount, s.sale_date
FROM sales s
JOIN customers c ON s.customer_id = c.customer_id
JOIN products p ON s.product_id = p.product_id
JOIN branches b ON s.branch_id = b.branch_id;

-- Create a Materialized View named TOP_CUSTOMERS.
CREATE MATERIALIZED VIEW TOP_CUSTOMERS AS
SELECT 
    c.customer_name,
    c.membership
FROM Customers c
WHERE c.membership = 'Platinum';

SELECT * FROM Sales_report;

SELECT * FROM TOP_CUSTOMERS;