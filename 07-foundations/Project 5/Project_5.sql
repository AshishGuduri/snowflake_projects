CREATE WAREHOUSE PROJECT_5;

CREATE DATABASE P5_DB;

CREATE SCHEMA P5_DB.P5_SCHEMA;

CREATE FILE FORMAT CSV_FILE
    FIELD_DELIMITER = ','
    TYPE = 'CSV'
    SKIP_HEADER = 1;
    
CREATE STAGE P5_STAGE FILE_FORMAT = CSV_FILE;

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
    State          VARCHAR(50),
    Region         VARCHAR(20),
    Manager_Name   VARCHAR(100)
);

CREATE TABLE DIM_DATE (
    Date_ID        NUMBER PRIMARY KEY,
    Date           DATE,
    Day            NUMBER(2),
    Day_Name       VARCHAR(20),
    Week_No        NUMBER(2),
    Month          VARCHAR(20),
    Quarter        VARCHAR(5),
    Year           NUMBER(4),
    Is_Weekend     VARCHAR(5)
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
FROM @P5_STAGE/customers.csv;

COPY INTO DIM_PRODUCT
FROM @P5_STAGE/products.csv;

COPY INTO DIM_BRANCH
FROM @P5_STAGE/branches.csv;

COPY INTO DIM_DATE
FROM @P5_STAGE/calendar.csv;

COPY INTO FACT_SALES
FROM @P5_STAGE/sales.csv;

SELECT * FROM DIM_CUSTOMER;   
SELECT * FROM DIM_PRODUCT;    
SELECT * FROM DIM_BRANCH;     
SELECT * FROM DIM_DATE;    
SELECT * FROM FACT_SALES; 

-- Customer-wise Sales Report
SELECT c.Customer_Name, c.State,
       SUM(f.Quantity) AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_CUSTOMER c ON f.Customer_ID = c.Customer_ID
GROUP BY c.Customer_Name, c.State
ORDER BY Total_Revenue DESC;

-- Product-wise Revenue Report
SELECT p.Product_Name, p.Category, p.Brand,
       SUM(f.Quantity)     AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_PRODUCT p ON f.Product_ID = p.Product_ID
GROUP BY p.Product_Name, p.Category, p.Brand
ORDER BY Total_Revenue DESC;

-- Branch-wise Revenue Report
SELECT b.Branch_Name, b.City, b.State, b.Region,
       SUM(f.Quantity)     AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_BRANCH b ON f.Branch_ID = b.Branch_ID
GROUP BY b.Branch_Name, b.City, b.State, b.Region
ORDER BY Total_Revenue DESC;

-- State-wise Revenue Report
SELECT b.State,
       SUM(f.Quantity)     AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_BRANCH b ON f.Branch_ID = b.Branch_ID
GROUP BY b.State
ORDER BY Total_Revenue DESC;

-- Monthly Revenue Report
SELECT d.Year, d.Month,
       SUM(f.Quantity)     AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_DATE d ON f.Date_ID = d.Date_ID
GROUP BY d.Year, d.Month
ORDER BY d.Year, d.Month;

-- Quarterly Revenue Report
SELECT d.Year, d.Quarter,
       SUM(f.Quantity)     AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_DATE d ON f.Date_ID = d.Date_ID
GROUP BY d.Year, d.Quarter
ORDER BY d.Year, d.Quarter;

-- Top 10 Customers
SELECT c.Customer_Name, c.Membership,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_CUSTOMER c ON f.Customer_ID = c.Customer_ID
GROUP BY c.Customer_Name, c.Membership
ORDER BY Total_Revenue DESC
LIMIT 10;

-- Top 10 Products
SELECT p.Product_Name, p.Category,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_PRODUCT p ON f.Product_ID = p.Product_ID
GROUP BY p.Product_Name, p.Category
ORDER BY Total_Revenue DESC
LIMIT 10;

-- Top 10 Branches
SELECT b.Branch_Name, b.Region,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_BRANCH b ON f.Branch_ID = b.Branch_ID
GROUP BY b.Branch_Name, b.Region
ORDER BY Total_Revenue DESC
LIMIT 10;

-- Category-wise Revenue
SELECT p.Category,
       SUM(f.Quantity)     AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_PRODUCT p ON f.Product_ID = p.Product_ID
GROUP BY p.Category
ORDER BY Total_Revenue DESC;

-- Customer Purchase Trend (revenue per customer per month)
SELECT c.Customer_Name, d.Year, d.Month,
       SUM(f.Quantity)     AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_CUSTOMER c ON f.Customer_ID = c.Customer_ID
JOIN DIM_DATE d ON f.Date_ID = d.Date_ID
GROUP BY c.Customer_Name, d.Year, d.Month
ORDER BY c.Customer_Name, d.Year,d.Month;

-- Product Performance Dashboard
SELECT p.Product_Name, p.Category, p.Brand,
       SUM(f.Quantity)               AS Total_Quantity,
       SUM(f.Total_Amount)           AS Total_Revenue,
       COUNT(DISTINCT f.Sale_ID)     AS Total_Transactions,
       COUNT(DISTINCT f.Customer_ID) AS Unique_Customers,
       ROUND(AVG(f.Total_Amount), 2) AS Avg_Sale_Value
FROM FACT_SALES f
JOIN DIM_PRODUCT p ON f.Product_ID = p.Product_ID
GROUP BY p.Product_Name, p.Category, p.Brand
ORDER BY Total_Revenue DESC;

-- Branch Performance Dashboard
SELECT b.Branch_Name, b.City, b.State, b.Region, b.Manager_Name,
       SUM(f.Quantity)               AS Total_Quantity,
       SUM(f.Total_Amount)           AS Total_Revenue,
       COUNT(DISTINCT f.Sale_ID)     AS Total_Transactions,
       COUNT(DISTINCT f.Customer_ID) AS Unique_Customers,
       ROUND(AVG(f.Total_Amount), 2) AS Avg_Sale_Value
FROM FACT_SALES f
JOIN DIM_BRANCH b ON f.Branch_ID = b.Branch_ID
GROUP BY b.Branch_Name, b.City, b.State, b.Region, b.Manager_Name
ORDER BY Total_Revenue DESC;

-- Sales Trend Analysis (daily revenue trend)
SELECT d.Date, d.Day_Name, d.Is_Weekend,
       SUM(f.Quantity)     AS Total_Quantity,
       SUM(f.Total_Amount) AS Total_Revenue
FROM FACT_SALES f
JOIN DIM_DATE d ON f.Date_ID = d.Date_ID
GROUP BY d.Date, d.Day_Name, d.Is_Weekend
ORDER BY d.Date;