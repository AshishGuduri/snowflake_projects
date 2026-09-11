================================================================================
PROJECT 20A: Healthcare Lakehouse Engine — Role-Playing, Hierarchies & Engine Optimization
================================================================================
Target Schedule: Week 3 — Day 12 (Topics M6–M10)
Target Topics: Role-Playing Dimensions, Bridge Tables, Parent-Child Hierarchies, 
               Delta Lake / Snowflake MERGE, Time Travel & Engine-Specific Optimizations
Difficulty: Medium
Target Platforms: Dual-Engine (Databricks Delta Lake / PySpark & Snowflake SQL)

--------------------------------------------------------------------------------
1. ENGINE-SPECIFIC REQUIREMENTS & TECHNICAL ENVIRONMENT
--------------------------------------------------------------------------------
To successfully complete this project across both environments, satisfy the 
following technical requirements for each task:

* Task 1 Requirements (Target Table Creation):
  - Databricks: Define a Delta Lake table partitioned by `admit_date_key`.
  - Snowflake: Define a Snowflake table with explicit data types and primary key constraints.

* Task 2 Requirements (Role-Playing Dimensions):
  - Both Engines: Construct three separate virtual dimension views (`vw_admit_date`, 
    `vw_discharge_date`, `vw_billing_date`) referencing the single underlying 
    `dim_date_kv` dataset to represent multiple temporal contexts.

* Task 3 Requirements (Multi-Valued Bridge Table Weighting):
  - Both Engines: Join `raw_encounters_kv` with `bridge_doctors_kv` and apply 
    `total_cost * weight_factor` to compute accurate multi-specialty revenue attribution.

* Task 4 Requirements (Recursive Parent-Child Hierarchy Flattening):
  - Both Engines: Implement a Recursive Common Table Expression (`WITH RECURSIVE`) 
    to traverse `dim_diagnosis_kv` from leaf level (Level 3) up to Root Level (Level 1).

* Task 5 Requirements (Data Upserts / MERGE INTO):
  - Databricks: Use PySpark `DeltaTable.merge()` or Delta SQL `MERGE INTO`.
  - Snowflake: Use native Snowflake `MERGE INTO` syntax.
  - Action: Update `total_cost` on `ENC-801` to `5000.00` and insert new record `ENC-821`.

* Task 6 Requirements (Time Travel Audit):
  - Databricks: Query Delta table history using `VERSION AS OF` or `TIMESTAMP AS OF`.
  - Snowflake: Query historical table state using `AT(OFFSET => ...)` or `BEFORE(STATEMENT => ...)`.

* Task 7 Requirements (Schema Evolution):
  - Databricks: Add column `patient_feedback_score` using Delta schema enforcement / evolution.
  - Snowflake: Use `ALTER TABLE ... ADD COLUMN` to evolve table definition.

* Task 8 Requirements (Storage Optimization):
  - Databricks: Execute `OPTIMIZE` with `ZORDER BY (patient_id, primary_diag_id)`.
  - Snowflake: Apply Clustering Key using `ALTER TABLE ... CLUSTER BY (patient_id, primary_diag_id)`.

--------------------------------------------------------------------------------
2. INPUT DATASETS (KEY-VALUE PAIR FORMAT)
--------------------------------------------------------------------------------

Master Date Data (`dim_date_kv`):
---------------------------------
dim_date_kv = [
    {"date_key": 20260801, "full_date": "2026-08-01", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260802, "full_date": "2026-08-02", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260803, "full_date": "2026-08-03", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260804, "full_date": "2026-08-04", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260805, "full_date": "2026-08-05", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260806, "full_date": "2026-08-06", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260807, "full_date": "2026-08-07", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260808, "full_date": "2026-08-08", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260809, "full_date": "2026-08-09", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260810, "full_date": "2026-08-10", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260811, "full_date": "2026-08-11", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260812, "full_date": "2026-08-12", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260813, "full_date": "2026-08-13", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260814, "full_date": "2026-08-14", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260815, "full_date": "2026-08-15", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260816, "full_date": "2026-08-16", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260817, "full_date": "2026-08-17", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260818, "full_date": "2026-08-18", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260819, "full_date": "2026-08-19", "year": 2026, "quarter": "Q3", "month_name": "August"},
    {"date_key": 20260820, "full_date": "2026-08-20", "year": 2026, "quarter": "Q3", "month_name": "August"}
]

