## Lab 3: The Medallion — Dataform, Authored by agy

<walkthrough-tutorial-duration duration="45"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="3"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

Your bronze layer is a faithful replica — including every flaw of the source system: duplicate customers, a `shiped` typo, lowercase currencies, orphaned line items, negative payments. In this lab you build the **silver** (cleaned, tested) and **gold** (business marts) layers with **Dataform**.

The twist: **agy writes all of the SQL**. You direct, review, run, and verify. This is the lab where "agent writes the pipeline" stops being a slide and becomes your terminal.

We use the open-source **Dataform CLI** — code-first, version-controllable, and a perfect fit for an agentic workflow (compile errors go straight back into agy). In production you would run the same project on a schedule in managed Dataform.

### About Dataform and the medallion pattern

Dataform manages SQL transformations as *code*: each table is a **SQLX** file (SQL plus a small config header), dependencies are declared with `${ref(...)}` instead of hardcoded table names, and from those references Dataform compiles a dependency graph and executes it in the right order against BigQuery. **Assertions** are data tests that run with every execution — uniqueness, non-null, arbitrary row conditions — and fail the run when the data breaks a promise; **tags** let you execute just a slice of the graph (you will run `silver` and `gold` separately).

The **medallion pattern** you are about to build is the standard way to organize such a warehouse: *bronze* holds raw, untouched source data (your CDC replica), *silver* is cleaned and tested, and *gold* holds the business-level marts that people — and, from Lab 5 on, agents — actually consume. Each layer has one job, and problems are fixed at the earliest layer that can see them.

