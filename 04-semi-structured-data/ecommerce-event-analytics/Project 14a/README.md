# E-Commerce Web Event Analytics

## Overview

Project 14a compares schema-on-read and schema-on-write approaches for e-commerce web events in Snowflake. It ingests JSON clickstream payloads containing views, cart activity, purchases, order details, promotional fields, and a malformed record, then produces financial and funnel metrics.

## Concepts Demonstrated

- Snowflake `VARIANT` storage for semi-structured JSON
- Schema-on-read JSON path extraction
- Schema evolution through optional `promo_code` and `discount_amount` fields
- Schema-on-write relational backfill in `DW_STRUCTURED_EVENTS`
- `TRY_PARSE_JSON` error handling
- Malformed-payload quarantine
- Net revenue calculation with `COALESCE`
- Purchase conversion and average order value metrics
- Backfilling semi-structured events into a typed analytical table

## Project Structure

```text
Project 14a/
├── Project-14a.txt
├── Project_14a.sql
└── README.md
```

`Project_14a.sql` creates the Snowflake context, loads inline raw events into staging, stores valid JSON in `LAKE_RAW_EVENTS`, backfills structured events, calculates funnel metrics, and quarantines invalid JSON. `Project-14a.txt` contains the scenario and expected outputs.

## How to Run

Execute `Project_14a.sql` from top to bottom in Snowflake. The script creates and uses `P14A_WH`, `P14A_DB`, and `P14A_SCHEMA`; no external file upload is required because the sample events are inserted directly into the staging table.
