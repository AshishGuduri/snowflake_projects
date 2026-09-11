# Enterprise Retail Analytics Data Warehouse

## Overview

Project 12 is a Snowflake retail warehouse built with Kimball dimensional modelling. It supports sales and customer loyalty analysis across store, product, customer, and transaction data.

The project covers an initial Q1 2026 load, Q2 customer master-data changes, and a subsequent sale for Customer 101. It demonstrates line-item fact design, surrogate-key relationships, and attribute history strategies across store and customer data.

## Architecture

The SQL builds the warehouse in a clear sequence:

1. Creates warehouse `P12_WH`, database `RETAIL_DW`, and schema `SALES_ANALYTICS`.
2. Creates Store, Product, and hybrid Customer dimensions with autoincrementing surrogate keys.
3. Loads source CSV data through named stage `P12_STAGE`.
4. Creates and populates `FACT_SALES` by resolving business identifiers to dimension keys.
5. Applies Store Type 1 and customer updates.
6. Inserts the Q2 transaction using Customer 101's current customer version.
7. Runs history, point-of-sale, and count queries.

```text
CSV source files
      |
      v
P12_STAGE -> DIM_STORE
          -> DIM_PRODUCT
          -> DIM_CUSTOMER_HYBRID
                         |
                         v
                   FACT_SALES
                         |
                         v
          Point-of-sale and audit queries
```

## Data Model

### Dimensions

- **`DIM_STORE`** stores store business identifiers, names, locations, and managers. `STORE_KEY` is the autoincrementing surrogate primary key.
- **`DIM_PRODUCT`** stores product identifiers, names, categories, and unit prices. `PRODUCT_KEY` is the surrogate primary key.
- **`DIM_CUSTOMER_HYBRID`** stores customer identity, current and prior attributes, membership history, segment, effective dates, expiry dates, and the `IS_CURRENT` indicator. `CUSTOMER_KEY` is the surrogate primary key.

### Fact grain and relationships

`FACT_SALES` is defined at one row per sales transaction line item. Each row contains `TRANSACTION_ID`, `TRANSACTION_DATE`, quantity, unit price, calculated `TOTAL_AMOUNT`, and foreign keys to the customer, store, and product dimensions.

The fact table uses `SALES_KEY` as an autoincrementing primary key. Its foreign keys reference `DIM_CUSTOMER_HYBRID.CUSTOMER_KEY`, `DIM_STORE.STORE_KEY`, and `DIM_PRODUCT.PRODUCT_KEY`. The supplied script inserts `TXN-1001`, `TXN-1002`, and `TXN-2001` by joining source business IDs to the appropriate dimension rows.

## Slowly Changing Dimensions

The project applies different SCD strategies according to the business meaning of each attribute.

### Store manager: Type 1

Store 201's `STORE_MANAGER` is overwritten in place with `Suresh Menon`. The dimension keeps the current value without creating a historical manager version.

### Customer segment: Type 2

For Customers 101, 103, and 104, the active rows are expired with `IS_CURRENT = FALSE` and an expiry date. New rows are inserted with new `CUSTOMER_KEY` values, update effective dates, `EXPIRY_DATE = '9999-12-31'`, and `IS_CURRENT = TRUE`. This preserves segment history by version.

### Customer city: previous-value tracking

The new customer version stores the prior city in `PREVIOUS_CITY`. The SQL then synchronizes `CITY` and `STATE` across affected customer rows so the dimension exposes the current profile while retaining the immediate prior city.

### Customer membership: hybrid Type 6

Membership combines three views of the attribute:

- `CURRENT_MEMBERSHIP` stores the current customer tier.
- `PREVIOUS_MEMBERSHIP` stores the immediately prior tier.
- `HISTORICAL_MEMBERSHIP` stores the membership value for each historical row version.

This supports both current-profile reporting and point-in-time membership analysis.

## Snowflake Features

The implementation uses warehouse, database, schema, stage, and table DDL; `COPY INTO` for CSV loading; `AUTOINCREMENT` keys; primary and foreign-key constraints; `INSERT ... SELECT` joins; `UPDATE`-based SCD processing; and `UNION ALL` record-count auditing.

## Project Structure

```text
Project 12/
├── CSV_FILES/
│   ├── customer_updates.csv      # Customer changes with effective dates
│   ├── customers_initial.csv     # Initial customer dimension load
│   ├── products.csv              # Product source data
│   └── stores.csv                # Store source data
├── Project_12.md                 # Scenario, requirements, source data, and expected outputs
├── Project_12.sql                # Warehouse build, loads, SCD processing, facts, and queries
└── README.md                     # Project documentation
```

## How to Run

1. Use a Snowflake role with permission to create the warehouse, database, schema, stage, tables, and constraints referenced by the script.
2. Make the four CSV files available through `P12_STAGE` at the paths used by the SQL.
3. Ensure the existing `CSV_FILE` file format is available for `CREATE STAGE P12_STAGE FILE_FORMAT = CSV_FILE`.
4. Execute `Project_12.sql` from top to bottom. It creates the warehouse context and dimensions, loads source data, creates and populates the fact, applies updates, inserts the Q2 transaction, and runs validation queries.
5. Review customer history, the Customer 101 point-of-sale query, and the final dimension and fact record counts.

## Key Takeaways

- Builds a Snowflake retail warehouse from source CSV data.
- Models sales at line-item grain with conformed Store, Product, and Customer dimensions.
- Uses surrogate keys to connect facts to descriptive and historical dimension records.
- Demonstrates Type 1, Type 2, Type 3-style, and hybrid Type 6 SCD techniques.
- Preserves customer segment and membership history for analytical reporting.
- Resolves current customer versions for post-update fact loading.
- Includes point-of-sale analysis and record-count validation.

## Interview Talking Points

### Why use surrogate keys?

`FACT_SALES` stores dimension surrogate keys, separating fact relationships from source business identifiers and allowing new customer versions to receive distinct keys.

### What is the fact grain?

`FACT_SALES` is designed at one row per sales transaction line item, with `TOTAL_AMOUNT` calculated from quantity and unit price.

### How is Store Manager history handled?

The manager uses Type 1 processing: Store 201 is updated in place and the current value is retained.

### How does customer Type 2 processing work?

The active row is expired, a new row is inserted with a new customer key, and effective dates plus `IS_CURRENT` identify the active and historical versions.

### What makes the membership design hybrid Type 6?

`CURRENT_MEMBERSHIP`, `PREVIOUS_MEMBERSHIP`, and `HISTORICAL_MEMBERSHIP` support current, prior, and version-specific membership analysis.

### Why does `TXN-2001` use a new customer key?

Its insert filters Customer 101 on `IS_CURRENT = TRUE`, resolving the transaction to the active post-update customer version.

### What reporting queries are included?

The script displays full customer history, joins facts to all dimensions for Customer 101 point-of-sale analysis, and audits dimension and fact record counts.

## Skills Demonstrated

- Snowflake warehouse implementation and CSV ingestion
- Kimball dimensional modelling
- Fact and dimension design
- Surrogate-key management
- SCD history modelling
- Analytical joins and calculated measures
- Data auditing and validation
