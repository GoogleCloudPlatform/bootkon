# Agenticdata provisioning (organizer tooling)

Everything **project-bound** — APIs, IAM, service accounts, the network path,
Datastream's private connection and BigQuery connection profile, the jump VM,
the PSC endpoint, the Cloud SQL instance, the seed bucket and the bronze
dataset — is provisioned here, ahead of the event. Participants never
wait on a build or an IAM propagation race; their Lab 1 starts on a project
where the infrastructure already exists. Participant-side setup (pip, seed
data, agy, per-user secrets) stays in `../bk-bootstrap` and `bk-init`.

## Quick start

Prep the whole fleet from your laptop (one Cloud Build **per participant
project**; nothing runs locally, the terminal returns after submitting):

```bash
./bk-prep-fleet --cloud-build "Bootkon Accounts - Sheet1.csv" "bootkon-event-"
```

Watch progress / check readiness any time (read-only, repeat freely). The
prefix is optional here — without it the projects are looked up by the
username's number:

```bash
./bk-verify-fleet "Bootkon Accounts - Sheet1.csv"
```

Single account (testing) — pass a username instead of the CSV:

```bash
./bk-prep-fleet --cloud-build devstar1234@gcplab.me "bootkon-event-"
./bk-verify-fleet devstar1234@gcplab.me
```

Reset a **test** project between runs:

```bash
./bk-prep-project --destroy devstar1234@gcplab.me bootkon-event-1234
```

The CSV needs the username in the first column (header row is skipped);
`project = PREFIX + numeric suffix of the username`. Both `bk-prep-fleet` and
`bk-verify-fleet` take the prefix optionally and otherwise look the projects up
by that number; `bk-prep-project` takes the full project id (project/username in
either order — the `@` disambiguates).

## The pieces

| File | Role |
|---|---|
| `bk-prep-fleet` | Fan-out over the CSV (or one username). `--cloud-build`: one build per project, submit-and-return. Without the flag: runs the preps locally via xargs (`BK_PREP_PARALLEL`, default 8). |
| `bk-prep-project` | The engine — everything below happens in here, identically on your laptop, in Cloud Shell and inside Cloud Build. |
| `bk-verify-fleet` | Read-only readiness check, ~26 checks per project (prefix optional). Green one-liner when ready; yellow with the pending components while a prep is still running; red with an ok/missing split otherwise. Exit code = fleet readiness. |
| `cloudbuild.yaml` | Wraps `bk-prep-project` for Cloud Build. `$PROJECT_ID` is the built-in substitution, so every build preps the project it runs in. |
| `terraform/` | The desired state (APIs, IAM, service accounts, network, private connection, jump VM, SQL, PSC endpoint). |
| `ensure-terraform` | Sourced helper: single Terraform version pin, self-installs into `~/.local/bin` when missing (Cloud Shell does not preinstall Terraform). |
| `bk-init` | NOT organizer-run: the stream hook `. bk` executes at participant setup (secrets, runtime config, background wake of the parked SQL instance). |

## How it works

- **State per project, no central anything.** Each project gets
  `gs://<project>-tfstate` inside itself; the state dies with the sandbox.
  There is no organizer project.
- **Identity.** Pass 1 of `bk-prep-fleet` creates a `bootkon-provisioner`
  service account with `roles/owner` in each project; the builds run as that
  SA. The caller additionally gets project-level `serviceAccountUser`
  (required to submit builds as a custom SA). Two passes on purpose: the
  grants age while the rest of the loop runs.
- **Cloud SQL is parked.** The instance is built running (the API refuses to
  create it stopped), then parked (`activation_policy NEVER`, storage-only
  cost ~$0.06/day). The participant's `. bk` wakes it in the background;
  Lab 1 carries a visible backup start. Prep days ahead is therefore cheap —
  the only meaningful cost starts when participants wake their instances
  (~$1.70/day each).
- **Self-healing, rerun-safe.** Re-running preps only what is missing.
  On top of the idempotent applies: pre-existing same-named resources (e.g.
  from older manual runs) are **adopted** into the state via `terraform
  import` and converged; a `FAILED` Datastream private connection (the IAM
  propagation race that survives even the built-in 180s buffer) is deleted
  and re-applied once; **stale** state locks (dead runs, killed builds) are
  broken automatically after 60 minutes — while a lock younger than that
  means a prep is genuinely running, and the second run backs off instead of
  interfering (`bk-prep-fleet` also skips projects with an active build).
- **Version pins.** Terraform in `ensure-terraform` (one pin for all
  runners — mixed versions would make the state unreadable to older CLIs),
  providers in `terraform/versions.tf`.

## Timing and requirements

- A prep takes **15–25 minutes per project** (SQL build and private
  connection run inside the apply, in parallel); with one build per project
  the whole fleet finishes in roughly the same wall time.
- The **caller** needs rights on every participant project. The gcplab base
  provisioning (editor + projectIamAdmin, see the other streams'
  `bk-bootstrap-accounts`) is sufficient — pass 1 self-grants the rest.
- On **Argolis/self-run** there is no organizer: Lab 1 has the participant
  run `bk-prep-project` themselves (Terraform self-installs; org policies
  may need loosening, the lab says which).

## When something is red

`bk-verify-fleet` names the missing component per project. The fix is almost
always the same: run `bk-prep-fleet --cloud-build` again for the affected
accounts (safe to repeat), then verify again. Raw build logs:
`gcloud builds list --project=<project>` /
`gcloud builds log <id> --project=<project>`.
