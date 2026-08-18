# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# One-time, per-project prep for the agenticdata stream: everything
# project-bound that participants must not spend event time (or IAM/API
# propagation waits) on. Applied per participant project by bk-prep-project
# with a state bucket in that same project; see versions.tf.

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_project_service" "this" {
  for_each = toset(local.apis)
  service  = each.value

  # The sandbox projects are torn down whole; never disable APIs on destroy.
  disable_on_destroy = false
}

# Datastream service agent: must exist and hold its role LONG before Lab 1
# creates the private connection -- created lazily otherwise, and a fresh
# role grant lost the IAM propagation race often enough to end the
# connection FAILED.
resource "google_project_service_identity" "datastream" {
  provider   = google-beta
  service    = "datastream.googleapis.com"
  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "datastream_agent" {
  project    = var.project_id
  role       = "roles/datastream.serviceAgent"
  member     = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-datastream.iam.gserviceaccount.com"
  depends_on = [google_project_service_identity.datastream]
}

resource "google_project_iam_member" "participant" {
  for_each   = toset(local.user_roles)
  project    = var.project_id
  role       = each.value
  member     = "user:${var.username}"
  depends_on = [google_project_service.this]
}

# Lab 4 data-quality service account (profile/quality scans run as this SA;
# Lab 7 reuses it as the managed-Dataform execution identity).
resource "google_service_account" "dataquality" {
  account_id   = "dataquality-service-account"
  display_name = "Knowledge Catalog DQ Service Account"
  depends_on   = [google_project_service.this]
}

resource "google_project_iam_member" "dataquality" {
  for_each = toset(local.dq_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.dataquality.email}"
}

# Network path for the PSC connectivity (Labs 1/2 build on it). The endpoint
# IP is reserved HERE, before any Datastream private connection exists: its
# PSC-interface bridge VM takes an ephemeral IP from this same subnet and
# must never get the one the database endpoint needs (bit us live).
resource "google_compute_network" "vpc" {
  name                    = "cymbal-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.this]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "cymbal-subnet"
  network       = google_compute_network.vpc.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"
}

resource "google_compute_address" "endpoint_ip" {
  name         = "cymbal-endpoint-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.subnet.id
  address      = "10.10.0.5"
}

# ACCEPT_AUTOMATIC keeps the workshop simple; production would use
# ACCEPT_MANUAL with a producer accept list, discovering the Datastream
# tenant project via `gcloud datastream private-connections create
# --validate-only`.
resource "google_compute_network_attachment" "attachment" {
  name                  = "cymbal-attachment"
  region                = var.region
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.subnet.self_link]
}

# The service-agent role grant above and the private-connection build below
# happen in the SAME apply here, so the IAM propagation race the stream kept
# hitting (build ends FAILED when the role has not propagated yet) would be
# back -- bridge it with a one-time pause. Created once, next to the grant;
# later applies skip it.
resource "time_sleep" "datastream_agent_iam" {
  create_duration = "180s"
  depends_on      = [google_project_iam_member.datastream_agent]
}

# Datastream's PSC-interface private connection: pure network plumbing with
# a 5-10 minute build -- exactly the thing participants should never wait
# on or debug. Building it at prep time removes the old Lab 1 kickoff, the
# Lab 2 wait, and the bk-wait-psc self-healing dance entirely. If a build
# still ends FAILED (unlucky propagation beyond the pause above): delete it
# with `gcloud datastream private-connections delete cymbal-psc` and re-run
# the prep.
resource "google_datastream_private_connection" "psc" {
  private_connection_id = "cymbal-psc"
  display_name          = "cymbal-psc"
  location              = var.region

  psc_interface_config {
    network_attachment = google_compute_network_attachment.attachment.id
  }

  # The endpoint-IP dependency is load-bearing: without it Terraform may
  # build the connection before the reservation, and Datastream's bridge VM
  # would be free to grab 10.10.0.5 as its ephemeral interface IP.
  depends_on = [
    time_sleep.datastream_agent_iam,
    google_compute_address.endpoint_ip,
  ]
}

