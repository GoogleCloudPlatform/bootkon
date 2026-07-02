# Canonical agy prompts

The prompts quoted in the labs, collected in one place so table captains can
copy them quickly. agy output varies by design — every artifact has a
reference solution under `content/agenticdata/src/` that participants can
fall back to.

## Lab 1 — understand the bootstrap

```
What does content/agenticdata/bk-bootstrap do? Summarize the IAM roles it
grants and explain why a separate data-quality service account is created.
```

## Lab 2 — Datastream configuration files

```
/goal Rewrite content/agenticdata/src/datastream/source_config.json and
content/agenticdata/src/datastream/destination_config.json for
`gcloud datastream streams create`.
The PostgreSQL source uses publication "cymbal_pub", replication slot
"cymbal_slot", and should include all tables of the "cymbal" schema.
The BigQuery destination writes every table into the single dataset
"<PROJECT_ID>:cymbal_bronze" with a data freshness of 0 seconds.
Use the exact JSON field names of the Datastream v1 API
(publication, replicationSlot, includeObjects/postgresqlSchemas,
singleTargetDataset/datasetId, dataFreshness).
```

Fallback: `git restore content/agenticdata/src/datastream/` then replace
`PROJECT_ID_PLACEHOLDER` in `destination_config.json` with sed.

## Lab 3 — the medallion pipeline (the centerpiece)

Run inside `~/bootkon/content/agenticdata/src/dataform` (participants work
directly on the starter project in the repo):

```
/goal This is a Dataform Core 3 project. definitions/sources.js declares the
bronze tables (a Datastream CDC replica of the Postgres schema "cymbal";
tables cymbal_customers, cymbal_products, cymbal_orders, cymbal_order_items,
cymbal_payments, cymbal_reviews in dataset cymbal_bronze).

Create a silver layer (dataset cymbal_silver, tag "silver") that fixes these
known data problems, one table per source table (stg_customers, stg_products,
stg_orders, stg_order_items, stg_payments):
- customers: normalize emails to lowercase, drop rows whose email is not a
  valid address, collapse duplicate emails keeping the most recently updated
  row, convert empty-string countries to NULL
- orders: lowercase statuses and fix the typo 'shiped' -> 'shipped',
  uppercase currency codes, drop orders with a future order_ts
- order_items: drop rows whose order_id has no matching order and rows with
  qty <= 0
- payments: drop negative amounts and payments without a matching order

Create a gold layer (dataset cymbal_gold, tag "gold"):
- fct_daily_revenue: date, currency, distinct orders, units,
  gross revenue = SUM(qty * unit_price), excluding cancelled orders
- dim_customer_360: one row per customer with lifetime_orders,
  lifetime_value, avg_order_value, first/last order date
- fct_product_performance: units, gross revenue and gross margin
  (unit_price - cost) per product, excluding cancelled and returned orders

Every silver table needs Dataform assertions: uniqueKey on its primary key,
nonNull on required columns, and rowConditions that assert the cleaning
worked (allowed status values, currency matches ^[A-Z]{3}$, qty > 0,
amount >= 0, order_ts not in the future).

Use ${ref(...)} for all dependencies. Run `dataform compile` yourself and fix
any compilation errors until the project compiles.
```

Fallback: `cp content/agenticdata/src/dataform_reference/definitions/*.sqlx content/agenticdata/src/dataform/definitions/`

## Lab 3 challenge — incremental gold

```
/goal Convert fct_daily_revenue into an incremental Dataform table that only
processes orders newer than the latest order_date already in the table.
Explain the trade-off versus a full rebuild in two sentences.
```

## Lab 5 — data agent instructions

```
agy -p "Read the table schemas: bq show --schema <PROJECT_ID>:cymbal_gold.fct_daily_revenue ; bq show --schema <PROJECT_ID>:cymbal_gold.dim_customer_360 ; bq show --schema <PROJECT_ID>:cymbal_gold.fct_product_performance. Then draft system instructions for a BigQuery conversational data agent over these three tables: synonyms business users might use (revenue, sales, LTV, best sellers), which table answers which kind of question, default groupings (order_date, currency, category), and columns to exclude from summaries (email). Output only the instructions text."
```

## Lab 6 — build the analyst agent

Run inside `content/agenticdata/src/adk` (participants
`rm -rf cymbal_analyst` first so agy builds it from scratch):

```
/goal Create a Python package cymbal_analyst implementing an ADK agent
(google-adk 2.x is installed):
- agent.py defines root_agent = Agent(name="cymbal_analyst",
  model=env BK_CYMBAL_MODEL default "gemini-2.5-flash") with ONE function tool
  that sends a question to a published BigQuery data agent via the
  google-cloud-geminidataanalytics DataChatServiceClient (stateless chat with
  DataAgentContext pointing at
  projects/$GOOGLE_CLOUD_PROJECT/locations/global/dataAgents/$BK_DATA_AGENT_ID)
  and returns the streamed text parts joined together.
- a2a_server.py exposes it via
  google.adk.a2a.utils.agent_to_a2a.to_a2a(root_agent, port=8001)
  as module attribute a2a_app for uvicorn.
- Read all configuration (GOOGLE_CLOUD_PROJECT, BK_DATA_AGENT_ID, BK_CYMBAL_MODEL)
  from environment variables; do not create any config files.
- __init__.py must do: from . import agent
```

Fallback: `git restore content/agenticdata/src/adk/cymbal_analyst/`

## Lab 6 challenge — extend the concierge

```
/goal Add a second tool to cymbal_concierge/agent.py:
recent_orders(customer_email: str) returning the last 5 orders (id, status,
total, order_ts) for that customer from the live Postgres database, reusing
the existing connection pattern. Update the agent instruction so it knows
when to use which tool.
```
