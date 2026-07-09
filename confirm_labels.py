# Copyright 2026 Google LLC.
# SPDX-License-Identifier: Apache-2.0

from google.cloud import bigquery
import json

def confirm_labels():
    project_id = "coffee-and-codey"
    client = bigquery.Client(project=project_id)
    
    # Query the view for the test developer email
    query = """
    SELECT 
      user_id,
      model_id,
      call_timestamp,
      input_tokens,
      output_tokens,
      estimated_cost_usd,
      user_prompt,
      model_response
    FROM 
      `coffee-and-codey.vertex_logs.user_cost_attribution_report`
    WHERE 
      user_id = 'test_developer_types@sapientcoffee.com'
    ORDER BY 
      call_timestamp DESC
    LIMIT 10
    """
    
    print("🔍 Querying BigQuery view for labeled test logs...")
    try:
        query_job = client.query(query)
        results = list(query_job.result())
        
        if results:
            print(f"✅ Success! Found {len(results)} rows with our injected client label in the view!")
            for idx, row in enumerate(results):
                print(f"\n--- MATCH {idx + 1} ---")
                print(f"  User ID (Extracted Label): {row['user_id']}")
                print(f"  Model ID:                  {row['model_id']}")
                print(f"  Call Timestamp:            {row['call_timestamp']}")
                print(f"  Input Tokens:              {row['input_tokens']}")
                print(f"  Output Tokens:             {row['output_tokens']}")
                print(f"  Estimated Cost (USD):      ${row['estimated_cost_usd']:.6f}")
                print(f"  User Prompt:               {row['user_prompt']}")
                print(f"  Model Response:            {row['model_response']}")
        else:
            print("⚠️ No matching rows found with user_id = 'test_developer_types@sapientcoffee.com' yet.")
            print("This could be due to a short ingestion delay (usually up to 1-2 minutes).")
            print("Let's query the raw table to see if the record has arrived...")
            
            raw_query = """
            SELECT 
              logging_time,
              model,
              full_request
            FROM 
              `coffee-and-codey.vertex_logs.request_response_logs`
            ORDER BY 
              logging_time DESC
            LIMIT 5
            """
            raw_job = client.query(raw_query)
            raw_results = list(raw_job.result())
            print("\nPreview of latest raw logs:")
            for r_idx, r_row in enumerate(raw_results):
                print(f"\n- Raw Row {r_idx + 1} at {r_row['logging_time']} for {r_row['model']}")
                req_str = json.dumps(r_row['full_request']) if isinstance(r_row['full_request'], dict) else (r_row['full_request'] or "")
                print(f"  Request snippet: {req_str[:300]}...")
                
    except Exception as e:
        print(f"❌ Error querying BigQuery: {e}")

if __name__ == "__main__":
    confirm_labels();
