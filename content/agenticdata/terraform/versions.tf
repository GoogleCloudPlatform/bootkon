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

terraform {
  required_version = ">= 1.5"

  # Per-project state: the bucket (gs://<project>-tfstate, living in the
  # participant project itself) is passed at init time by bk-prep-project --
  # there is deliberately NO central state anywhere.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    # google_project_service_identity is beta-only.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.0"
    }
    # time_sleep bridges the IAM propagation gap between the Datastream
    # service-agent grant and the private-connection build (see main.tf).
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
    # Placeholder root password for the Cloud SQL instance; participants
    # replace it with their own BK_DB_PASSWORD in Lab 1.
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
