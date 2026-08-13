## Lab 7: From Laptop to Schedule — the Medallion on Managed Dataform

<walkthrough-tutorial-duration duration="40"></walkthrough-tutorial-duration>
{{ author('Fabian Hirschmann', 'https://linkedin.com/in/fhirschmann') }}
<walkthrough-tutorial-difficulty difficulty="2"></walkthrough-tutorial-difficulty>
<bootkon-cloud-shell-note/>
<!-- Optional module: not wired into TUTORIAL.md. Not yet smoke-tested.
     When including: renumber the "Lab N" title to match the event agenda, merge
     src/optional/managed_dataform/prompts.md into src/prompts.md, and add the
     40 min to the README agenda table. Placement: slot this module AFTER Lab 4
     (governance) — once the 15-minute schedule is live, every rebuild removes
     console-attached column metadata such as Lab 4's hand-attached policy tags. -->

Lab 3 ended with a promise: *"In production you would run the same project on a schedule in managed Dataform."* This lab cashes it. You push the exact project agy wrote — not a rewrite, the very same SQLX files — into a **managed Dataform repository**, walk its interactive dependency graph, and put it on a 15-minute schedule that runs as a service account instead of you. When you leave this lab, the medallion refreshes itself.

Before you start: this lab assumes **Labs 1–3 are complete** — the Dataform project in `content/agenticdata/src/dataform` compiles and has been run at least once — and that **terminal 2 (the IAP tunnel) and terminal 3 (the data simulator)** from Lab 2 are still running. The simulator matters here: live writes are what make a schedule worth having.

### About managed Dataform

Managed Dataform is the hosted side of the tool you used in Lab 3 — same Dataform core, same SQLX, same `workflow_settings.yaml`, but Google runs it. A **repository** is a Google-hosted git repository (or a connected external one); **development workspaces** are personal editing branches with the compile loop built into the browser; a **release configuration** compiles the code from a git branch into an immutable **compilation result**; and a **workflow configuration** executes compilation results on a cron schedule, as a service account. The division of labor for Cymbal: the CLI stays the developer loop where agy authors and you review, and managed Dataform becomes the *operator* — because a production pipeline should not depend on anyone's laptop, terminal, or working hours.

