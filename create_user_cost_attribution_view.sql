-- Copyright 2026 Google LLC.
-- SPDX-License-Identifier: Apache-2.0

-- Create or replace the unified cost attribution report view, tailored specifically to Antigravity CLI & 2.0
CREATE OR REPLACE VIEW `coffee-and-codey.vertex_logs.user_cost_attribution_report` AS
WITH trajectory_mapping AS (
  -- Antigravity-Specific Optimization:
  -- Map conversation trajectory_ids to the authentic principalEmail of the developer
  -- using standard data-access audit logs written on any regional calls within that session.
  SELECT DISTINCT
    JSON_VALUE(log.full_request, "$.labels.trajectory_id") AS trajectory_id,
    audit.protopayload_auditlog.authenticationInfo.principalEmail AS principal_email
  FROM 
    `coffee-and-codey.vertex_logs.request_response_logs` AS log
  INNER JOIN 
    `coffee-and-codey.cloudaudit_googleapis_com.data_access_2026` AS audit
  ON 
    JSON_VALUE(log.metadata, "$.request_id") = JSON_VALUE(audit.protopayload_auditlog.metadata, "$.request_id")
  WHERE 
    JSON_VALUE(log.full_request, "$.labels.trajectory_id") IS NOT NULL
    AND audit.protopayload_auditlog.authenticationInfo.principalEmail IS NOT NULL
)
SELECT 
  COALESCE(
    -- 1. Direct developer_email labels (e.g. from custom client overrides)
    JSON_VALUE(log.full_request, "$.labels.developer_email"),
    JSON_VALUE(log.full_request, "$.config.labels.developer_email"),
    JSON_VALUE(log.full_request, "$.labels.developer-email"),
    JSON_VALUE(log.full_request, "$.config.labels.developer-email"),
    
    -- 2. Antigravity Trajectory Mapping: Automatically resolve the developer's email 
    -- from conversation context even on logical global endpoints (No Audit Logs required!)
    map.principal_email,
    
    -- 3. Fallback to direct request_id audit log join for this specific call (regional only)
    audit.protopayload_auditlog.authenticationInfo.principalEmail,
    
    -- 4. Unlabeled placeholder
    "unlabeled_request"
  ) AS user_id,
  
  -- Antigravity Session Identifiers for rich dashboard reporting
  JSON_VALUE(log.full_request, "$.labels.trajectory_id") AS antigravity_trajectory_id,
  JSON_VALUE(log.full_request, "$.labels.last_execution_id") AS antigravity_execution_id,
  
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
  ) AS estimated_cost_usd,
  
  -- Raw Text Payload Extraction
  JSON_VALUE(log.full_request, "$.contents[0].parts[0].text") AS user_prompt,
  JSON_VALUE(log.full_response, "$.candidates[0].content.parts[0].text") AS model_response
FROM 
  `coffee-and-codey.vertex_logs.request_response_logs` AS log
LEFT OUTER JOIN 
  `coffee-and-codey.cloudaudit_googleapis_com.data_access_2026` AS audit
ON 
  JSON_VALUE(log.metadata, "$.request_id") = JSON_VALUE(audit.protopayload_auditlog.metadata, "$.request_id")
LEFT OUTER JOIN 
  trajectory_mapping AS map
ON 
  JSON_VALUE(log.full_request, "$.labels.trajectory_id") = map.trajectory_id;
