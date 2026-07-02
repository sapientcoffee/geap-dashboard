# ☕ Sophisticated User & Usage Tracking Guide

Yes! It is absolutely possible to track specific users, teams, and exact usage details. To achieve this level of sophistication, we must go beyond platform-level aggregate metrics.

We have deployed an advanced, unified dashboard to your Google Cloud project:
👉 **[geap-monitoring-dashboard-v2.json](geap-monitoring-dashboard-v2.json)**

> [!NOTE]
> **Unified PromQL Architecture**: Dashboard v2 has been migrated to PromQL with logical fallbacks (`or`). This means a single dashboard definition natively and dynamically supports **both** Solution A1 and Solution A2. If you start with Solution A1, the charts display request counts; once you enable Solution A2, the dashboard automatically transitions to plotting exact token count metrics!

Here are the two standard patterns to implement per-user and per-team tracking:

---

## 🏗️ Pattern A: Real-Time Dashboards (Custom Log-Based Metrics)

To populate your dashboard with per-user data, we have configured and created the log-based metric **`user_tokens`** directly in your project. It queries your Cloud Logging entries and extracts custom fields and labels.

### 🛠️ Solution A1: No-Code Audit Logs (Request Counts) - *DEPLOYED!* ⚡
If you want to track developer request counts without changing any configurations or client code:
1. We verified that **Vertex AI Data Access Audit Logs are already enabled** in your project `coffee-and-codey` for `aiplatform.googleapis.com`.
2. We deployed the log-based metric `user_tokens` using our pre-built, hardened configuration:
   👉 **[user-tokens-audit-log.yaml](user-tokens-audit-log.yaml)**
3. When any developer runs local `agy` or `GeminiCLI` commands, the audit logs will automatically capture their email (`user_id`) and the model called (`model_id`), feeding them into Dashboard v2!

### 🏗️ Solution A2: Native Request-Response Logging (Exact Token Counts) 💎
If you want to track exact input, output, and cached token totals with zero intermediate servers:
1. Enable native request-response logging on your base models (detailed in [HOW_TO_COLLECT_USER_DATA.md](HOW_TO_COLLECT_USER_DATA.md)).
2. Update your `user_tokens` metric to extract exact token distributions from native OpenTelemetry logs using our configuration:
   👉 **[user-tokens-proxy.yaml](user-tokens-proxy.yaml)**
   ```bash
   gcloud logging metrics update user_tokens --config-from-file=user-tokens-proxy.yaml
   ```
3. Dashboard v2 will automatically detect and transition to exact token tracking graphs!

---

## 📊 Pattern B: Cost & Billing Allocation (BigQuery & Looker Studio)

If your goal is high-fidelity financial auditing, chargebacks, or cost attribution, you can use GEAP's native **BigQuery Request-Response Destination**. 

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
  `coffee-and-codey.cloudaudit_googleapis_com.data_access_*` AS audit
ON 
  JSON_EXTRACT_SCALAR(log.metadata, "$.request_id") = JSON_EXTRACT_SCALAR(audit.protopayload_auditlog.metadata, "$.request_id")
WHERE 
  _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE());
```

### Step 2: Build a Looker Studio Report
1. Open **Looker Studio** (formerly Data Studio).
2. Click **Create > Data Source** and select **BigQuery**.
3. Choose your project, dataset `vertex_logs`, and connect directly to the view `user_cost_attribution_report`.
4. Create charts (e.g. Pie Charts, Bar Charts, Tables) plotting `estimated_cost_usd` grouped by `user_id`.
5. Schedule monthly automated emails to send these reports directly to budget and department owners!

---

## 💰 Resource & Pricing Free-Tiers

| Log/Metric Source | Cost Structure | Pricing Free-Tier Rationale |
| :--- | :--- | :--- |
| **GCM System Metrics** | **$0.00** | Used by Dashboard v1. Built-in metrics are 100% free to query and store. |
| **Cloud Logging** | **$0.00** | First **50 GiB/month** per project is completely free. Overages are billed at $0.50/GiB. |
| **BigQuery Ingest & Store** | **$0.00** | BigQuery provides **10 GiB** of free storage and **1 TiB** of free query processing per month. |
| **Custom Log-Based Metrics** | **$0.00** | GCM custom metrics are free up to **150 MiB/month** per project. Overages are $0.30 per million samples. |
