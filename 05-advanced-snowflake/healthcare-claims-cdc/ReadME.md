# Healthcare Claims & Billing — Real-Time CDC & Dynamic Table Pipelines

## Overview

Project 16 is a Snowflake data engineering solution for healthcare claims and billing analytics. It turns semi-structured claim events into trusted financial data, preserves malformed input for review, and retains the latest state of claims as statuses change.

The implementation combines newline-delimited JSON, `VARIANT`, staged ingestion, CDC-oriented stream tracking, relational SQL transformations, and a Dynamic Table for provider-level reporting. It uses a Bronze, Silver, and Gold-style architecture.

## Architecture & Data Flow

```text
bronze_raw_claims.json
        |
        v
@STG_CLAIMS_FILES -- COPY INTO --> STG_RAW_TEXT_LINES
        |                                  |
        |                                  +--> invalid JSON
        |                                  |       --> QUARANTINE_CLAIMS_PAYLOADS
        v
TRY_PARSE_JSON --> BRONZE_RAW_CLAIMS (VARIANT)
                         |
                         +--> STRM_BRONZE_CLAIMS
                         |
                         v
                 ROW_NUMBER / QUALIFY
                         |
                         v
              MERGE --> SILVER_CLAIMS_TRANSACTIONS
                         |
                         v
              Dynamic Table, TARGET_LAG = 1 minute
                         |
                         v
              DT_PROVIDER_FINANCIAL_SUMMARY
```

## Bronze -> Silver -> Gold

### Bronze

The script creates the internal stage `STG_CLAIMS_FILES` and the `FF_RAW_LINE` file format for newline-delimited input. `COPY INTO` loads each line into temporary table `STG_RAW_TEXT_LINES`. Valid lines are parsed with `TRY_PARSE_JSON` and stored as `VARIANT` payloads in `BRONZE_RAW_CLAIMS`, together with `INGEST_ID` and `LOADED_AT` metadata.

Malformed lines are written to `QUARANTINE_CLAIMS_PAYLOADS` with the reason `MALFORMED_JSON_BODY`.

### Silver

`SILVER_CLAIMS_TRANSACTIONS` projects JSON fields into typed claim columns: claim ID, submission time, patient, provider, diagnosis, billed amount, copay, net payable amount, and status.

The script creates `STRM_BRONZE_CLAIMS` on the Bronze table as a Snowflake change-tracking capability for CDC-oriented design. The Silver load uses `ROW_NUMBER()` partitioned by `CLAIM_ID`, ordered by descending `INGEST_ID`, and `QUALIFY` to select the latest event before a `MERGE` updates or inserts the current claim state.

### Gold

`DT_PROVIDER_FINANCIAL_SUMMARY` is the analytical layer. With `TARGET_LAG = '1 minute'`, it groups `APPROVED` claims by provider and calculates total billed amount, copay collected, net payable amount, and approved claim count.

## Key Features

- Healthcare claims and billing analytics use case
- Snowflake Bronze/Silver/Gold-style architecture
- Semi-structured JSON with `VARIANT`
- Internal stage and `COPY INTO` ingestion
- `TRY_PARSE_JSON` and malformed-data quarantine
- Streams for CDC/change tracking
- `MERGE`-based latest-state processing
- `ROW_NUMBER()` and `QUALIFY` deduplication
- Dynamic Table with one-minute `TARGET_LAG`
- Refresh monitoring and cross-layer reconciliation

## Snowflake Concepts Demonstrated

| Concept | Implementation |
| --- | --- |
| Semi-structured data | JSON payloads stored in a `VARIANT` Bronze column |
| File ingestion | Internal stage, file format, temporary staging, and `COPY INTO` |
| Data quality | `TRY_PARSE_JSON` and reason-coded quarantine |
| CDC concepts | `STRM_BRONZE_CLAIMS` on the Bronze table |
| State processing | `MERGE` with latest-record selection |
| Deduplication | `ROW_NUMBER()` and `QUALIFY` by `CLAIM_ID` and `INGEST_ID` |
| Declarative analytics | Dynamic Table with `TARGET_LAG = '1 minute'` |
| Monitoring | `DYNAMIC_TABLE_REFRESH_HISTORY` |
| Reconciliation | Bronze, Silver, and Gold-style billed-total query |

## Data Quality & Reliability

`TRY_PARSE_JSON` keeps invalid JSON out of the Bronze claims table while preserving the raw text in the quarantine table. The Bronze layer records ingestion order and load time. Silver deduplication selects the greatest `INGEST_ID` for each claim, and `NET_PAYABLE_AMOUNT` is calculated as billed amount minus copay amount during inserts and updates.

The script also includes a Dynamic Table refresh-history query and an audit query that surfaces billed totals across Bronze, Silver, and the approved-claims summary layer.

## Project Structure

```text
healthcare-claims-cdc/
├── New Text Document.txt
├── ReadME.md
├── README.md
└── Project 16/
    ├── JSON_FILES/
    │   └── bronze_raw_claims.json
    ├── Project-16 (4.5).md
    └── Project_16.sql
```

`Project_16.sql` contains the Snowflake pipeline, monitoring, and audit SQL. `bronze_raw_claims.json` contains the newline-delimited claim payloads. `Project-16 (4.5).md` documents the scenario and expected outputs. The two root-level text files are project documentation files.

## How to Run

1. Use a Snowflake role with permission to create the database, schema, tables, stage, file format, stream, and Dynamic Table used by the script.
2. Make `Project 16/JSON_FILES/bronze_raw_claims.json` available at `@STG_CLAIMS_FILES/bronze_raw_claims.json` through the Snowflake client or interface used for execution.
3. Execute `Project_16.sql` from top to bottom in a Snowflake worksheet or SQL client. The script sets `HEALTHCARE_PIPELINE_DB`, `CLAIMS_CORE`, and `COMPUTE_WH` as its working context.
4. Review the Bronze count, quarantined payloads, Silver claim state, provider summary, refresh history, and reconciliation results.

## Interview Talking Points

### Why use `VARIANT` in Bronze?

It preserves the original JSON structure while allowing typed projection in Silver.

### How are bad payloads handled?

`TRY_PARSE_JSON` accepts valid JSON and routes invalid raw text to the quarantine table with a reason code.

### How does deduplication work?

`ROW_NUMBER()` and `QUALIFY` retain the highest `INGEST_ID` per `CLAIM_ID` before the `MERGE`.

### What CDC capability is demonstrated?

`STRM_BRONZE_CLAIMS` is created on the Bronze table for Snowflake stream-based change tracking.

### Why use a Dynamic Table?

It provides a declarative provider summary with a one-minute target lag for approved-claims analytics.

### How is the pipeline monitored?

The script queries `INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY` and includes a cross-layer billed-total reconciliation query.

## Skills Demonstrated

- Snowflake warehouse and semi-structured data design
- JSON ingestion with `COPY INTO` and `VARIANT`
- Data quality and malformed-record isolation
- CDC concepts with Streams
- SQL transformation with `MERGE`
- Window-function deduplication
- Dynamic Table analytics and target-lag design
- Monitoring, reconciliation, and healthcare claims modelling
