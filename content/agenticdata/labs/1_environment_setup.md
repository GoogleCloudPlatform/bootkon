## Lab 1: Environment Setup & Meet Your Co-Engineer

<walkthrough-tutorial-duration duration="20"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="1"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>

Welcome to Cymbal{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! By 17:00 you will have built a complete agentic data platform: a live operational database, change-data-capture into BigQuery, a governed bronze→silver→gold architecture, and two AI agents talking to each other over **A2A** — the open *agent-to-agent* protocol that lets AI agents call each other the way HTTP lets services do it. Don't worry if that's new to you: the finale lab explains and builds it step by step.

In this lab you will enable services, run the bootstrap that stages the seed data, take ownership of your already-provisioned production database, and meet **Antigravity CLI (`agy`)** — your co-engineer for the afternoon.

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

{% if ON_ARGOLIS %}
### Prepare your project (Argolis)

At an event, the organizers provision every project days ahead — on Argolis you are your own organizer, so run the prep yourself first. It enables the stream APIs, grants your roles, sets up the Datastream service agent and its private connection, creates the data-quality service account, and builds the network path and the Cloud SQL instance (idempotent, safe to re-run; expect 15–25 minutes):

```bash
content/agenticdata/bk-prep-project
```

❗ Argolis organization policies (for example `constraints/compute.requireOsLogin`, `constraints/compute.requireShieldedVm`, or SQL constraints) may block the VM or instance creation inside the prep. If it fails with a policy error, disable the constraint under IAM & Admin → Organization Policies and run the prep again.
{% endif %}

### Run the bootstrap

Execute the following script. It installs Python dependencies and the Dataform CLI (you'll meet it in Lab 3), generates Cymbal's synthetic order history and stages it in Cloud Storage, and pre-configures your AI co-engineer. (Everything project-bound — APIs, IAM roles, service accounts — {% if ON_ARGOLIS %}was covered by the prep step above{% else %}was already provisioned for your event project ahead of time; that's why the API step above was instantly green{% endif %}.) It runs for about three minutes — you can inspect <walkthrough-editor-open-file filePath="content/agenticdata/bk-bootstrap">bk-bootstrap</walkthrough-editor-open-file> while it works:

```bash
content/agenticdata/bk-bootstrap
```

Your database passwords were already generated during setup and live in `vars.local.sh` — the commands below use them as `$BK_DB_PASSWORD`, and **every terminal picks them up automatically**.

### The network path

Our database will have **no public IP**. Instead, Datastream will reach it through Private Service Connect (PSC) — and the network for that is already in your project{% if ON_ARGOLIS %} (created by the prep step above){% endif %}: the VPC `cymbal-vpc` with subnet `cymbal-subnet` (`10.10.0.0/24`), the address `10.10.0.5` — the PSC endpoint that **is** your database's door — the network attachment `cymbal-attachment` with Datastream's private connection `cymbal-psc` already plugged into it, and a tiny jump VM (`cymbal-jump`) you will meet in Lab 2. Take a look at [VPC networks](https://console.cloud.google.com/networking/networks/list) to see the pieces.

So what is this setup? **Private Service Connect** is Google Cloud's way of exposing a service across VPC boundaries without peering entire networks or using public IPs: the producer (here: your Cloud SQL instance) publishes a *service attachment*, and consumers plug an *endpoint* into it — traffic stays on Google's backbone, and each side only sees the single socket it was given. The **network attachment** is the reverse construct: it lets a Google-managed producer (Datastream) place a network interface *into* your VPC. You will connect both halves in Lab 2.

Learn more:
- [Private Service Connect](https://docs.cloud.google.com/vpc/docs/private-service-connect)
- [Network attachments](https://docs.cloud.google.com/vpc/docs/about-network-attachments)
- [Cloud SQL and Private Service Connect](https://docs.cloud.google.com/sql/docs/postgres/about-private-service-connect)

### Take ownership of your database

Cymbal's production order database is already running: `cymbal-oltp`, PostgreSQL on Cloud SQL — with **logical decoding** enabled at creation time (Postgres emits every committed change in logical form; the prerequisite for CDC, set at birth so the instance never needs a flag-change restart), **Private Service Connect** instead of a public IP (its endpoint is the `10.10.0.5` from above), and a deliberately small machine (`db-custom-1-3840`) — CDC reads the log, it does not stress the database.

It was provisioned with a throwaway root password, so make it yours — set the `postgres` password to your generated `$BK_DB_PASSWORD`:

```bash
gcloud sql users set-password postgres --instance=cymbal-oltp --password=$BK_DB_PASSWORD
```

Learn more:
- [Set up logical replication on Cloud SQL](https://docs.cloud.google.com/sql/docs/postgres/replication/configure-logical-replication)

### The seed data

Cymbal's order history was generated **inside your project** while the bootstrap ran — deterministic synthetic data, so every participant works with identical rows (including some deliberately broken ones you will meet again in Lab 3). Have a look at <walkthrough-editor-open-file filePath="content/agenticdata/src/datagen/generate.py">generate.py</walkthrough-editor-open-file> — note the *planted flaws* section at the top.

The bootstrap staged the six CSVs in Cloud Storage, where Lab 2's server-side import will pick them up. Verify they are there:

```bash
gcloud storage ls -l gs://{{ PROJECT_ID }}-bucket/seed/
```

Six files, about 111 MB in total — half a million orders plus the customers, products, order items, payments and reviews around them.

### Meet your co-engineer

`agy` (Antigravity CLI) is already installed in Cloud Shell, and `bk-bootstrap` pre-configured its basics (project, location, trusted workshop folders). One thing it cannot do for you is sign in — that is a one-time step you do now. **Maximize the terminal first** so the whole sign-in dialog fits on screen, then start agy from the repository root (you are already there):

```bash
agy
```

On the first run, agy asks how you want to sign in — choose the **Google Cloud project** option. agy will tell you your account has **no license for Gemini Enterprise** — that is expected, we don't use Gemini Enterprise today: if it asks for a project, enter your event project ID (it may already be pre-filled from the configuration):

```bash
{{ PROJECT_ID }}
```

If a login URL appears, open it with **Ctrl+Click** (Cmd+Click on a Mac), sign in as `{{ GCP_USERNAME }}`, and paste the confirmation code into the token field back in the terminal. Accept the Terms of Service if prompted. Every later `agy` start lands straight at the prompt — restore the terminal to its usual size once you are signed in.

The everyday commands agy needs today (file exploration, `dataform compile`, Python checks) are **pre-approved**, so authoring flows uninterrupted — but anything that would touch your cloud resources still asks you first. That split is deliberate: agy types, you review (with `/diff`), and the cloud stays your call.

### Let agy explain what just happened

Your first prompt. Paste this into agy:

```bash
What does content/agenticdata/bk-bootstrap do? Explain how the seed data generation stays deterministic and why identical data matters for this workshop.
```

Read the answer — this is the pattern for the whole afternoon: you stay in command, agy does the reading and writing, and you verify.

### Verify in the console

Let's look at your database. Open [Cloud SQL instances](https://console.cloud.google.com/sql/instances) and find <walkthrough-spotlight-pointer locator="text('cymbal-oltp')">cymbal-oltp</walkthrough-spotlight-pointer>: running, with **Private service connect** as its connectivity — and no public IP anywhere.

### Success

🎉 Congratulations{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! Your project has IAM sorted, Datastream already plugged into your VPC, a production database answering to **your** password, half a million synthetic orders staged in Cloud Storage, and an AI co-engineer standing by in your terminal. On to the data! 🚀
