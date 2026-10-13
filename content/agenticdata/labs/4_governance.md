## Lab 4: Governance with Knowledge Catalog

<walkthrough-tutorial-duration duration="30"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

You have a working medallion — now make it *trustworthy*. Before an AI agent touches your data in Lab 5, you need three answers: **Can I find it? Can I trust it? Who may see it?** You answer each one with **Knowledge Catalog** (formerly Dataplex), and you'll find that the catalog has already done most of the work.

### About Knowledge Catalog

Knowledge Catalog is Google Cloud's metadata and governance layer, and it **fills itself**: every BigQuery dataset, table and column you created in Labs 2–3 is already in it, together with the descriptions from your Dataform code. You add the two things the platform can't guess: **data quality rules**, which measure what's actually in a table, and **policy tags**, which decide who may read a sensitive column. Humans search this metadata, and agents rely on it to understand your data.

Learn more:
- [Knowledge Catalog overview](https://docs.cloud.google.com/knowledge-catalog/docs/introduction)
- [Auto data quality](https://docs.cloud.google.com/knowledge-catalog/docs/auto-data-quality-overview)
- [Column-level security with policy tags](https://docs.cloud.google.com/bigquery/docs/column-level-security-intro)

### Find your data

Nobody has registered a single table, so search anyway. Open [Knowledge Catalog search](https://console.cloud.google.com/dataplex/dp-search) and ask in plain English:

```
Which tables contain revenue by day?
```

`fct_daily_revenue` comes up (if the results look off, a plain `revenue` finds it too). The catalog picked it up from BigQuery automatically, with no crawler and no registration step.

Now see what the catalog knows about it. In [BigQuery](https://console.cloud.google.com/bigquery), open `cymbal_gold` → `fct_daily_revenue` → <walkthrough-spotlight-pointer locator="semantic({tab 'Details'})">Details</walkthrough-spotlight-pointer>. If agy gave the model a `description` in its Dataform config, it shows up here, so documentation written in code lands in the catalog. (No description? An agent would have to guess what this table means. Lab 5 fixes that with agent instructions.)

### Hold bronze to a standard

In Lab 3 your assertions tested what Dataform *built*, at build time. A **data quality scan** checks a table independently of any pipeline, on demand or on a schedule, and publishes a score to the catalog. Point one at bronze, where you know the flaws are.

The rules live in a short spec file: <walkthrough-editor-open-file filePath="content/agenticdata/src/governance/orders_quality.yaml">orders_quality.yaml</walkthrough-editor-open-file>. It has two rules, the same ones your silver assertions enforce: `status` must be one of six known values, and `order_ts` must not lie in the future.

The scan runs as `dataquality-service-account`, which is pre-provisioned in your project with BigQuery read access. First, allow the Knowledge Catalog service agent to act as it:

```bash
gcloud iam service-accounts add-iam-policy-binding dataquality-service-account@{{ PROJECT_ID }}.iam.gserviceaccount.com \
    --member=serviceAccount:service-{{ PROJECT_NUMBER }}@gcp-sa-dataplex.iam.gserviceaccount.com \
    --role=roles/iam.serviceAccountTokenCreator
```

IAM changes take a moment to propagate, so give the binding about a minute before you create the scan. If the create command below **fails** with a permission error on the service account, that's propagation: wait a minute and run it again.

Then create the scan:

```bash
cd ~/bootkon
gcloud dataplex datascans create data-quality bronzeorders \
    --location={{ REGION }} \
    --data-source-resource=//bigquery.googleapis.com/projects/{{ PROJECT_ID }}/datasets/cymbal_bronze/tables/cymbal_orders \
    --data-quality-spec-file=content/agenticdata/src/governance/orders_quality.yaml \
    --service-account=dataquality-service-account@{{ PROJECT_ID }}.iam.gserviceaccount.com
```

A word on the flags: your datasets sit in the `us` multi-region, and a scan may live in any region inside it, so `{{ REGION }}` it is. With no `--schedule`, the scan runs on demand. The spec's `catalogPublishingEnabled: true` publishes every result to the catalog and to BigQuery.

Now run it:

```bash
gcloud dataplex datascans run bronzeorders --location={{ REGION }}
```

The job takes two to three minutes. Then, in [BigQuery](https://console.cloud.google.com/bigquery), open `cymbal_bronze` → `cymbal_orders` and click <walkthrough-spotlight-pointer locator="semantic({tab 'Data quality'})">Data quality</walkthrough-spotlight-pointer> (refresh the page if the tab is still empty).

**The scan fails, on purpose.** A few percent of rows break the `status` rule (the `shiped` typo), and a handful break the `order_ts` rule. Your pipeline already cleans these flaws away, but now the catalog records them too, so anyone who opens this table sees that bronze is raw and shouldn't be consumed directly.

### Lock down PII

`stg_customers.email` is personal data. Enforce column-level security with a policy tag:

1. Open [BigQuery policy tags](https://console.cloud.google.com/bigquery/policy-tags) and click <walkthrough-spotlight-pointer locator="text('Create taxonomy')">Create Taxonomy</walkthrough-spotlight-pointer>:
    - Taxonomy name: `cymbal`, location `us`
    - Policy tag: `pii`, description: `Personal data — restricted`
2. Create it, then toggle `Enforce access control` on.
3. In [BigQuery](https://console.cloud.google.com/bigquery), open `cymbal_silver` → `stg_customers` → <walkthrough-spotlight-pointer locator="semantic({button 'Edit schema'})">Edit schema</walkthrough-spotlight-pointer>, select the `email` column, click *Add policy tag*, and pick `cymbal > pii`. Save.

Now prove it works. This query **must fail** with an access-denied error on the tagged column:

```sql
SELECT email FROM `{{ PROJECT_ID }}.cymbal_silver.stg_customers` LIMIT 5
```

And this one works fine:

```sql
SELECT * EXCEPT (email) FROM `{{ PROJECT_ID }}.cymbal_silver.stg_customers` LIMIT 5
```

Even with admin rights on BigQuery, you can't read that column: reading tagged data needs a separate grant (**Fine-Grained Reader**). That's the guarantee you want before you let AI agents loose on the warehouse.

❗ If the first query suddenly works again later, a `dataform run` has rebuilt `stg_customers` and dropped the hand-attached tag. Attach it again (step 3).

### Challenge: prove silver passes

**\[TASK\]** Take up to 5 minutes.

1. Clone the scan onto `cymbal_silver.stg_orders`: use the same spec file and the new scan ID `silverorders`. Only the scan ID and `--data-source-resource` change. Run it and compare both scores in the Data quality tab.
2. Discuss with your table: if silver passes, why keep scanning bronze at all?

### Success

🎉 Splendid{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! Your platform now explains itself: every table is findable without anyone registering it, bronze carries an honest (failing) quality score, and customer emails are locked down even against admins. Governance done — the agents can come. 🛡️