ICD Diagnosis Parent-Child Hierarchy (`dim_diagnosis_kv`):
---------------------------------------------------------
dim_diagnosis_kv = [
    {"diagnosis_id": "ICD-1000", "diagnosis_name": "Respiratory System", "parent_diagnosis_id": None, "category_level": 1},
    {"diagnosis_id": "ICD-1100", "diagnosis_name": "Infectious Respiratory", "parent_diagnosis_id": "ICD-1000", "category_level": 2},
    {"diagnosis_id": "ICD-1110", "diagnosis_name": "Acute Bronchitis", "parent_diagnosis_id": "ICD-1100", "category_level": 3},
    {"diagnosis_id": "ICD-1120", "diagnosis_name": "Pneumonia", "parent_diagnosis_id": "ICD-1100", "category_level": 3},
    {"diagnosis_id": "ICD-1200", "diagnosis_name": "Chronic Respiratory", "parent_diagnosis_id": "ICD-1000", "category_level": 2},
    {"diagnosis_id": "ICD-1210", "diagnosis_name": "Asthma", "parent_diagnosis_id": "ICD-1200", "category_level": 3},
    {"diagnosis_id": "ICD-1220", "diagnosis_name": "COPD", "parent_diagnosis_id": "ICD-1200", "category_level": 3},
    {"diagnosis_id": "ICD-2000", "diagnosis_name": "Cardiovascular System", "parent_diagnosis_id": None, "category_level": 1},
    {"diagnosis_id": "ICD-2100", "diagnosis_name": "Ischemic Heart Disease", "parent_diagnosis_id": "ICD-2000", "category_level": 2},
    {"diagnosis_id": "ICD-2110", "diagnosis_name": "Acute Myocardial Infarction", "parent_diagnosis_id": "ICD-2100", "category_level": 3},
    {"diagnosis_id": "ICD-2120", "diagnosis_name": "Angina Pectoris", "parent_diagnosis_id": "ICD-2100", "category_level": 3},
    {"diagnosis_id": "ICD-2200", "diagnosis_name": "Hypertensive Disease", "parent_diagnosis_id": "ICD-2000", "category_level": 2},
    {"diagnosis_id": "ICD-2210", "diagnosis_name": "Essential Hypertension", "parent_diagnosis_id": "ICD-2200", "category_level": 3},
    {"diagnosis_id": "ICD-3000", "diagnosis_name": "Digestive System", "parent_diagnosis_id": None, "category_level": 1},
    {"diagnosis_id": "ICD-3100", "diagnosis_name": "Gastrointestinal", "parent_diagnosis_id": "ICD-3000", "category_level": 2},
    {"diagnosis_id": "ICD-3110", "diagnosis_name": "Gastritis", "parent_diagnosis_id": "ICD-3100", "category_level": 3},
    {"diagnosis_id": "ICD-3120", "diagnosis_name": "Gastroenteritis", "parent_diagnosis_id": "ICD-3100", "category_level": 3},
    {"diagnosis_id": "ICD-4000", "diagnosis_name": "Nervous System", "parent_diagnosis_id": None, "category_level": 1},
    {"diagnosis_id": "ICD-4100", "diagnosis_name": "Central Nervous System", "parent_diagnosis_id": "ICD-4000", "category_level": 2},
    {"diagnosis_id": "ICD-4110", "diagnosis_name": "Migraine", "parent_diagnosis_id": "ICD-4100", "category_level": 3}
]

