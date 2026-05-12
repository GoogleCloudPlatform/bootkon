#!/bin/bash
# Copyright 2025 Google LLC
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


INPUT_DATA_FILE="content/data/src/ml/instances.json"
ENDPOINT_ID="$(gcloud ai endpoints list --region=$REGION \
    --filter=display_name=bootkon-endpoint \
    | grep ENDPOINT_ID | awk '{ print $2 }' | head -n 1)"
ACCESS_TOKEN="$(gcloud auth print-access-token)"

curl \
-X POST \
-H "Authorization: Bearer $ACCESS_TOKEN" \
-H "Content-Type: application/json" \
"https://us-central1-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/us-central1/endpoints/${ENDPOINT_ID}:predict" -d "@${INPUT_DATA_FILE}"