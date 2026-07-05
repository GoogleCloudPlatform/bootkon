# Canonical agy prompts — optional sharing lab

Local mirror for the optional BigQuery sharing lab, in the same format as
`content/agenticdata/src/prompts.md`. When the lab is wired into TUTORIAL.md,
merge this section into that file and repoint the lab's prompts.md link.

## Lab 9 — listing description (the data contract)

```
agy -p "Read the table schemas: bq show --schema <PROJECT_ID>:cymbal_gold.fct_daily_revenue ; bq show --schema <PROJECT_ID>:cymbal_gold.dim_customer_360 ; bq show --schema <PROJECT_ID>:cymbal_gold.fct_product_performance. Then write a listing description for sharing these three tables with Cymbal's partners — a data contract as prose, in markdown: one paragraph on what the dataset is, a short section per table (grain, key columns, what questions it answers), a freshness section (the tables are fed by live Datastream CDC from the production Postgres and rebuilt by Dataform runs), and a definitions section (gross revenue is SUM(qty * unit_price) excluding cancelled orders; lifetime value is the gross revenue of a customer's non-cancelled orders; in fct_daily_revenue amounts are per currency and must never be summed across currencies; lifetime_value and the fct_product_performance amounts sum across order currencies without conversion, so present them as activity indicators, not accounting figures). Output only the markdown."
```

Fallback: `cat content/agenticdata/src/optional/sharing/listing_description.md`
(a known-good contract ships with the repository — copy it into the listing's
Documentation field directly).
