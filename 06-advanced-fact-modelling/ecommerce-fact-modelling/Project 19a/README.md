# E-Commerce Sales, Inventory & Customer Lifecycle Fact Modelling

## Overview

Project 19a is a Snowflake dimensional-modelling exercise for an e-commerce and retail logistics business. It brings together order transactions, store inventory snapshots, and order fulfillment milestones so each business process can be analysed at the grain most appropriate to it.

The project demonstrates how transaction facts, periodic snapshots, accumulating snapshots, junk dimensions, and degenerate dimensions work together in a practical sales and fulfillment warehouse model.

## Architecture

```text
CSV source files
      |
      v
PROJECT_19A_STAGE
      |
      v
RAW_ORDERS       RAW_INVENTORY       RAW_FULFILLMENT
      |                 |                    |
      v                 v                    v
DIM_ORDER_       FACT_INVENTORY_      FACT_ORDER_
INDICATORS       SNAPSHOT             FULFILLMENT
      |
      v
FACT_SALES_TRANSACTIONS
      |
      v
Revenue, inventory, and fulfillment analysis
```

The SQL creates the Snowflake warehouse, database, schema, CSV file format, and named stage first. It then loads the three raw datasets and builds analytical structures for order sales, inventory position, and fulfillment lifecycle tracking.

## Dimensional Model

### `DIM_ORDER_INDICATORS`

This junk dimension groups low-cardinality order attributes into reusable combinations:

- `PAYMENT_METHOD`
- `SHIPPING_OPTION`
- `GIFT_WRAP_FLAG`

`INDICATOR_SK` is generated with `ROW_NUMBER()` and is used by the transaction fact to avoid repeating these operational flags on every analytical query.

### `FACT_SALES_TRANSACTIONS`

**Grain:** one row per order transaction.

The fact retains `ORDER_ID`, `ORDER_DATE`, `USER_ID`, `STORE_ID`, `INDICATOR_SK`, `AMOUNT`, and `TAX`. `ORDER_ID` remains directly in the fact as a degenerate dimension, while payment, shipping, and gift-wrap attributes are represented through `INDICATOR_SK`.

### `FACT_INVENTORY_SNAPSHOT`

**Grain:** one row per `SNAPSHOT_DATE` and `STORE_ID` combination.

The fact aggregates raw inventory by date and store into `TOTAL_UNITS_HELD` and `TOTAL_INVENTORY_VAL`. Product-level rows from the raw input are rolled up at this layer, making the measures useful for periodic store inventory reporting.

### `FACT_ORDER_FULFILLMENT`

**Grain:** one row per order fulfillment lifecycle.

The fact stores order, pick, ship, and delivery milestone dates. It derives `PICK_LAG_DAYS`, `SHIP_LAG_DAYS`, `DELIVERY_LAG_DAYS`, and `TOTAL_FULFILLMENT_DAYS`, enabling process-duration analysis and incomplete-order monitoring.

### Factless Fact

No standalone factless fact table is implemented. The project focuses on measurable sales, inventory, and fulfillment facts.

## Fact Modelling Patterns

### Transaction Fact

`FACT_SALES_TRANSACTIONS` records the financial event of each order. Its grain is one row per order transaction, with `AMOUNT` and `TAX` as measures and `ORDER_ID` as a degenerate dimension.

### Periodic Snapshot Fact

`FACT_INVENTORY_SNAPSHOT` records inventory position at recurring snapshot dates. Its grain is one row per store and snapshot date. `TOTAL_UNITS_HELD` is an inventory balance, while `TOTAL_INVENTORY_VAL` is calculated as quantity on hand multiplied by unit cost.

### Accumulating Snapshot Fact

`FACT_ORDER_FULFILLMENT` tracks the lifecycle of an order across milestones from order placement through delivery. Its dates are populated as the process advances, and the lag measures quantify picking, shipping, delivery, and total fulfillment duration. The status audit identifies orders that have not yet reached delivery.

### Factless Fact

A factless event or coverage relationship is not part of the implemented model. The project uses measured facts instead.

### Junk Dimension

`DIM_ORDER_INDICATORS` consolidates the low-cardinality combination of payment method, shipping option, and gift-wrap flag. The transaction fact stores one `INDICATOR_SK`, making the combination reusable for reporting such as revenue by payment method.

### Degenerate Dimension

`ORDER_ID` remains directly in `FACT_SALES_TRANSACTIONS` because it is the business transaction identifier and does not require a separate descriptive dimension for this model.

## Business Scenarios

- **Order sales:** Order amount and tax are recorded for orders across users and stores.
- **Inventory monitoring:** Store inventory is measured on August 24 and August 25, 2026, with unit counts and inventory valuation.
- **Fulfillment performance:** Orders are tracked through picking, shipping, and delivery milestones.
- **Incomplete lifecycle monitoring:** Orders such as `ORD-104` and `ORD-105` are classified according to their current fulfillment milestone.
- **Operational sales analysis:** Revenue and order counts are aggregated by payment method through the junk dimension.

