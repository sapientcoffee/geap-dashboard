# ☕ Sophisticated User & Usage Tracking Guide

Yes! It is absolutely possible to track specific users, teams, and exact usage details. To achieve this level of sophistication, we must go beyond platform-level aggregate metrics.

We have deployed an advanced, unified dashboard to your Google Cloud project:
👉 **[geap-monitoring-dashboard-v2.json](geap-monitoring-dashboard-v2.json)**

> [!NOTE]
> **Unified PromQL Architecture**: Dashboard v2 has been migrated to PromQL with logical fallbacks (`or`). This means a single dashboard definition natively and dynamically supports **both** Solution A1 and Solution A2. If you start with Solution A1, the charts display request counts; once you enable Solution A2, the dashboard automatically transitions to plotting exact token count metrics!

---

## 🛑 The Regional Endpoint Mandate (Critical Requirement)

To track user-level metrics in **either** Google Cloud Monitoring (GCM) or BigQuery, your developer clients (including **Antigravity CLI** and custom SDK scripts) **MUST** route their Vertex AI requests through a **regional endpoint** (such as `us-central1` or `europe-west1`) instead of the logical `global` endpoint.

### Why is this required?
* **No Global Audit Logs**: The Vertex AI global multi-region routing endpoint (`location="global"`) does **not** write standard `DATA_READ` audit logs to Cloud Logging.
* **No GCM Email Mapping**: Without audit logs, GCM has no log-line source containing the caller's email (`principalEmail`), leaving GCM user widgets completely blank.
* **No BigQuery Email Mapping**: In BigQuery, payload logs do not contain user emails directly for privacy and compliance reasons. Cost attribution is performed by running an `INNER JOIN` with data access audit logs on the `request_id`. If you call the global endpoint, no audit log is written, meaning the join finds no matching records and the user's calls will not appear in the cost report.

### Regional vs. Global Endpoint Feature Matrix
| Feature | Regional Endpoints (e.g. `us-central1`) | Global Endpoint (`location="global"`) |
| :--- | :--- | :--- |
| **GCP Data Access Audit Logs** | **Yes** (Generates `DATA_READ` logs) | **No** (Zero audit logging) |
| **User Email Tracking (GCM)** | **Yes** (Via Audit-Log custom metric) | **No** (GCM widgets remain blank) |
| **Exact Token Payload Logs (BQ)** | **Yes** (Via BigQuery Destination) | **Yes** (Via BigQuery Destination) |
| **Cost Attribution Join (BQ)** | **Yes** (Full corporate email mapping) | **No** (Omits global calls due to missing audit records) |

---

## 🏗️ Pattern A: Real-Time Dashboards (Custom Log-Based Metrics in GCM)

To populate your live Cloud Monitoring dashboard with per-user data, we use the log-based metric **`user_tokens`** created directly in your project. It queries your Cloud Logging entries and extracts custom fields and labels.

### 🛠️ Solution A1: No-Code Audit Logs (Request Counts & Costs) - *ACTIVE!* ⚡
If you want to track developer request counts and estimated costs natively in GCM without modifying any developer setups or deploying custom proxy servers:
1. Ensure **Vertex AI Data Access Audit Logs are enabled** in your project `coffee-and-codey` for `aiplatform.googleapis.com` (already active!).
2. Ensure the log-based metric `user_tokens` is configured to read from regional audit logs by running:
   ```bash
   gcloud logging metrics update user_tokens --config-from-file=user-tokens-audit-log.yaml --project=coffee-and-codey
   ```
3. When any developer runs local `agy` or `GeminiCLI` commands routed through `us-central1`, the audit logs will automatically capture their email (`user_id`) and the model called (`model_id`), instantly feeding them into Dashboard v2!

### 🏗️ Solution A2: Native Request-Response Logging (Exact Token Counts) 💎
If you want to track exact input, output, and cached token totals in GCM with zero intermediate servers:
1. Enable native request-response logging on your base models (detailed in [HOW_TO_COLLECT_USER_DATA.md](HOW_TO_COLLECT_USER_DATA.md)).
2. Update your `user_tokens` metric to extract exact token distributions from native OpenTelemetry logs:
   ```bash
   gcloud logging metrics update user_tokens --config-from-file=user-tokens-proxy.yaml --project=coffee-and-codey
   ```
3. Dashboard v2 will automatically detect and transition to exact token tracking graphs!

---

## 📊 Pattern B: Cost & Billing Allocation (BigQuery & Looker Studio)

