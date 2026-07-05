# Cymbal Gold — Commerce Analytics

Curated, analysis-ready marts from Cymbal's order platform. This is the same
gold layer Cymbal's own analysts and AI agents use: raw operational data is
replicated live into BigQuery, cleaned and tested in the silver layer, and
aggregated here — no raw PII, no operational tables, no CSV exports.

## What's inside

| Table | Grain | Use it for |
|---|---|---|
| `fct_daily_revenue` | one row per day and currency | Revenue and volume trends: `orders`, `units`, `gross_revenue` by `order_date` and `currency`. |
| `dim_customer_360` | one row per deduplicated customer | Customer analytics: `lifetime_orders`, `lifetime_value`, `avg_order_value`, first and last order dates, `country`. |
| `fct_product_performance` | one row per product | Product and category analytics: `units_sold`, `gross_revenue`, `gross_margin` per `sku`, `name`, `category`. |

## Freshness

The source of truth is Cymbal's production PostgreSQL order platform,
replicated continuously into BigQuery via Datastream change data capture.
These marts are rebuilt on top of that live replica by Dataform
transformation runs; every row reflects the state of the platform as of the
most recent run.

## Definitions

- **Gross revenue** is `SUM(qty * unit_price)` and excludes cancelled orders.
- **Lifetime value (LTV)** is the gross revenue of a customer's non-cancelled
  orders.
- `fct_product_performance` additionally excludes returned orders — margin is
  only counted on goods that stayed sold.
- In `fct_daily_revenue`, amounts are reported **per currency** (ISO 4217,
  normalized in silver) — never sum across currencies without converting
  first. `lifetime_value` and the `fct_product_performance` amounts are
  summed across order currencies without conversion; treat them as activity
  indicators, not accounting figures.
- Customers are **deduplicated** by lowercased email; counts here may be lower
  than in the operational system.

## Contact

Cymbal data platform team — data-platform@cymbal.example
