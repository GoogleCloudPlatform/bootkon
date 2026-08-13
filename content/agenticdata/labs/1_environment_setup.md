## Lab 1: Environment Setup & Meet Your Co-Engineer

<walkthrough-tutorial-duration duration="20"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="1"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

Welcome to Cymbal{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! By 17:00 you will have built a complete agentic data platform: a live operational database, change-data-capture into BigQuery, a governed bronze→silver→gold architecture, and two AI agents talking to each other over **A2A** — the open *agent-to-agent* protocol that lets AI agents call each other the way HTTP lets services do it. Don't worry if that's new to you: the finale lab explains and builds it step by step.

In this lab you will enable services, run the bootstrap that preps your project and stages the seed data, kick off the two slow infrastructure builds (they run in the background while you work), and meet **Antigravity CLI (`agy`)** — your co-engineer for the afternoon.

One rule for today: **you** run the infrastructure commands, **agy** writes code and configs, and the **console** is where you verify what happened.

Along the way you will spot **Prefer the console?** notes: optional UI routes for when you'd rather click than type — the one licensed exception to the rule above. Each replaces the command right above it, so take one route or the other; both roads lead to Cymbal.

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

Execute the following script. It installs Python dependencies, grants IAM roles, creates a service account for data-quality scans, generates Cymbal's synthetic order history and stages it in Cloud Storage, and pre-configures your AI co-engineer. It runs for about four minutes — you can inspect <walkthrough-editor-open-file filePath="content/agenticdata/bk-bootstrap">bk-bootstrap</walkthrough-editor-open-file> while it works:

```bash
content/agenticdata/bk-bootstrap
```

Your database passwords were already generated during setup and live in `vars.local.sh` — the commands below use them as `$BK_DB_PASSWORD`, and **every terminal picks them up automatically**.

### Create the network path

Our database will have **no public IP**. Instead, Datastream will reach it through Private Service Connect (PSC). First, create a VPC and a subnet:

```bash
gcloud compute networks create cymbal-vpc --subnet-mode=custom
```

```bash
gcloud compute networks subnets create cymbal-subnet \
    --network=cymbal-vpc --region={{ REGION }} --range=10.10.0.0/24
```

Datastream connects into your VPC through a **network attachment** — the entry door for its PSC interface:

```bash
gcloud compute network-attachments create cymbal-attachment --region={{ REGION }} \
    --connection-preference=ACCEPT_AUTOMATIC --subnets=cymbal-subnet
```

Note: `ACCEPT_AUTOMATIC` keeps this workshop simple. In production you would use `ACCEPT_MANUAL` with a `--producer-accept-list`, discovering the Datastream tenant project via `gcloud datastream private-connections create --validate-only`.

So what did you just build? **Private Service Connect** is Google Cloud's way of exposing a service across VPC boundaries without peering entire networks or using public IPs: the producer (here: your Cloud SQL instance) publishes a *service attachment*, and consumers plug an *endpoint* into it — traffic stays on Google's backbone, and each side only sees the single socket it was given. The **network attachment** you created is the reverse construct: it lets a Google-managed producer (Datastream) place a network interface *into* your VPC. You will connect both halves in Lab 2.

Learn more:
- [Private Service Connect](https://docs.cloud.google.com/vpc/docs/private-service-connect)
- [Network attachments](https://docs.cloud.google.com/vpc/docs/about-network-attachments)
- [Cloud SQL and Private Service Connect](https://docs.cloud.google.com/sql/docs/postgres/about-private-service-connect)

### Launch your operational database

This is Cymbal's production order database: PostgreSQL on Cloud SQL, with logical decoding enabled at creation time (Datastream needs it for CDC) and Private Service Connect instead of a public IP. The `--async` flag returns immediately — the instance builds in the background for the next 10–15 minutes while you continue:

{% if ON_ARGOLIS %}
❗ You are on Argolis. Instance and VM creation in this stream may be blocked by organization policies (for example `constraints/compute.requireOsLogin` or `constraints/compute.requireShieldedVm`). If a create command fails with a policy error, disable the constraint under IAM & Admin → Organization Policies and retry.
{% endif %}

```bash
gcloud sql instances create cymbal-oltp \
    --database-version=POSTGRES_15 --edition=enterprise \
    --tier=db-custom-1-3840 --storage-size=10GB \
    --region={{ REGION }} \
    --root-password=$BK_DB_PASSWORD \
    --database-flags=cloudsql.logical_decoding=on \
    --enable-private-service-connect \
    --allowed-psc-projects={{ PROJECT_ID }} \
    --no-assign-ip \
    --async
```

A word on the flags: `cloudsql.logical_decoding=on` switches Postgres' write-ahead log to *logical* decoding — the prerequisite for change data capture — set at creation time so the instance boots with it and never needs a flag-change restart. `--no-assign-ip` means there is no public address at all; the remaining flags wire the instance to the private path you prepared above. And `db-custom-1-3840` is a deliberately small machine: CDC reads the log, it does not stress the database.

Learn more:
- [Set up logical replication on Cloud SQL](https://docs.cloud.google.com/sql/docs/postgres/replication/configure-logical-replication)

### Kick off Datastream private connectivity

Datastream's private connection takes around 5–10 minutes to build, so kick it off now too. The command returns right away and the build continues in the background — Lab 2 verifies it reached the `CREATED` state:

```bash
gcloud datastream private-connections create cymbal-psc --location={{ REGION }} \
    --display-name=cymbal-psc \
    --network-attachment=projects/{{ PROJECT_ID }}/regions/{{ REGION }}/networkAttachments/cymbal-attachment
```

**Prefer the console?** The same thing, clickable: open [Datastream → Private connectivity configurations](https://console.cloud.google.com/datastream/private-connections) → **Create configuration**: name `cymbal-psc`, region `{{ REGION }}`, private connectivity method **PSC interfaces**, project left on `{{ PROJECT_ID }}`, network attachment `cymbal-attachment`. If the wizard offers an **Update allowlist** step, click it (a formality with our auto-accept attachment), then **Create**. And if the wizard balks at anything, the gcloud command above is the sure path.

### The seed data

Cymbal's order history was generated **inside your project** while the bootstrap ran — deterministic synthetic data, so every participant works with identical rows (including some deliberately broken ones you will meet again in Lab 3). Have a look at <walkthrough-editor-open-file filePath="content/agenticdata/src/datagen/generate.py">generate.py</walkthrough-editor-open-file> — note the *planted flaws* section at the top.

The bootstrap staged the six CSVs in Cloud Storage, where Lab 2's server-side import will pick them up. Verify they are there:

```bash
gcloud storage ls -l gs://{{ PROJECT_ID }}-bucket/seed/
```

Six files, about 111 MB in total — half a million orders plus the customers, products, order items, payments and reviews around them.

### Meet your co-engineer

`agy` (Antigravity CLI) is already installed in Cloud Shell, and `bk-bootstrap` pre-configured its basics (theme, trusted workshop folders). One thing it cannot do for you is sign in — agy authenticates with your **Google account**, not with your Cloud Shell credentials. Start it from the repository root (you are already there):

```bash
agy
```

On the first run, agy asks how you want to sign in — choose the **Google Cloud project** option: agy then authenticates through your event project (`{{ PROJECT_ID }}`, read from the environment), which is where today's usage belongs. If a login URL appears, open it with **Ctrl+Click** (Cmd+Click on a Mac) and sign in as `{{ GCP_USERNAME }}`. Back in the terminal, move down to the token field with **Shift+Down-Arrow** and paste the confirmation code there. Accept the Terms of Service if prompted. This is a one-time step: every later `agy` start lands straight at the prompt.

agy **asks before it acts** — approve its file edits as they come, and anything that would touch your cloud resources stays your call. Reviewing what agy did (with `/diff`) is your job too.

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
