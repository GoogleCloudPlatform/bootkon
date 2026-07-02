## Lab 2: Live Replication with Datastream

<walkthrough-tutorial-duration duration="40"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

In this lab you bring Cymbal's database to life and replicate it — continuously — into BigQuery using **Datastream** change data capture (CDC). By the end, every INSERT, UPDATE and DELETE in Postgres lands in your `cymbal_bronze` dataset within moments.

Make sure your terminal has the stream state loaded:

```bash
source ~/.agenticdata.env
```

### Wait for the database

If the Lab 1 build already finished, this returns instantly:

```bash
OP=$(gcloud sql operations list --instance=cymbal-oltp --filter='status!=DONE' --format='value(name)')
[ -n "$OP" ] && gcloud sql operations wait $OP --timeout=unlimited || echo "cymbal-oltp is ready."
```

Also confirm the Datastream private connection from Lab 1 reached the `CREATED` state:

```bash
gcloud datastream private-connections describe cymbal-psc --location=$REGION --format='value(state)'
```

### Create the Private Service Connect endpoint

Your instance exposes a **service attachment** — a private socket other networks can plug into. Create an endpoint for it in your VPC at the reserved IP `10.10.0.5`:

```bash
SA_URI=$(gcloud sql instances describe cymbal-oltp --format="value(pscServiceAttachmentLink)")
gcloud compute addresses create cymbal-endpoint-ip --region=$REGION \
    --subnet=cymbal-subnet --addresses=$ENDPOINT_IP
gcloud compute forwarding-rules create cymbal-endpoint --region=$REGION \
    --address=cymbal-endpoint-ip --network=cymbal-vpc \
    --target-service-attachment=$SA_URI --allow-psc-global-access
```

From now on, `10.10.0.5` **is** your database — for Datastream and for the jump VM below.

### Create the jump VM

Cloud Shell lives outside your VPC and a PSC-only instance has no public IP, so you need a tiny helper: an e2-micro VM (no external IP either!) that forwards port 5432 to the database endpoint. You will reach the VM through an **IAP tunnel** — identity-based, no IPs exposed anywhere:

```bash
gcloud compute instances create cymbal-jump --zone=${REGION}-a \
    --machine-type=e2-micro --subnet=cymbal-subnet --no-address --can-ip-forward \
    --metadata=startup-script='#!/bin/bash
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -F
iptables -t nat -A PREROUTING -p tcp --dport 5432 -j DNAT --to-destination 10.10.0.5
iptables -t nat -A POSTROUTING -p tcp --dport 5432 -j MASQUERADE'
```

```bash
gcloud compute firewall-rules create allow-iap-ingress --network=cymbal-vpc \
    --direction=INGRESS --action=allow --rules=tcp:22,tcp:5432 \
    --source-ranges=35.235.240.0/20
```

### Open the tunnel

Open a **second terminal tab** (`+`), initialize it, and start the tunnel. **Leave this terminal open for the rest of the event** — the simulator and (much later) your concierge agent use it:

```bash
. bk && source ~/.agenticdata.env
gcloud compute start-iap-tunnel cymbal-jump 5432 \
    --local-host-port=localhost:5432 --zone=${REGION}-a
```

When you see *Listening on port [5432]*, `localhost:5432` in Cloud Shell is your production database. (If the tunnel ever drops — it disconnects after an hour of inactivity — just re-run this command.)

### Create the schema and load the data

Back in your **first terminal**. Create the database (control-plane, no tunnel needed):

```bash
gcloud sql databases create cymbal --instance=cymbal-oltp
```

Apply the schema through the tunnel:

```bash
PGPASSWORD="$DB_PASSWORD" psql -h localhost -p 5432 -U postgres -d cymbal \
    -f content/agenticdata/src/datagen/schema.sql
```

