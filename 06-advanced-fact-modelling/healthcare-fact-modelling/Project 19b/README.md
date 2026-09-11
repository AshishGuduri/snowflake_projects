# Healthcare Patient Journeys & Coverage Fact Modelling

## Overview

Project 19b models hospital staffing coverage, patient admission lifecycles, and treatment billing in Snowflake. It combines a factless coverage fact, an accumulating patient lifecycle snapshot, and a treatment billing transaction fact to support operational and financial analysis.

## Concepts Demonstrated

- Factless fact modelling for doctor shift coverage
- Accumulating snapshot for patient admission milestones
- Transaction fact for treatment claims
- Degenerate `CLAIM_ID` in the billing fact
- Additive cost and charge measures
- Non-additive insurance discount percentage
- `DATEDIFF` lifecycle duration calculations
- Unbilled encounter detection with left joins

## Project Structure

```text
Project 19b/
├── 24.08.2026_Project_19b.txt
├── CSV_FILES/
│   ├── raw_doctor_roster.csv
│   ├── raw_patient_journey.csv
│   └── raw_treatment_bills.csv
├── Project_19b.sql
└── README.md
```

`Project_19b.sql` creates the Snowflake context, loads the three CSV datasets, builds coverage, lifecycle, and billing facts, calculates net charges and durations, and audits uncovered shifts and unbilled encounters.

## How to Run

1. Make the three CSV files available through `STG_PROJECT_19B` at the paths used by the SQL.
2. Use a Snowflake role able to create `P19B_WH`, `P19B_DB`, `PROJECT_19B`, the stage, file format, staging tables, and facts.
3. Execute `Project_19b.sql` from top to bottom and review the coverage, lifecycle, billing, and audit queries.