## Snowflake Implementation

- Creates warehouse `P19a_WH`, database `P19a_DB`, and schema `P19a_SCHEMA`.
- Defines `CSV_FF` with comma delimiters, header skipping, and null handling.
- Creates named stage `PROJECT_19A_STAGE` and loads all three CSV datasets with `COPY INTO`.
- Uses `CREATE TABLE AS SELECT` to build the junk dimension and fact tables.
- Uses `ROW_NUMBER()` to generate junk-dimension surrogate keys.
- Uses `GROUP BY` and `SUM` for periodic inventory aggregation.
- Uses `DATEDIFF` for fulfillment lag calculations.
- Uses `CASE` and null milestone checks for lifecycle status auditing.
- Uses joins and aggregations for revenue analysis.

## SQL & Data Engineering Concepts

- Selecting fact grain according to business process
- Transaction, periodic snapshot, and accumulating snapshot design
- Semi-additive inventory measures across time
- Additive order measures such as transaction amount and tax
- Degenerate dimensions for business transaction identifiers
- Junk dimensions for low-cardinality indicators
- Surrogate-key generation with window functions
- Snapshot aggregation and inventory valuation
- Date-difference process metrics
- Incomplete-process status classification
- Fact-to-dimension joins and grouped revenue analysis

## Project Structure

```text
Project 19a/
├── 24.08.2026_Project_19a.txt       # Scenario, requirements, source data, and expected outputs
├── CSV_FILES/
│   ├── raw_fulfillment.csv          # Order lifecycle milestone dates
│   ├── raw_inventory.csv            # Inventory snapshots by date, store, and product
│   └── raw_orders.csv               # Order transactions and order indicators
├── Project_19a.sql                  # Snowflake setup, ingestion, fact modelling, and analysis queries
└── README.md                        # Project documentation
```

## How to Run

1. Use a Snowflake role with permission to create the warehouse, database, schema, file format, stage, and tables referenced by the SQL.
2. Make `raw_orders.csv`, `raw_inventory.csv`, and `raw_fulfillment.csv` available in `PROJECT_19A_STAGE` at the paths used by the script.
3. Execute `Project_19a.sql` from top to bottom. It creates the Snowflake context and ingestion objects, loads the raw tables, builds the junk dimension, creates the three fact tables, and runs the analysis queries.
4. Review the junk-dimension combinations, sales transactions, inventory snapshots, fulfillment lags, incomplete lifecycle statuses, and revenue summary.

## Key Engineering Takeaways

- Fact grain must reflect the business process being measured.
- Transaction facts capture events, while periodic snapshots capture state at regular points in time.
- Accumulating snapshots are effective for milestone-driven operational workflows.
- Inventory balances are semi-additive: meaningful across stores at a point in time, but not blindly additive across dates.
- Junk dimensions simplify repeated low-cardinality operational attributes.
- Degenerate dimensions preserve useful business identifiers directly in facts.
- Window functions, conditional logic, date arithmetic, and aggregation support practical dimensional analytics.

## Interview Talking Points

### Why use three different fact patterns?

Sales are events, inventory is a recurring state, and fulfillment is a lifecycle. Separate fact patterns preserve the natural grain and analytical behavior of each process.

### What is the grain of the transaction fact?

`FACT_SALES_TRANSACTIONS` has one row per order transaction and stores amount, tax, user, store, and the junk-dimension key.

### Why is inventory a periodic snapshot?

Inventory is measured at recurring dates. The model stores one store-level row per snapshot date after aggregating product-level source records.

### Why is fulfillment an accumulating snapshot?

An order moves through known milestones. The fact stores milestone dates and updates the process view with lag durations as fulfillment progresses.

### Why is `ORDER_ID` a degenerate dimension?

It is a useful business transaction identifier, but it has no separate descriptive attributes requiring a standalone dimension.

### What does the junk dimension contain?

It combines payment method, shipping option, and gift-wrap flag into unique indicator combinations keyed by `INDICATOR_SK`.

### Which measures are additive or semi-additive?

Order amount and tax are additive across transactions. Inventory units and value represent balances, so they are most meaningful across stores for a given snapshot date rather than summed across dates.

### How are incomplete orders identified?

A `CASE` expression checks missing pick, ship, and delivery dates and labels undelivered orders such as `NOT_PICKED`, `PICKED_NOT_SHIPPED`, or `SHIPPED_NOT_DELIVERED`.

### How is inventory value calculated?

The periodic snapshot sums `qty_on_hand * unit_cost` by snapshot date and store.

## Portfolio Highlights

- Demonstrates three complementary fact-table patterns in one e-commerce model.
- Makes grain explicit for transactions, inventory states, and fulfillment lifecycles.
- Uses a junk dimension to standardize operational order indicators.
- Applies a degenerate dimension for direct order-level analysis.
- Calculates inventory valuation and fulfillment duration with Snowflake SQL.
- Shows dimensional-modelling trade-offs for additive and semi-additive measures.