If your goal is high-fidelity financial auditing, chargebacks, or department cost attribution, you should use GEAP's native **BigQuery Request-Response Destination**. 

Because payload logs do not directly write user emails to BigQuery to protect data privacy, you run an inner join between your **Native Payload Logs** and **GCP Data Access Audit Logs** in BigQuery on the `request_id` field.

### Step 1: Create the Unified Cost Attribution SQL View
Execute this SQL query in BigQuery to create a clean reporting view of exact token consumption mapped to verified corporate emails:

```sql
CREATE OR REPLACE VIEW `vertex_logs.user_cost_attribution_report` AS
SELECT 
  audit.protopayload_auditlog.authenticationInfo.principalEmail AS user_id,
  log.model AS model_id,
  log.logging_time AS call_timestamp,
  
  -- Exact Token Counts
  CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.promptTokenCount") AS INT64) AS input_tokens,
  CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.candidatesTokenCount") AS INT64) AS output_tokens,
  CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.promptTokenCount") AS INT64) + 
    CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.candidatesTokenCount") AS INT64) AS total_tokens,
    
  -- Financial Calculation (using standard list rates)
  ROUND(
    CASE 
      WHEN log.model LIKE "%gemini-3.5-flash%" THEN 
        (CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.promptTokenCount") AS FLOAT64) * 0.00000150) + 
        (CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.candidatesTokenCount") AS FLOAT64) * 0.00000900)
      WHEN log.model LIKE "%gemini-3.1-pro%" THEN 
        (CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.promptTokenCount") AS FLOAT64) * 0.00000200) + 
        (CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.candidatesTokenCount") AS FLOAT64) * 0.00001200)
      WHEN log.model LIKE "%gemini-2.5-flash%" THEN 
        (CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.promptTokenCount") AS FLOAT64) * 0.000000075) + 
        (CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.candidatesTokenCount") AS FLOAT64) * 0.00000030)
      WHEN log.model LIKE "%gemini-1.5-pro%" THEN 
        (CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.promptTokenCount") AS FLOAT64) * 0.00000125) + 
        (CAST(JSON_EXTRACT(log.full_response, "$.usageMetadata.candidatesTokenCount") AS FLOAT64) * 0.00000500)
      ELSE 0.0
    END, 6
  ) AS estimated_cost_usd
FROM 
  `coffee-and-codey.vertex_logs.request_response_logs` AS log
INNER JOIN 
  `coffee-and-codey.cloudaudit_googleapis_com.data_access_2026` AS audit
ON 
  JSON_EXTRACT_SCALAR(log.metadata, "$.request_id") = JSON_EXTRACT_SCALAR(audit.protopayload_auditlog.metadata, "$.request_id");
```

### Step 2: Build a Looker Studio Report
1. Open **Looker Studio**.
2. Click **Create > Data Source** and select **BigQuery**.
3. Choose your project, dataset `vertex_logs`, and connect directly to the view `user_cost_attribution_report`.
4. Create charts (e.g. Pie Charts, Bar Charts, Tables) plotting `estimated_cost_usd` grouped by `user_id`.

---

## 💻 Client-Side Configuration (Antigravity CLI)

To force the Antigravity CLI (`agy`) on developer workstations to target a regional endpoint (enabling full user auditing and GCM metric reporting):

1. **Locate settings file**: Open the global settings file at:
   `~/.gemini/antigravity-cli/settings.json`
2. **Modify GCP Block**: Update the `"location"` from `"global"` to `"us-central1"` (or your preferred GCP region where Gemini models are available):
   ```json
   "gcp": {
     "project": "coffee-and-codey",
     "location": "us-central1"
   }
   ```
3. Save the file and restart any active CLI sessions.

---

## 💰 Resource & Pricing Free-Tiers

| Log/Metric Source | Cost Structure | Pricing Free-Tier Rationale |
| :--- | :--- | :--- |
| **GCM System Metrics** | **$0.00** | Used by Dashboard v1. Built-in metrics are 100% free to query and store. |
| **Cloud Logging** | **$0.00** | First **50 GiB/month** per project is completely free. Overages are billed at $0.50/GiB. |
| **BigQuery Ingest & Store** | **$0.00** | BigQuery provides **10 GiB** of free storage and **1 TiB** of free query processing per month. |
| **Custom Log-Based Metrics** | **$0.00** | GCM custom metrics are free up to **150 MiB/month** per project. Overages are $0.30 per million samples. |
