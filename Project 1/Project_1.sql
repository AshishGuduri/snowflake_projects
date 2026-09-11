CREATE WAREHOUSE "SALES_WH";
CREATE DATABASE "CUSTOMER_SALES_DB";
CREATE SCHEMA CUSTOMER_SALES_DB.SALES_SCHEMA;

USE DATABASE CUSTOMER_SALES_DB;
USE SCHEMA SALES_SCHEMA;

CREATE FILE FORMAT CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1;

CREATE STAGE SALES_STAGE
    FILE_FORMAT = 'CSV_FORMAT';

LIST @SALES_STAGE;

CREATE TABLE CUSTOMERS(
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(50),
    phone INT,
    address VARCHAR(50)
);

CREATE TABLE FOODITEMS(
    food_id INT PRIMARY KEY,
    name VARCHAR(50),
    price INT,
    category VARCHAR(50),
    availability VARCHAR(50)
);

CREATE TABLE ORDERS(
    order_id INT PRIMARY KEY,
    customer_id INT REFERENCES CUSTOMERS(customer_id),
    food_id INT REFERENCES FOODITEMS(food_id),
    quantity INT,
    order_date TIMESTAMP_NTZ,
    status VARCHAR(50),
    total_amount INT
);

COPY INTO CUSTOMERS
FROM @SALES_STAGE/customers.csv;

COPY INTO FOODITEMS
FROM @SALES_STAGE/fooditems.csv;

COPY INTO ORDERS
FROM @SALES_STAGE/orders.csv;

SELECT * FROM CUSTOMERS;
SELECT * FROM FOODITEMS;
SELECT * FROM ORDERS;

SELECT 
    c.customer_id AS "Customer ID",
    CONCAT_WS(' ',c.first_name,c.last_name) AS "Customer Name",
    SUM(o.total_amount) AS "Total Spent"
FROM Customers c
JOIN Orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY "Total Spent" DESC;

SELECT 
    c.customer_id AS "Customer ID",
    CONCAT_WS(' ',c.first_name,c.last_name) AS "Customer Name",
    SUM(o.total_amount) AS "Total Spent"
FROM Customers c
JOIN Orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY "Total Spent" DESC
LIMIT 1;

SELECT
    SUM(total_amount) AS "Total Revenue"
FROM Orders;

SELECT
    fi.category AS Category,
    SUM(o.total_amount) AS Revenue
FROM Orders o
JOIN FOODITEMS fi
    ON o.food_id = fi.food_id
GROUP BY fi.category
ORDER BY Revenue DESC;

SELECT 
    status AS "Order Status",
    SUM(total_amount) AS Revenue
FROM ORDERS
GROUP BY status
ORDER BY Revenue DESC;

SELECT 
    c.customer_id AS "Customer ID",
    CONCAT_WS(' ',c.first_name,c.last_name) AS "Customer Name",
    SUM(o.total_amount) AS "Total Spent"
FROM Customers c
JOIN Orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY "Total Spent" DESC
LIMIT 3;

SELECT 
    c.customer_id AS "Customer ID",
    CONCAT_WS(' ',c.first_name,c.last_name) AS "Customer Name",
    COUNT(o.order_id) AS "Orders Placed"
FROM CUSTOMERS c
JOIN ORDERS o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name,c.last_name
ORDER BY "Orders Placed" DESC, "Customer ID";

SELECT 
    order_id,
    customer_id,
    food_id,
    status,
    total_amount
FROM ORDERS 
WHERE status = 'Delivered';

SELECT 
    order_id,
    CONCAT_WS(' ',c.first_name,c.last_name) AS "Customer Name",
    order_date,
    status,
    total_amount
FROM ORDERS o
JOIN CUSTOMERS c
    ON c.customer_id = o.customer_id
WHERE DATE(order_date) > '2026-07-12'
ORDER BY order_id;

CREATE VIEW CUSTOMER_SALES_REPORT AS
    SELECT c.customer_id, CONCAT_WS(' ',c.first_name,c.last_name) AS "customer_name", SUM(o.total_amount) AS "Total Amount Spent" FROM CUSTOMERS c JOIN ORDERS o ON c.customer_id = o.customer_id GROUP BY c.customer_id,c.first_name,c.last_name;

SELECT * FROM CUSTOMER_SALES_REPORT ORDER BY "Total Amount Spent" DESC;    