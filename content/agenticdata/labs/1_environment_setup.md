## Lab 1: Environment Setup & Meet Your Co-Engineer

<walkthrough-tutorial-duration duration="25"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="1"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

Welcome to Cymbal{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! By 17:00 you will have built a complete agentic data platform: a live operational database, change-data-capture into BigQuery, a governed bronze→silver→gold architecture, and two AI agents talking to each other over the A2A protocol.

In this lab you will enable services, kick off the two slow infrastructure builds (they run in the background while you work), stage the seed data, and install **Antigravity CLI (`agy`)** — your co-engineer for the afternoon.

> One rule for today: **you** run the infrastructure commands, **agy** writes code and configs, and the **console** is where you verify what happened.

### Enable services

<walkthrough-enable-apis apis=
  "sqladmin.googleapis.com,
  datastream.googleapis.com,
  compute.googleapis.com,
  servicenetworking.googleapis.com,
  iap.googleapis.com,
  bigquery.googleapis.com,
  bigqueryconnection.googleapis.com,
  dataplex.googleapis.com,
  datacatalog.googleapis.com,
  datalineage.googleapis.com,
  dlp.googleapis.com,
  geminidataanalytics.googleapis.com,
  cloudaicompanion.googleapis.com,
  aiplatform.googleapis.com,
  storage-component.googleapis.com,
  serviceusage.googleapis.com,
  cloudresourcemanager.googleapis.com,
  iam.googleapis.com,
  artifactregistry.googleapis.com">
</walkthrough-enable-apis>

### Assign permissions

Execute the following script. It installs Python dependencies, grants IAM roles, creates a service account for data-quality scans, and generates the database passwords for your project. You can inspect <walkthrough-editor-open-file filePath="content/agenticdata/bk-bootstrap">bk-bootstrap</walkthrough-editor-open-file> while it runs:

```bash
content/agenticdata/bk-bootstrap
```

The script appended your stream configuration (instance name, generated passwords, agent settings) to `~/.bashrc`, so **every new terminal picks it up automatically**. Load it into this already-open one:

```bash
source ~/.bashrc
```

### Create the network path

Our database will have **no public IP**. Instead, Datastream will reach it through Private Service Connect (PSC). First, create a VPC and a subnet:

```bash
gcloud compute networks create cymbal-vpc --subnet-mode=custom
```

```bash
gcloud compute networks subnets create cymbal-subnet \
    --network=cymbal-vpc --region=$REGION --range=10.10.0.0/24
```

Datastream connects into your VPC through a **network attachment** — the entry door for its PSC interface:

```bash
gcloud compute network-attachments create cymbal-attachment --region=$REGION \
    --connection-preference=ACCEPT_AUTOMATIC --subnets=cymbal-subnet
```

Note: `ACCEPT_AUTOMATIC` keeps this workshop simple. In production you would use `ACCEPT_MANUAL` with a `--producer-accept-list`, discovering the Datastream tenant project via `gcloud datastream private-connections create --validate-only`.

### Launch your operational database

This is Cymbal's production order database: PostgreSQL on Cloud SQL, with logical decoding enabled at creation time (Datastream needs it for CDC) and Private Service Connect instead of a public IP. The `--async` flag returns immediately — the instance builds in the background for the next 10–15 minutes while you continue:

{% if ON_ARGOLIS %}
❗ You are on Argolis. Instance and VM creation in this stream may be blocked by organization policies (for example `constraints/compute.requireOsLogin` or `constraints/compute.requireShieldedVm`). If a create command fails with a policy error, disable the constraint under IAM & Admin → Organization Policies and retry.
{% endif %}

```bash
gcloud sql instances create cymbal-oltp \
    --database-version=POSTGRES_15 --edition=enterprise \
    --tier=db-custom-1-3840 --storage-size=10GB \
    --region=$REGION \
    --root-password=$BK_DB_PASSWORD \
    --database-flags=cloudsql.logical_decoding=on \
    --enable-private-service-connect \
    --allowed-psc-projects=$PROJECT_ID \
    --no-assign-ip \
    --async
```

### Kick off Datastream private connectivity

Datastream's private connection also takes a few minutes to build, so start it now too. **This command blocks until it finishes** — leave it running and continue with the next section in a **new terminal tab** (the `+` button in the terminal panel). Remember to run `. bk` in the new terminal.

```bash
gcloud datastream private-connections create cymbal-psc --location=$REGION \
    --display-name=cymbal-psc \
    --network-attachment=projects/$PROJECT_ID/regions/$REGION/networkAttachments/cymbal-attachment
```

### Stage the seed data

Cymbal's order history is generated **inside your project** — deterministic synthetic data, so every participant works with identical rows (including some deliberately broken ones you will meet again in Lab 3). Create a bucket and generate the data:

```bash
gcloud storage buckets create gs://${PROJECT_ID}-bucket --location=$REGION
```

```bash
python3 content/agenticdata/src/datagen/generate.py --out ~/seed_data
```

While it runs (about a minute), have a look at <walkthrough-editor-open-file filePath="content/agenticdata/src/datagen/generate.py">generate.py</walkthrough-editor-open-file> — note the *planted flaws* section at the top. Then upload the CSVs:

```bash
gcloud storage cp ~/seed_data/*.csv gs://${PROJECT_ID}-bucket/seed/
```

### Install Antigravity CLI

Time to meet your co-engineer. Install `agy`:

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

The installer prints an `export PATH=...` line — run it (or open a fresh terminal). Then start agy from the repository root:

```bash
cd ~/bootkon && agy
```

To sign in:
1. Select **Use a Google Cloud project**.
2. Follow the authentication link, copy the code back into the terminal.
3. When asked for a project, use `{{ PROJECT_ID }}` and set the location to `global`.
4. Accept the Terms of Service and pick a color scheme you like.

### Let agy explain what just happened

Your first prompt. Paste this into agy:

```
What does content/agenticdata/bk-bootstrap do? Summarize the IAM roles it grants and explain why a separate data-quality service account is created.
```

Read the answer — this is the pattern for the whole afternoon: you stay in command, agy does the reading and writing, and you verify.

### Verify in the console

Let's check on your database build. Open [Cloud SQL instances](https://console.cloud.google.com/sql/instances) and find <walkthrough-spotlight-pointer locator="text('cymbal-oltp')">cymbal-oltp</walkthrough-spotlight-pointer>. You should see it being created (a spinner) or already running with **Private service connect** as its connectivity — and no public IP anywhere. If it is still creating, perfect: that's exactly why we started it first.

### Success

🎉 Congratulations{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! Your project has IAM sorted, a VPC with a door for Datastream, a database building itself in the background, half a million synthetic orders staged in Cloud Storage, and an AI co-engineer standing by in your terminal. On to the data! 🚀
