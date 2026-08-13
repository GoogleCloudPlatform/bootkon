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
