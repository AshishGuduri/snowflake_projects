# Enterprise Data Security & Governance

## Overview

Project 17 demonstrates a Snowflake security and governance architecture for regional banking transactions. It transforms semi-structured JSON payloads into a governed Silver transaction table while protecting sensitive client and account data according to role and region.

The implementation combines Bronze ingestion, malformed-record quarantine, role-based access control, dynamic data masking, row-level security, and a secure aggregate view for settled-transaction reporting.

## Architecture

```text
bronze_bank_payloads.json
          |
          v
@STG_BANK_FILES -- COPY INTO --> STG_RAW_TEXT_LINES
          |                              |
          |                              +--> QUARANTINE_GOVERNANCE_PAYLOADS
          v
BRONZE_BANK_PAYLOADS (VARIANT)
          |
          v
SILVER_BANK_TRANSACTIONS
          |
          +--> masking policies on CLIENT_SSN and ACCOUNT_NO
          +--> RAP_REGION_POLICY on REGION
          |
          v
SECURE_GOLD_EXTERNAL_AUDIT_SUMMARY
```

The script creates database `FINANCIAL_GOVERNANCE_DB`, schema `WEALTH_CORE`, and uses `COMPUTE_WH`. Valid newline-delimited JSON is staged, parsed into `BRONZE_BANK_PAYLOADS`, and projected into typed Silver columns. The Silver table is the governed access point: masking policies protect sensitive columns, while the row access policy filters regional records. A secure view publishes settled financial aggregates by region.

## Security Model

The SQL creates three roles:

| Role | Core access | Row scope | Sensitive columns |
| --- | --- | --- | --- |
| `COMPLIANCE_OFFICER` | Database, schema, warehouse, and Silver `SELECT` | All regions | Full SSN and account values |
| `NA_ANALYST` | Database, schema, warehouse, and Silver `SELECT` | `REGION = 'NA'` | Masked SSN and account values |
| `EU_ANALYST` | Database, schema, warehouse, and Silver `SELECT` | `REGION = 'EU'` | Masked SSN and account values |

Each role receives database usage on `FINANCIAL_GOVERNANCE_DB`, schema usage on `WEALTH_CORE`, `SELECT` on `SILVER_BANK_TRANSACTIONS`, and warehouse usage on `COMPUTE_WH`. The roles are granted to `SYSADMIN` and to user `GJ`.

`COMPLIANCE_OFFICER` also receives `CREATE VIEW` on the schema, `SELECT` on `BRONZE_BANK_PAYLOADS`, and `SELECT` on `SECURE_GOLD_EXTERNAL_AUDIT_SUMMARY`. This separates broad compliance access from region-restricted analyst access.

## Dynamic Data Masking

Two masking policies are attached to the Silver table:

- **`MASK_SSN`** protects `CLIENT_SSN`. `COMPLIANCE_OFFICER` sees the original SSN; other roles see the final four digits, for example `***-**-3456`.
- **`MASK_ACCOUNT`** protects `ACCOUNT_NO`. `COMPLIANCE_OFFICER` sees the original account number; other roles see `ACT-****`.

Both policies use `CURRENT_ROLE()` and apply at query time without creating duplicate masked data. Analysts can query permitted transaction rows while direct client and account identifiers remain protected.

## Row-Level Security

`RAP_REGION_POLICY` is attached to `SILVER_BANK_TRANSACTIONS` on the `REGION` column. Its role-aware rules are:

- `COMPLIANCE_OFFICER` can view all regions.
- `NA_ANALYST` can view only rows where `REGION = 'NA'`.
- `EU_ANALYST` can view only rows where `REGION = 'EU'`.
- Other roles receive no permitted rows through the policy.

The SQL validates the policy by switching to `EU_ANALYST` and querying the Silver table. Row filtering and column masking work together: visible records are region-scoped, and sensitive fields remain role-scoped.

## Data Governance

The project demonstrates a governed data lifecycle:

