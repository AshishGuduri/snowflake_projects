# Cross-Border Logistics & Fleet Telematics Lakehouse

## Overview

Project 15 implements a Snowflake medallion pipeline for logistics IoT and customs data. It stores raw telematics and delivery payloads as `VARIANT`, extracts customs events into a typed Silver table, calculates duties, and produces country-level cleared-duty summaries.

The project also handles malformed payload quarantine, evolved JSON fields, Snowflake Time Travel recovery after simulated corruption, and Bronze-to-Gold reconciliation.

## Concepts Demonstrated

- Bronze schema-on-read ingestion with `VARIANT`
- Snowflake stage, file format, and `COPY INTO`
- `TRY_PARSE_JSON` and dead-letter quarantine
- Silver schema-on-write transformations
- Duty calculation and Gold aggregation
- Optional schema-field handling for `border_clearance_code`
- Time Travel inspection and `MERGE` recovery
- Cross-layer lineage and reconciliation

## Project Structure

```text
Project 15/
├── JSON_FILES/
│   └── bronze_iot_streams.json
├── Project-15 (4.4a and 4.4b).txt
├── Project_15.sql
└── README.md
```

`Project_15.sql` creates the logistics database context, loads IoT JSON, quarantines malformed text, builds customs Silver and Gold tables, performs Time Travel recovery, and runs reconciliation. The text file contains the business scenario and expected outputs.

## How to Run

1. Make `bronze_iot_streams.json` available at `@P15_STAGE`.
2. Use a Snowflake role able to create `P15_WH`, `LOGISTICS_LAKEHOUSE_DB`, `FLEET_CORE`, stages, formats, and tables.
3. Execute `Project_15.sql` from top to bottom. The script creates the warehouse and database context and runs ingestion, transformations, recovery, and audit queries.
