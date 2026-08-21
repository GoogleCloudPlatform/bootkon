## Lab 4: Governance with Knowledge Catalog

<walkthrough-tutorial-duration duration="30"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

You have a working medallion — now make it *trustworthy*. In this lab you govern it with **Knowledge Catalog** (formerly Dataplex): label the tiers so everyone can find the right data, measure quality automatically, lock down PII, and give business terms a home. In Lab 5 an AI agent becomes a consumer of exactly this governed layer — governance is what keeps agents grounded.

This lab is console-first: you built everything with code so far; now see how the platform describes itself.

### About Knowledge Catalog

Knowledge Catalog (formerly Dataplex Universal Catalog) is Google Cloud's metadata and governance layer. Every dataset, table and column is an **entry** in the catalog; you enrich entries with **aspects** (structured, typed metadata — like the data tiers you are about to define), attach **business glossary** terms, and let **data profiling** and **auto data quality** scans measure the actual content on a schedule or on demand. Because BigQuery reports **lineage** automatically, the catalog also knows where every table came from. All of this metadata is searchable — by humans and, increasingly, by Gemini and agents. That is the deeper point of this lab: a well-curated catalog is the grounding layer that keeps AI answers trustworthy.

Learn more:
- [Knowledge Catalog overview](https://docs.cloud.google.com/dataplex/docs/introduction)
- [Aspects and aspect types](https://docs.cloud.google.com/dataplex/docs/enrich-entries-metadata)
- [Auto data quality](https://docs.cloud.google.com/dataplex/docs/auto-data-quality-overview) and [data profiling](https://docs.cloud.google.com/dataplex/docs/data-profiling-overview)
- [Column-level security with policy tags](https://docs.cloud.google.com/bigquery/docs/column-level-security-intro)
- [Business glossary](https://docs.cloud.google.com/dataplex/docs/manage-glossaries)
- [Data lineage](https://docs.cloud.google.com/dataplex/docs/about-data-lineage)

### Label the medallion tiers with aspects

Aspects are structured metadata attached to catalog entries. We'll create a **Data tier** aspect type and stamp bronze/silver/gold onto the datasets.

1. Open [Knowledge Catalog](https://console.cloud.google.com/dataplex) and go to <walkthrough-spotlight-pointer locator="text('Metadata types')">Metadata types</walkthrough-spotlight-pointer> → <walkthrough-spotlight-pointer locator="semantic({tab 'Aspect types'})">Aspect types</walkthrough-spotlight-pointer>.
2. Click <walkthrough-spotlight-pointer locator="semantic({button 'Create'})">Create</walkthrough-spotlight-pointer> (or *Create aspect type*) and use:
    - Aspect type ID: `data-tier`
    - Display name: `Data tier`
    - Location: `global` — this matters: an aspect type can only be attached to entries in the same location or in `global`, and your BigQuery datasets live in the multi-region `us`. A regional aspect type (e.g. `us-central1`) will *not* show up when you try to attach it below.
3. Add a field (under *Template*, click <walkthrough-spotlight-pointer locator="semantic({button 'Add Field'})">Add Field</walkthrough-spotlight-pointer>):
    - Type: **Enum** (<walkthrough-spotlight-pointer locator="text('Type')">Type</walkthrough-spotlight-pointer>), Name: `tier`, Display name: `Tier`
    - Enum values (click <walkthrough-spotlight-pointer locator="semantic({button 'Add an Enum Value'})">Add an Enum Value</walkthrough-spotlight-pointer> three times): `bronze`, `silver`, `gold`
    - Check <walkthrough-spotlight-pointer locator="text('Is Required')">Is Required</walkthrough-spotlight-pointer>.
4. Click <walkthrough-spotlight-pointer locator="semantic({button 'Create'})">Create</walkthrough-spotlight-pointer>.

Now attach it. Go to <walkthrough-spotlight-pointer locator="text('Search')">Search</walkthrough-spotlight-pointer>, search for `cymbal_gold`, and open the dataset entry:

5. In the entry's details, find `Aspects` → under *Optional aspects* click <walkthrough-spotlight-pointer locator="text('Add')">Add</walkthrough-spotlight-pointer>, filter for **Data tier**, set Tier to `gold` → save.
6. Repeat for `cymbal_silver` (`silver`) and `cymbal_bronze` (`bronze`).

Verify the point of the exercise: in the catalog search bar, filter by your new aspect (e.g. search for `cymbal` and use the aspect filter for `Data tier = gold`) — anyone in the company can now find the *consumable* data without asking around.

### Measure quality automatically

In Lab 3 your assertions tested what Dataform *built*. Knowledge Catalog's **auto data quality** watches tables *continuously* — no pipeline required. Let's point it at the flaws you know are in bronze.

First, allow the Dataplex service agent to use your scan service account:

```bash
gcloud iam service-accounts add-iam-policy-binding dataquality-service-account@{{ PROJECT_ID }}.iam.gserviceaccount.com \
    --member=serviceAccount:service-{{ PROJECT_NUMBER }}@gcp-sa-dataplex.iam.gserviceaccount.com \
    --role=roles/iam.serviceAccountTokenCreator
```

Now profile the customer data:

1. In Knowledge Catalog, open <walkthrough-spotlight-pointer locator="text('Data profiling & quality')">Data profiling & quality</walkthrough-spotlight-pointer>.
2. Click <walkthrough-spotlight-pointer locator="semantic({button 'Create data profile scan'})">Create data profile scan</walkthrough-spotlight-pointer>:
    - Display name: `cymbal-profile-bronze-customers`
    - Table: browse to `cymbal_bronze` → `cymbal_customers`
    - Scope *Entire data*, sampling *All data*, Publish *results to Knowledge Catalog*
    - Credential type: **Service account** → `dataquality-service-account`
    - Schedule: *On-demand*
3. Create it, open it, and click <walkthrough-spotlight-pointer locator="semantic({button 'Run now'})">Run now</walkthrough-spotlight-pointer>.
4. When the job finishes (a few minutes), explore the results — look at the `country` column: there's your planted ~1.5% NULL rate, and the `email` column's distinct count hints at the duplicates.

Then hold bronze orders to a standard:

5. Back on the same page, click <walkthrough-spotlight-pointer locator="semantic({button 'Create data quality scan'})">Create data quality scan</walkthrough-spotlight-pointer>:
    - Display name: `cymbal-dq-bronze-orders`
    - Table: `cymbal_bronze` → `cymbal_orders`
    - Scope *Entire data*, sampling *All data*, Publish *results to Knowledge Catalog*
    - Credential type: **Service account** → `dataquality-service-account`
    - Schedule: *On-demand*
6. Add two rules (rule type *Row check* / validity):

   Dimension Validity:
    ```
    status IN ('pending','paid','shipped','delivered','cancelled','returned')
    ```

    Dimension Accuracy:
    ```
    order_ts <= CURRENT_TIMESTAMP()
    ```
    
7. Run the scan. **It fails — on purpose.** The `shiped` typo and the future-dated orders you saw in Lab 3 are now caught by governance, not just by your pipeline. Discuss with your table: the same rules would pass on `cymbal_silver.stg_orders` — why keep both layers scanned? (If you have time, clone the scan onto silver and prove it passes.)

### Lock down PII

`stg_customers.email` is personal data. Enforce column-level security with a policy tag:

1. Open [BigQuery policy tags](https://console.cloud.google.com/bigquery/policy-tags) and click <walkthrough-spotlight-pointer locator="text('Create taxonomy')">Create Taxonomy</walkthrough-spotlight-pointer>:
    - Taxonomy name: `cymbal-governance`, location `us`
    - Policy tag: `PII`, description: `Personal data — restricted`
2. Create it, then toggle `Enforce access control` on.
3. In [BigQuery](https://console.cloud.google.com/bigquery), open `cymbal_silver` → `stg_customers` → <walkthrough-spotlight-pointer locator="semantic({button 'Edit schema'})">Edit schema</walkthrough-spotlight-pointer>, select the `email` column, click *Add policy tag*, and pick `cymbal-governance > PII`. Save.

Now prove it works — this query **must fail** with an access-denied error on the tagged column:

```sql
SELECT email FROM `{{ PROJECT_ID }}.cymbal_silver.stg_customers` LIMIT 5
```

And this one works fine:

```sql
SELECT * EXCEPT (email) FROM `{{ PROJECT_ID }}.cymbal_silver.stg_customers` LIMIT 5
```

You are the project owner and *still* can't read that column — fine-grained access is a separate grant (Fine-Grained Reader). That's exactly the guarantee you want before letting AI agents loose on the warehouse. (At scale you wouldn't tag by hand: [Sensitive Data Protection discovery](https://docs.cloud.google.com/sensitive-data-protection/docs/data-profiles) profiles your tables continuously and pushes its findings into the catalog as aspects.)

### Give the business a vocabulary

1. In Knowledge Catalog, open <walkthrough-spotlight-pointer locator="text('Glossaries')">Glossaries</walkthrough-spotlight-pointer> and create glossary `Cymbal Business Glossary` (location `us-central1`).
2. Add a term: **Lifetime value** — *"Gross revenue of a customer's non-cancelled orders, in the order currency. Source of truth: cymbal_gold.dim_customer_360.lifetime_value."*
3. Open the `dim_customer_360` entry via catalog Search, go to its schema, select the `lifetime_value` column and attach the term.

Then try the agentic side of governance — in the catalog <walkthrough-spotlight-pointer locator="text('Search')">Search</walkthrough-spotlight-pointer>, ask in natural language:

```
Which tables contain revenue by day?
```

Gemini-powered search reads the same metadata you just curated — every aspect, term, and description you add makes both humans *and* agents smarter.

### Admire the lineage

One more look: open `cymbal_gold.fct_daily_revenue` in BigQuery and its <walkthrough-spotlight-pointer locator="semantic({tab 'Lineage'})">Lineage</walkthrough-spotlight-pointer> tab. Bronze→silver→gold, captured automatically from the Dataform runs. (Datastream's Postgres→bronze hop publishes its metadata to the catalog in Preview, but doesn't draw lineage edges yet — watch that space.)

### Success

🎉 Splendid{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! Your platform now explains itself: tiers are labeled, quality is measured continuously (and honestly — bronze fails, as it should), PII is locked down even against project owners, business terms live next to the data, and lineage draws itself. Governance done — the agents can come. 🛡️
