-- Copyright 2026 Google LLC.
-- SPDX-License-Identifier: Apache-2.0

-- Create or replace the unified cost attribution report view
CREATE OR REPLACE VIEW `coffee-and-codey.vertex_logs.user_cost_attribution_report` AS
SELECT 
  audit.protopayload_auditlog.authenticationInfo.principalEmail AS user_id,
  log.model AS model_id,
  log.logging_time AS call_timestamp,
  
  -- Exact Token Counts
  CAST(JSON_VALUE(log.full_response, "$.usageMetadata.promptTokenCount") AS INT64) AS input_tokens,
  CAST(JSON_VALUE(log.full_response, "$.usageMetadata.candidatesTokenCount") AS INT64) AS output_tokens,
  CAST(JSON_VALUE(log.full_response, "$.usageMetadata.promptTokenCount") AS INT64) + 
    CAST(JSON_VALUE(log.full_response, "$.usageMetadata.candidatesTokenCount") AS INT64) AS total_tokens,
    
  -- Financial Calculation (using standard list rates)
  ROUND(
    CASE 
      WHEN log.model LIKE "%gemini-3.5-flash%" THEN 
        (CAST(JSON_VALUE(log.full_response, "$.usageMetadata.promptTokenCount") AS FLOAT64) * 0.00000150) + 
        (CAST(JSON_VALUE(log.full_response, "$.usageMetadata.candidatesTokenCount") AS FLOAT64) * 0.00000900)
      WHEN log.model LIKE "%gemini-3.1-pro%" THEN 
        (CAST(JSON_VALUE(log.full_response, "$.usageMetadata.promptTokenCount") AS FLOAT64) * 0.00000200) + 
        (CAST(JSON_VALUE(log.full_response, "$.usageMetadata.candidatesTokenCount") AS FLOAT64) * 0.00001200)
      WHEN log.model LIKE "%gemini-2.5-flash%" THEN 
        (CAST(JSON_VALUE(log.full_response, "$.usageMetadata.promptTokenCount") AS FLOAT64) * 0.000000075) + 
        (CAST(JSON_VALUE(log.full_response, "$.usageMetadata.candidatesTokenCount") AS FLOAT64) * 0.00000030)
      WHEN log.model LIKE "%gemini-1.5-pro%" THEN 
        (CAST(JSON_VALUE(log.full_response, "$.usageMetadata.promptTokenCount") AS FLOAT64) * 0.00000125) + 
        (CAST(JSON_VALUE(log.full_response, "$.usageMetadata.candidatesTokenCount") AS FLOAT64) * 0.00000500)
      ELSE 0.0
    END, 6
  ) AS estimated_cost_usd
FROM 
  `coffee-and-codey.vertex_logs.request_response_logs` AS log
INNER JOIN 
  `coffee-and-codey.cloudaudit_googleapis_com.data_access_2026` AS audit
ON 
  JSON_VALUE(log.metadata, "$.request_id") = JSON_VALUE(audit.protopayload_auditlog.metadata, "$.request_id");
