## Lab 10: Day-2 Ops — Dashboards, Alerts, and the 3 A.M. Page

<walkthrough-tutorial-duration duration="45"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="3"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>
<!-- Optional module: not wired into TUTORIAL.md. Renumber the "Lab N" title to match the event agenda when including. Not yet smoke-tested. -->

You built a pipeline. Tonight, at 3 a.m., it will break — and nobody will know until the Monday revenue meeting stares at Friday's numbers. In this lab you become Cymbal's on-call engineer: you build a **Cloud Monitoring dashboard as code** (authored by agy), create the **alert** Datastream doesn't ship, and then — deliberately — **break your own replication** with a chaos script you are not allowed to read first. You'll watch the incident unfold on your dashboard, diagnose it with agy as your read-only co-responder, fix it with one line of SQL, and prove that not a single row was lost.

This lab expects **Labs 1–3 to be complete**: `cymbal-cdc-stream` replicating into `cymbal_bronze`, and the medallion built. It also needs **terminal 2 (the `bk-tunnel` IAP tunnel) and terminal 3 (the simulator) still running** — an incident is only interesting while live traffic is flowing. If the simulator stopped, restart it from Lab 2's *Watch it flow* section before continuing.

(The commands below contain your generated database password, rendered into the tutorial. If you see empty quotes instead, run the `bk-start` reload step from the end of Lab 1.)

### About day-2 operations

Day 1 is building the pipeline; **day 2** is everything after: watching it, alerting on it, and fixing it at 3 a.m. Cloud Monitoring gives you the three pieces. **Metrics** are the numeric time series every managed service emits — Datastream reports how far it lags behind the source (**data freshness**, in seconds), Cloud SQL reports connections and CPU, BigQuery's Storage Write API reports ingested rows. **Dashboards** arrange those series into one pane of glass, and because a dashboard is just a JSON document deployed via API, it can live in git and be code-reviewed like everything else you built today. **Alerting policies** watch a metric against a condition and open an **incident** when it's violated — and here is today's teaching point: Datastream emits excellent metrics but ships **not a single alert out of the box**. If bronze freezes tonight, nobody's phone buzzes unless *you* make it so. That's this lab.

