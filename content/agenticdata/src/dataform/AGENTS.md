# Cymbal Dataform project — agent context

This is a Dataform Core 3 project (`workflow_settings.yaml`). It builds a
medallion architecture on BigQuery from a Datastream CDC replica of the
Postgres schema `cymbal`.

## Source data (bronze, dataset `cymbal_bronze`, declared in definitions/sources.js)

- `cymbal_customers` (customer_id PK, full_name, email, phone, address, country, created_at, updated_at)
- `cymbal_products` (product_id PK, sku, name, category, price, cost)
- `cymbal_orders` (order_id PK, customer_id, status, currency, order_ts, updated_at)
- `cymbal_order_items` (order_item_id PK, order_id, product_id, qty, unit_price)
- `cymbal_payments` (payment_id PK, order_id, method, amount, status, paid_at)
- `cymbal_reviews` (review_id PK, order_id, rating, review_text, created_at)

Every bronze table also carries a Datastream `datastream_metadata` column —
exclude it from all downstream tables.

Known data problems, planted upstream on purpose: duplicate customers (same
email in different letter case), invalid email addresses, empty-string
countries, the status typo `shiped`, mixed-case currency codes, `qty <= 0`,
orphaned order_items (order_id without a matching order), future `order_ts`,
negative payment amounts.

## Target architecture

**Silver** (dataset `cymbal_silver`, tag `silver`) — one `stg_*` table per
source table except reviews, fixing the problems above:

- `stg_customers`: lowercase/trim emails, drop rows whose email is not a
  valid address, collapse duplicate emails keeping the most recently updated
  row, convert empty-string countries to NULL.
- `stg_products`: cast price/cost to NUMERIC.
- `stg_orders`: lowercase statuses and fix `shiped` -> `shipped`, uppercase
  currency codes, drop orders with a future `order_ts`.
- `stg_order_items`: drop orphans (inner join to `stg_orders`) and rows with
  `qty <= 0`.
- `stg_payments`: drop negative amounts and payments without a matching order.

**Gold** (dataset `cymbal_gold`, tag `gold`):

- `fct_daily_revenue`: order_date, currency, distinct orders, units,
  gross_revenue = SUM(qty * unit_price), excluding cancelled orders.
- `dim_customer_360`: one row per customer with lifetime_orders,
  lifetime_value, avg_order_value, first/last order date.
- `fct_product_performance`: units_sold, gross_revenue and gross_margin =
  SUM(qty * (unit_price - cost)) per product, excluding cancelled and
  returned orders.

## Conventions

- Use `${ref(...)}` for every dependency; never hardcode table names.
- Every silver table gets assertions: `uniqueKey` on its primary key,
  `nonNull` on required columns, and `rowConditions` proving the cleaning
  worked (allowed status values, currency matches `^[A-Z]{3}$`, `qty > 0`,
  `amount >= 0`, `order_ts <= CURRENT_TIMESTAMP()`).
- After changing files, run `dataform compile` and fix errors until the
  project compiles cleanly.
- Do not modify `workflow_settings.yaml` or `definitions/sources.js`.
