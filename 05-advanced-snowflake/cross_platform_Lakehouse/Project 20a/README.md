# Healthcare Lakehouse Engine — Role-Playing Dimensions, Hierarchies & Engine Optimization

## Overview

Project 20a defines a cross-platform healthcare analytics lakehouse design for patient encounters, diagnosis hierarchies, attending-doctor attribution, and multi-date clinical events. The project brief targets both Databricks Delta Lake with PySpark and Snowflake SQL, showing how the same dimensional and analytical requirements can be expressed across lakehouse and cloud data warehouse engines.

The documented design covers role-playing date dimensions, weighted bridge-table attribution, parent-child diagnosis traversal, `MERGE` upserts, time-travel auditing, schema evolution, and engine-specific storage optimization. The current project folder contains the design specification only; the executable implementation files described by the brief are not present.

## Architecture

The target architecture described in the project brief is:

```text
Healthcare source key-value datasets
        |
        v
Encounter, date, diagnosis, and doctor relationship data
        |
        +--> FACT_PATIENT_ENCOUNTERS
        |        partitioned by admit_date_key in Delta
        |
        +--> Role-playing date views
        |        admit / discharge / billing
        |
        +--> Weighted bridge attribution
        |        encounter cost x doctor weight
        |
        +--> Recursive diagnosis hierarchy
        |        leaf diagnosis -> root category
        |
        v
Databricks Delta Lake / PySpark     Snowflake SQL
        |                                  |
        +--> MERGE, time travel,          +--> MERGE, Time Travel,
             schema evolution,                  schema evolution,
             OPTIMIZE ZORDER                    CLUSTER BY
```

The source structures specified are `dim_date_kv`, `dim_diagnosis_kv`, `raw_encounters_kv`, and `bridge_doctors_kv`. The intended analytical layer is centered on `FACT_PATIENT_ENCOUNTERS`, with date-role views, doctor-cost attribution, diagnosis hierarchy outputs, and engine-specific audit and optimization operations.

## Data Model

### Patient encounter fact

The brief specifies `FACT_PATIENT_ENCOUNTERS` as the central encounter fact. Its business grain is one row per patient encounter, identified by `encounter_id`. It includes patient, admission, discharge, billing, diagnosis, and total-cost attributes. The Databricks target is partitioned by `admit_date_key`; the Snowflake target uses explicit data types and primary-key constraints.

### Role-playing date dimensions

The single `dim_date_kv` dataset is intended to serve three temporal roles through separate views:

- `vw_admit_date`
- `vw_discharge_date`
- `vw_billing_date`

Each view represents the same date dimension in a different business context, allowing an encounter to be analysed by admission date, discharge date, or billing date without duplicating the underlying date data.

### Diagnosis hierarchy

`dim_diagnosis_kv` is a parent-child hierarchy with Level 1 root categories, Level 2 intermediate categories, and Level 3 leaf diagnoses. Each record contains `diagnosis_id`, `diagnosis_name`, `parent_diagnosis_id`, and `category_level`.

### Doctor bridge

`bridge_doctors_kv` represents the many-to-many relationship between encounters and attending doctors. Its relationship grain is one row per `encounter_id` and `doctor_id`, with `weight_factor` allocating an encounter's cost across participating doctors.

## Role-Playing Dimensions

Role-playing dimensions provide multiple analytical perspectives over one shared dimension. The specified date views reuse `dim_date_kv` for admission, discharge, and billing roles. This keeps calendar attributes consistent while allowing queries to filter or group by each clinical or financial date independently.

## Hierarchies

The diagnosis data uses a parent-child relationship through `parent_diagnosis_id`. The specified recursive CTE starts with diagnosis records and repeatedly joins each node to its parent, traversing from Level 3 diagnoses through Level 2 categories to Level 1 root categories.

This supports hierarchy flattening such as mapping `Acute Bronchitis` to `Infectious Respiratory` and ultimately to `Respiratory System`, enabling reporting at both detailed and root-category levels.

## Bridge Tables

`bridge_doctors_kv` resolves the multi-valued attending-doctor relationship. A fact encounter can relate to multiple doctors, so the bridge stores one encounter-doctor row per association and a weighting factor. The specified attribution calculation is:

```text
attributed_cost = total_cost * weight_factor
```

This preserves the encounter's total cost while allocating responsibility across multiple specialties or doctors.

## Lakehouse / Delta Lake

The project brief specifies the following Databricks target capabilities:

- A Delta Lake encounter fact partitioned by `admit_date_key`.
- PySpark or Delta SQL `MERGE` for updating `ENC-801` and inserting `ENC-821`.
- Delta time-travel access using `VERSION AS OF` or `TIMESTAMP AS OF`.
- Schema evolution to add `patient_feedback_score`.
- `OPTIMIZE` with `ZORDER BY (patient_id, primary_diag_id)`.

