CREATE WAREHOUSE P7_WH;

CREATE DATABASE P7_DB;

CREATE SCHEMA P7_DB.P7_SCHEMA;

USE WAREHOUSE P7_WH;

USE DATABASE P7_DB;

USE SCHEMA P7_SCHEMA;

CREATE OR REPLACE FILE FORMAT CSV_FILE
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1;


CREATE STAGE P7_STAGE FILE_FORMAT = CSV_FILE;

CREATE TABLE PATIENTS_STAGE(
    patient_id     VARCHAR(10),
    patient_name   VARCHAR(100),
    gender         VARCHAR(10),
    city           VARCHAR(50),
    state          VARCHAR(50)
);

CREATE TABLE DOCTORS_STAGE(
    doctor_id      VARCHAR(10),
    doctor_name    VARCHAR(100),
    specialization VARCHAR(50)
);

CREATE TABLE HOSPITALS_STAGE(
    hospital_id    VARCHAR(10),
    hospital_name  VARCHAR(100),
    city           VARCHAR(50),
    state          VARCHAR(50),
    region         VARCHAR(50)
);

CREATE TABLE DEPARTMENTS_STAGE(
    department_id   VARCHAR(10),
    department_name VARCHAR(50)
);

CREATE TABLE TREATMENTS_STAGE(
    treatment_id       VARCHAR(10),
    treatment_name     VARCHAR(100),
    treatment_category VARCHAR(50)
);

CREATE TABLE ADMISSIONS_STAGE(
    admission_id    VARCHAR(10),
    patient_id      VARCHAR(10),
    doctor_id       VARCHAR(10),
    hospital_id     VARCHAR(10),
    department_id   VARCHAR(10),
    admission_date  DATE,
    discharge_date  DATE
);

CREATE TABLE BILLING_STAGE(
    billing_id        VARCHAR(10),
    admission_id      VARCHAR(10),
    patient_id        VARCHAR(10),
    doctor_id         VARCHAR(10),
    hospital_id       VARCHAR(10),
    department_id     VARCHAR(10),
    treatment_id      VARCHAR(10),
    billing_date      DATE,
    quantity           NUMBER(5,0),
    treatment_amount   NUMBER(10,2),
    discount            NUMBER(10,2),
    net_amount           NUMBER(10,2)
);

COPY INTO PATIENTS_STAGE
FROM @P7_STAGE/patients.csv;

COPY INTO DOCTORS_STAGE
FROM @P7_STAGE/doctors.csv;

COPY INTO HOSPITALS_STAGE
FROM @P7_STAGE/hospitals.csv;

COPY INTO DEPARTMENTS_STAGE
FROM @P7_STAGE/departments.csv;

COPY INTO TREATMENTS_STAGE
FROM @P7_STAGE/treatments.csv;

COPY INTO ADMISSIONS_STAGE
FROM @P7_STAGE/admissions.csv;

COPY INTO BILLING_STAGE
FROM @P7_STAGE/billing.csv;

CREATE TABLE DIM_PATIENT(
    patient_key   NUMBER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    patient_id    VARCHAR(10) NOT NULL UNIQUE,
    patient_name  VARCHAR(100),
    gender        VARCHAR(10),
    city          VARCHAR(50),
    state         VARCHAR(50)
);

CREATE TABLE DIM_DOCTOR(
    doctor_key      NUMBER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    doctor_id       VARCHAR(10) NOT NULL UNIQUE,
    doctor_name     VARCHAR(100),
    specialization  VARCHAR(50)
);

CREATE TABLE DIM_HOSPITAL(
    hospital_key    NUMBER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    hospital_id     VARCHAR(10) NOT NULL UNIQUE,
    hospital_name   VARCHAR(100),
    city            VARCHAR(50),
    state           VARCHAR(50),
    region          VARCHAR(50)
);

CREATE TABLE DIM_DEPARTMENT(
    department_key   NUMBER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    department_id    VARCHAR(10) NOT NULL UNIQUE,
    department_name  VARCHAR(50)
);

