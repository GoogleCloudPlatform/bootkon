## Lab 2: Live Replication with Datastream

<walkthrough-tutorial-duration duration="40"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

In this lab you bring Cymbal's database to life and replicate it — continuously — into BigQuery using **Datastream** change data capture (CDC). By the end of the day, every INSERT, UPDATE and DELETE in Postgres lands in your `cymbal_bronze` dataset within moments.

(The commands below contain your generated database passwords, rendered into the tutorial. If you see empty quotes instead, run the `bk-start` reload step from the end of Lab 1.)

### About Datastream

Datastream is Google Cloud's serverless **change data capture (CDC)** service: instead of periodically re-exporting tables, it taps the source database's transaction log and replicates every INSERT, UPDATE and DELETE as it happens. For PostgreSQL that log is the **write-ahead log (WAL)**: Postgres emits every committed change in *logical* form, and Datastream consumes that feed through a replication slot. A stream has two phases that run in parallel — a one-time **backfill** (snapshot of the existing rows) and continuous **CDC streaming** — and the destination side writes into BigQuery for you: no pipeline code, no cluster to manage.

Learn more:
- [Datastream overview](https://docs.cloud.google.com/datastream/docs/overview)
- [PostgreSQL as a source](https://docs.cloud.google.com/datastream/docs/sources-postgresql)

### Back to the shell

Lab 1 left agy standing by in your terminal — but the commands in this lab are **shell commands**, so exit agy first by typing `/quit` (you will call your co-engineer back for the authoring step later in this lab).

### The Private Service Connect endpoint

A quick look at the plumbing you get to use today: your instance exposes a **service attachment** — a private socket other networks can plug into — and your VPC carries the matching **endpoint** for it at `10.10.0.5` (`cymbal-endpoint`, on the address reserved at provisioning time). That address **is** your database — for Datastream (its private connection `cymbal-psc` is already plugged into your VPC) and for the jump VM.

### The jump VM

Cloud Shell lives outside your VPC and a PSC-only instance has no public IP — so your project ships with a tiny helper: `cymbal-jump`, an e2-micro VM (no external IP either!) that forwards port 5432 to the database endpoint. Its <walkthrough-editor-open-file filePath="content/agenticdata/src/jumpvm-startup.sh">startup script</walkthrough-editor-open-file> is four lines of iptables. You reach it through an **IAP tunnel** — identity-based, no IPs exposed anywhere.

### The tunnel

`localhost:5432` in your Cloud Shell **is** the Cymbal database — no setup needed: your bootkon environment opened an IAP tunnel to the jump VM in the background, and the VM forwards the port to the PSC endpoint at `10.10.0.5`.

**Identity-Aware Proxy (IAP)** TCP forwarding is what makes this safe: the tunnel is authorized by your Google identity and an IAM role (`iap.tunnelResourceAccessor`), not by network position — no VPN, no bastion with a public IP, and every connection is auditable. ([IAP TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding))

❗ Should any command below ever answer *connection refused*, the tunnel is gone — a long break recycles your Cloud Shell and takes background processes with it. Run `. bk` to bring it back, or start it in a spare tab (it logs to `~/.bootkon-tunnel.log`):

```bash
~/bootkon/content/agenticdata/bk-tunnel
```

### Create the schema and load the data

Back in your **first terminal**. Create the database (control-plane, no tunnel needed):

```bash
gcloud sql databases create cymbal --instance=cymbal-oltp
```

Apply the schema through the tunnel:

```bash
PGPASSWORD="{{ BK_DB_PASSWORD }}" psql -h localhost -p 5432 -U postgres -d cymbal \
    -f content/agenticdata/src/datagen/schema.sql
```

Open <walkthrough-editor-open-file filePath="content/agenticdata/src/datagen/schema.sql">schema.sql</walkthrough-editor-open-file> — notice every table has a primary key (Datastream's merge mode needs them) and there are deliberately no foreign keys.

Now the bulk load. This is a **server-side import from Cloud Storage** — the instance pulls the CSVs itself; nothing flows through your tunnel. It can do that because every Cloud SQL instance acts as its own Google-managed identity, and yours was granted read access to your seed bucket when the project was provisioned. Import all six tables (one loop, one line — each import reports itself):

```bash
for t in customers products orders order_items payments reviews; do gcloud sql import csv cymbal-oltp gs://{{ PROJECT_ID }}-bucket/seed/${t}.csv --database=cymbal --table=cymbal.${t} --quiet; done
```

This takes about two to three minutes for all six tables. While it runs, read ahead — but execute the next sections only once the import finished.

### Verify in the console

Time to see your data through the console's eyes: open [Cloud SQL Studio](https://console.cloud.google.com/sql/instances/cymbal-oltp/studio) and sign in as user `postgres` with password `{{ BK_DB_PASSWORD }}` — and in the **Database** field, replace the preselected `postgres` with `cymbal` (signing into the wrong database is exactly what a *"relation cymbal.orders does not exist"* later means). Then run:

```sql
SELECT COUNT(*) AS total_orders FROM cymbal.orders;
```

Half a million orders — Cymbal's production history, now living in **your** database. Expand the table tree on the left for the other five tables. (Studio is the console's window into the instance; your tunnel stays the pipe for everything else today.)

### Prepare logical replication

Datastream reads Postgres' write-ahead log through a **publication** and a **replication slot**, as a dedicated replication user. The publication defines *which* tables' changes are exposed (`FOR ALL TABLES` here — the safe default), and the slot tracks *how far* a consumer has read: Postgres retains WAL until the slot has consumed it, which is why Datastream never misses a change, even across restarts. (Details: [Configure a Cloud SQL for PostgreSQL source](https://docs.cloud.google.com/datastream/docs/configure-cloudsql-psql).)

Have a look at <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/replication_setup.sql">replication_setup.sql</walkthrough-editor-open-file>, then (once the import finished) run it:

```bash
PGPASSWORD="{{ BK_DB_PASSWORD }}" psql -h localhost -p 5432 -U postgres -d cymbal \
    -v ds_password="{{ BK_DS_PASSWORD }}" \
    -f content/agenticdata/src/datastream/replication_setup.sql
```

### Provision Datastream

A stream needs two **connection profiles** — where the data comes from, and where it goes. The destination side already exists in your project: the BigQuery profile `cymbal-bq-profile` and the empty `cymbal_bronze` dataset the stream will fill. Take a look while it's still empty: open [BigQuery](https://console.cloud.google.com/bigquery), expand <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer> and its **Datasets** entry.

The source profile is yours to create — it carries your generated replication password. Note the hostname: the PSC endpoint IP, because Datastream private connections do not resolve DNS:

```bash
gcloud datastream connection-profiles create cymbal-postgres-profile --location={{ REGION }} \
    --type=postgresql --display-name=cymbal-postgres-profile \
    --postgresql-hostname=10.10.0.5 --postgresql-port=5432 \
    --postgresql-username=datastream_user --postgresql-password="{{ BK_DS_PASSWORD }}" \
    --postgresql-database=cymbal --private-connection=cymbal-psc
```

The stream itself is defined by two JSON files that ship with the repository — you work on them directly in `content/agenticdata/src/datastream/` (the shipped destination config still contains a placeholder). Writing API-correct configuration is authoring work — so call your co-engineer back into the terminal:

```bash
cd ~/bootkon && agy
```

Now brief it:

```bash
/goal Rewrite content/agenticdata/src/datastream/source_config.json and content/agenticdata/src/datastream/destination_config.json for gcloud datastream streams create. The PostgreSQL source uses publication "cymbal_pub", replication slot "cymbal_slot", and should include all tables of the "cymbal" schema. The BigQuery destination writes every table into the single dataset "{{ PROJECT_ID }}:cymbal_bronze" with a data freshness of 0 seconds. Use the exact JSON field names of the Datastream v1 API (publication, replicationSlot, includeObjects/postgresqlSchemas, singleTargetDataset/datasetId, dataFreshness).
```

**Review what agy wrote**: open <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/source_config.json">source_config.json</walkthrough-editor-open-file> and <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/destination_config.json">destination_config.json</walkthrough-editor-open-file>. If agy went off-script, git has your back — restore the shipped files and fill in the placeholder yourself:

```bash
git -C ~/bootkon restore content/agenticdata/src/datastream/
sed -i "s/PROJECT_ID_PLACEHOLDER/{{ PROJECT_ID }}/" content/agenticdata/src/datastream/destination_config.json
```

The next commands are for the **shell again, not for agy** — exit agy with `/quit` first. Then create the stream, with a full backfill of the seed data:

```bash
gcloud datastream streams create cymbal-cdc-stream --location={{ REGION }} \
    --display-name=cymbal-cdc-stream \
    --source=cymbal-postgres-profile --postgresql-source-config=content/agenticdata/src/datastream/source_config.json \
    --destination=cymbal-bq-profile --bigquery-destination-config=content/agenticdata/src/datastream/destination_config.json \
    --backfill-all
```

The create takes a few minutes — watch it happen in the [Datastream console](https://console.cloud.google.com/datastream/streams): your stream appears with status **Creating**, then **Not started**. Don't rush the start: an update issued too early answers *"The resource is being created"*, even when the console already shows *Not started* (the create operation is still finalizing — trust the API, not the list). This helper waits for the real thing:

```bash
content/agenticdata/bk-wait-stream
```

Now flip the stream to `RUNNING`:

```bash
gcloud datastream streams update cymbal-cdc-stream --location={{ REGION }} \
    --state=RUNNING --update-mask=state
```

Datastream now validates everything (logical decoding, slot, publication, permissions, connectivity) and starts the backfill. The stream reaches **Running** after about two minutes, and the seed data lands in BigQuery roughly a minute later.

Two design choices in the destination config are worth understanding: the stream runs in **merge mode**, meaning every change event is upserted into the BigQuery table (via the Storage Write API's CDC support), so bronze always mirrors the *current state* of Postgres — the alternative, *append-only*, would keep every event as its own row, giving you a full change history instead. And `dataFreshness: "0s"` tells BigQuery to apply pending changes at query time rather than on a schedule — that's what makes the live demo below feel instant.

Learn more:
- [BigQuery as a destination (merge vs. append-only)](https://docs.cloud.google.com/datastream/docs/destination-bigquery)
- [BigQuery change data capture](https://docs.cloud.google.com/bigquery/docs/change-data-capture)

### Watch it flow

Open [Datastream](https://console.cloud.google.com/datastream/streams) and click <walkthrough-spotlight-pointer locator="text('cymbal-cdc-stream')">cymbal-cdc-stream</walkthrough-spotlight-pointer>. Explore the <walkthrough-spotlight-pointer locator="text('Objects')">Objects</walkthrough-spotlight-pointer> tab — you can watch the per-table backfill progress live. Within a couple of minutes the stream shows **Running** and the six `cymbal_*` tables appear.

Now make it *live*. Open a **second terminal tab** (`+`), and start the activity simulator — Cymbal's customers waking up:

```bash
cd ~/bootkon
python3 content/agenticdata/src/datagen/simulate.py
```

Leave it running. Go to [BigQuery](https://console.cloud.google.com/bigquery), expand <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer> → **Datasets** → `cymbal_bronze`, and run this query a few times (use the editor, **not** table preview — preview lags behind CDC):

```sql
SELECT MAX(order_id) AS latest_order, COUNT(*) AS total_orders
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_orders`
```

Watch `latest_order` climb as the simulator inserts. Then prove UPDATEs work end-to-end — back in terminal 1:

```bash
PGPASSWORD="{{ BK_DB_PASSWORD }}" psql -h localhost -p 5432 -U postgres -d cymbal \
    -c "UPDATE cymbal.customers SET country = 'Iceland', updated_at = now() WHERE customer_id = 42;"
```

(Cloud SQL Studio works for this `UPDATE` too, if you still have it open from the verify step.)

And in BigQuery (give it a minute or two):

```sql
SELECT customer_id, full_name, country
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_customers`
WHERE customer_id = 42
```

Customer 42 just moved to Iceland — from a Postgres UPDATE to a BigQuery row, hands-free. That's merge-mode CDC.

### Success

🎉 Outstanding{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! You built a private, production-style CDC pipeline: a PSC-only Postgres instance, an identity-based tunnel, logical replication, and a running Datastream that mirrors every change into BigQuery in near real time. The bronze layer is alive — time to refine it. 🥉→🥈
