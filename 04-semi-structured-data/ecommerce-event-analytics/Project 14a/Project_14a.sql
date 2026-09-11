CREATE WAREHOUSE P14A_WH;
USE WAREHOUSE P14A_WH;

CREATE DATABASE P14A_DB;
USE DATABASE P14A_DB;

CREATE SCHEMA P14A_SCHEMA;
USE SCHEMA P14A_SCHEMA;

-- TASK 1: Data Lake Ingestion
CREATE TABLE STAGING_RAW_EVENTS (
    RAW_TEXT VARCHAR
);

INSERT INTO STAGING_RAW_EVENTS (RAW_TEXT) VALUES
('{"event_id":"EVT-8001","timestamp":"2026-07-01T08:15:00Z","user_id":1001,"page":"checkout","action":"purchase","order":{"total":12500.00,"shipping_cost":250.00,"tax":625.00,"items":2}}'),
('{"event_id":"EVT-8002","timestamp":"2026-07-01T08:20:00Z","user_id":1002,"page":"product_detail","action":"view","order":null}'),
('{"event_id":"EVT-8003","timestamp":"2026-07-01T08:35:00Z","user_id":1003,"page":"cart","action":"add_to_cart","order":null}'),
('{"event_id":"EVT-8004","timestamp":"2026-07-01T09:10:00Z","user_id":1004,"page":"checkout","action":"purchase","order":{"total":45000.00,"shipping_cost":500.00,"tax":2250.00,"items":5}}'),
('{"event_id":"EVT-8005","timestamp":"2026-07-01T09:45:00Z","user_id":1001,"page":"product_detail","action":"view","order":null}'),
('{"event_id":"EVT-8006","timestamp":"2026-07-02T10:00:00Z","user_id":1005,"page":"checkout","action":"purchase","order":{"total":18000.00,"shipping_cost":300.00,"tax":900.00,"items":3},"promo_code":"SUMMER20","discount_amount":3600.00}'),
('{"event_id":"EVT-8007","timestamp":"2026-07-02T10:15:00Z","user_id":1002,"page":"checkout","action":"purchase","order":{"total":8500.00,"shipping_cost":150.00,"tax":425.00,"items":1},"promo_code":"WELCOME10","discount_amount":850.00}'),
('{"event_id":"EVT-8008","timestamp":"2026-07-02T10:30:00Z","user_id":1006,"page":"cart","action":"add_to_cart","order":null,"promo_code":null,"discount_amount":0.00}'),
('{"event_id":"EVT-8009","timestamp":"2026-07-02T11:00:00Z","user_id":1003,"page":"checkout","action":"purchase","order":{"total":32000.00,"shipping_cost":400.00,"tax":1600.00,"items":4},"promo_code":"FESTIVE15","discount_amount":4800.00}'),
('{"event_id":"EVT-8010","timestamp":"2026-07-02T11:20:00Z","user_id":1007,"page":"product_detail","action":"view","order":null,"promo_code":null,"discount_amount":0.00}'),
('{"event_id":"EVT-8011","timestamp":"2026-07-03T12:00:00Z","user_id":1008,"page":"checkout","action":"purchase","order":{"total":0.00,"shipping_cost":0.00,"tax":0.00,"items":0},"promo_code":"FREEPASS","discount_amount":0.00}'),
('INVALID_JSON_PAYLOAD_MALFORMED_STRING');

CREATE TABLE LAKE_RAW_EVENTS (
    RAW_JSON VARIANT
);

INSERT INTO LAKE_RAW_EVENTS (RAW_JSON)
SELECT TRY_PARSE_JSON(RAW_TEXT)
FROM STAGING_RAW_EVENTS
WHERE TRY_PARSE_JSON(RAW_TEXT) IS NOT NULL;

SELECT COUNT(*) AS TOTAL_RAW_RECORD_CT FROM LAKE_RAW_EVENTS;

-- TASK 2: Schema-on-Read Ingestion & Extraction
SELECT
    RAW_JSON:event_id::STRING                          AS EVENT_ID,
    RAW_JSON:timestamp::TIMESTAMP_NTZ                   AS EVENT_TIME,
    RAW_JSON:user_id::NUMBER                            AS USER_ID,
    RAW_JSON:action::STRING                             AS ACTION,
    RAW_JSON:order.total::NUMBER(10,2)                  AS ORDER_TOTAL,
    RAW_JSON:promo_code::STRING                         AS PROMO_CODE
FROM LAKE_RAW_EVENTS
ORDER BY EVENT_ID;