CREATE TABLE DIM_TREATMENT(
    treatment_key       NUMBER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    treatment_id        VARCHAR(10) NOT NULL UNIQUE,
    treatment_name      VARCHAR(100),
    treatment_category  VARCHAR(50)
);

INSERT INTO DIM_PATIENT (patient_id, patient_name, gender, city, state)
SELECT patient_id, patient_name, gender, city, state
FROM PATIENTS_STAGE;

INSERT INTO DIM_DOCTOR (doctor_id, doctor_name, specialization)
SELECT doctor_id, doctor_name, specialization
FROM DOCTORS_STAGE;

INSERT INTO DIM_HOSPITAL (hospital_id, hospital_name, city, state, region)
SELECT hospital_id, hospital_name, city, state, region
FROM HOSPITALS_STAGE;

INSERT INTO DIM_DEPARTMENT (department_id, department_name)
SELECT department_id, department_name
FROM DEPARTMENTS_STAGE;

INSERT INTO DIM_TREATMENT (treatment_id, treatment_name, treatment_category)
SELECT treatment_id, treatment_name, treatment_category
FROM TREATMENTS_STAGE;

CREATE TABLE DIM_DATE(
    date_key    NUMBER PRIMARY KEY,
    full_date   DATE,
    day         NUMBER(2,0),
    day_name    VARCHAR(10),
    week_no     NUMBER(2,0),
    month       NUMBER(2,0),
    month_name  VARCHAR(10),
    quarter     VARCHAR(2),
    year        NUMBER(4,0)
);

INSERT INTO DIM_DATE
SELECT
    TO_NUMBER(TO_CHAR(d, 'YYYYMMDD'))  AS date_key,
    d                                   AS full_date,
    DAY(d)                              AS day,
    DAYNAME(d)                          AS day_name,
    WEEKOFYEAR(d)                       AS week_no,
    MONTH(d)                            AS month,
    MONTHNAME(d)                        AS month_name,
    'Q' || QUARTER(d)                   AS quarter,
    YEAR(d)                             AS year
FROM (
    SELECT DATEADD(day, SEQ4(), '2026-01-01') AS d
    FROM TABLE(GENERATOR(ROWCOUNT => 90))
);

CREATE TABLE FACT_ADMISSION (
    admission_key    NUMBER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    admission_id     VARCHAR(10),
    patient_key      NUMBER REFERENCES DIM_PATIENT(patient_key),
    doctor_key       NUMBER REFERENCES DIM_DOCTOR(doctor_key),
    hospital_key     NUMBER REFERENCES DIM_HOSPITAL(hospital_key),
    department_key   NUMBER REFERENCES DIM_DEPARTMENT(department_key),
    date_key         NUMBER REFERENCES DIM_DATE(date_key),
    admission_count  NUMBER(2,0),
    length_of_stay   NUMBER(3,0)
);

INSERT INTO FACT_ADMISSION
    (admission_id, patient_key, doctor_key, hospital_key, department_key, date_key,
     admission_count, length_of_stay)
SELECT
    a.admission_id,
    p.patient_key,
    d.doctor_key,
    h.hospital_key,
    dp.department_key,
    dt.date_key,
    1 AS admission_count,
    DATEDIFF(day, a.admission_date, a.discharge_date) AS length_of_stay
FROM ADMISSIONS_STAGE a
JOIN DIM_PATIENT    p  ON a.patient_id    = p.patient_id
JOIN DIM_DOCTOR     d  ON a.doctor_id     = d.doctor_id
JOIN DIM_HOSPITAL   h  ON a.hospital_id   = h.hospital_id
JOIN DIM_DEPARTMENT dp ON a.department_id = dp.department_id
JOIN DIM_DATE       dt ON a.admission_date = dt.full_date;

