# Enterprise Customer Master Data Management

## Overview

Project 11 implements a Snowflake hybrid customer dimension for an online retail customer master. It applies different history strategies to customer city, state, segment, and membership attributes while preserving current and historical customer versions.

## Concepts Demonstrated

- Snowflake warehouse, database, schema, stage, and CSV file format setup
- Autoincrement surrogate key with `CUSTOMER_KEY`
- Hybrid customer dimension design
- SCD Type 2 row versioning with effective and expiry dates
- Current-row tracking through `IS_CURRENT`
- Previous-value tracking with `PREVIOUS_CITY` and `PREVIOUS_MEMBERSHIP`
- Historical membership slices through `HISTORICAL_MEMBERSHIP`
- Point-in-time customer history queries

## Project Structure

```text
Project 11/
├── CSV_FILES/
│   ├── customer_updates.csv
│   └── customers_initial.csv
├── Project_11.md
├── Project_11.sql
└── README.md
```

`Project_11.sql` creates and loads `HYBRID_TABLE`, applies customer updates, and queries current, historical, and point-in-time states. `Project_11.md` contains the scenario and expected outputs.

## How to Run

1. Make the two CSV files available through the `P11_STAGE` paths used by the SQL.
2. Ensure the Snowflake role can create `P11_WH`, `P11_DB`, `P11_SCHEMA`, the stage, format, and table.
3. Execute `Project_11.sql` from top to bottom to load the initial dimension, apply updates, and run the validation queries.
