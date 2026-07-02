## Lab 2: Live Replication with Datastream

<walkthrough-tutorial-duration duration="40"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

In this lab you bring Cymbal's database to life and replicate it — continuously — into BigQuery using **Datastream** change data capture (CDC). By the end, every INSERT, UPDATE and DELETE in Postgres lands in your `cymbal_bronze` dataset within moments.

(If any command below complains about an unset variable like `$BK_DB_PASSWORD`, run `source ~/.bashrc` — the bootstrap in Lab 1 put the stream configuration there.)

### About Datastream

Datastream is Google Cloud's serverless **change data capture (CDC)** service: instead of periodically re-exporting tables, it taps the source database's transaction log and replicates every INSERT, UPDATE and DELETE as it happens. For PostgreSQL that log is the **write-ahead log (WAL)**: Postgres emits every committed change in *logical* form, and Datastream consumes that feed through a replication slot. A stream has two phases that run in parallel — a one-time **backfill** (snapshot of the existing rows) and continuous **CDC streaming** — and the destination side writes into BigQuery for you: no pipeline code, no cluster to manage.

Learn more:
- [Datastream overview](https://docs.cloud.google.com/datastream/docs/overview)
- [PostgreSQL as a source](https://docs.cloud.google.com/datastream/docs/sources-postgresql)

### Wait for the database

If the Lab 1 build already finished, this returns instantly — otherwise it waits for the create operation to complete:

```bash
gcloud sql operations wait --timeout=unlimited \
    $(gcloud sql operations list --instance=cymbal-oltp --format='value(name)' --limit=1)
```

Also confirm the Datastream private connection from Lab 1 reached the `CREATED` state (it takes around 5–10 minutes from when you kicked it off — if it still shows `CREATING`, wait a moment and re-run):

```bash
gcloud datastream private-connections describe cymbal-psc --location={{ REGION }} --format='value(state)'
```

### Create the Private Service Connect endpoint

Your instance exposes a **service attachment** — a private socket other networks can plug into. Create an endpoint for it in your VPC at the reserved IP `10.10.0.5`:

```bash
SA_URI=$(gcloud sql instances describe cymbal-oltp --format="value(pscServiceAttachmentLink)")
gcloud compute addresses create cymbal-endpoint-ip --region={{ REGION }} \
    --subnet=cymbal-subnet --addresses=10.10.0.5
gcloud compute forwarding-rules create cymbal-endpoint --region={{ REGION }} \
    --address=cymbal-endpoint-ip --network=cymbal-vpc \
    --target-service-attachment=$SA_URI --allow-psc-global-access
```

From now on, `10.10.0.5` **is** your database — for Datastream and for the jump VM below.

### Create the jump VM

Cloud Shell lives outside your VPC and a PSC-only instance has no public IP, so you need a tiny helper: an e2-micro VM (no external IP either!) that forwards port 5432 to the database endpoint. Its <walkthrough-editor-open-file filePath="content/agenticdata/src/jumpvm-startup.sh">startup script</walkthrough-editor-open-file> is four lines of iptables. You will reach the VM through an **IAP tunnel** — identity-based, no IPs exposed anywhere:

```bash
gcloud compute instances create cymbal-jump --zone={{ REGION }}-a \
    --machine-type=e2-micro --subnet=cymbal-subnet --no-address --can-ip-forward \
    --metadata-from-file=startup-script=content/agenticdata/src/jumpvm-startup.sh
```

```bash
gcloud compute firewall-rules create allow-iap-ingress --network=cymbal-vpc \
    --direction=INGRESS --action=allow --rules=tcp:22,tcp:5432 \
    --source-ranges=35.235.240.0/20
```

### Open the tunnel

Open a **second terminal tab** (`+`) and start the tunnel. **Leave this terminal open for the rest of the event** — the simulator and (much later) your concierge agent use it:

```bash
gcloud compute start-iap-tunnel cymbal-jump 5432 \
    --local-host-port=localhost:5432 --zone={{ REGION }}-a
```

When you see *Listening on port [5432]*, `localhost:5432` in Cloud Shell is your production database. (If the tunnel ever drops — it disconnects after an hour of inactivity — just re-run this command.)

**Identity-Aware Proxy (IAP)** TCP forwarding is what makes this safe: the tunnel is authorized by your Google identity and an IAM role (`iap.tunnelResourceAccessor`), not by network position — no VPN, no bastion with a public IP, and every connection is auditable. ([IAP TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding))

### Create the schema and load the data

Back in your **first terminal**. Create the database (control-plane, no tunnel needed):

```bash
gcloud sql databases create cymbal --instance=cymbal-oltp
```

Apply the schema through the tunnel:

```bash
PGPASSWORD="$BK_DB_PASSWORD" psql -h localhost -p 5432 -U postgres -d cymbal \
    -f content/agenticdata/src/datagen/schema.sql
```

Open <walkthrough-editor-open-file filePath="content/agenticdata/src/datagen/schema.sql">schema.sql</walkthrough-editor-open-file> — notice every table has a primary key (Datastream's merge mode needs them) and there are deliberately no foreign keys.

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
PGPASSWORD="$BK_DB_PASSWORD" psql -h localhost -p 5432 -U postgres -d cymbal \
    -v ds_password="$BK_DS_PASSWORD" \
    -f content/agenticdata/src/datastream/replication_setup.sql
```

### Create the bronze dataset

Both paths below land the CDC data here, so create the destination dataset first:

```bash
bq mk --location=US --dataset {{ PROJECT_ID }}:cymbal_bronze
```

### Provision Datastream: pick your path

Now you create two **connection profiles** (a PostgreSQL source and a BigQuery destination) and the **CDC stream**. There are two equivalent ways — **pick one**, then continue at *Watch it flow*:

- **Path A — Console**: click through the Datastream UI, guided by spotlights. Good if you like seeing the wizard and every option.
- **Path B — Command line**: `gcloud`, with agy authoring the stream config. Faster and scriptable.

You'll need the Datastream user's password for either path. Print it so you can copy it:

```bash
echo $BK_DS_PASSWORD
```

***

#### Path A — Console (UI)

**Create the source connection profile.**

1. Open [Datastream → Connection profiles](https://console.cloud.google.com/datastream/connection-profiles) and click <walkthrough-spotlight-pointer locator="semantic({button 'Create profile'})">Create profile</walkthrough-spotlight-pointer>.
2. Choose the <walkthrough-spotlight-pointer locator="text('PostgreSQL')">PostgreSQL</walkthrough-spotlight-pointer> profile type.
3. Fill in:
    - Connection profile name: `cymbal-postgres-profile`
    - Region: `{{ REGION }}`
    - Hostname or IP: `10.10.0.5` (the PSC endpoint — Datastream private connections don't resolve DNS, so use the IP)
    - Port: `5432`, Username: `datastream_user`, Password: *(the value you just printed)*, Database: `cymbal`
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
    --postgresql-username=datastream_user --postgresql-password="$BK_DS_PASSWORD" \
    --postgresql-database=cymbal --private-connection=cymbal-psc
```

```bash
gcloud datastream connection-profiles create cymbal-bq-profile --location={{ REGION }} \
    --type=bigquery --display-name=cymbal-bq-profile
```

The stream itself is defined by two JSON files that ship with the repository — you work on them directly in `content/agenticdata/src/datastream/` (the shipped destination config still contains a placeholder). Writing API-correct configuration is authoring work — agy's job. In your agy session (started from `~/bootkon`), run:

```
/goal Rewrite content/agenticdata/src/datastream/source_config.json and content/agenticdata/src/datastream/destination_config.json for `gcloud datastream streams create`. The PostgreSQL source uses publication "cymbal_pub", replication slot "cymbal_slot", and should include all tables of the "cymbal" schema. The BigQuery destination writes every table into the single dataset "{{ PROJECT_ID }}:cymbal_bronze" with a data freshness of 0 seconds. Use the exact JSON field names of the Datastream v1 API (publication, replicationSlot, includeObjects/postgresqlSchemas, singleTargetDataset/datasetId, dataFreshness).
```

**Review what agy wrote**: open <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/source_config.json">source_config.json</walkthrough-editor-open-file> and <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/destination_config.json">destination_config.json</walkthrough-editor-open-file>. If agy went off-script, git has your back — restore the shipped files and fill in the placeholder yourself:

```bash
git -C ~/bootkon restore content/agenticdata/src/datastream/
sed -i "s/PROJECT_ID_PLACEHOLDER/{{ PROJECT_ID }}/" content/agenticdata/src/datastream/destination_config.json
```

Create the stream (with a full backfill of the seed data), then flip it to `RUNNING`:

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
PGPASSWORD="$BK_DB_PASSWORD" psql -h localhost -p 5432 -U postgres -d cymbal \
    -c "UPDATE cymbal.customers SET country = 'Iceland', updated_at = now() WHERE customer_id = 42;"
```

And in BigQuery (give it a minute or two):

```sql
SELECT customer_id, full_name, country
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_customers`
WHERE customer_id = 42
```

Customer 42 just moved to Iceland — from a Postgres UPDATE to a BigQuery row, hands-free. That's merge-mode CDC.

### Challenge: dig deeper

**\[TASK\]** Take up to 10 minutes:

1. DELETE an order in psql (pick a high `order_id` from the simulator's output, remove its `order_items` and `payments` rows first) and confirm it disappears from `cymbal_bronze.cymbal_orders`.
2. Every bronze table has an extra `datastream_metadata` column — inspect it and ask agy what `source_timestamp` and `uuid` are for.
3. Ask agy: *"What is the difference between Datastream's merge and append-only modes for BigQuery, and when would I choose each?"*

### Success

🎉 Outstanding{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! You built a private, production-style CDC pipeline: a PSC-only Postgres instance, an identity-based tunnel, logical replication, and a running Datastream that mirrors every change into BigQuery in near real time. The bronze layer is alive — time to refine it. 🥉→🥈
