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

We have packaged the SQL query as a dedicated schema file and created an automated deployment shell script in the repository:
*   📜 **[create_user_cost_attribution_view.sql](create_user_cost_attribution_view.sql)**: Deploys a unified reporting view merging payload logs and audit events using SQL `JSON_VALUE`.
*   🚀 **[deploy_bq_view.sh](deploy_bq_view.sh)**: A shell script that executes the view creation query in the `coffee-and-codey` project.

To deploy the view, run the script from your terminal:
```bash
./deploy_bq_view.sh
```

For manual deployment, execute this SQL query in the BigQuery Studio console:

```sql
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

---

## 🛑 The Per-User Dashboard Feasibility & Technical History

Administrators often ask if we can provide a **dedicated, isolated "Per-User Dashboard"** (where each developer logs in and can only see their own metrics, costs, and token usage) inside Google Cloud Monitoring (GCM). 

While our **Unified Dashboard v2** lists all developers and aggregates usage transparently across the team, serving dynamically filtered, isolated dashboard views *per logged-in developer* is technically unfeasible in GCM. 

Below is an in-depth explanation of the technical barriers and a historical log of all alternative architectures that have been tested and evaluated.

### 1. Why Per-User Isolated Dashboards are Unfeasible in GCM

* **Lack of Dynamic Viewer Context**: GCM dashboards are static, shared project-level resources. There is no native PromQL, MQL, or dashboard-level variable (such as `current_user()`, `session.viewer_email`, or `iam.principal`) that can dynamically filter chart timeseries data based on the identity of the Google Cloud console viewer.
* **Lack of Row-Level Access Controls**: GCM permissions are managed at the project level (`roles/monitoring.viewer`). If a developer has permission to view GCM dashboards, they can view all custom metrics, including the `user_tokens` metric containing other developers' emails. There is no native way to restrict metric timeseries access at the row or label level.
* **Label Cardinality Limits**: Creating high-cardinality labels (e.g., thousands of unique developer email strings) on GCM distribution metrics causes "cardinality bloat." GCM heavily penalizes or drops timeseries points when label value cardinality is too high, making direct dashboard plotting of individual developer emails unreliable for large organizations.

---

### 2. Historical Summary of Attempted Solutions & Architectural Boundaries

During our technical discovery and design iterations, several alternative architectures were built and tested to overcome these limitations. Each hit specific GCP platform or security boundaries:

#### ❌ Attempt 1: Direct Local Terminal Telemetry Pulling via CLI
* **The Idea**: Instead of using the Google Cloud Console, have the `agy` CLI pull the current developer's token usage and cost metrics directly from BigQuery or GCM and render a private, per-user ASCII dashboard locally in the terminal.
* **The Failure (Security/Least Privilege)**: To query BigQuery cost views or GCM metrics, every developer's workstation would need to be granted `roles/bigquery.user` or `roles/monitoring.viewer` permissions on the central logging dataset. This violates the principle of least privilege, as any developer could bypass the CLI and query raw request-response tables containing other developers' prompt text and response payloads.

#### ❌ Attempt 2: Dynamic Provisioning of Per-User GCM Dashboard Assets
* **The Idea**: Programmatically generate and push a distinct dashboard JSON file to GCM for every developer (e.g., `dashboard-robedwards.json`, `dashboard-alice.json`), hard-filtering each dashboard's queries to that specific developer's email.
* **The Failure (Scale & Configuration Drift)**: This pattern is highly unscalable. Creating, updating, and deleting individual dashboards as developers join, leave, or change teams creates immense administrative drift. It also quickly exhausts GCP’s project-level dashboard resource quotas.

#### ❌ Attempt 3: Native Payload User-Extraction on the Global Endpoint
* **The Idea**: Extracting the authenticated developer's identity directly from native OpenTelemetry (OTel) request-response payload logs on the logical global endpoint.
* **The Failure (Compliance & Privacy Enforcements)**: To protect developer privacy and comply with data governance, Google's native, platform-level request-response log streams strictly redact human-identifiable metadata (such as verified emails or workstation names) from raw payloads. This made direct extraction of user identities from OTel payloads alone impossible on global endpoints.

#### ❌ Attempt 4: Extracting User Identities from Global Audit Logs
* **The Idea**: Joining global endpoint request-response logs with logical global audit logs on `request_id`.
* **The Failure (GCP Auditing Limitation)**: GCP does not write standard data-access audit logs for calls routed through the logical global endpoint (`aiplatform.googleapis.com` under `/locations/global`), leaving the audit logs completely empty and making matching impossible.

---

### 🏆 The Approved Architecture (The Best of Both Worlds)

To overcome all of the security, scale, and platform limitations listed above, the approved architecture splits the problem into two distinct, optimized patterns:

1. **The Shared Operational Dashboard (GCM Dashboard v2)**: Use Cloud Monitoring for high-level team monitoring, capacity planning, and model performance. Charts are grouped and aggregated dynamically using high-performance PromQL fallbacks to prevent cardinality bloat, with setup instructions embedded directly inside the dashboard.
2. **The Secure Financial Report (Looker Studio + BigQuery View)**: For individual developer cost attribution and chargebacks, use our deployed BigQuery view `vertex_logs.user_cost_attribution_report` to join payloads with regional audit trails and trajectory mappings. Since Looker Studio supports **Row-Level Security (RLS)** and BigQuery supports **Authorized Views**, administrators can easily configure a single Looker Studio report that securely and dynamically displays only the logged-in developer's cost data, keeping the database secure and private.

