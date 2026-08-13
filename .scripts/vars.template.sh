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

# This file is the template for the per-participant config. `. bk` copies it to
# $BK_DIR/vars.local.sh (git-ignored) on first run and works from there -- edit
# vars.local.sh, not this file.

# Your (first) name, shown in the tutorial greeting. Optional. Example: Ada
export MY_NAME=""

# Your Google Cloud project. Leave empty to auto-detect it once from the Cloud
# Shell project picker on first run. To switch projects later, edit this value
# in vars.local.sh and run: . bk
export PROJECT_ID=""

# Your Google Cloud account. Leave empty to auto-detect from Cloud Shell.
# Example: devstar3110@gcplab.me
export GCP_USERNAME=""

# Deployment region. Do not change this value.
export REGION="us-central1"