Patient Encounters Data (`raw_encounters_kv`):
-----------------------------------------------
raw_encounters_kv = [
    {"encounter_id": "ENC-801", "patient_id": "PAT-10", "admit_date_key": 20260801, "discharge_date_key": 20260804, "billing_date_key": 20260806, "primary_diag_id": "ICD-1110", "total_cost": 4500.00},
    {"encounter_id": "ENC-802", "patient_id": "PAT-11", "admit_date_key": 20260801, "discharge_date_key": 20260805, "billing_date_key": 20260808, "primary_diag_id": "ICD-2110", "total_cost": 12000.00},
    {"encounter_id": "ENC-803", "patient_id": "PAT-12", "admit_date_key": 20260802, "discharge_date_key": 20260806, "billing_date_key": 20260809, "primary_diag_id": "ICD-1120", "total_cost": 3200.00},
    {"encounter_id": "ENC-804", "patient_id": "PAT-13", "admit_date_key": 20260802, "discharge_date_key": 20260803, "billing_date_key": 20260805, "primary_diag_id": "ICD-2210", "total_cost": 1800.00},
    {"encounter_id": "ENC-805", "patient_id": "PAT-14", "admit_date_key": 20260803, "discharge_date_key": 20260807, "billing_date_key": 20260810, "primary_diag_id": "ICD-3110", "total_cost": 2900.00},
    {"encounter_id": "ENC-806", "patient_id": "PAT-15", "admit_date_key": 20260803, "discharge_date_key": 20260808, "billing_date_key": 20260812, "primary_diag_id": "ICD-1210", "total_cost": 5100.00},
    {"encounter_id": "ENC-807", "patient_id": "PAT-16", "admit_date_key": 20260804, "discharge_date_key": 20260809, "billing_date_key": 20260811, "primary_diag_id": "ICD-2120", "total_cost": 8400.00},
    {"encounter_id": "ENC-808", "patient_id": "PAT-17", "admit_date_key": 20260805, "discharge_date_key": 20260807, "billing_date_key": 20260810, "primary_diag_id": "ICD-4110", "total_cost": 1500.00},
    {"encounter_id": "ENC-809", "patient_id": "PAT-18", "admit_date_key": 20260805, "discharge_date_key": 20260810, "billing_date_key": 20260814, "primary_diag_id": "ICD-1220", "total_cost": 9500.00},
    {"encounter_id": "ENC-810", "patient_id": "PAT-19", "admit_date_key": 20260806, "discharge_date_key": 20260811, "billing_date_key": 20260815, "primary_diag_id": "ICD-3120", "total_cost": 3800.00},
    {"encounter_id": "ENC-811", "patient_id": "PAT-20", "admit_date_key": 20260807, "discharge_date_key": 20260812, "billing_date_key": 20260816, "primary_diag_id": "ICD-4110", "total_cost": 6200.00},
    {"encounter_id": "ENC-812", "patient_id": "PAT-21", "admit_date_key": 20260808, "discharge_date_key": 20260811, "billing_date_key": 20260813, "primary_diag_id": "ICD-1110", "total_cost": 2200.00},
    {"encounter_id": "ENC-813", "patient_id": "PAT-22", "admit_date_key": 20260809, "discharge_date_key": 20260815, "billing_date_key": 20260818, "primary_diag_id": "ICD-2110", "total_cost": 14500.00},
    {"encounter_id": "ENC-814", "patient_id": "PAT-23", "admit_date_key": 20260810, "discharge_date_key": 20260814, "billing_date_key": 20260817, "primary_diag_id": "ICD-1120", "total_cost": 4100.00},
    {"encounter_id": "ENC-815", "patient_id": "PAT-24", "admit_date_key": 20260810, "discharge_date_key": 20260812, "billing_date_key": 20260815, "primary_diag_id": "ICD-2210", "total_cost": 1950.00},
    {"encounter_id": "ENC-816", "patient_id": "PAT-25", "admit_date_key": 20260811, "discharge_date_key": 20260816, "billing_date_key": 20260820, "primary_diag_id": "ICD-3110", "total_cost": 3100.00},
    {"encounter_id": "ENC-817", "patient_id": "PAT-26", "admit_date_key": 20260812, "discharge_date_key": 20260817, "billing_date_key": 20260821, "primary_diag_id": "ICD-1210", "total_cost": 4800.00},
    {"encounter_id": "ENC-818", "patient_id": "PAT-27", "admit_date_key": 20260813, "discharge_date_key": 20260818, "billing_date_key": 20260822, "primary_diag_id": "ICD-2120", "total_cost": 7900.00},
    {"encounter_id": "ENC-819", "patient_id": "PAT-28", "admit_date_key": 20260814, "discharge_date_key": 20260816, "billing_date_key": 20260819, "primary_diag_id": "ICD-4110", "total_cost": 1650.00},
    {"encounter_id": "ENC-820", "patient_id": "PAT-29", "admit_date_key": 20260815, "discharge_date_key": 20260820, "billing_date_key": 20260824, "primary_diag_id": "ICD-1220", "total_cost": 10200.00}
]