Open <walkthrough-editor-open-file filePath="content/agenticdata/src/datagen/schema.sql">schema.sql</walkthrough-editor-open-file> — notice every table has a primary key (Datastream's merge mode needs them) and there are deliberately no foreign keys.

Now the bulk load. This is a **server-side import from Cloud Storage** — the instance pulls the CSVs itself; nothing flows through your tunnel:

```bash
SQL_SA=$(gcloud sql instances describe cymbal-oltp --format="value(serviceAccountEmailAddress)")
gcloud storage buckets add-iam-policy-binding gs://${PROJECT_ID}-bucket \
    --member=serviceAccount:$SQL_SA --role=roles/storage.objectAdmin
for t in customers products orders order_items payments reviews; do
    echo "Importing $t ..."
    gcloud sql import csv cymbal-oltp gs://${PROJECT_ID}-bucket/seed/${t}.csv \
        --database=cymbal --table=cymbal.${t} --quiet
done
```

This takes a few minutes. While it runs, read the next section — but don't execute it yet.

### Prepare logical replication

Datastream reads Postgres' write-ahead log through a **publication** and a **replication slot**, as a dedicated replication user. Have a look at <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/replication_setup.sql">replication_setup.sql</walkthrough-editor-open-file>, then (once the import finished) run it:

```bash
PGPASSWORD="$DB_PASSWORD" psql -h localhost -p 5432 -U postgres -d cymbal \
    -v ds_password="$DS_PASSWORD" \
    -f content/agenticdata/src/datastream/replication_setup.sql
```

### Create the connection profiles

Two profiles: where the data comes from, and where it goes. Note the hostname — the PSC endpoint IP, because Datastream private connections do not resolve DNS:

```bash
gcloud datastream connection-profiles create cymbal-postgres-profile --location=$REGION \
    --type=postgresql --display-name=cymbal-postgres-profile \
    --postgresql-hostname=$ENDPOINT_IP --postgresql-port=5432 \
    --postgresql-username=datastream_user --postgresql-password="$DS_PASSWORD" \
    --postgresql-database=cymbal --private-connection=cymbal-psc
```

```bash
gcloud datastream connection-profiles create cymbal-bq-profile --location=$REGION \
    --type=bigquery --display-name=cymbal-bq-profile
```

### Let agy write the stream configuration

The stream itself is defined by two JSON files that ship with the repository — you work on them directly in `content/agenticdata/src/datastream/` (the shipped destination config still contains a placeholder). Writing API-correct configuration is authoring work — agy's job. In your agy session (started from `~/bootkon`), run:

```
/goal Rewrite content/agenticdata/src/datastream/source_config.json and content/agenticdata/src/datastream/destination_config.json for `gcloud datastream streams create`. The PostgreSQL source uses publication "cymbal_pub", replication slot "cymbal_slot", and should include all tables of the "cymbal" schema. The BigQuery destination writes every table into the single dataset "{{ PROJECT_ID }}:cymbal_bronze" with a data freshness of 0 seconds. Use the exact JSON field names of the Datastream v1 API (publication, replicationSlot, includeObjects/postgresqlSchemas, singleTargetDataset/datasetId, dataFreshness).
```

**Review what agy wrote**: open <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/source_config.json">source_config.json</walkthrough-editor-open-file> and <walkthrough-editor-open-file filePath="content/agenticdata/src/datastream/destination_config.json">destination_config.json</walkthrough-editor-open-file>. If agy went off-script, git has your back — restore the shipped files and fill in the placeholder yourself:

```bash
git -C ~/bootkon restore content/agenticdata/src/datastream/
sed -i "s/PROJECT_ID_PLACEHOLDER/$PROJECT_ID/" content/agenticdata/src/datastream/destination_config.json
```

### Start the stream

Create the bronze dataset, then the stream (with a full backfill of the seed data), then flip it to `RUNNING`:

```bash
bq mk --location=US --dataset ${PROJECT_ID}:cymbal_bronze
```

```bash
gcloud datastream streams create cymbal-cdc-stream --location=$REGION \
    --display-name=cymbal-cdc-stream \
    --source=cymbal-postgres-profile --postgresql-source-config=content/agenticdata/src/datastream/source_config.json \
    --destination=cymbal-bq-profile --bigquery-destination-config=content/agenticdata/src/datastream/destination_config.json \
    --backfill-all
```

```bash
gcloud datastream streams update cymbal-cdc-stream --location=$REGION \
    --state=RUNNING --update-mask=state
```

Datastream now validates everything (logical decoding, slot, publication, permissions, connectivity) and starts the backfill.

### Watch it flow

Open [Datastream](https://console.cloud.google.com/datastream/streams) and click <walkthrough-spotlight-pointer locator="text('cymbal-cdc-stream')">cymbal-cdc-stream</walkthrough-spotlight-pointer>. Explore the <walkthrough-spotlight-pointer locator="text('Objects')">Objects</walkthrough-spotlight-pointer> tab — you can watch the per-table backfill progress live. Within a couple of minutes the stream shows **Running** and the six `cymbal_*` tables appear.

Now make it *live*. Open a **third terminal tab**, and start the activity simulator — Cymbal's customers waking up:

```bash
. bk && source ~/.agenticdata.env
python3 content/agenticdata/src/datagen/simulate.py
```

Leave it running. Go to [BigQuery](https://console.cloud.google.com/bigquery), expand <walkthrough-spotlight-pointer locator="semantic({treeitem 'Toggle node {{ PROJECT_ID }}'} {button 'Toggle node'})">{{ PROJECT_ID }}</walkthrough-spotlight-pointer> → `cymbal_bronze`, and run this query a few times (use the editor, **not** table preview — preview lags behind CDC):

```sql
SELECT MAX(order_id) AS latest_order, COUNT(*) AS total_orders
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_orders`
```

Watch `latest_order` climb as the simulator inserts. Then prove UPDATEs work end-to-end — back in terminal 1:

```bash
PGPASSWORD="$DB_PASSWORD" psql -h localhost -p 5432 -U postgres -d cymbal \
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

**[TASK]** Take up to 10 minutes:

1. DELETE an order in psql (pick a high `order_id` from the simulator's output, remove its `order_items` and `payments` rows first) and confirm it disappears from `cymbal_bronze.cymbal_orders`.
2. Every bronze table has an extra `datastream_metadata` column — inspect it and ask agy what `source_timestamp` and `uuid` are for.
3. Ask agy: *"What is the difference between Datastream's merge and append-only modes for BigQuery, and when would I choose each?"*

### Success

🎉 Outstanding{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! You built a private, production-style CDC pipeline: a PSC-only Postgres instance, an identity-based tunnel, logical replication, and a running Datastream that mirrors every change into BigQuery in near real time. The bronze layer is alive — time to refine it. 🥉→🥈
