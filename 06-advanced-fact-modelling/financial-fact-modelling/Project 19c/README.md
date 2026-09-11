# Financial Wire Transfers, Vault Balances & Compliance Coverage

## Overview

Project 19c is a Snowflake multi-fact model for financial operations. It combines wire-transfer transactions, periodic vault cash balances, credit approval lifecycles, and compliance audit coverage in one analytical schema.

The model demonstrates how transaction, periodic snapshot, accumulating snapshot, factless, junk-dimension, and degenerate-dimension patterns support different banking and compliance questions.

## Concepts Demonstrated

- Junk dimension for authentication, risk, and transfer type
- Wire-transfer transaction fact with `TXN_ID` retained directly
- Currency-normalized and net transfer measures
- Periodic vault cash snapshots
- Semi-additive balance and non-additive reserve measures
- Credit approval accumulating snapshot
- Factless compliance audit coverage
- Bottleneck and cross-fact reconciliation analysis

## Project Structure

```text
Project 19c/
├── 25.08.2026_Project_19             # Scenario, source data, requirements, and expected outputs
├── CSV_FILES/
│   ├── raw_audit_coverage.csv
│   ├── raw_credit_lifecycles.csv
│   ├── raw_vault_cash.csv
│   └── raw_wire_transfers.csv
├── Project_19c.sql                    # Snowflake setup, fact modelling, analysis, and audit queries
└── README.md                          # Project documentation
```

## How to Run

1. Make the four CSV files available through `STG_PROJECT_19C` at the paths used by the SQL.
2. Use a Snowflake role able to create `P19C_WH`, `P19C_DB`, `PROJECT_19C`, the stage, file format, staging tables, dimensions, and facts.
3. Execute `Project_19c.sql` from top to bottom to load the sources, build the multi-fact model, and run risk, compliance, bottleneck, and reconciliation analyses.