# Jump VM + IAP firewall: Cloud Shell lives outside the VPC and the
# PSC-only database has no public IP, so this e2-micro (no external IP
# either) forwards port 5432 to the database endpoint -- four lines of
# iptables in the startup script. Participants reach it through an IAP
# tunnel (bk-tunnel), which stays a lab step: tunnels are runtime, not
# provisioning.
resource "google_compute_firewall" "allow_iap_ingress" {
  name      = "allow-iap-ingress"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22", "5432"]
  }

  # IAP's TCP forwarding source range.
  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_instance" "jump" {
  name           = "cymbal-jump"
  zone           = "${var.region}-a"
  machine_type   = "e2-micro"
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    # No access_config block: no external IP.
  }

  metadata = {
    startup-script = file("${path.module}/../../src/jumpvm-startup.sh")
  }
}

# Cymbal's production order database: PostgreSQL with logical decoding
# enabled at creation time (the CDC prerequisite -- set here so the instance
# boots with it and never needs a flag-change restart), PSC instead of a
# public IP, and a deliberately small machine (CDC reads the log, it does
# not stress the database). The instance is PARKED STOPPED between prep
# and event: the API refuses to CREATE it stopped ("This operation is not
# valid for this instance", verified live), so it is created running and
# bk-prep-project parks it right after a fresh creation (storage-only
# cost, ~$0.06/day instead of ~$1.70/day). The participant's `. bk` setup
# (bk-init) wakes it silently in the background -- the 1-2 minute start
# overlaps with onboarding and bootstrap, and Lab 1 carries a visible
# backup start. The ignore_changes below is load-bearing in both
# directions: a re-apply must neither wake a parked instance (config
# default ALWAYS) nor stop a woken one. This is the slowest build of the
# prep (10-15 minutes); it runs in parallel with the private connection
# above.
resource "random_password" "sql_root" {
  length  = 24
  special = false
}

resource "google_sql_database_instance" "oltp" {
  name                = "cymbal-oltp"
  database_version    = "POSTGRES_15"
  region              = var.region
  root_password       = random_password.sql_root.result
  deletion_protection = false # sandbox projects; --destroy must work

  settings {
    edition           = "ENTERPRISE"
    tier              = "db-custom-1-3840"
    disk_size         = 10
    availability_type = "ZONAL"

    database_flags {
      name  = "cloudsql.logical_decoding"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled = false
      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.project_id]
      }
    }
  }

  timeouts {
    create = "45m"
  }

  lifecycle {
    # The wrapper parks the instance (NEVER) after creation, Lab 1 wakes it
    # (ALWAYS); re-applies must never touch the policy in either direction.
    ignore_changes = [settings[0].activation_policy]
  }

  depends_on = [google_project_service.this]
}

# The destination side of the CDC pipeline, plus the seed bucket. All of it
# is boilerplate the labs used to type: the bronze dataset the stream writes
# into, the BigQuery connection profile (no secrets in it -- unlike the
# PostgreSQL profile, which carries BK_DS_PASSWORD and therefore stays a
# Lab 2 command), and the bucket the seed CSVs are staged in, with the SQL
# instance's service account allowed to read them for the server-side
# import (terraform knows that account, so the lab needs no describe/grant
# dance).
resource "google_bigquery_dataset" "bronze" {
  dataset_id = "cymbal_bronze"
  location   = "US"

  # Sandbox projects: --destroy must not trip over CDC-filled tables.
  delete_contents_on_destroy = true

  depends_on = [google_project_service.this]
}

resource "google_datastream_connection_profile" "bq" {
  connection_profile_id = "cymbal-bq-profile"
  display_name          = "cymbal-bq-profile"
  location              = var.region

  bigquery_profile {}

  depends_on = [google_project_service.this]
}

resource "google_storage_bucket" "seed" {
  name                        = "${var.project_id}-bucket"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.this]
}

resource "google_storage_bucket_iam_member" "sql_seed_access" {
  bucket = google_storage_bucket.seed.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_sql_database_instance.oltp.service_account_email_address}"
}

# The consumer half of the database's PSC pair: the endpoint at the reserved
# 10.10.0.5, plugged into the service attachment the instance publishes.
# From here on that address IS the database -- for Datastream and for the
# jump VM's iptables forward. load_balancing_scheme must be empty for PSC
# consumer forwarding rules.
resource "google_compute_forwarding_rule" "endpoint" {
  name                    = "cymbal-endpoint"
  region                  = var.region
  network                 = google_compute_network.vpc.id
  ip_address              = google_compute_address.endpoint_ip.id
  target                  = google_sql_database_instance.oltp.psc_service_attachment_link
  load_balancing_scheme   = ""
  allow_psc_global_access = true
}