Bridge Encounter Doctors Data (`bridge_doctors_kv`):
----------------------------------------------------
bridge_doctors_kv = [
    {"encounter_id": "ENC-801", "doctor_id": "DOC-1", "weight_factor": 0.60},
    {"encounter_id": "ENC-801", "doctor_id": "DOC-2", "weight_factor": 0.40},
    {"encounter_id": "ENC-802", "doctor_id": "DOC-2", "weight_factor": 0.70},
    {"encounter_id": "ENC-802", "doctor_id": "DOC-3", "weight_factor": 0.30},
    {"encounter_id": "ENC-803", "doctor_id": "DOC-1", "weight_factor": 0.50},
    {"encounter_id": "ENC-803", "doctor_id": "DOC-3", "weight_factor": 0.50},
    {"encounter_id": "ENC-804", "doctor_id": "DOC-4", "weight_factor": 1.00},
    {"encounter_id": "ENC-805", "doctor_id": "DOC-5", "weight_factor": 0.80},
    {"encounter_id": "ENC-805", "doctor_id": "DOC-1", "weight_factor": 0.20},
    {"encounter_id": "ENC-806", "doctor_id": "DOC-2", "weight_factor": 0.50},
    {"encounter_id": "ENC-806", "doctor_id": "DOC-4", "weight_factor": 0.50},
    {"encounter_id": "ENC-807", "doctor_id": "DOC-3", "weight_factor": 0.60},
    {"encounter_id": "ENC-807", "doctor_id": "DOC-5", "weight_factor": 0.40},
    {"encounter_id": "ENC-808", "doctor_id": "DOC-1", "weight_factor": 1.00},
    {"encounter_id": "ENC-809", "doctor_id": "DOC-2", "weight_factor": 0.80},
    {"encounter_id": "ENC-809", "doctor_id": "DOC-3", "weight_factor": 0.20},
    {"encounter_id": "ENC-810", "doctor_id": "DOC-4", "weight_factor": 0.50},
    {"encounter_id": "ENC-810", "doctor_id": "DOC-5", "weight_factor": 0.50},
    {"encounter_id": "ENC-811", "doctor_id": "DOC-1", "weight_factor": 0.70},
    {"encounter_id": "ENC-811", "doctor_id": "DOC-2", "weight_factor": 0.30}
]

--------------------------------------------------------------------------------
3. TASKS & EXPECTED OUTPUTS
--------------------------------------------------------------------------------

TASK 1: Target Table Creation & Data Loading
- Create partitioned fact table `FACT_PATIENT_ENCOUNTERS` partitioned by `admit_date_key`.

