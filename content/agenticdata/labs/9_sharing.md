## Lab 9: The Data Exchange — Sharing the Gold

<walkthrough-tutorial-duration duration="25"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="1"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>
<!-- Optional module: not wired into TUTORIAL.md. Renumber the "Lab N" title to match the event agenda when including. Not yet smoke-tested — smoke-test item 1: subscribe to your OWN listing in one sandbox project (the "Subscribe like a partner" step). If the dialog refuses same-project subscriptions, restructure the default path around neighbor pairing and pre-verify the org policy allows cross-account Analytics Hub Subscriber grants. When wiring into TUTORIAL.md: merge src/optional/sharing/prompts.md into src/prompts.md and repoint the prompts.md link in "Draft the data contract with agy". -->

Remember where this story started: Cymbal's analytics team drowning in one-off CSV exports. You built the cure for the *inside* of the company — but Cymbal's partners still get their numbers the old way: somebody exports a CSV, attaches it to an email, and it's stale before it lands. In this lab you close that loop with **BigQuery sharing**: publish the gold marts as a **listing** in your own **data exchange**, then switch chairs and subscribe to it exactly like a partner would — receiving a live, read-only, zero-copy view instead of an attachment.

This lab assumes Labs 1–3 are complete (the `cymbal_gold` marts exist and have been built at least once) and that your two background terminals from Lab 2 are still open: the tunnel (terminal 2) and the data simulator (terminal 3) — the simulator is what makes the zero-copy proof land. If you also did Lab 4's data-product challenge, you'll recognize the shape: the catalog *described* the contract; now you *distribute* it. (Nothing below depends on Lab 4.)

### About BigQuery sharing

**BigQuery sharing** is BigQuery's built-in distribution channel — you may know it as **Analytics Hub**: Google renamed it, the console page is labeled *Sharing (Analytics Hub)*, and the API keeps the old name. The moving parts: a **data exchange** is a catalog you own — a container for listings, created in your project, no organization-level setup required. A **listing** is one shareable asset (here: a BigQuery dataset) plus the metadata a consumer needs to trust it. When someone subscribes, they get a **linked dataset** in their own project: a read-only *pointer* to your data. Because BigQuery separates storage from compute, a thousand subscribers cost you no extra storage — and publishers stay in control, with egress restrictions, usage metrics, and revocable subscriptions.