CREATE TABLE FACT_BILLING (
    billing_key       NUMBER AUTOINCREMENT START 1 INCREMENT 1 PRIMARY KEY,
    billing_id        VARCHAR(10),
    patient_key       NUMBER REFERENCES DIM_PATIENT(patient_key),
    doctor_key        NUMBER REFERENCES DIM_DOCTOR(doctor_key),
    hospital_key      NUMBER REFERENCES DIM_HOSPITAL(hospital_key),
    department_key    NUMBER REFERENCES DIM_DEPARTMENT(department_key),
    treatment_key     NUMBER REFERENCES DIM_TREATMENT(treatment_key),
    date_key          NUMBER REFERENCES DIM_DATE(date_key),
    quantity          NUMBER(5,0),
    treatment_amount  NUMBER(10,2),
    discount          NUMBER(10,2),
    net_amount        NUMBER(10,2)
);

INSERT INTO FACT_BILLING
    (billing_id, patient_key, doctor_key, hospital_key, department_key, treatment_key, date_key,
     quantity, treatment_amount, discount, net_amount)
SELECT
    b.billing_id,
    p.patient_key,
    d.doctor_key,
    h.hospital_key,
    dp.department_key,
    t.treatment_key,
    dt.date_key,
    b.quantity,
    b.treatment_amount,
    b.discount,
    b.treatment_amount - b.discount AS net_amount
FROM BILLING_STAGE b
JOIN DIM_PATIENT    p  ON b.patient_id    = p.patient_id
JOIN DIM_DOCTOR     d  ON b.doctor_id     = d.doctor_id
JOIN DIM_HOSPITAL   h  ON b.hospital_id   = h.hospital_id
JOIN DIM_DEPARTMENT dp ON b.department_id = dp.department_id
JOIN DIM_TREATMENT  t  ON b.treatment_id  = t.treatment_id
JOIN DIM_DATE       dt ON b.billing_date  = dt.full_date;

-- TASK 13 — Admission Analytics
SELECT
    h.hospital_name AS HOSPITAL_NAME,
    SUM(fa.admission_count) AS TOTAL_ADMISSIONS
FROM fact_admission fa
JOIN dim_hospital h
    ON fa.hospital_key = h.hospital_key
GROUP BY h.hospital_name
ORDER BY TOTAL_ADMISSIONS DESC;

-- TASK 14 — Hospital Revenue Analytics
SELECT
    h.hospital_name AS HOSPITAL_NAME,
    SUM(fb.net_amount) AS TOTAL_REVENUE
FROM fact_billing fb
JOIN dim_hospital h
    ON fb.hospital_key = h.hospital_key
GROUP BY h.hospital_name
ORDER BY TOTAL_REVENUE DESC;

-- TASK 15 — Monthly Revenue
SELECT 
    TO_CHAR(d.full_date, 'YYYY-MM') AS MONTH,
    SUM(fb.net_amount) AS TOTAL_REVENUE
FROM FACT_BILLING fb
JOIN dim_date d 
    ON fb.date_key = d.date_key
GROUP BY TO_CHAR(d.full_date, 'YYYY-MM')
ORDER BY MONTH;

-- TASK 16 — Doctor-wise Revenue
SELECT 
    d.doctor_name AS DOCTOR,
    SUM(fb.net_amount) AS TOTAL_REVENUE
FROM dim_doctor d
JOIN FACT_BILLING fb
    ON d.doctor_key = fb.doctor_key
GROUP BY d.doctor_name;

-- TASK 17 — Drill-Across Analysis
WITH admission AS(
    SELECT 
        h.hospital_key,
        h.hospital_name,
        SUM(fa.admission_count) AS TOTAL_ADMISSIONS
    FROM fact_admission fa
    JOIN dim_hospital h
        ON h.hospital_key = fa.hospital_key
    GROUP BY h.hospital_key, h.hospital_name
),
billing AS(
    SELECT 
        h.hospital_name,
        SUM(fb.net_amount) AS TOTAL_REVENUE
    FROM fact_billing fb
    JOIN dim_hospital h
        ON fb.hospital_key = h.hospital_key
    GROUP BY h.hospital_name
)
SELECT 
    a.hospital_name AS HOSPITAL_NAME,
    a.total_admissions AS TOTAL_ADMISSIONS,
    b.total_revenue AS TOTAL_REVENUE
FROM admission a
JOIN billing b
    ON a.hospital_name = b.hospital_name
ORDER BY TOTAL_ADMISSIONS DESC;    