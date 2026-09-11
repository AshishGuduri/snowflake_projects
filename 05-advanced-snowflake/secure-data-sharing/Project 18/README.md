# Cross-Enterprise Data Clean Room & Secure Data Sharing

## Overview

Project 18 demonstrates a Snowflake collaboration pattern for a retailer and a consumer packaged goods or ad-tech partner. The business goal is to measure campaign-attributed retail sales across organizations without sharing raw point-of-sale or customer-level data with the external consumer.

The implementation ingests retailer transactions and advertising exposures as semi-structured JSON, matches them through a shared hashed identifier, calculates conversion timing, and publishes only thresholded campaign-level aggregates through a secure view. That view is granted to an outbound Snowflake share and a managed reader account for a partner without a native Snowflake deployment.

## Architecture

```text
Provider data                         Secure collaboration layer                 Consumer access

bronze_retail_transactions.json       RAW_RETAIL_TRANSACTIONS
              |                                  |
              v                                  v
      BRONZE_RETAIL_TRANSACTIONS      BRONZE_AD_EXPOSURES
              \                                  /
               \-- inner join on HASHED_EMAIL --/
                              |
                              v
                 SILVER_ATTRIBUTION_MATCH
                 + conversion lag in hours
                              |
                              v
       SECURE_GOLD_CAMPAIGN_ATTRIBUTION_PERFORMANCE
       + first-touch channel
       + aggregate metrics
       + COUNT(DISTINCT POS_ID) >= 2
                              |
               +--------------+--------------+
               |                             |
               v                             v
 SHARE_CPG_PARTNER_ANALYTICS       CPG_READER_ACCT_01
               |
               v
      CPG partner analysis
```

The provider creates `CLEANROOM_SHARED_DB.PARTNER_TELEMETRY`, stages both JSON datasets, and normalizes them into Bronze tables. The Silver layer performs the controlled overlap join on `HASHED_EMAIL` and retains campaign, channel, basket value, POS ID, store, and conversion timing. The secure Gold view applies first-touch channel logic and exposes aggregate attribution metrics. The share grants the secure view, not the raw provider tables.

## Snowflake Secure Data Sharing

The SQL implements an outbound Snowflake share named `SHARE_CPG_PARTNER_ANALYTICS`. It grants the share:

- `USAGE` on `CLEANROOM_SHARED_DB`
- `USAGE` on schema `PARTNER_TELEMETRY`
- `SELECT` on `SECURE_GOLD_CAMPAIGN_ATTRIBUTION_PERFORMANCE`

This is a zero-copy sharing model: the consumer receives access to the provider's curated secure view rather than a copied dataset. The SQL also creates the managed reader account `CPG_READER_ACCT_01`, adds it to the share under provider account `XWHRFAG`, and creates `CPG_READER_WH` for reader-account workloads.

The provider controls the share and the objects exposed through it. The reader account consumes the granted secure view. The script confirms the share and managed account with `SHOW SHARES` and `SHOW MANAGED ACCOUNTS`.

## Data Clean Room

The clean-room-style computation is implemented in two stages:

1. `SILVER_ATTRIBUTION_MATCH` performs an inner join between retailer transactions and ad exposures on `HASHED_EMAIL`. It calculates `CONVERSION_HOURS` using the difference between ad exposure time and POS transaction time.
2. `SECURE_GOLD_CAMPAIGN_ATTRIBUTION_PERFORMANCE` aggregates matched records by campaign and first-touch channel.

The secure view returns only:

- `CAMPAIGN_NAME`
- First-touch `CHANNEL`
- `CONVERTED_USER_COUNT`
- `TOTAL_ATTRIBUTED_SALES`
- `AVG_BASKET_VALUE`

The privacy guardrail is `HAVING COUNT(DISTINCT POS_ID) >= 2`, which suppresses campaign groups below the implemented minimum. The view does not select `HASHED_EMAIL`, and the share grants the view rather than the Bronze or Silver tables.

## Data Privacy & Security

- Raw JSON is stored in provider-controlled tables and is not granted to the share.
- The overlap uses `HASHED_EMAIL` as a matching key and excludes it from the Silver match output and secure Gold view.
- The outbound share exposes aggregate campaign performance rather than individual transaction rows.
- The minimum distinct POS threshold reduces exposure from very small result groups.
- The secure view is the only object granted to `SHARE_CPG_PARTNER_ANALYTICS`.
- The reader account uses a dedicated `XSMALL` warehouse with 60-second auto-suspend, auto-resume, and a monthly five-credit resource monitor.

## Audit & Governance

The project includes governance and reconciliation checks. `SHOW SHARES` and `SHOW MANAGED ACCOUNTS` verify sharing objects and reader-account provisioning.

The final compliance query:

- Sums matched Silver basket values.
- Sums Gold shared attributed sales.
- Inspects `INFORMATION_SCHEMA.COLUMNS` for a `HASHED_EMAIL` column on the secure view.
- Returns `PII_EXPOSURE_FLAG` and `RECONCILED_FLAG`.