Learn more:
- [Monitor a Datastream stream](https://docs.cloud.google.com/datastream/docs/monitor-a-stream)
- [Dashboards via the API](https://docs.cloud.google.com/monitoring/dashboards/api-dashboard)
- [Alerting overview](https://docs.cloud.google.com/monitoring/alerts)

### Prepare the observability surface

First, bring terminal 1 back to the repo root — Lab 3 parked it in the Dataform folder, and every repository path in this lab (and each `agy` session you'll start) expects to run from `~/bootkon`:

```bash
cd ~/bootkon
```

Enable the two services (idempotent — on most projects they are already on) and grant yourself the Monitoring and Logging roles. Sandbox users are typically project owners already; the explicit grants keep this lab portable:

```bash
gcloud services enable monitoring.googleapis.com logging.googleapis.com
gcloud projects add-iam-policy-binding {{ PROJECT_ID }} \
    --member="user:{{ GCP_USERNAME }}" --role="roles/monitoring.editor" --condition=None >/dev/null
gcloud projects add-iam-policy-binding {{ PROJECT_ID }} \
    --member="user:{{ GCP_USERNAME }}" --role="roles/logging.viewer" --condition=None >/dev/null
```

Then a pre-flight check — this must print `RUNNING` (if not, revisit Lab 2 before injecting chaos into a stream that's already down):

```bash
gcloud datastream streams describe cymbal-cdc-stream --location={{ REGION }} --format='value(state)'
```

### Author the dashboard with agy

A dashboard definition is a config artifact — authoring work, so it goes to agy; you review, deploy, and verify. The full brief — which six charts, the exact metric types, the API shape — lives in <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/day2_ops/AGENTS.md">AGENTS.md</walkthrough-editor-open-file>, right next to the artifact. Read it: it pins the metric names character for character, because monitoring metric types are exactly the kind of detail an agent will confidently misremember.

The repository ships a finished dashboard as reference, so clear the stage first for the authentic experience:

```bash
rm content/agenticdata/src/optional/day2_ops/dashboard.json
```

Start `agy` from `~/bootkon` and hand over the brief:

```
/goal Read content/agenticdata/src/optional/day2_ops/AGENTS.md and create content/agenticdata/src/optional/day2_ops/dashboard.json exactly as it specifies: valid Cloud Monitoring Dashboard API JSON, six widgets in the given order, the exact metric types from the brief, and the 120-second threshold line on the freshness chart. No comments, no trailing commas.
```

**Review what agy wrote**: open <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/day2_ops/dashboard.json">dashboard.json</walkthrough-editor-open-file> and check the six `metric.type` strings against the brief's table. If agy went off-script, git has your back:

```bash
git -C ~/bootkon restore content/agenticdata/src/optional/day2_ops/dashboard.json
```

### Deploy and admire

Exit agy — deploying is operating, so it's your job, and it's one command:

```bash
gcloud monitoring dashboards create \
    --config-from-file=content/agenticdata/src/optional/day2_ops/dashboard.json
```

❗ If this fails with `INVALID_ARGUMENT` and a field path (e.g. an unknown field or a malformed filter string), that's agy's JSON, not your command — paste the full error into agy and let it repair the file, or restore the reference above and re-run.

Open [Monitoring → Dashboards](https://console.cloud.google.com/monitoring/dashboards) and click <walkthrough-spotlight-pointer locator="text('Cymbal Day-2 Ops')">Cymbal Day-2 Ops</walkthrough-spotlight-pointer>. Set the time range to **1 hour** and read your pipeline's vital signs, live:

- **Datastream — data freshness** hugs the bottom of the chart, safely under the red 120 s SLO line: Datastream is keeping up with the WAL.
- **Datastream — throughput** shows a steady trickle — your simulator commits a change every second or three, and each one becomes events here.
- **Cloud SQL — connections/CPU** are calm and boring. Boring is the goal.
- **BigQuery Storage Write API — ingested rows** is the destination-side echo of the same trickle. (This chart can lag a few minutes behind — metric ingestion has latency; remember that number, it matters later.)

One pane of glass, three services, and every line on it is explained by a system *you* built. Take ten seconds to feel good about this. Then let's talk about what's missing.

### The missing alert

A dashboard only works if someone is looking at it. At 3 a.m., nobody is — that's what **alerting policies** are for, and Datastream doesn't create any for you. The one that matters most for CDC is data freshness: *"page me when bronze is more than two minutes behind production."*

Datastream's console has a shortcut for exactly this:

1. Open [Datastream](https://console.cloud.google.com/datastream/streams) and click <walkthrough-spotlight-pointer locator="text('cymbal-cdc-stream')">cymbal-cdc-stream</walkthrough-spotlight-pointer>.
2. On the stream's page, scroll until the **Data freshness** graph appears (on the details view — or on the **Monitoring** tab, depending on console version) and click the **Create alerting policy** link next to it. It drops you into the Monitoring policy editor with the freshness metric preselected. (Link missing or moved? Same destination by hand: [Monitoring → Alerting](https://console.cloud.google.com/monitoring/alerting) → **Create policy** → select the metric **Datastream Stream → Stream freshness**.)
3. Configure the trigger: condition type **Threshold**, **Above threshold**, value `120` (the metric's unit is seconds — the same SLO line agy drew on your dashboard). Leave the rolling window at its default.
4. On the notifications step, **skip the notification channels** — email delivery is not part of today's game (and unverified on sandbox accounts). The [Alerting](https://console.cloud.google.com/monitoring/alerting) incidents list *is* your pager for this lab; you'll keep it open.
5. Name the policy `cymbal-freshness-slo` and create it.

A word on the threshold: freshness sits near 0 when the stream is healthy and the simulator writes continuously, so 120 s is far above any normal jitter — this alert cannot false-positive on you. It can only mean one thing: replication has stopped while the source keeps moving. (Production tip: pair a threshold alert with a **metric absence** condition on the same metric — a stream that stops *reporting* entirely should page too.) Time to arrange exactly that: replication stopped, while the source keeps moving.

### Break it

Time to earn the pager. The repository ships a chaos script. The rule of this exercise: **run it now, read it later** — real incidents don't send you their source code in advance. You have a dashboard; that's more than most on-calls get.

```bash
content/agenticdata/src/optional/day2_ops/chaos.sh
```

Note the timestamp it prints — your incident timeline starts there. The script will taunt you. It has earned the right.

### First signals

Go back to your **Cymbal Day-2 Ops** dashboard and watch the incident develop over the next couple of minutes (charts refresh on their own, or use the refresh button):

- **Data freshness** stops hugging zero and starts climbing — a straight, relentless ramp toward the red SLO line and past it.
- **Throughput** decays to zero. No events are arriving from the source.
- And the tell that makes this a *good* mystery: **Cloud SQL connections and CPU don't move.** Check terminal 3 — the simulator is still cheerfully inserting orders. Postgres is fine. Production is fine. Only the replica is freezing.

Now the producer's view: on the [Datastream](https://console.cloud.google.com/datastream/streams) page, open <walkthrough-spotlight-pointer locator="text('cymbal-cdc-stream')">cymbal-cdc-stream</walkthrough-spotlight-pointer> — the stream no longer looks healthy, and as the lockout persists its status flips from **Running** to **Failed**, with the stream's error details naming the reason.

What about your pager? Be honest about physics: metric ingestion plus alert evaluation means the incident appears on the [Alerting](https://console.cloud.google.com/monitoring/alerting) page **3–8 minutes after the chaos** — monitoring is fast, not instant. Don't sit there refreshing; the diagnosis below is designed to fill exactly that window. (When it fires, the incident shows up at the top of the Alerting page under **Incidents** — check back after the next section.)

### Diagnose with your co-responder

You know *that* it's broken. An on-call needs *why*. This is investigation, not authoring — so agy joins as a **read-only co-responder**: it proposes the commands, but every single one needs your approval before it runs. That's the incident-response pattern worth taking home: the human authorizes, the agent investigates. Back in terminal 1, start `agy` (from `~/bootkon`) and paste the symptom:

```
Our BigQuery bronze dataset stopped receiving new rows a few minutes ago, and data freshness on the Datastream stream cymbal-cdc-stream (location us-central1) keeps climbing. The source Postgres itself is healthy and still taking writes. Investigate the Datastream side with read-only commands only (gcloud datastream streams describe, gcloud logging read) and tell me your diagnosis. Ask me before each command, and do not change anything.
```

Approve each command as it comes and read the output together with agy. If agy meanders, these two are the heart of the matter — run them yourself:

```bash
gcloud datastream streams describe cymbal-cdc-stream --location={{ REGION }} \
    --format='yaml(state, errors)'
```

```bash
gcloud logging read 'resource.type="datastream.googleapis.com/Stream" severity>=WARNING' \
    --freshness=15m --limit=5 --format='yaml(timestamp, severity, jsonPayload)'
```

Somewhere in that output sits the confession, in classic Postgres phrasing: `role "datastream_user" is not permitted to log in`. The replication user — the identity Datastream has used since Lab 2 — can't connect. Production traffic (user `postgres`) was never touched; only the replication lane was closed.

Diagnosis in hand, you've earned the right to read the crime scene. Open <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/day2_ops/chaos.sh">chaos.sh</walkthrough-editor-open-file> — yes, *now* — and let agy narrate:

```
Read content/agenticdata/src/optional/day2_ops/chaos.sh and explain, statement by statement, how it broke replication -- and why the simulator kept writing happily the whole time.
```

Two statements: `ALTER ROLE datastream_user NOLOGIN` bars new connections, and `pg_terminate_backend` killed the existing one. Note what the script deliberately did *not* touch: the publication `cymbal_pub` and the slot `cymbal_slot`. Keep that in mind for the recovery — it's about to pay off.

### Fix it like it's 3:07 a.m.

Leave agy open — it witnessed the whole incident, and the challenge will put that memory to work. Open a **new terminal tab** (`+`) instead: the fix is one line, and — operating surface — you type it, through the tunnel, as the superuser:

```bash
PGPASSWORD="{{ BK_DB_PASSWORD }}" psql -h localhost -p 5432 -U postgres -d cymbal \
    -c "ALTER ROLE datastream_user LOGIN;"
```

❗ Don't panic when the stream doesn't recover the very second you run this — Datastream retries failed connections **with backoff**, so it may take a few minutes to notice the door is open again. Watch the [stream page](https://console.cloud.google.com/datastream/streams): the status returns to **Running** on its own — a `Failed` stream resumes automatically once the cause is fixed, no restart needed ([stream lifecycle](https://docs.cloud.google.com/datastream/docs/stream-states-and-actions)). On your dashboard, freshness tips over its peak and slides back toward zero.

Now the question that separates an outage from an annoyance: **did we lose data?** During the lockout the simulator kept writing — did those rows make it? Ask both ends of the pipe. The source:

```bash
PGPASSWORD="{{ BK_DB_PASSWORD }}" psql -h localhost -p 5432 -U postgres -d cymbal \
    -c "SELECT MAX(order_id) FROM cymbal.orders;"
```

And the replica, in [BigQuery](https://console.cloud.google.com/bigquery) (the editor, not table preview):

```sql
SELECT MAX(order_id) AS latest_order, COUNT(*) AS total_orders
FROM `{{ PROJECT_ID }}.cymbal_bronze.cymbal_orders`
```

Within a couple of minutes of the stream turning healthy, the two `MAX(order_id)` values match (give or take the row the simulator inserted while you were switching windows). Every order placed *during* the outage is present — nothing skipped, nothing replayed. This is the Lab 2 lesson cashing its cheque: the **replication slot** `cymbal_slot` kept retaining WAL while Datastream was locked out, and the moment the connection came back, Datastream resumed reading from exactly where it stopped. The outage delayed the data; it never lost it.

### Watch the incident close

One loose end: your pager. Back on [Monitoring → Alerting](https://console.cloud.google.com/monitoring/alerting), find the `cymbal-freshness-slo` incident that opened mid-chaos. You don't have to do anything — once freshness has been back under 120 s for the policy's window, Monitoring **resolves the incident automatically** (like the firing, this takes a few minutes after the metric recovers; the incident's timeline shows both edges). Open the incident and read it as your future 3 a.m. self: when it started, how long it lasted, which metric and threshold. Trust, but verify — and now, *monitor*.

### Challenge: run the incident review

**\[TASK\]** Take up to 10 minutes — pick at least one:

1. **The postmortem.** Every real incident ends with a blameless write-up, and yours had an unusually well-documented perpetrator. In the *same* agy session (it witnessed the whole thing), have agy write a blameless postmortem — summary, impact, timeline with your actual times, root cause, detection, resolution, action items — to `POSTMORTEM.md` in the lab's folder, overwriting the shipped example (prompt in the lab folder's own <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/day2_ops/prompts.md">prompts.md</walkthrough-editor-open-file>). Then compare against the reference with `git -C ~/bootkon diff content/agenticdata/src/optional/day2_ops/POSTMORTEM.md` — did agy catch that the dashboard beat the pager?
2. **Design your own chaos.** Propose the next drill to your table — but *discuss reversibility before anyone runs anything*. The safe list is short: today's script only flipped a role attribute. Dropping `cymbal_pub` or `cymbal_slot` is **off the table** — kill the slot and Datastream loses its position in the WAL; that's the `Failed permanently` state, and the road back is a re-backfill, not a one-liner. A genuinely reversible (and sneaky) one: `gcloud compute instances stop cymbal-jump --zone={{ REGION }}-a` — then explain why freshness now stays at *zero* while it's the *simulator* that dies. Which plane did you just break? (Afterwards: `start` the VM; `bk-tunnel` reconnects on its own, then restart the simulator in terminal 3.)
3. **Page on the logs, not just the lag.** The error log line you found above appeared minutes before the freshness alert fired. In [Logs Explorer](https://console.cloud.google.com/logs), query `resource.type="datastream.googleapis.com/Stream" severity>=ERROR`, then use **Create alert** to turn it into a [log-based alert](https://docs.cloud.google.com/logging/docs/alerting/log-based-alerts) — and discuss: when do you page on symptoms (freshness) versus causes (error logs)?

Note: If you are stuck and cannot figure out how to proceed after a few minutes, ask your team captain.

### Success

🎉 Phenomenal{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! You gave Cymbal's pipeline what every production system deserves: a dashboard someone can read at 3 a.m., the alert the platform didn't ship, and an on-call — you — who diagnosed a dead replica with an AI co-responder, fixed it with one line, and proved zero data loss. The pipeline broke, and it didn't matter. That's operations. 📟✅
