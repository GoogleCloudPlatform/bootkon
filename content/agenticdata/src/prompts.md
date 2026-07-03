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

Run inside `~/bootkon/content/agenticdata/src/dataform`. The full
specification lives in that folder's `AGENTS.md` — the prompt only hands
over the brief:

```
/goal Read AGENTS.md and build the complete silver and gold layers it
specifies. Run `dataform compile` yourself and fix any errors until the
project compiles cleanly.
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
`rm -rf cymbal_analyst` first so agy builds it from scratch). The full
specification lives in that folder's `AGENTS.md`:

```
/goal Read AGENTS.md, then create the files of the cymbal_analyst package
(cymbal_analyst/__init__.py, agent.py, a2a_server.py) exactly as it
describes.
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
