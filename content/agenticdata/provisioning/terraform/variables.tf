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

variable "project_id" {
  description = "The participant project to prepare."
  type        = string
}

variable "username" {
  description = "The participant account (e.g. devstar1234@gcplab.me) that receives the stream roles."
  type        = string
}

variable "region" {
  description = "Deployment region; fixed to us-central1 for this stream."
  type        = string
  default     = "us-central1"
}

locals {
  apis = [
    "sqladmin.googleapis.com",
    "datastream.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "iap.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryconnection.googleapis.com",
    "dataplex.googleapis.com",
    "datacatalog.googleapis.com",
    "datalineage.googleapis.com",
    "dlp.googleapis.com",
    "geminidataanalytics.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "aiplatform.googleapis.com",
    "storage-component.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
  ]

  # Keep in sync with what the lab commands actually need.
  user_roles = [
    "roles/editor",                               # baseline: run the labs' commands
    "roles/resourcemanager.projectIamAdmin",      # in-lab self-grants (Lab 9) + manual recovery
    "roles/cloudsql.admin",                       # create/manage the Cymbal instance
    "roles/datastream.admin",                     # profiles, private connection, stream
    "roles/compute.admin",                        # jump VM, firewall, PSC endpoint
    "roles/iap.tunnelResourceAccessor",           # IAP TCP tunnel to the jump VM
    "roles/bigquery.admin",                       # datasets, jobs, connections
    "roles/dataplex.admin",                       # Knowledge Catalog: aspects, scans, glossary
    "roles/datalineage.admin",                    # lineage graph
    "roles/aiplatform.user",                      # Gemini calls from ADK agents
    "roles/geminidataanalytics.dataAgentCreator", # create + chat with data agents
    "roles/cloudaicompanion.user",                # conversational analytics chat
    "roles/storage.admin",                        # seed bucket
    "roles/iam.serviceAccountAdmin",              # create service accounts
    "roles/iam.serviceAccountUser",               # act as service accounts
  ]

  dq_roles = [
    "roles/bigquery.jobUser",
    "roles/bigquery.dataViewer",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser",
    "roles/storage.objectViewer",
  ]
}
