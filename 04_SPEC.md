# ☕ Stage 4: Technical Specification

This technical specification details the architectural, query, and configuration improvements to migrate Developer AI Tools: User Token Tracker Dashboard (v2) to PromQL, harden log-based metrics, and implement **Native GEAP Request-Response Logging (via `PublisherModelConfig`)**.

---

## 1. Dashboard v2 PromQL Migration Design

Standard GCM filter widgets in `geap-monitoring-dashboard-v2.json` are upgraded to utilize `prometheusQuery` blocks.

### 1.1 Metric Translation Maps
In PromQL, GCP translates the custom log-based metric `logging.googleapis.com/user/user_tokens` to:
*   Metric Name: `logging_googleapis_com:user_user_tokens`
*   Labels:
    *   `metric.labels.user_id` $\rightarrow$ `user_id`
    *   `metric.labels.model_id` $\rightarrow$ `model_id`

For `DISTRIBUTION` metrics (Option 2), PromQL exposes these scalar suffixes:
*   `logging_googleapis_com:user_user_tokens_sum`: Accumulates total tokens.
*   `logging_googleapis_com:user_user_tokens_count`: Accumulates request count.

### 1.2 The Fallback Schema Pattern
To ensure the dashboard works seamlessly under both Audit Logs (counters) and Native Logging (distributions), every chart utilizes the PromQL `or` operator:
```promql
<Option_2_Distribution_Query> or <Option_1_Scalar_Query>
```
If Native Logging (Option 2) is active, the first operand returns data and is displayed. If Native Logging is not deployed, the first operand returns an empty vector, and PromQL falls back to evaluating the second operand (Option 1's request-count data).

---

## 2. Updated Widget Queries Spec

### Widget 2: Token (or Request) Consumption Rate (Over Time)
*   **Widget Type**: `xyChart` (Line)
*   **PromQL Query**:
    ```promql
    sum(rate(logging_googleapis_com:user_user_tokens_sum{monitored_resource="aiplatform.googleapis.com/PublisherModel"}[1m])) by (user_id) or sum(rate(logging_googleapis_com:user_user_tokens{monitored_resource="audited_resource"}[1m])) by (user_id)
    ```
*   **Axes & Legend**:
    *   Title: `"Token Consumption (or Requests) by User (Over Time)"`
    *   Y-Axis Label: `"Rate / Second"`

### Widget 3: Total Tokens (or Requests) Consumed per User
*   **Widget Type**: `xyChart` (Stacked Bar)
*   **PromQL Query**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum{monitored_resource="aiplatform.googleapis.com/PublisherModel"}[1m])) by (user_id) or sum(increase(logging_googleapis_com:user_user_tokens{monitored_resource="audited_resource"}[1m])) by (user_id)
    ```
*   **Axes & Legend**:
    *   Title: `"Total Tokens (or Requests) Consumed per User"`
    *   Y-Axis Label: `"Total Count (Tokens or Requests)"`

### Widget 4: API Requests Count by User
*   **Widget Type**: `xyChart` (Line)
*   **PromQL Query**:
    ```promql
    sum(rate(logging_googleapis_com:user_user_tokens_count{monitored_resource="aiplatform.googleapis.com/PublisherModel"}[1m])) by (user_id) or sum(rate(logging_googleapis_com:user_user_tokens{monitored_resource="audited_resource"}[1m])) by (user_id)
    ```
*   **Axes & Legend**:
    *   Title: `"API Request Count by User (Rate)"`
    *   Y-Axis Label: `"Requests / Second"`

### Widget 5: Model Types Utilized per User
*   **Widget Type**: `xyChart` (Stacked Bar)
*   **PromQL Query**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum{monitored_resource="aiplatform.googleapis.com/PublisherModel"}[1m])) by (user_id, model_id) or sum(increase(logging_googleapis_com:user_user_tokens{monitored_resource="audited_resource"}[1m])) by (user_id, model_id)
    ```
*   **Axes & Legend**:
    *   Title: `"Model Types Utilized by User"`
    *   Y-Axis Label: `"Total Count (Tokens or Requests)"`

