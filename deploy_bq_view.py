# Copyright 2026 Google LLC.
# SPDX-License-Identifier: Apache-2.0

import os
from google.cloud import bigquery

def main():
    print("☕ Deploying BigQuery Unified Cost Attribution View via Python Client...")
    project_id = "coffee-and-codey"
    sql_file = "create_user_cost_attribution_view.sql"
    
    if not os.path.exists(sql_file):
        print(f"❌ Error: {sql_file} not found.")
        return
        
    with open(sql_file, "r") as f:
        query_text = f.read()
        
    client = bigquery.Client(project=project_id)
    
    print(f"Project ID: {project_id}")
    print("Running deployment query...")
    
    query_job = client.query(query_text)
    query_job.result()  # Wait for query to complete
    
    print("✅ BigQuery View 'vertex_logs.user_cost_attribution_report' successfully deployed!")

if __name__ == "__main__":
    main()
