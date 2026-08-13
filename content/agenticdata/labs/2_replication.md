## Lab 2: Live Replication with Datastream

<walkthrough-tutorial-duration duration="40"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

In this lab you bring Cymbal's database to life and replicate it — continuously — into BigQuery using **Datastream** change data capture (CDC). By the end, every INSERT, UPDATE and DELETE in Postgres lands in your `cymbal_bronze` dataset within moments.

(The commands below contain your generated database passwords, rendered into the tutorial. If you see empty quotes instead, run the `bk-start` reload step from the end of Lab 1.)

### About Datastream

Datastream is Google Cloud's serverless **change data capture (CDC)** service: instead of periodically re-exporting tables, it taps the source database's transaction log and replicates every INSERT, UPDATE and DELETE as it happens. For PostgreSQL that log is the **write-ahead log (WAL)**: Postgres emits every committed change in *logical* form, and Datastream consumes that feed through a replication slot. A stream has two phases that run in parallel — a one-time **backfill** (snapshot of the existing rows) and continuous **CDC streaming** — and the destination side writes into BigQuery for you: no pipeline code, no cluster to manage.

Learn more:
- [Datastream overview](https://docs.cloud.google.com/datastream/docs/overview)
- [PostgreSQL as a source](https://docs.cloud.google.com/datastream/docs/sources-postgresql)

### Wait for the database

Lab 1 left agy standing by in your terminal — but the commands in this lab are **shell commands**, so exit agy first by typing `/quit` (you will call your co-engineer back for the authoring step later in this lab).

If the Lab 1 build already finished, this returns instantly — otherwise it waits for the create operation to complete:

```bash
gcloud sql operations wait --timeout=unlimited \
    $(gcloud sql operations list --instance=cymbal-oltp --format='value(name)' --limit=1)
```

### Create the Private Service Connect endpoint

Your instance exposes a **service attachment** — a private socket other networks can plug into. Create an endpoint for it in your VPC at `10.10.0.5`, the address you reserved back in Lab 1:

```bash
SA_URI=$(gcloud sql instances describe cymbal-oltp --format="value(pscServiceAttachmentLink)")
gcloud compute forwarding-rules create cymbal-endpoint --region={{ REGION }} \
    --address=cymbal-endpoint-ip --network=cymbal-vpc \
    --target-service-attachment=$SA_URI --allow-psc-global-access
```

From now on, `10.10.0.5` **is** your database — for Datastream (its private connection `cymbal-psc` is already plugged into your VPC) and for the jump VM.

### The jump VM

Cloud Shell lives outside your VPC and a PSC-only instance has no public IP — so your project ships with a tiny helper: `cymbal-jump`, an e2-micro VM (no external IP either!) that forwards port 5432 to the database endpoint. Its <walkthrough-editor-open-file filePath="content/agenticdata/src/jumpvm-startup.sh">startup script</walkthrough-editor-open-file> is four lines of iptables. You reach it through an **IAP tunnel** — identity-based, no IPs exposed anywhere.

### Open the tunnel

Open a **second terminal tab** (`+`) and start the tunnel. **Leave this terminal open for the rest of the event** — the simulator and (much later) your concierge agent use it. The helper wraps `gcloud compute start-iap-tunnel` and reconnects automatically if the tunnel ever drops:

```bash
~/bootkon/content/agenticdata/bk-tunnel
```

When you see *Listening on port [5432]*, `localhost:5432` in Cloud Shell is your production database.

**Identity-Aware Proxy (IAP)** TCP forwarding is what makes this safe: the tunnel is authorized by your Google identity and an IAM role (`iap.tunnelResourceAccessor`), not by network position — no VPN, no bastion with a public IP, and every connection is auditable. ([IAP TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding))

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

**Prefer the console?** The SQL steps of this lab also work in **Cloud SQL Studio**, the query editor built into the console — as a replacement for the psql commands, not on top of them (running the same DDL twice just earns you an *already exists* error). Open [Cloud SQL Studio](https://console.cloud.google.com/sql/instances/cymbal-oltp/studio), sign in to database `cymbal` as user `postgres` with password `{{ BK_DB_PASSWORD }}`, paste the contents of `schema.sql` into the editor and hit **Run**. Studio replaces your keyboard, not your tunnel — keep terminal 2 open either way: the simulator below and the Lab 6 concierge go through it. (And if Studio refuses to connect to your PSC-only instance, no drama — the psql path works everywhere.)

Now the bulk load. This is a **server-side import from Cloud Storage** — the instance pulls the CSVs itself; nothing flows through your tunnel:

```bash
SQL_SA=$(gcloud sql instances describe cymbal-oltp --format="value(serviceAccountEmailAddress)")
gcloud storage buckets add-iam-policy-binding gs://{{ PROJECT_ID }}-bucket \
    --member=serviceAccount:$SQL_SA --role=roles/storage.objectAdmin
for t in customers products orders order_items payments reviews; do
    echo "Importing $t ..."
    gcloud sql import csv cymbal-oltp gs://{{ PROJECT_ID }}-bucket/seed/${t}.csv \
        --database=cymbal --table=cymbal.${t} --quiet
done
```

This takes about two to three minutes for all six tables. While it runs, read the next section — but don't execute it yet.

### Prepare logical replication

Datastream reads Postgres' write-ahead log through a **publication** and a **replication slot**, as a dedicated replication user. The publication defines *which* tables' changes are exposed (`FOR ALL TABLES` here — the safe default), and the slot tracks *how far* a consumer has read: Postgres retains WAL until the slot has consumed it, which is why Datastream never misses a change, even across restarts. (Details: [Configure a Cloud SQL for PostgreSQL source](https://docs.cloud.google.com/datastream/docs/configure-cloudsql-psql).)

Have a look at <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/replication_setup.sql">replication_setup.sql</walkthrough-editor-open-file>, then (once the import finished) run it:

```bash
PGPASSWORD="{{ BK_DB_PASSWORD }}" psql -h localhost -p 5432 -U postgres -d cymbal \
    -v ds_password="{{ BK_DS_PASSWORD }}" \
    -f content/agenticdata/src/datastream/replication_setup.sql
```

**Prefer the console?** If you took the Cloud SQL Studio route, run the same statements there **instead of** the psql command above (it's `replication_setup.sql` with the psql variable replaced by your generated Datastream password) — first this batch:

```sql
ALTER USER postgres WITH REPLICATION;
CREATE USER datastream_user WITH REPLICATION IN ROLE cloudsqlsuperuser LOGIN PASSWORD '{{ BK_DS_PASSWORD }}';
GRANT USAGE ON SCHEMA cymbal TO datastream_user;
GRANT SELECT ON ALL TABLES IN SCHEMA cymbal TO datastream_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA cymbal GRANT SELECT ON TABLES TO datastream_user;
CREATE PUBLICATION cymbal_pub FOR ALL TABLES;
```

Then — still in Studio, and only if you skipped the psql command — create the replication slot as its **own** run (slot creation refuses to share a transaction with writes, and being a `SELECT`, it returns a row: your visible confirmation):

```sql
SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('cymbal_slot', 'pgoutput');
```

### Create the bronze dataset

Both paths below land the CDC data here, so create the destination dataset first:

```bash
bq mk --location=US --dataset {{ PROJECT_ID }}:cymbal_bronze
```

**Prefer the console?** In [BigQuery](https://console.cloud.google.com/bigquery), click the three-dot menu next to your project → **Create dataset**: ID `cymbal_bronze`, location type **Multi-region** → `US`. Same thing — `bq` is just the keyboard-shaped door into BigQuery.

### Provision Datastream: pick your path

Now you create two **connection profiles** (a PostgreSQL source and a BigQuery destination) and the **CDC stream**. There are two equivalent ways — **pick one**, then continue at *Watch it flow*:

- **Path A — Console**: click through the Datastream UI, guided by spotlights. Good if you like seeing the wizard and every option. **Unsure? Take this one.**
- **Path B — Command line**: `gcloud`, with agy authoring the stream config. Faster and scriptable.

***

#### Path A — Console (UI)

**Create the source connection profile.**

1. Open [Datastream → Connection profiles](https://console.cloud.google.com/datastream/connection-profiles) and click <walkthrough-spotlight-pointer locator="semantic({button 'Create profile'})">Create profile</walkthrough-spotlight-pointer>.
2. Choose the <walkthrough-spotlight-pointer locator="text('PostgreSQL')">PostgreSQL</walkthrough-spotlight-pointer> profile type.
3. Fill in:
    - Connection profile name: `cymbal-postgres-profile`
    - Region: `{{ REGION }}`
    - Hostname or IP: `10.10.0.5` (the PSC endpoint — Datastream private connections don't resolve DNS, so use the IP)
    - Port: `5432`, Username: `datastream_user`, Password: `{{ BK_DS_PASSWORD }}`, Database: `cymbal`
4. Click <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">Continue</walkthrough-spotlight-pointer>, choose **Private connectivity** and select `cymbal-psc`, then <walkthrough-spotlight-pointer locator="semantic({button 'Create'})">Create</walkthrough-spotlight-pointer>.

**Create the destination connection profile.**

5. Back on Connection profiles, click <walkthrough-spotlight-pointer locator="semantic({button 'Create profile'})">Create profile</walkthrough-spotlight-pointer> again and choose <walkthrough-spotlight-pointer locator="text('BigQuery')">BigQuery</walkthrough-spotlight-pointer>.
6. Name it `cymbal-bq-profile`, region `{{ REGION }}`, then <walkthrough-spotlight-pointer locator="semantic({button 'Create'})">Create</walkthrough-spotlight-pointer>.

**Create and start the stream.**

7. Go to [Datastream → Streams](https://console.cloud.google.com/datastream/streams) and click <walkthrough-spotlight-pointer locator="semantic({button 'Create stream'})">Create stream</walkthrough-spotlight-pointer>.
8. Stream name `cymbal-cdc-stream`; source type **PostgreSQL**, destination type **BigQuery**. Work through the wizard with <walkthrough-spotlight-pointer locator="semantic({button 'Continue'})">Continue</walkthrough-spotlight-pointer>:
    - **Source**: select `cymbal-postgres-profile`. Run the connectivity test.
    - **Configure source**: include the `cymbal` schema (all tables); set **Publication** to `cymbal_pub` and **Replication slot** to `cymbal_slot`.
    - **Destination**: select `cymbal-bq-profile`.
    - **Configure destination**: choose *Single dataset for all schemas* → `cymbal_bronze`; set the **staleness limit** to `0` seconds.
9. Run the validation, then click <walkthrough-spotlight-pointer locator="semantic({button 'Create'})">Create</walkthrough-spotlight-pointer>, and finally <walkthrough-spotlight-pointer locator="semantic({button 'Create & start'})">Create & start</walkthrough-spotlight-pointer> (or open the stream and press **Start**) with a full backfill.

Skip Path B and continue at **Watch it flow**.

***

#### Path B — Command line (gcloud)

Two profiles: where the data comes from, and where it goes. Note the hostname — the PSC endpoint IP, because Datastream private connections do not resolve DNS:

```bash
gcloud datastream connection-profiles create cymbal-postgres-profile --location={{ REGION }} \
    --type=postgresql --display-name=cymbal-postgres-profile \
    --postgresql-hostname=10.10.0.5 --postgresql-port=5432 \
    --postgresql-username=datastream_user --postgresql-password="{{ BK_DS_PASSWORD }}" \
    --postgresql-database=cymbal --private-connection=cymbal-psc
```

```bash
gcloud datastream connection-profiles create cymbal-bq-profile --location={{ REGION }} \
    --type=bigquery --display-name=cymbal-bq-profile
```

The stream itself is defined by two JSON files that ship with the repository — you work on them directly in `content/agenticdata/src/datastream/` (the shipped destination config still contains a placeholder). Writing API-correct configuration is authoring work — agy's job. In your agy session (started from `~/bootkon`), run:

```bash
/goal Rewrite content/agenticdata/src/datastream/source_config.json and content/agenticdata/src/datastream/destination_config.json for gcloud datastream streams create. The PostgreSQL source uses publication "cymbal_pub", replication slot "cymbal_slot", and should include all tables of the "cymbal" schema. The BigQuery destination writes every table into the single dataset "{{ PROJECT_ID }}:cymbal_bronze" with a data freshness of 0 seconds. Use the exact JSON field names of the Datastream v1 API (publication, replicationSlot, includeObjects/postgresqlSchemas, singleTargetDataset/datasetId, dataFreshness).
```

**Review what agy wrote**: open <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/source_config.json">source_config.json</walkthrough-editor-open-file> and <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/destination_config.json">destination_config.json</walkthrough-editor-open-file>. If agy went off-script, git has your back — restore the shipped files and fill in the placeholder yourself:

```bash
git -C ~/bootkon restore content/agenticdata/src/datastream/
sed -i "s/PROJECT_ID_PLACEHOLDER/{{ PROJECT_ID }}/" content/agenticdata/src/datastream/destination_config.json
```

The next commands are for the **shell again, not for agy** — exit agy with `/quit` first. Then create the stream (with a full backfill of the seed data) and flip it to `RUNNING`:

```bash
gcloud datastream streams create cymbal-cdc-stream --location={{ REGION }} \
    --display-name=cymbal-cdc-stream \
    --source=cymbal-postgres-profile --postgresql-source-config=content/agenticdata/src/datastream/source_config.json \
    --destination=cymbal-bq-profile --bigquery-destination-config=content/agenticdata/src/datastream/destination_config.json \
    --backfill-all
```

```bash
gcloud datastream streams update cymbal-cdc-stream --location={{ REGION }} \
    --state=RUNNING --update-mask=state
```

***

Whichever path you took, Datastream now validates everything (logical decoding, slot, publication, permissions, connectivity) and starts the backfill. The stream reaches **Running** after about two minutes, and the seed data lands in BigQuery roughly a minute later.

Two design choices in the destination config are worth understanding: the stream runs in **merge mode**, meaning every change event is upserted into the BigQuery table (via the Storage Write API's CDC support), so bronze always mirrors the *current state* of Postgres — the alternative, *append-only*, would keep every event as its own row, giving you a full change history instead. And `dataFreshness: "0s"` tells BigQuery to apply pending changes at query time rather than on a schedule — that's what makes the live demo below feel instant.

Learn more:
- [BigQuery as a destination (merge vs. append-only)](https://docs.cloud.google.com/datastream/docs/destination-bigquery)
- [BigQuery change data capture](https://docs.cloud.google.com/bigquery/docs/change-data-capture)

### Watch it flow

Open [Datastream](https://console.cloud.google.com/datastream/streams) and click <walkthrough-spotlight-pointer locator="text('cymbal-cdc-stream')">cymbal-cdc-stream</walkthrough-spotlight-pointer>. Explore the <walkthrough-spotlight-pointer locator="text('Objects')">Objects</walkthrough-spotlight-pointer> tab — you can watch the per-table backfill progress live. Within a couple of minutes the stream shows **Running** and the six `cymbal_*` tables appear.

Now make it *live*. Open a **third terminal tab**, and start the activity simulator — Cymbal's customers waking up:

```bash
cd ~/bootkon
python3 content/agenticdata/src/datagen/simulate.py
```

Leave it running. Go to [BigQuery](https://console.cloud.google.com/bigquery), expand <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer> → `cymbal_bronze`, and run this query a few times (use the editor, **not** table preview — preview lags behind CDC):

```sql
SELECT MAX(order_id) AS latest_order, COUNT(*) AS total_orders
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_orders`
```

Watch `latest_order` climb as the simulator inserts. Then prove UPDATEs work end-to-end — back in terminal 1:

```bash
PGPASSWORD="{{ BK_DB_PASSWORD }}" psql -h localhost -p 5432 -U postgres -d cymbal \
    -c "UPDATE cymbal.customers SET country = 'Iceland', updated_at = now() WHERE customer_id = 42;"
```

(Cloud SQL Studio works for this `UPDATE` too, if that's been your route.)

And in BigQuery (give it a minute or two):

```sql
SELECT customer_id, full_name, country
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_customers`
WHERE customer_id = 42
```

Customer 42 just moved to Iceland — from a Postgres UPDATE to a BigQuery row, hands-free. That's merge-mode CDC.

### Success

🎉 Outstanding{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! You built a private, production-style CDC pipeline: a PSC-only Postgres instance, an identity-based tunnel, logical replication, and a running Datastream that mirrors every change into BigQuery in near real time. The bronze layer is alive — time to refine it. 🥉→🥈