### Widget 6: Total Tokens (or Requests) Consumed per User per Model (Table Summary)
*   **Widget Type**: `timeSeriesTable` with `"outputFullDuration": true`
*   **PromQL Query**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum{monitored_resource="aiplatform.googleapis.com/PublisherModel"}[${__interval}])) by (user_id, model_id) or sum(increase(logging_googleapis_com:user_user_tokens{monitored_resource="audited_resource"}[${__interval}])) by (user_id, model_id)
    ```
*   **Settings**: `"outputFullDuration": true` aggregates the cumulative sums exactly over the active selected dashboard window (e.g. Last 7 Days, Last 1 Hour).

---

## 3. Log-Based Metric Hardening Spec

### 3.1 `user-tokens-audit-log.yaml` (Option 1)
Identifies API activities from standard Audit Logs and extracts caller and model details:
```yaml
filter: 'logName:"cloudaudit.googleapis.com%2Fdata_access" AND protoPayload.serviceName="aiplatform.googleapis.com" AND (protoPayload.methodName:"GenerateContent" OR protoPayload.methodName:"Predict")'
```

### 3.2 `user-tokens-proxy.yaml` (Option 2 - OpenTelemetry Log Extractor)
When native request-response logging has OpenTelemetry (`enableOtelLogging`) enabled, Vertex AI writes structured OpenTelemetry logs to Cloud Logging. The metric extracts exact token counts directly from the OTel body payload:
```yaml
filter: 'resource.type="aiplatform.googleapis.com/PublisherModel" AND jsonPayload.body.name="gemini_call"'
valueExtractor: 'EXTRACT(jsonPayload.body.totalTokens)'
```

---

## 4. Native GEAP Ingestion & BigQuery Spec

Instead of hosting custom proxy servers, GEAP model logging is enabled natively using the `setPublisherModelConfig` API.

### 4.1 Native Platform Configuration Request
*   **Method**: `POST`
*   **URL**: `https://{LOCATION}-aiplatform.googleapis.com/v1beta1/projects/{PROJECT_ID}/locations/{LOCATION}/publishers/google/models/{MODEL_ID}:setPublisherModelConfig`
*   **Headers**: `Authorization: Bearer $(gcloud auth print-access-token)`
*   **Request Payload**:
    ```json
    {
      "publisherModelConfig": {
        "loggingConfig": {
          "enabled": true,
          "samplingRate": 1.0,
          "bigqueryDestination": {
            "outputUri": "bq://{PROJECT_ID}.vertex_logs.request_response_logs"
          },
          "enableOtelLogging": true
        }
      }
    }
    ```

### 4.2 BigQuery Cost & Security Correlation Query
Because payload logs do not directly write the caller's email into the BigQuery dataset (to prevent data privacy leaks), administrators correlate exact token usage with validated user identities by running an inner join between the native **BigQuery Logging Table** and the native **GCP Cloud Audit Logs Table**:

```sql
SELECT 
  audit.protopayload_auditlog.authenticationInfo.principalEmail AS user_id,
  log.model AS model_id,
  log.logging_time AS call_timestamp,
  CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.promptTokenCount") AS INT64) AS input_tokens,
  CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.candidatesTokenCount") AS INT64) AS output_tokens,
  CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.promptTokenCount") AS INT64) + 
    CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.candidatesTokenCount") AS INT64) AS total_tokens
FROM 
  `{PROJECT_ID}.vertex_logs.request_response_logs` AS log
INNER JOIN 
  `{PROJECT_ID}.cloudaudit_googleapis_com.data_access_*` AS audit
ON 
  JSON_EXTRACT_SCALAR(log.metadata, "$.request_id") = JSON_EXTRACT_SCALAR(audit.protopayload_auditlog.metadata, "$.request_id")
WHERE 
  _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)) AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
ORDER BY 
  call_timestamp DESC;
```

---

## 5. Security & Cost Considerations Spec

### 5.1 Native Security & IAM
*   **Pre-Auth Enforcement**: Developers are authenticated locally via standard Google ADC. Since they connect directly to `aiplatform.googleapis.com`, standard GCP IAM handles access control. 
*   **Preventing Bypasses**: Developers cannot bypass log collection. If they call a base model configured with `PublisherModelConfig` logging, Vertex AI's internal platform engine intercepts and logs the call asynchronously, regardless of the developer's client configurations.

### 5.2 Cost Optimization Strategy
*   **BigQuery Ingestion & Storage**: BigQuery storage is cheap ($0.02 per GiB/month). The first 10 GiB is completely free.
*   **Custom Metrics**: Metric samples beyond GCM's free tier of 150 MiB/month are charged at $0.30 per million.
*   **Adaptive Sampling Rate**: For large development organizations with massive request volume, administrators can adjust the `samplingRate` under `loggingConfig` (e.g. `0.1` for 10% sampling) to scale down logging storage and metric ingestion volumes, while maintaining statistically accurate dashboards!