-- TASK 3: Schema-on-Read Financial Analysis
SELECT
    RAW_JSON:event_id::STRING AS EVENT_ID,
    RAW_JSON:order.total::NUMBER(10,2) AS ORDER_TOTAL,
    RAW_JSON:order.shipping_cost::NUMBER(10,2) AS SHIPPING_COST,
    RAW_JSON:order.tax::NUMBER(10,2) AS TAX,
    COALESCE(RAW_JSON:discount_amount::NUMBER(10,2),0) AS DISCOUNT_AMOUNT,
    RAW_JSON:order.total::NUMBER - RAW_JSON:order.shipping_cost::NUMBER - RAW_JSON:order.tax::NUMBER - COALESCE(RAW_JSON:discount_amount::NUMBER,0) AS NET_REVENUE
FROM LAKE_RAW_EVENTS
WHERE RAW_JSON:order.total::NUMBER > 0;

-- TASK 4: Funnel & Conversion Key Metrics
SELECT
    COUNT(*) AS TOTAL_EVENTS,
    COUNT(CASE WHEN RAW_JSON:action::STRING = 'purchase' AND RAW_JSON:order.total::NUMBER > 0 THEN 1 END) AS TOTAL_PURCHASES,
    ROUND(COUNT(CASE WHEN RAW_JSON:action::STRING = 'purchase' AND RAW_JSON:order.total::NUMBER > 0 THEN 1 END) / COUNT(*) * 100, 2) AS CONVERSION_RATE_PCT,
    SUM(RAW_JSON:order.total::NUMBER) AS TOTAL_GROSS_REVENUE,
    ROUND(SUM(RAW_JSON:order.total::NUMBER)/COUNT(CASE WHEN RAW_JSON:action::STRING = 'purchase' AND RAW_JSON:order.total::NUMBER > 0 THEN 1 END),2) AS AVERAGE_ORDER_VALUE
FROM LAKE_RAW_EVENTS;

-- TASK 5: Data Warehouse Backfill (Schema-on-Write)
CREATE TABLE DW_STRUCTURED_EVENTS (
    EVENT_ID VARCHAR,
    EVENT_TIME TIMESTAMP_NTZ,
    USER_ID NUMBER,
    ACTION VARCHAR,
    ORDER_TOTAL NUMBER(10,2),
    SHIPPING_COST NUMBER(10,2),
    TAX NUMBER(10,2),
    DISCOUNT_AMOUNT NUMBER(10,2),
    NET_REVENUE NUMBER(10,2)
);

INSERT INTO DW_STRUCTURED_EVENTS
SELECT
    RAW_JSON:event_id::STRING                          AS EVENT_ID,
    RAW_JSON:timestamp::TIMESTAMP_NTZ                   AS EVENT_TIME,
    RAW_JSON:user_id::NUMBER                            AS USER_ID,
    RAW_JSON:action::STRING                             AS ACTION,
    RAW_JSON:order.total::NUMBER(10,2)                  AS ORDER_TOTAL,
    RAW_JSON:order.shipping_cost::NUMBER(10,2)          AS SHIPPING_COST,
    RAW_JSON:order.tax::NUMBER(10,2)                    AS TAX,
    COALESCE(RAW_JSON:discount_amount::NUMBER(10,2), 0) AS DISCOUNT_AMOUNT,
    RAW_JSON:order.total::NUMBER(10,2)
        - RAW_JSON:order.shipping_cost::NUMBER(10,2)
        - RAW_JSON:order.tax::NUMBER(10,2)
        - COALESCE(RAW_JSON:discount_amount::NUMBER(10,2), 0) AS NET_REVENUE
FROM LAKE_RAW_EVENTS;

SELECT
    COUNT(*)         AS STORED_RECORDS_QTY,
    SUM(NET_REVENUE) AS TOTAL_NET_REVENUE
FROM DW_STRUCTURED_EVENTS;

-- TASK 6: Data Integrity & Error Quarantine Strategy
CREATE TABLE QUARANTINE_RAW_EVENTS (
    QUARANTINE_ID     NUMBER AUTOINCREMENT,
    RAW_RECORD_TEXT   VARCHAR,
    REASON            VARCHAR
);

INSERT INTO QUARANTINE_RAW_EVENTS (RAW_RECORD_TEXT, REASON)
SELECT
    RAW_TEXT,
    'MALFORMED_JSON_BODY'
FROM STAGING_RAW_EVENTS
WHERE TRY_PARSE_JSON(RAW_TEXT) IS NULL;

SELECT * FROM QUARANTINE_RAW_EVENTS ORDER BY QUARANTINE_ID;