- Semi-structured source data is separated from typed analytical data through Bronze and Silver layers.
- `TRY_PARSE_JSON` isolates malformed input in `QUARANTINE_GOVERNANCE_PAYLOADS` with the reason `MALFORMED_JSON_BODY`.
- Access is managed through explicit roles and object grants.
- PII and account identifiers are protected with role-aware masking policies.
- Regional visibility is enforced with a table-attached row access policy.
- `SECURE_GOLD_EXTERNAL_AUDIT_SUMMARY` exposes only settled totals, counts, and average amounts by region, excluding SSNs and account numbers.
- The final audit query compares Bronze and Silver gross totals and reports the Gold aggregate for reconciliation review.

## Snowflake Features

- `VARIANT` storage and JSON path extraction
- Named stages, file formats, and `COPY INTO`
- `TRY_PARSE_JSON` for tolerant parsing
- Temporary staging tables
- Snowflake roles and privilege grants
- Dynamic masking policies with `CURRENT_ROLE()`
- Row access policies
- Secure views
- `USE ROLE` context switching
- Aggregations with `SUM`, `COUNT`, `AVG`, `ROUND`, and `GROUP BY`
- Cross-layer scalar-subquery auditing

## Project Structure

```text
Project 17/
├── JSON_FILES/
│   └── bronze_bank_payloads.json   # Seven valid banking payloads and one malformed line
├── Project-17.md                   # Scenario, requirements, source payloads, and expected outputs
├── Project_17.sql                  # Ingestion, RBAC, policies, secure view, and audit SQL
└── README.md                       # Project documentation
```

## How to Run

1. Use a Snowflake role with privileges to create the database, schema, tables, stage, policies, roles, grants, and secure view referenced by the script.
2. Ensure `COMPUTE_WH` is available and make `JSON_FILES/bronze_bank_payloads.json` available at `@STG_BANK_FILES/bronze_bank_payloads.json`.
3. Execute `Project_17.sql` from top to bottom. It creates the database context and Bronze objects, loads and quarantines payloads, creates Silver data, provisions roles, attaches masking and row policies, creates the secure view, and runs audit queries.
4. Review the role-specific validation queries as `NA_ANALYST`, `EU_ANALYST`, and `COMPLIANCE_OFFICER` where the script switches role context.

## Key Engineering Concepts

- Bronze-to-Silver modelling for semi-structured financial data
- RBAC with role inheritance and object-level grants
- Role-aware dynamic data masking
- Regional row-level security
- PII and account-number protection
- Secure aggregate reporting
- Malformed-record quarantine and reconciliation auditing

## Interview Talking Points

### How is access separated?

Three roles receive common Silver access, while `COMPLIANCE_OFFICER` receives additional Bronze, secure-view, and view-creation privileges. Analyst visibility is restricted by region.

### What does `MASK_SSN` protect?

It protects `CLIENT_SSN`, showing the full value to `COMPLIANCE_OFFICER` and a final-four masked value to other roles.

### How does regional filtering work?

`RAP_REGION_POLICY` evaluates `CURRENT_ROLE()` and the row's `REGION`, allowing NA or EU analysts to see only their assigned region.

### Why use masking and row access together?

Row access controls which records are visible, while masking controls the sensitive values returned within those records.

### What does the secure view provide?

It aggregates settled transactions by region and returns total value, transaction count, and average amount without selecting SSN or account-number columns.

### How is malformed data handled?

Valid JSON is loaded into Bronze; invalid text is retained in `QUARANTINE_GOVERNANCE_PAYLOADS` with a reason code.

### What does the final audit measure?

It reports Bronze, Silver, and secure-view settled totals and calculates a Bronze-to-Silver reconciliation flag.

## Portfolio Highlights

- Implements Snowflake RBAC for compliance and regional analyst personas.
- Protects SSNs and account numbers with query-time dynamic masking.
- Enforces NA/EU data isolation through a row access policy.
- Converts semi-structured banking JSON into governed typed transactions.
- Publishes non-PII settled-transaction KPIs through a secure view.
- Demonstrates practical data quality, access governance, and reconciliation patterns.
