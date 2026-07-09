#!/bin/bash
# Copyright 2026 Google LLC.
# SPDX-License-Identifier: Apache-2.0
#
# This script deploys the BigQuery User Cost Attribution Report View to Google Cloud.

set -euo pipefail

PROJECT_ID="coffee-and-codey"
SQL_FILE="create_user_cost_attribution_view.sql"

echo "☕ Deploying BigQuery Unified Cost Attribution View..."
echo "Project ID: ${PROJECT_ID}"
echo "SQL Schema: ${SQL_FILE}"

if [ ! -f "${SQL_FILE}" ]; then
  echo "❌ Error: SQL schema file ${SQL_FILE} not found." >&2
  exit 1
fi

# Run bq query command to deploy the view
bq query \
  --project_id="${PROJECT_ID}" \
  --use_legacy_sql=false \
  < "${SQL_FILE}"

echo "✅ BigQuery View 'vertex_logs.user_cost_attribution_report' successfully deployed!"
