#!/usr/bin/env bash
#
# push_to_dataform.sh -- beam the local Dataform CLI project into a managed
# Dataform development workspace, using nothing but the Dataform REST API
# and curl.
#
# Managed Dataform has no gcloud commands: its two surfaces are the console
# and the Dataform API. Every button in the console maps to one of the calls
# below -- this script is the console, minus the mouse.
#
# Usage:
#   push_to_dataform.sh [REPOSITORY_ID] [WORKSPACE_ID]
#   (defaults: cymbal-dataform cymbal-dev; project/region come from
#    $PROJECT_ID and $REGION, exported by '. bk')
#
# The six calls, in order:
#   1. GET  workspaces/{ws}                 fail fast if the workspace is missing
#   2. POST workspaces/{ws}:makeDirectory   mkdir, one call per directory
#   3. POST workspaces/{ws}:writeFile       upload, one call per file (base64 body)
#   4. POST workspaces/{ws}:commit          one git commit inside the workspace
#   5. POST workspaces/{ws}:push            workspace branch -> default branch (main)
#   6. POST workspaces/{ws}:installNpmPackages   best effort; a no-op for this
#      project (workflow_settings.yaml replaces package.json in Dataform core 3)
#
# What stays home: .df-credentials.json (your LOCAL credentials pointer --
# managed Dataform brings its own identity, and credentials never belong in
# a repository), AGENTS.md (agy's brief, not pipeline code), dotfiles, and
# node_modules.

set -euo pipefail

REPO_ID="${1:-cymbal-dataform}"
WORKSPACE_ID="${2:-cymbal-dev}"
: "${PROJECT_ID:?PROJECT_ID is not set. Run '. bk' or open a new terminal.}"
LOCATION="${REGION:-us-central1}"
SRC_DIR="$HOME/bootkon/content/agenticdata/src/dataform"

WS_PATH="projects/${PROJECT_ID}/locations/${LOCATION}/repositories/${REPO_ID}/workspaces/${WORKSPACE_ID}"
API="https://dataform.googleapis.com/v1"
TOKEN="$(gcloud auth print-access-token)"

# Authenticated JSON call; on failure, print the API's error body to stderr.
api() { # api METHOD PATH [JSON_BODY]
    local method="$1" path="$2" body="${3:-}" out
    if out=$(curl --silent --show-error --fail-with-body -X "$method" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        ${body:+--data "$body"} \
        "${API}/${path}" 2>&1); then
        printf '%s' "$out"
    else
        printf '%s\n' "$out" >&2
        return 1
    fi
}

# --- 1. The workspace must exist (you created it in the console) ------------
echo "Checking workspace ${WS_PATH} ..."
if ! api GET "${WS_PATH}" > /dev/null; then
    echo ""
    echo "Workspace not found. Create the repository '${REPO_ID}' and the"
    echo "development workspace '${WORKSPACE_ID}' in the console first (see the"
    echo "lab), or pass your own names:"
    echo "  push_to_dataform.sh <repository_id> <workspace_id>"
    exit 1
fi

cd "${SRC_DIR}"

# Everything except credentials, agy's brief, dotfiles and node_modules.
# NUL-delimited so a hand-made "my model.sqlx" (space and all) survives intact.
mapfile -d '' -t FILES < <(find . -type f \
    ! -name '.df-credentials.json' \
    ! -name 'AGENTS.md' \
    ! -path '*/node_modules/*' \
    ! -path '*/.*' \
    -print0 | sort -z)

# --- 2. Recreate the directory tree -----------------------------------------
mapfile -d '' -t DIRS < <(find . -mindepth 1 -type d \
    ! -path '*/.*' ! -path '*/node_modules*' -print0 | sort -z)
for dir in "${DIRS[@]}"; do
    dir="${dir#./}"
    echo "makeDirectory  ${dir}/"
    api POST "${WS_PATH}:makeDirectory" \
        "$(jq -n --arg path "$dir" '{path: $path}')" > /dev/null 2>&1 \
        || echo "               (already exists -- fine)"
done

# --- 3. Upload every file ----------------------------------------------------
# JSON cannot carry raw bytes, so writeFile takes the contents base64-encoded.
count=0
for f in "${FILES[@]}"; do
    f="${f#./}"
    echo "writeFile      ${f}"
    api POST "${WS_PATH}:writeFile" \
        "$(jq -n --arg path "$f" --arg contents "$(base64 -w0 "$f")" \
            '{path: $path, contents: $contents}')" > /dev/null
    count=$((count + 1))
done

# --- 4. One git commit for the lot -------------------------------------------
AUTHOR_EMAIL="$(gcloud config get-value account 2>/dev/null || true)"
COMMIT_BODY="$(jq -n \
    --arg name  "${MY_NAME:-Bootkon participant}" \
    --arg email "${AUTHOR_EMAIL:-participant@example.com}" \
    --arg msg   "Import the agy-authored medallion project (Lab 3, ${count} files)" \
    '{author: {name: $name, emailAddress: $email}, commitMessage: $msg}')"
# Committing an unchanged workspace is an API error, not a no-op -- but so is
# a real failure (say, an IAM grant still propagating). Tell them apart.
if err=$(api POST "${WS_PATH}:commit" "${COMMIT_BODY}" 2>&1 >/dev/null); then
    echo "commit         ${count} files"
elif grep -qiE 'no changes|nothing to commit|up to date' <<<"${err}"; then
    echo "commit         nothing new to commit (files unchanged) -- continuing"
else
    printf '%s\n' "${err}" >&2
    exit 1
fi

# --- 5. Push the workspace branch to the repository's default branch ---------
api POST "${WS_PATH}:push" '{}' > /dev/null
echo "push           workspace -> default branch (main)"

# --- 6. Install npm packages (best effort) ------------------------------------
# With Dataform core 3, workflow_settings.yaml replaces package.json, so this
# project has nothing to install -- but if you ever add dependency packages,
# this is the call behind the console's "Install packages" button.
if api POST "${WS_PATH}:installNpmPackages" > /dev/null 2>&1; then
    echo "installNpm     done"
else
    echo "installNpm     nothing to install (no package.json) -- fine"
fi

echo ""
echo "Done. Refresh the '${WORKSPACE_ID}' workspace in the console -- your"
echo "project is there, committed, and already pushed to main."
