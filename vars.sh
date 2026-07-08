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

# This file holds the defaults. `. bk` copies it to vars.local.sh (git-ignored)
# on first run and works from there -- edit vars.local.sh, not this file.

# Your (first) name, shown in the tutorial greeting. Optional. Example: Ada
export MY_NAME=""

# Google Cloud project and account. Leave empty to auto-detect from Cloud Shell;
# set a value to override what `. bk` detects.
# Examples: bootkon-data-3472 / devstar3110@gcplab.me
export PROJECT_ID=""
export GCP_USERNAME=""

# Deployment region. Do not change this value.
export REGION="us-central1"