Learn more:
- [Create a Dataform repository](https://docs.cloud.google.com/dataform/docs/create-repository)
- [Release configurations](https://docs.cloud.google.com/dataform/docs/release-configurations)
- [Workflow configurations](https://docs.cloud.google.com/dataform/docs/workflow-configurations)
- [The Dataform REST API](https://docs.cloud.google.com/dataform/reference/rest)

### Set up the execution identity

Who runs the pipeline at 3 a.m.? Not you — and that is the whole point of this section. Scheduled Dataform executions involve two identities: the Google-managed **Dataform service agent** (it compiles your code and orchestrates runs), and a **custom service account** that the actual BigQuery jobs run as — every repository must have one; the console won't even offer the service agent for that job. You already own a perfect candidate: `dataquality-service-account` from Lab 1's bootstrap, which holds BigQuery read and job roles. It only lacks write access.

IAM comes *first* in this lab for the same reason the Datastream service agent came first in `bk-bootstrap`: grants take a few minutes to propagate, and doing them now means they're live by the time you execute. Enable the service and materialize the service agent:

```bash
gcloud services enable dataform.googleapis.com
gcloud beta services identity create --service=dataform.googleapis.com --project={{ PROJECT_ID }}
```

Let yourself administer Dataform (sandbox owners have this implicitly; the explicit grant keeps the lab portable):

```bash
gcloud projects add-iam-policy-binding {{ PROJECT_ID }} \
    --member=user:{{ GCP_USERNAME }} --role=roles/dataform.admin --condition=None
```

Upgrade the execution account from reader to writer — it will be rebuilding silver and gold:

```bash
gcloud projects add-iam-policy-binding {{ PROJECT_ID }} \
    --member=serviceAccount:dataquality-service-account@{{ PROJECT_ID }}.iam.gserviceaccount.com \
    --role=roles/bigquery.dataEditor --condition=None
```

And let the Dataform service agent *act as* that account — it executes your workflows by minting short-lived tokens for it:

```bash
for role in roles/iam.serviceAccountTokenCreator roles/iam.serviceAccountUser; do
    gcloud iam service-accounts add-iam-policy-binding \
        dataquality-service-account@{{ PROJECT_ID }}.iam.gserviceaccount.com \
        --member=serviceAccount:service-{{ PROJECT_NUMBER }}@gcp-sa-dataform.iam.gserviceaccount.com \
        --role=$role
done
```

That impersonation chain — service agent → token → execution account → BigQuery job — is exactly how your pipeline will run without your credentials anywhere in the loop. ([Control access with IAM](https://docs.cloud.google.com/dataform/docs/access-control))

### Create the repository

Now give the project a home. Open [Dataform](https://console.cloud.google.com/bigquery/dataform) in the console (it lives inside BigQuery) and click <walkthrough-spotlight-pointer locator="semantic({button 'Create repository'})">Create repository</walkthrough-spotlight-pointer>:

1. Repository ID: `cymbal-dataform`
2. Region: `{{ REGION }}`
3. Service account: select `dataquality-service-account@{{ PROJECT_ID }}.iam.gserviceaccount.com` — note that the default Dataform service agent is not on offer: a repository *must* execute as a custom service account, which is precisely the identity separation you just wired up.
4. Leave the remaining defaults and click **Create**.

### Create a development workspace

Open <walkthrough-spotlight-pointer locator="text('cymbal-dataform')">cymbal-dataform</walkthrough-spotlight-pointer> and click <walkthrough-spotlight-pointer locator="semantic({button 'Create development workspace'})">Create development workspace</walkthrough-spotlight-pointer>. Workspace ID: `cymbal-dev`, then **Create**.

Open the workspace — it's empty and offers to initialize itself with boilerplate. **Don't click Initialize workspace**: your project already exists, agy wrote it in Lab 3, and it arrives through the API in a minute.

### Push the project through the API

Here is a fact worth a coffee-break story: managed Dataform has **no gcloud commands**. The CLI from Lab 3 compiles and runs projects but cannot manage repositories — those have exactly two surfaces: the console and the REST API. Every button you clicked above is a REST call underneath. So we upload the Lab 3 project the way any CI system would: with the API. The repository ships a script for it — run it (takes a few seconds):

```bash
cd ~/bootkon
content/agenticdata/src/optional/managed_dataform/push_to_dataform.sh
```

(It defaults to `cymbal-dataform` / `cymbal-dev`; if you named things differently, pass your names as two arguments.)

You should see one `writeFile` line per project file, a `commit`, and a `push`. Now read what you just ran — open <walkthrough-editor-open-file filePath="content/agenticdata/src/optional/managed_dataform/push_to_dataform.sh">push_to_dataform.sh</walkthrough-editor-open-file>. It is a crash course in the Dataform API, six calls end to end:

1. `GET` the workspace — fail fast if it doesn't exist.
2. `:makeDirectory` — recreate the folder tree.
3. `:writeFile` — one call per file, contents base64-encoded (JSON can't carry raw bytes).
4. `:commit` — one git commit inside the workspace, author and message included.
5. `:push` — the workspace branch onto the repository's default branch, `main`.
6. `:installNpmPackages` — best effort, and usually a no-op here: with Dataform core 3, `workflow_settings.yaml` replaces `package.json`, so there is nothing to install until a project adds dependency packages.

Two details deserve your attention. `gcloud auth print-access-token` turns your logged-in identity into the bearer token every call carries — the same token gcloud uses internally. And the script deliberately does **not** upload `.df-credentials.json`: that file points the *CLI* at your local credentials, managed Dataform brings its own identity, and credentials never belong in a repository. Trust, but verify: refresh the `cymbal-dev` workspace in the console — `workflow_settings.yaml` and agy's `definitions/` are all there, already committed and pushed.

### Admire the compiled graph

The workspace compiles your project automatically. Click the <walkthrough-spotlight-pointer locator="semantic({tab 'Compiled graph'})">Compiled graph</walkthrough-spotlight-pointer> tab: there it is — the medallion as an interactive DAG. Six bronze declarations on the left, five silver staging models, three gold marts, and every assertion agy wrote (the reference solution compiles to 26 nodes, 12 of them assertions; agy's count varies). This graph is what the `${ref(...)}` calls in agy's SQLX have been encoding all along — in Lab 3 you saw it as lineage *after* running; here you see it *before*, computed from code alone.

❗ If the tab shows a compilation error mentioning `Failed to resolve workflow_settings.yaml` or missing packages, open `workflow_settings.yaml` inside the workspace and click **Install packages** — then the graph appears.

Click `fct_daily_revenue`: the metadata pane lists its dependencies and dependents, and the query pane shows the compiled SQL with every `${ref(...)}` resolved to a real table name. Try filtering the graph by tag `gold`.

### Compile a release

A workspace is for humans; production runs from git. A **release configuration** tells Dataform which branch to compile and how. On the repository page, open the <walkthrough-spotlight-pointer locator="semantic({tab 'Releases & scheduling'})">Releases & scheduling</walkthrough-spotlight-pointer> tab, and under <walkthrough-spotlight-pointer locator="text('Release configurations')">Release configurations</walkthrough-spotlight-pointer> click **Create**:

1. Release ID: `cymbal-release`
2. Git commitish: `main` (the default — exactly where your push landed)
3. Leave the frequency and the compilation overrides empty: your `workflow_settings.yaml` already carries project and datasets, and today you compile by hand.

Create it, open <walkthrough-spotlight-pointer locator="text('cymbal-release')">cymbal-release</walkthrough-spotlight-pointer>, and click <walkthrough-spotlight-pointer locator="semantic({button 'New compilation'})">New compilation</walkthrough-spotlight-pointer>. After a few seconds a **compilation result** appears in the Manual/API compilation results table.

So what did you just build? A compilation result is a frozen snapshot of your *SQL* — the code as it stood on `main` at that moment. The *data* is not frozen: re-executing the same result re-runs that SQL against whatever is in bronze then. New data needs no new compilation; only new code does. In production you'd give the release configuration a schedule (say, daily) so merged changes compile themselves.

### Put it on a schedule

Now the piece that replaces your keyboard: under <walkthrough-spotlight-pointer locator="text('Workflow configurations')">Workflow configurations</walkthrough-spotlight-pointer> click **Create**:

1. Configuration ID: `cymbal-15min`
2. Release configuration: `cymbal-release`
3. Authentication: **Execute with selected service account** — pick `dataquality-service-account` if it isn't already preselected from the repository.
4. Schedule frequency: `*/15 * * * *` — every quarter-hour (leave the timezone at UTC; quarter-hours are quarter-hours everywhere).
5. Under workflow actions, choose **Selection of tags** and pick `silver` and `gold` — the same slices you ran by hand in Lab 3, assertions included.
6. Click **Create**.

❗ The schedule fires at the next quarter-hour boundary — which may well land after this lab ends. Don't wait for it; the next section triggers the run right now, and the ticks keep coming all event long either way.

While the clock runs, ask your co-engineer to cement the concept. In your agy session (terminal 1):

```bash
Explain the managed Dataform model like I run data platforms for a living: what exactly is frozen in a compilation result, why does re-executing the same compilation result still pick up new bronze rows, and when would I schedule release compilations more often than daily?
```

### Trigger the first run

The scheduler is armed, but a demo shouldn't wait for a clock. Exit agy with `/quit`, then trigger the workflow configuration yourself — with the *same API call the scheduler makes* at :00, :15, :30 and :45:

```bash
curl -s -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json" \
    -d '{"workflowConfig": "projects/{{ PROJECT_ID }}/locations/{{ REGION }}/repositories/cymbal-dataform/workflowConfigs/cymbal-15min"}' \
    https://dataform.googleapis.com/v1/projects/{{ PROJECT_ID }}/locations/{{ REGION }}/repositories/cymbal-dataform/workflowInvocations
```

The response is a **workflow invocation** in state `RUNNING` — your pipeline, executing, with your terminal completely uninvolved from here on.

❗ If the call (or the invocation itself) fails immediately with `PERMISSION_DENIED` and the message mentions the service account or the Dataform service agent, IAM propagation from the first section is still in flight — the same 3–4 minute lesson as the Datastream agent in Lab 2. Wait a few minutes and run the command again.

### Watch gold refresh itself

Back on the repository page, open the <walkthrough-spotlight-pointer locator="semantic({tab 'Workflow execution logs'})">Workflow execution logs</walkthrough-spotlight-pointer> tab. Your invocation is there — **Running**, then **Succeeded** after a minute or two at seed-data scale. Click it: every model and every assertion is listed with its own status and timing. This page is where an operator lives; nobody watches a terminal at 3 a.m.

Trust, but verify the identity too: open [BigQuery](https://console.cloud.google.com/bigquery), click **Job history** at the bottom, and switch to the **Project history** tab — the jobs from this run were executed by `dataquality-service-account`, not by you.

Now the payoff. Run this in the BigQuery editor:

```sql
SELECT order_date, currency, orders, gross_revenue
FROM `{{ PROJECT_ID }}.cymbal_gold.fct_daily_revenue`
ORDER BY order_date DESC, currency
LIMIT 8
```

The top rows are *today* — and the numbers are already bigger than anything your Lab 3 run could have seen: the simulator has been writing orders all along, Datastream mirrored them into bronze, and the execution you just triggered folded them into gold. Re-run the query after the next quarter-hour tick (check the execution logs for the scheduled entry) and watch today's `orders` climb — no terminal, no `dataform run`, no you.

### Success

🎉 Magnificent{% if MY_NAME %}, {{ MY_NAME }}{% endif %}! The medallion left your laptop: agy's project now lives in a hosted repository, compiles from `main` on demand, and rebuilds itself every 15 minutes as a service account — while you read execution logs like an operator instead of running jobs like a machine. Wherever the afternoon goes next, gold will be fresher than you left it. ⏰