EXPECTED OUTPUT:
+------------------------+-------------------+
| TABLE_NAME             | STATUS            |
+------------------------+-------------------+
| FACT_PATIENT_ENCOUNTERS| TABLE_CREATED     |
+------------------------+-------------------+


TASK 2: Role-Playing Dimension Views Implementation
- Construct role-playing views referencing single date dimension for Admit, Discharge, and Billing dates.

EXPECTED OUTPUT:
+--------------+------------+----------------+--------------+
| ENCOUNTER_ID | ADMIT_DATE | DISCHARGE_DATE | BILLING_DATE |
+--------------+------------+----------------+--------------+
| ENC-801      | 2026-08-01 | 2026-08-04     | 2026-08-06   |
| ENC-802      | 2026-08-01 | 2026-08-05     | 2026-08-08   |
| ENC-803      | 2026-08-02 | 2026-08-06     | 2026-08-09   |
+--------------+------------+----------------+--------------+


TASK 3: Multi-Valued Attribute Weighting via Bridge Table
- Calculate attributed revenue across attending doctors based on weighting allocation.

EXPECTED OUTPUT:
+--------------+-----------+---------------+-----------------+
| ENCOUNTER_ID | DOCTOR_ID | WEIGHT_FACTOR | ATTRIBUTED_COST |
+--------------+-----------+---------------+-----------------+
| ENC-801      | DOC-1     | 0.60          | 2700.00         |
| ENC-801      | DOC-2     | 0.40          | 1800.00         |
| ENC-802      | DOC-2     | 0.70          | 8400.00         |
| ENC-802      | DOC-3     | 0.30          | 3600.00         |
+--------------+-----------+---------------+-----------------+


TASK 4: Recursive Parent-Child Hierarchy Flattening
- Flatten disease hierarchy to link child diagnoses with top-level root categories using a CTE.

EXPECTED OUTPUT:
+--------------+--------------------------+--------------------+
| DIAGNOSIS_ID | DIAGNOSIS_NAME           | ROOT_CATEGORY_NAME |
+--------------+--------------------------+--------------------+
| ICD-1100     | Infectious Respiratory   | Respiratory System |
| ICD-1110     | Acute Bronchitis         | Respiratory System |
| ICD-2110     | Acute Myocardial Inf...  | Cardiovascular Sys |
| ICD-3110     | Gastritis                | Digestive System   |
+--------------+--------------------------+--------------------+


TASK 5: Delta Lake / Snowflake Upsert (MERGE INTO)
- Update total cost on existing record `ENC-801` to `5000.00` and insert `ENC-821`.

EXPECTED OUTPUT:
+-------------------+-------------------+
| ROWS_INSERTED     | ROWS_UPDATED      |
+-------------------+-------------------+
| 1                 | 1                 |
+-------------------+-------------------+


TASK 6: Time Travel Audit Evaluation
- Retrieve state of record `ENC-801` prior to modification using engine-compatible time travel queries.

EXPECTED OUTPUT:
+--------------+------------+
| ENCOUNTER_ID | TOTAL_COST |
+--------------+------------+
| ENC-801      | 4500.00    |
+--------------+------------+


TASK 7: Cross-Engine Schema Evolution
- Evolve table schema to include patient rating scores across Databricks and Snowflake (`patient_feedback_score`).

EXPECTED OUTPUT:
+---------------+---------------+-----------------------+
| ENCOUNTER_ID  | TOTAL_COST    | PATIENT_FEEDBACK_SCORE|
+---------------+---------------+-----------------------+
| ENC-801       | 5000.00       | NULL                  |
+---------------+---------------+-----------------------+


TASK 8: Engine Storage Optimization Execution
- Apply micro-partition and data file layout optimization across respective target engines (ZORDER / CLUSTER BY).

EXPECTED OUTPUT:
+-----------------------+---------------------+
| STATUS_METRIC         | RESULT              |
+-----------------------+---------------------+
| OPTIMIZATION_STATUS   | SUCCESS             |
+-----------------------+---------------------+