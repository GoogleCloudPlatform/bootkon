## Lab 3: The Medallion — Dataform, Authored by agy

<walkthrough-tutorial-duration duration="40"></walkthrough-tutorial-duration>
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

The Dataform CLI is already on your machine, and the project is pre-wired — the Lab 1 bootstrap installed the CLI, pointed the settings at your project, and wrote the credentials file. The starter project ships with the repository — you work on it directly in `content/agenticdata/src/dataform` (settings + bronze source declarations only; the models are agy's job). **This folder is your home for the rest of this lab** — change into it once:

```bash
cd ~/bootkon/content/agenticdata/src/dataform
```

Two files are worth a look before you brief anyone. <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform/workflow_settings.yaml">workflow_settings.yaml</walkthrough-editor-open-file> (generated for you from the template by the bootstrap) — `defaultProject` should read `{{ PROJECT_ID }}`, and the git-ignored `.df-credentials.json` next to it tells the CLI to use your logged-in identity (Application Default Credentials) against BigQuery — no keys involved. And <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform/definitions/sources.js">sources.js</walkthrough-editor-open-file>: it declares the six bronze tables so every model can reference them with `${ref(...)}`, which is what builds the dependency graph — and, later, your lineage.

### Brief your co-engineer

The full specification of what to build — source schemas, the known data problems, the target silver/gold tables, and the assertion rules — lives in <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform/AGENTS.md">AGENTS.md</walkthrough-editor-open-file>, right inside the project. Read it: it's the brief you are about to hand your co-engineer, and keeping it in a file (instead of a giant prompt) makes agy's work reproducible.

Start agy (you are already in the project folder):

```bash
agy
```

And hand over the brief:

```bash
/goal Read AGENTS.md and build the complete silver and gold layers it specifies. Run dataform compile yourself and fix any errors until the project compiles cleanly.
```

Watch agy work: it will create the `.sqlx` files, run `dataform compile`, read the errors, and fix its own code. Review the result with `/diff` before accepting.

Note: **If agy took a wrong turn** or you want to compare with a known-good implementation, the reference lives right next door in `src/dataform_reference/` — for example <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform_reference/definitions/stg_customers.sqlx">stg_customers.sqlx</walkthrough-editor-open-file> and <walkthrough-editor-open-file filePath="content/agenticdata/src/dataform_reference/definitions/fct_daily_revenue.sqlx">fct_daily_revenue.sqlx</walkthrough-editor-open-file>. Restore with:

```bash
cp ~/bootkon/content/agenticdata/src/dataform_reference/definitions/*.sqlx ~/bootkon/content/agenticdata/src/dataform/definitions/
```

### Compile and run

Exit agy and verify the compilation yourself — trust, but verify:

```bash
dataform compile
```

You should see the models, their dependencies, and the assertions. Now build silver, then gold — each run finishes in well under a minute on the seed data:

```bash
dataform run --tags silver
```

```bash
dataform run --tags gold
```

Each run also executes the **assertions** — data tests that fail the run if the cleaning didn't work. If a run fails, paste the error into agy and let it repair its own pipeline; that feedback loop is the whole point of this lab.

### Verify in the console

Open [BigQuery](https://console.cloud.google.com/bigquery) and expand your project:

1. You now have three medallion datasets: <walkthrough-spotlight-pointer locator="text('cymbal_bronze')">cymbal_bronze</walkthrough-spotlight-pointer> , <walkthrough-spotlight-pointer locator="text('cymbal_silver')">cymbal_silver</walkthrough-spotlight-pointer> and <walkthrough-spotlight-pointer locator="text('cymbal_gold')">cymbal_gold</walkthrough-spotlight-pointer> (plus <walkthrough-spotlight-pointer locator="text('cymbal_assertions')">cymbal_assertions</walkthrough-spotlight-pointer> — the test results).
2. Open <walkthrough-spotlight-pointer locator="text('cymbal_silver')">cymbal_silver</walkthrough-spotlight-pointer> → `stg_customers` and check the row count in <walkthrough-spotlight-pointer locator="semantic({tab 'Details'})">Details</walkthrough-spotlight-pointer> — fewer rows than `cymbal_bronze` → `cymbal_customers`: the duplicates and invalid emails are gone.
3. Query the flaw you'll never see again:

```sql
SELECT 'bronze' AS layer, COUNT(*) AS shiped_typos
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_orders` WHERE status = 'shiped'
UNION ALL
SELECT 'silver', COUNT(*)
FROM `{{ PROJECT_ID }}.cymbal_silver.stg_orders` WHERE status = 'shiped'
```


One more thing: your simulator (terminal 2) is still writing to Postgres, and Datastream keeps updating bronze. Re-run `dataform run` at any time and the whole medallion refreshes with the latest data.

### Success

🎉 Bravo{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! You briefed an AI agent, and it wrote, compiled, and repaired a complete medallion pipeline — which *you* reviewed, executed, and verified, assertions and all. Duplicates deduplicated, typos untypo'd, orphans re-homed (well, evicted). The gold layer shines — now let's govern it. 🥇