This provides a lightweight verification of the published view's column surface and Silver-to-Gold value reconciliation.

## Data Flow

```text
Provider JSON files
        |
        v
Secure provider stage and Bronze tables
        |
        v
Hashed-identifier overlap join
        |
        v
Silver attribution match with conversion timing
        |
        v
Thresholded secure Gold aggregation
        |
        v
Outbound share and managed reader account
        |
        v
Consumer campaign-performance analysis
```

## Project Structure

```text
Project 18/
├── 22.08.2026_Project_18.txt       # Scenario, requirements, source data, and expected outputs
├── JSON_FILES/
│   ├── bronze_ad_exposures.json     # Campaign advertising exposure events
│   └── bronze_retail_transactions.json # Retail POS transactions
├── Project_18.sql                   # Snowflake ingestion, clean-room logic, sharing, reader account, and audit SQL
└── README.md                        # Project documentation
```

## How to Run

1. Use a Snowflake `ACCOUNTADMIN` session with access to `COMPUTE_WH` and privileges to create the database, schema, stage, tables, secure view, share, managed account, warehouse, and resource monitor used by the script.
2. Make `bronze_retail_transactions.json` and `bronze_ad_exposures.json` available in `STG_PARTNER_TELEMETRY` at the paths referenced by the `COPY INTO` statements.
3. Execute `Project_18.sql` from top to bottom. It creates the provider database context and ingestion objects, loads and normalizes both datasets, builds the Silver match, creates the secure Gold view, creates and grants the share, provisions the reader account and its warehouse, and runs the final reconciliation check.
4. Review the secure-view output, share and managed-account confirmations, resource-control objects, and final `PII_EXPOSURE_FLAG` and `RECONCILED_FLAG` values.

## Key Snowflake Concepts

- Semi-structured JSON ingestion with `VARIANT`
- Named stages and JSON file formats
- `COPY INTO` loading
- Provider-controlled Bronze and Silver layers
- Inner joins on hashed collaboration keys
- Secure views for governed output
- Aggregate-only sharing with `HAVING` thresholds
- Zero-copy outbound shares
- Managed reader accounts for non-Snowflake consumers
- Reader-specific warehouses and resource monitors
- `INFORMATION_SCHEMA.COLUMNS` governance inspection
- Reconciliation with scalar CTE queries

## What This Project Demonstrates

- Designing a cross-enterprise attribution workflow in Snowflake.
- Separating provider-owned raw data from consumer-facing aggregate outputs.
- Matching datasets through a hashed identifier without publishing that identifier.
- Applying minimum-group thresholds before sharing campaign results.
- Creating a secure view as the controlled data-sharing boundary.
- Provisioning an outbound share and managed reader account.
- Governing reader compute through a warehouse and resource monitor.
- Validating privacy-oriented column exposure and aggregate reconciliation.

## Interview Talking Points

### What is Snowflake Secure Data Sharing?

It allows a provider to grant another Snowflake consumer access to selected database objects without copying the underlying data. This project creates `SHARE_CPG_PARTNER_ANALYTICS` and grants it a secure aggregate view.

### Why use a secure view for sharing?

The secure view defines the consumer-facing contract. Here it exposes campaign, first-touch channel, conversion count, attributed sales, and average basket value while keeping the shared surface aggregate-only.

### How can organizations collaborate without copying raw data?

The provider keeps Bronze and Silver data in its account, performs the controlled match, and shares only the secure Gold view through the outbound share.

### What are the provider and consumer responsibilities?

The provider owns the database objects, clean-room computation, secure view, share, and grants. The consumer uses the share through the provisioned reader account and its dedicated warehouse.

### What is a reader account?

A managed reader account allows a partner without a native Snowflake deployment to consume shared data. This project creates `CPG_READER_ACCT_01` and adds it to the provider share.

### What is the clean-room join in this project?

Retail transactions and ad exposures are joined on `HASHED_EMAIL`, and the Silver layer calculates conversion lag in hours without carrying the matching key into its output columns.

### How is small-group exposure controlled?

The secure view uses `HAVING COUNT(DISTINCT POS_ID) >= 2`, so campaign groups below two distinct POS IDs are not exposed.

### How is PII exposure checked?

The final query inspects `INFORMATION_SCHEMA.COLUMNS` for a `HASHED_EMAIL` column on the secure view and returns `PII_EXPOSURE_FLAG` alongside the Silver-to-Gold reconciliation flag.

### What governance controls the reader workload?

`CPG_READER_WH` is XSMALL, auto-suspends after 60 seconds, auto-resumes, and uses `RM_CPG_READER` with a monthly five-credit quota and 80% notification and 100% suspension triggers.

## Portfolio Highlights

- Implements a provider-controlled Snowflake secure sharing architecture.
- Builds a clean-room-style attribution join on hashed identifiers.
- Publishes thresholded campaign performance through a secure view.
- Provisions a reader account for partners without a native Snowflake deployment.
- Combines privacy-oriented column checks with Silver-to-Gold reconciliation.
- Demonstrates practical governance for zero-copy data collaboration and reader compute.