Learn more:
- [Introduction to BigQuery sharing](https://docs.cloud.google.com/bigquery/docs/analytics-hub-introduction)
- [Manage listings](https://docs.cloud.google.com/bigquery/docs/analytics-hub-manage-listings)
- [View and subscribe to listings](https://docs.cloud.google.com/bigquery/docs/analytics-hub-view-subscribe-listings)

### Enable sharing and put on both hats

BigQuery sharing has its own API and its own IAM roles: **Analytics Hub Admin** runs exchanges and listings, **Analytics Hub Subscriber** consumes them. You'll play both sides today, so grant yourself both (idempotent, safe to re-run):

```bash
gcloud services enable analyticshub.googleapis.com
gcloud projects add-iam-policy-binding {{ PROJECT_ID }} \
    --member=user:{{ GCP_USERNAME }} --role=roles/analyticshub.admin --condition=None
gcloud projects add-iam-policy-binding {{ PROJECT_ID }} \
    --member=user:{{ GCP_USERNAME }} --role=roles/analyticshub.subscriber --condition=None
```

❗ **Permission denied on the Sharing page?** Fresh IAM grants can take a minute to propagate — wait a moment and reload the page.

### Create the exchange

The exchange is Cymbal's shop window — create it in the console:

1. Open [Sharing (Analytics Hub)](https://console.cloud.google.com/bigquery/analytics-hub) and click <walkthrough-spotlight-pointer locator="semantic({button 'Create exchange'})">Create exchange</walkthrough-spotlight-pointer>.
2. Fill in:
    - Display name: `cymbal-exchange`
    - Region: **US** (the multi-region) — a listing can only share a dataset that lives in the exchange's region, and your medallion lives in the `US` multi-region.
    - Description: `Cymbal's curated data products` (primary contact is optional).
3. Click **Create exchange**. When the *Exchange permissions* step appears, **Skip** it — you granted yourself everything you need a minute ago (in real life, this is where you'd invite publishers and subscribers by email).

Notice what you did *not* need: an organization admin. Exchanges are project-level resources — any team that owns a project can open a shop.

### Draft the data contract with agy

A listing is only as trustworthy as its description: a consumer who can't tell what's in the tables, how fresh they are, or what "revenue" means will fall back to emailing you for a CSV. Turning live schemas into honest prose is authoring work — agy's job. Run this one-shot in terminal 1 (the prompt is also in <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/sharing/prompts.md">prompts.md</walkthrough-editor-open-file>):

```bash
agy -p "Read the table schemas: bq show --schema {{ PROJECT_ID }}:cymbal_gold.fct_daily_revenue ; bq show --schema {{ PROJECT_ID }}:cymbal_gold.dim_customer_360 ; bq show --schema {{ PROJECT_ID }}:cymbal_gold.fct_product_performance. Then write a listing description for sharing these three tables with Cymbal's partners — a data contract as prose, in markdown: one paragraph on what the dataset is, a short section per table (grain, key columns, what questions it answers), a freshness section (the tables are fed by live Datastream CDC from the production Postgres and rebuilt by Dataform runs), and a definitions section (gross revenue is SUM(qty * unit_price) excluding cancelled orders; lifetime value is the gross revenue of a customer's non-cancelled orders; in fct_daily_revenue amounts are per currency and must never be summed across currencies; lifetime_value and the fct_product_performance amounts sum across order currencies without conversion, so present them as activity indicators, not accounting figures). Output only the markdown."
```

Review the draft — you are about to sign it in Cymbal's name. A known-good contract ships with the repository: open <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/sharing/listing_description.md">listing_description.md</walkthrough-editor-open-file> to compare — or to copy from directly, if agy's draft went off-script or you'd rather not select text in a terminal:

```bash
cat content/agenticdata/src/optional/sharing/listing_description.md
```

### Publish the listing

1. Back on the Sharing page, open <walkthrough-spotlight-pointer locator="text('cymbal-exchange')">cymbal-exchange</walkthrough-spotlight-pointer> and click <walkthrough-spotlight-pointer locator="semantic({button 'Create listing'})">Create listing</walkthrough-spotlight-pointer>.
2. Resource type: **BigQuery dataset** → select `cymbal_gold`.
3. Listing details:
    - Display name: `Cymbal Gold — Commerce Analytics`
    - Description: `Analysis-ready commerce marts: daily revenue, customer 360, product performance. Live CDC + Dataform.`
    - Paste your reviewed data contract into the **Documentation** field (it takes markdown).
4. Find the **data egress controls** and tick *Disable copy and export of shared data* — partners get to query the gold, not to bulk-exfiltrate it. (Note the other two options: you can also restrict copying of query results and API-level table exports.)
5. Click <walkthrough-spotlight-pointer locator="semantic({button 'Publish'})">Publish</walkthrough-spotlight-pointer>.

Your gold layer is now a product with a front door — description, contract, contact, and house rules.

### Subscribe like a partner

Time to switch chairs. Open your freshly published listing from the exchange page — this is exactly what a consumer sees: your description, your contract, your contact.

1. Click <walkthrough-spotlight-pointer locator="semantic({button 'Subscribe'})">Subscribe</walkthrough-spotlight-pointer>. A *Create linked dataset* dialog appears.
2. Fill in:
    - Project: `{{ PROJECT_ID }}` — yes, the same project; a publisher can subscribe to their own listing, which is exactly how you test what partners will experience.
    - Linked dataset name: `cymbal_gold_linked`
    - Primary region: **US** (the multi-region, matching the source).
3. Click <walkthrough-spotlight-pointer locator="semantic({button 'Save'})">Save</walkthrough-spotlight-pointer>.

❗ **The dialog refuses your own project?** Pair up with a neighbor and subscribe to each other's listings instead — the Challenge below has the exact steps. Name the linked dataset `cymbal_gold_linked` and everything below works the same, on their live data instead of your own.

Now look at what arrived: open [BigQuery](https://console.cloud.google.com/bigquery), expand your project, and find <walkthrough-spotlight-pointer locator="text('cymbal_gold_linked')">cymbal_gold_linked</walkthrough-spotlight-pointer> — wearing a small *linked* badge on its dataset icon. Click into `fct_daily_revenue`: same schema, same descriptions — but read-only. No copy job ran, no bytes moved; this dataset is a pointer.

### Prove it's a pointer, not a copy

"Zero-copy" is a fine slogan — trust, but verify. In the BigQuery query editor (**Compose new query**), run the source and the linked dataset side by side (order counts can be totaled across currencies; revenue can't — your own contract says so — hence euros only):

```sql
SELECT 'source' AS via, SUM(orders) AS orders,
       ROUND(SUM(IF(currency = 'EUR', gross_revenue, 0)), 2) AS eur_revenue
FROM `{{ PROJECT_ID }}.cymbal_gold.fct_daily_revenue`
UNION ALL
SELECT 'linked', SUM(orders),
       ROUND(SUM(IF(currency = 'EUR', gross_revenue, 0)), 2)
FROM `{{ PROJECT_ID }}.cymbal_gold_linked.fct_daily_revenue`
```

Two identical rows — of course: it's the same storage. Expect roughly 450,000 non-cancelled orders; the exact number depends on how long your simulator has been running. Now make the *source* move. Your simulator (terminal 3) has been writing to Postgres all along, and Datastream has been keeping bronze fresh — refresh silver from live bronze and rebuild gold, same commands as Lab 3, each run finishing in well under a minute:

```bash
cd ~/bootkon/content/agenticdata/src/dataform
dataform run --tags silver && dataform run --tags gold
```

Re-run the query above. Both rows climbed — **in lockstep**. Nobody re-exported anything, no partner pipeline re-ran, and there is no second copy that could go stale. The CSV attachment could never do that.

### Check the meters

One more publisher privilege: back on [Sharing (Analytics Hub)](https://console.cloud.google.com/bigquery/analytics-hub), open `cymbal-exchange`, switch to its <walkthrough-spotlight-pointer locator="text('Usage metrics')">Usage metrics</walkthrough-spotlight-pointer> tab, and pick your listing from the *Listings* menu. As the publisher you see total subscriptions, subscribers per organization, jobs executed, bytes scanned, and which shared tables get queried most ([monitor listings](https://docs.cloud.google.com/bigquery/docs/analytics-hub-monitor-listings)). Your own subscription should already be counted; the job charts may trail the queries you just ran — check back later. Under the hood the same numbers live in a SQL view, ready for the day you want to build a mart about your marts: `` `region-us`.INFORMATION_SCHEMA.SHARED_DATASET_USAGE ``.

And the egress control? Try copying a table out of `cymbal_gold_linked` (three-dot menu next to the table → *Copy*) — you ticked the box, so the copy is denied. Querying: yes. Exfiltrating: no.

### Challenge: subscribe to a neighbor's listing

**\[TASK\]** Take up to 10 minutes — data sharing is more fun with two projects:

1. Team up with a neighbor. Each of you opens your own listing, clicks *Set permissions* → *Add principal*, and adds the other's account as an **Analytics Hub Subscriber**. Then find their listing — *Search listings* on the Sharing page, filter to *Private* — and subscribe to it as `cymbal_gold_neighbor`: you are now watching *their* simulator's numbers, live, from your project. ❗ This one depends on the sandbox's org policy: **domain-restricted sharing** may block grants to other accounts. If IAM refuses, that's the policy working as intended — move on to option 2.
2. Plan B (works everywhere): on *Search listings*, filter to **public** listings and subscribe to one Google publishes — the **Google Trends** listing is a classic. Top search terms land as a linked dataset next to your gold, zero copies, same mechanism you just built for Cymbal.

Note: If you are stuck and cannot figure out how to proceed after a few minutes, ask your team captain.

### Success

🎉 Superb{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! The CSV-export era at Cymbal is officially over: the gold layer is now a published data product with a prose contract, an egress policy, usage metering — and subscribers who get a live pointer instead of a stale attachment. Publish once, subscribe anywhere. 📬→📡
