# ☕ Stage 4: Technical Specification

This technical specification outlines the design, query architectures, and dashboard layout parameters to extend GCM Dashboard v2 (User Token Tracker) with real-time user-level cost estimation and robust model consumption tracking.

---

## 1. Unified PromQL Ingest Fallbacks

All widgets in Dashboard v2 must support both **No-Code Audit Logs (Option 1)** and **Native request-response logging (Option 2)**. This is accomplished using PromQL's `or` logical fallback operator:

```promql
<Option_2_Exact_Token_Query> or <Option_1_Request_Count_Query>
```

---

## 2. Real-Time Cost Estimation Equations

Since Option 2 tracks `totalTokens` and Option 1 tracks requests, we define specific pricing multiplier coefficients:

### 2.1 Option 2 (Exact Token Counts) - Blended Pricing ($ per token)
*   **Gemini 3.5 Flash**: `$0.00000300` ($3.00 per 1M tokens)
*   **Gemini 3.1 Pro**: `$0.00000400` ($4.00 per 1M tokens)
*   **Gemini 1.5 & 2.5 Flash**: `$0.00000012` ($0.12 per 1M tokens)
*   **Gemini 1.5 Pro**: `$0.00000200` ($2.00 per 1M tokens)

### 2.2 Option 1 (No-Code Audit Logs) - Fallback Cost-Per-Request ($ per request)
*   **Gemini 3.5 Flash**: `$0.01500000` ($15.00 per 1k requests)
*   **Gemini 3.1 Pro**: `$0.02000000` ($20.00 per 1k requests)
*   **Gemini 1.5 & 2.5 Flash**: `$0.00060000` ($0.60 per 1k requests)
*   **Gemini 1.5 Pro**: `$0.01000000` ($10.00 per 1k requests)

---

## 3. Detailed Widget Specifications

### 3.1 New Widget: Developer Cost over Time
*   **Title**: `"Real-Time Estimated Cost (USD) per User (Over Time) [ESTIMATED COSTS]"`
*   **Type**: `xyChart` (Line)
*   **Y-Axis Label**: `"Estimated Cost (USD) / Minute"`
*   **PromQL Query**:
    ```promql
    sum(
      (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*gemini-3.5-flash.*"}[1m])) by (user_id, model_id) * 0.00000300) or
      (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*gemini-3.1-pro.*"}[1m])) by (user_id, model_id) * 0.00000400) or
      (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*(gemini-1.5-flash|gemini-2.5-flash).*"}[1m])) by (user_id, model_id) * 0.00000012) or
      (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*gemini-1.5-pro.*"}[1m])) by (user_id, model_id) * 0.00000200) or
      (sum(increase(logging_googleapis_com:user_user_tokens{model_id=~".*gemini-3.5-flash.*"}[1m])) by (user_id, model_id) * 0.01500000) or
      (sum(increase(logging_googleapis_com:user_user_tokens{model_id=~".*gemini-3.1-pro.*"}[1m])) by (user_id, model_id) * 0.02000000) or
      (sum(increase(logging_googleapis_com:user_user_tokens{model_id=~".*(gemini-1.5-flash|gemini-2.5-flash).*"}[1m])) by (user_id, model_id) * 0.00060000) or
      (sum(increase(logging_googleapis_com:user_user_tokens{model_id=~".*gemini-1.5-pro.*"}[1m])) by (user_id, model_id) * 0.01000000)
    ) by (user_id)
    ```

### 3.2 New Widget: Developer Total Cost Summary Table
*   **Title**: `"Total Estimated Cost (USD) per User (Selected Timeframe) [ESTIMATED COSTS]"`
*   **Type**: `timeSeriesTable`
*   **Settings**: `"outputFullDuration": true`, `"metricVisualization": "NUMBER"`
*   **PromQL Query**:
    ```promql
    label_replace(
      sum(
        (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*gemini-3.5-flash.*"}[${__interval}])) by (user_id, model_id) * 0.00000300) or
        (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*gemini-3.1-pro.*"}[${__interval}])) by (user_id, model_id) * 0.00000400) or
        (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*(gemini-1.5-flash|gemini-2.5-flash).*"}[${__interval}])) by (user_id, model_id) * 0.00000012) or
        (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*gemini-1.5-pro.*"}[${__interval}])) by (user_id, model_id) * 0.00000200) or
        (sum(increase(logging_googleapis_com:user_user_tokens{model_id=~".*gemini-3.5-flash.*"}[${__interval}])) by (user_id, model_id) * 0.01500000) or
        (sum(increase(logging_googleapis_com:user_user_tokens{model_id=~".*gemini-3.1-pro.*"}[${__interval}])) by (user_id, model_id) * 0.02000000) or
        (sum(increase(logging_googleapis_com:user_user_tokens{model_id=~".*(gemini-1.5-flash|gemini-2.5-flash).*"}[${__interval}])) by (user_id, model_id) * 0.00060000) or
        (sum(increase(logging_googleapis_com:user_user_tokens{model_id=~".*gemini-1.5-pro.*"}[${__interval}])) by (user_id, model_id) * 0.01000000)
      ) by (user_id),
      "currency", "USD", "user_id", ".*"
    )
    ```

---

## 4. Layout & Grid Specification

The GCM grid is structured using `"columns": "2"`.
*   **Row 1**: Setup Guide (Full Width)
*   **Row 2**: Token Consumption over Time & Total Tokens per User
*   **Row 3**: API Requests Rate & Model Types Utilized per User
*   **Row 4**: Per-User Token Consumption by Model (Table) & Total Model Invocations (All Users)
*   **Row 5**: Real-Time User Cost over Time & User Cost Summary Table (New Rows)

---

## 5. Client-Side Location Specification (Antigravity CLI)
To ensure developer calls are fully captured by regional GCM metric ingestion schemas and generate required audit logs, clients must target a regional endpoint rather than logical global multi-regions:
*   **Target File**: `~/.gemini/antigravity-cli/settings.json`
*   **JSON Path**: `$.gcp.location`
*   **Value Requirement**: Must be updated from `"global"` to a regional endpoint (e.g. `"us-central1"`).
   ```json
   "gcp": {
     "project": "coffee-and-codey",
     "location": "us-central1"
   }
   ```

---

## 6. BigQuery Cost Attribution View & Deployment Script Spec
To ensure high-fidelity financial auditability:
1.  **View SQL Spec (`create_user_cost_attribution_view.sql`)**:
    *   Defines a standard `CREATE OR REPLACE VIEW` statement targeting the dataset/view `vertex_logs.user_cost_attribution_report`.
    *   Uses Standard GoogleSQL `JSON_VALUE` for parsing scalar keys from nested JSON.
    *   Applies standard list pricing calculations for input and output tokens:
        *   Gemini 3.5 Flash: $0.00000150 (input), $0.00000900 (output)
        *   Gemini 3.1 Pro: $0.00000200 (input), $0.00001200 (output)
        *   Gemini 2.5 Flash: $0.000000075 (input), $0.00000030 (output)
        *   Gemini 1.5 Pro: $0.00000125 (input), $0.00000500 (output)
2.  **Deploy Script Spec (`deploy_bq_view.sh`)**:
    *   Target shell: Bash.
    *   Authenticates and executes view code via standard `bq query --project_id=coffee-and-codey --use_legacy_sql=false` using file input redirection.