These are target requirements documented in the project brief; no Databricks notebook, PySpark source, or Delta table implementation is included in the current folder.

## Snowflake Implementation

The brief specifies a parallel Snowflake implementation with:

- Native `MERGE INTO` for the `ENC-801` update and `ENC-821` insert.
- Time Travel using `AT(OFFSET => ...)` or `BEFORE(STATEMENT => ...)`.
- `ALTER TABLE ... ADD COLUMN` for `patient_feedback_score`.
- A clustering key on `(patient_id, primary_diag_id)`.
- Explicit data types and primary-key constraints for the encounter fact.

No Snowflake SQL file is present in the project folder, so these capabilities are documented design targets rather than verified executable objects.

## Engine Optimization

The design assigns optimization techniques to each engine:

- Databricks: partition the encounter fact by admission date and use `OPTIMIZE ... ZORDER BY (patient_id, primary_diag_id)` for data layout.
- Snowflake: use `CLUSTER BY (patient_id, primary_diag_id)` to organize storage around common patient and diagnosis access patterns.

The specification identifies these operations but does not provide execution results or benchmark measurements.

## Project Structure

```text
Project 20a/
├── 25.08.2026_Project_20A (Week3_Day2).txt  # Cross-platform design brief, datasets, tasks, and expected outputs
└── README.md                                # Project documentation
```

## How to Run

The current folder contains no executable SQL, Python, PySpark, notebook, or deployment file. There is therefore no repository command or runnable engine workflow to execute yet.

For a future implementation, the project brief separates the intended work into two paths:

- **Databricks/PySpark:** create the partitioned Delta fact, implement the role-playing views, bridge allocation, recursive hierarchy, Delta `MERGE`, time travel, schema evolution, and `OPTIMIZE ZORDER` operations.
- **Snowflake SQL:** create the typed fact and views, implement native `MERGE INTO`, Time Travel, `ALTER TABLE` schema evolution, and `CLUSTER BY` optimization.

The source datasets and expected outputs are embedded in `25.08.2026_Project_20A (Week3_Day2).txt`; no external credentials, clusters, warehouses, databases, schemas, or commands are defined by the repository.

## Key Data Engineering Concepts

- Cross-platform lakehouse and warehouse design
- Role-playing dimensions over a shared date dimension
- Parent-child hierarchy modelling
- Recursive CTE traversal
- Many-to-many bridge relationships
- Weighted cost attribution
- Encounter-level fact grain
- Delta and Snowflake `MERGE` patterns
- Time-travel auditing and schema evolution
- Partitioning, Z-Ordering, and clustering concepts

## Interview Talking Points

### What is a lakehouse?

A lakehouse combines flexible data-lake storage with warehouse-style modelling and analytics. This project brief applies that idea across a Databricks Delta Lake target and a Snowflake target.

### Why use PySpark?

The specified Databricks path uses PySpark or Delta SQL for transformations and upserts. PySpark is suited to distributed transformation of encounter, diagnosis, and bridge data, although no PySpark file is included here.

### What are role-playing dimensions?

They are multiple views of one shared dimension used in different business roles. The design reuses `dim_date_kv` for admission, discharge, and billing dates.

### Why use a bridge table?

An encounter can involve multiple doctors. `bridge_doctors_kv` stores each encounter-doctor relationship and a weight so total cost can be allocated without losing the many-to-many relationship.

### How does the diagnosis hierarchy work?

`parent_diagnosis_id` links each diagnosis to its parent. A recursive CTE is specified to traverse leaf diagnoses through intermediate categories to root categories.

### Why use `MERGE`?

The specified upsert updates `ENC-801` to `5000.00` and inserts new encounter `ENC-821` in both engine paths.

### What is schema evolution here?

The target schema adds `patient_feedback_score`, using Delta schema evolution in Databricks and `ALTER TABLE ... ADD COLUMN` in Snowflake.

### How do the optimization approaches differ?

Databricks uses partitioning and `OPTIMIZE ZORDER`; Snowflake uses a clustering key on patient and diagnosis columns. Both target more efficient access to common query dimensions.

### What is the main implementation status?

The repository currently contains the cross-platform specification and expected outputs, not executable Databricks or Snowflake code. The documented patterns should be treated as the target design until implementation files are added.

## Portfolio Highlights

- Defines a healthcare lakehouse model spanning Databricks Delta Lake and Snowflake.
- Uses role-playing date views for admission, discharge, and billing analysis.
- Models many-to-many doctor attribution with weighted bridge relationships.
- Traverses ICD-style diagnosis hierarchies with recursive CTE logic.
- Compares engine-specific `MERGE`, time travel, schema evolution, and storage optimization approaches.
- Makes fact grain and cross-platform modelling decisions explicit for implementation.