Learn more:
- [Dataform overview](https://docs.cloud.google.com/dataform/docs/overview)
- [Dataform core concepts](https://docs.cloud.google.com/dataform/docs/dataform-core)
- [The Dataform CLI](https://docs.cloud.google.com/dataform/docs/use-dataform-cli)
- [Assertions](https://docs.cloud.google.com/dataform/docs/assertions)

### Set up the project

Install the CLI:

```bash
npm install -g @dataform/cli@3
```

The starter project ships with the repository — you work on it directly in `content/agenticdata/src/dataform` (settings + bronze source declarations only; the models are agy's job). Point it at your project and set up credentials:

```bash
cd ~/bootkon/content/agenticdata/src/dataform
sed -i "s/PROJECT_ID_PLACEHOLDER/$PROJECT_ID/" workflow_settings.yaml
echo "{\"projectId\": \"$PROJECT_ID\", \"location\": \"US\"}" > .df-credentials.json
```

The credentials file tells the CLI to use your logged-in identity (Application Default Credentials) against BigQuery — no keys involved. Check that the `sed` worked by opening <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform/workflow_settings.yaml">workflow_settings.yaml</walkthrough-editor-open-file> — `defaultProject` should now be `{{ PROJECT_ID }}`. Then have a look at <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform/definitions/sources.js">sources.js</walkthrough-editor-open-file>: it declares the six bronze tables so every model can reference them with `${ref(...)}`, which is what builds the dependency graph — and, later, your lineage.

### Brief your co-engineer

Start agy inside the project:

```bash
cd ~/bootkon/content/agenticdata/src/dataform && agy
```

And give it the full brief (this is one prompt — paste it whole):

```
/goal This is a Dataform Core 3 project. definitions/sources.js declares the bronze tables (a Datastream CDC replica of the Postgres schema "cymbal"; tables cymbal_customers, cymbal_products, cymbal_orders, cymbal_order_items, cymbal_payments, cymbal_reviews in dataset cymbal_bronze). Create a silver layer (dataset cymbal_silver, tag "silver") that fixes these known data problems, one table per source table (stg_customers, stg_products, stg_orders, stg_order_items, stg_payments): customers: normalize emails to lowercase, drop rows whose email is not a valid address, collapse duplicate emails keeping the most recently updated row, convert empty-string countries to NULL; orders: lowercase statuses and fix the typo 'shiped' -> 'shipped', uppercase currency codes, drop orders with a future order_ts; order_items: drop rows whose order_id has no matching order and rows with qty <= 0; payments: drop negative amounts and payments without a matching order. Create a gold layer (dataset cymbal_gold, tag "gold"): fct_daily_revenue (date, currency, distinct orders, units, gross revenue = SUM(qty * unit_price), excluding cancelled orders), dim_customer_360 (one row per customer with lifetime_orders, lifetime_value, avg_order_value, first/last order date), fct_product_performance (units, gross revenue and gross margin (unit_price - cost) per product, excluding cancelled and returned orders). Every silver table needs Dataform assertions: uniqueKey on its primary key, nonNull on required columns, and rowConditions that assert the cleaning worked (allowed status values, currency matches ^[A-Z]{3}$, qty > 0, amount >= 0, order_ts not in the future). Use ${ref(...)} for all dependencies. Run `dataform compile` yourself and fix any compilation errors until the project compiles.
```

Watch agy work: it will create the `.sqlx` files, run `dataform compile`, read the errors, and fix its own code. Review the result with `/diff` before accepting.

Note: **If agy took a wrong turn** or you want to compare with a known-good implementation, the reference lives right next door in `src/dataform_reference/` — for example <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform_reference/definitions/stg_customers.sqlx">stg_customers.sqlx</walkthrough-editor-open-file> and <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform_reference/definitions/fct_daily_revenue.sqlx">fct_daily_revenue.sqlx</walkthrough-editor-open-file>. Restore with:

```bash
cp ~/bootkon/content/agenticdata/src/dataform_reference/definitions/*.sqlx ~/bootkon/content/agenticdata/src/dataform/definitions/
```

### Compile and run

Exit agy (or use a new terminal, remembering `. bk`) and verify the compilation yourself — trust, but verify:

```bash
cd ~/bootkon/content/agenticdata/src/dataform && dataform compile
```

You should see the models, their dependencies, and the assertions. Now build silver, then gold:

```bash
dataform run --tags silver
```

```bash
dataform run --tags gold
```

Each run also executes the **assertions** — data tests that fail the run if the cleaning didn't work. If a run fails, paste the error into agy and let it repair its own pipeline; that feedback loop is the whole point of this lab.

### Verify in the console

Open [BigQuery](https://console.cloud.google.com/bigquery) and expand your project:

1. You now have three medallion datasets: `cymbal_bronze`, <walkthrough-spotlight-pointer locator="text('cymbal_silver')">cymbal_silver</walkthrough-spotlight-pointer> and <walkthrough-spotlight-pointer locator="text('cymbal_gold')">cymbal_gold</walkthrough-spotlight-pointer> (plus `cymbal_assertions` — the test results).
2. Click `stg_customers` and check the row count in <walkthrough-spotlight-pointer locator="semantic({tab 'Details'})">Details</walkthrough-spotlight-pointer> — fewer rows than bronze `cymbal_customers`: the duplicates and invalid emails are gone.
3. Query the flaw you'll never see again:

```sql
SELECT 'bronze' AS layer, COUNT(*) AS shiped_typos
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_orders` WHERE status = 'shiped'
UNION ALL
SELECT 'silver', COUNT(*)
FROM `{{ PROJECT_ID }}.cymbal_silver.stg_orders` WHERE status = 'shiped'
```

4. The payoff: open `fct_daily_revenue` and click the <walkthrough-spotlight-pointer locator="semantic({tab 'Lineage'})">Lineage</walkthrough-spotlight-pointer> tab. The bronze→silver→gold graph you see was **not configured by anyone** — BigQuery reports [data lineage](https://docs.cloud.google.com/dataplex/docs/about-data-lineage) automatically from the jobs the Dataform CLI just ran, following the `${ref(...)}` dependencies agy wrote.

One more thing: your simulator (terminal 3) is still writing to Postgres, and Datastream keeps updating bronze. Re-run `dataform run` at any time and the whole medallion refreshes with the latest data.

### Challenge: harden the pipeline

**\[TASK\]** Take up to 10 minutes — pick at least one:

1. **Incremental gold**: ask agy to convert `fct_daily_revenue` into an incremental table that only processes new days. (Reference prompt in <walkthrough-editor-open-file filePath="content/agenticdata/src/prompts.md">prompts.md</walkthrough-editor-open-file>.)
2. **Detect, don't just filter**: silver silently drops negative payments. Add a standalone assertion on the **bronze** payments table so the pipeline *alerts* on them — run it and watch it fail on purpose. (Reference: <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform_reference/definitions/assert_bronze_payments_non_negative.sqlx">assert_bronze_payments_non_negative.sqlx</walkthrough-editor-open-file>.)
3. **Bonus**: ask agy to add a gold table that classifies `cymbal_reviews` sentiment with BigQuery's `AI.GENERATE` — and discuss with your table what that costs at scale.

Note: If you are stuck and cannot figure out how to proceed after a few minutes, ask your team captain.

### Success

🎉 Bravo{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! You briefed an AI agent, and it wrote, compiled, and repaired a complete medallion pipeline — which *you* reviewed, executed, and verified, assertions and all. Duplicates deduplicated, typos untypo'd, orphans re-homed (well, evicted). The gold layer shines — now let's govern it. 🥇
