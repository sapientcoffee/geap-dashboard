# ☕ Stage 3: Extraction (Dashboard Audit & Codebase Research)

This document contains a comprehensive, blind, factual audit of the Google Cloud Monitoring dashboards, log-based metrics, and support configurations in this repository to identify any errors, incorrect collection/display patterns, or inconsistencies.

---

## 🔍 Executive Summary of Findings

Our deep-dive audit of the active dashboard files, log-based metrics, and documentation guides has uncovered several critical inconsistencies and design issues:

1.  **Dashboard v2 Rendering Crash (Option 2 - Proxy)**:
    *   **The Bug**: Under **Option 2 (Logging Proxy)**, the `user_tokens` custom metric is ingested with `valueType: "DISTRIBUTION"`. However, the GCM widgets in `geap-monitoring-dashboard-v2.json` attempt to apply scalar aligners (`ALIGN_RATE` and `ALIGN_SUM`) directly to this distribution metric on a standard `LINE` or `STACKED_BAR` chart.
    *   **Impact**: Google Cloud Monitoring cannot natively render distribution metrics on standard line/bar charts without a scalar conversion function (like percentiles or mean). Trying to apply `ALIGN_RATE` or `ALIGN_SUM` to a `DISTRIBUTION` metric on these charts will throw an API error and **fail to render or crash the dashboard entirely**.

2.  **Dashboard v2 Misleading Labels (Option 1 - Audit Logs)**:
    *   **The Inconsistency**: Under **Option 1 (No-Code Audit Logs)**, the `user_tokens` custom metric is ingested with `valueType: "INT64"`. Because audit logs do not capture payload data, the metric behaves as a counter of **request counts** (incrementing by 1 for each API call).
    *   **Impact**: The dashboard widgets are titled "Token Consumption by User (Over Time)" and "Total Tokens Consumed per User" with axes labeled "Tokens". A developer who made 5 requests will see "5 Tokens" on the chart, which is highly misleading (since those requests actually consumed thousands of tokens).

3.  **Ambiguous Filter Precedence in `user-tokens-proxy.yaml`**:
    *   **The Bug**: Line 17 of `user-tokens-proxy.yaml` defines the filter as:
        `filter: 'resource.type="global" OR resource.type="cloud_run_revision" AND jsonPayload.event="gemini_call"'`
    *   **Impact**: Because of logical operator precedence rules in Cloud Logging and common developer misunderstandings, omitting parentheses is risky. This is parsed as matching *all* `global` resource logs, regardless of whether they have `jsonPayload.event="gemini_call"`, polluting the metric and bloating ingestion costs.

4.  **Case-Sensitivity Risk in `user-tokens-audit-log.yaml`**:
    *   **The Issue**: Line 17 filters by `protoPayload.methodName:"generateContent" OR protoPayload.methodName:"predict"`.
    *   **Impact**: The actual gRPC service methods logged in Cloud Audit Logs are `GenerateContent` and `Predict` (with capital G and P). Although substring searches using `:` are currently case-insensitive, relying on lowercase substrings is bad practice and highly vulnerable to future platform behavior changes.

5.  **Python Proxy Issues in `HOW_TO_COLLECT_USER_DATA.md`**:
    *   **The Defects**:
        1. The FastAPI proxy initializes `client = genai.Client()` globally, which fails to dynamically configure the project and location based on the incoming route parameters `{project}` and `{location}`.
        2. The return statement `return response.model_dump()` returns the SDK's internal dictionary structure (which may have camelCase/snake_case discrepancies or custom fields) rather than the standard, exact raw Vertex AI JSON REST format expected by local developer runtimes.

---

## 🛠️ The Solution: PromQL Migration & Fallback Scheme

To solve both Dashboard v2 bugs cleanly, we can **migrate Dashboard v2 to PromQL**, just like we successfully did for Dashboard v1. 

PromQL provides native, robust distribution-to-scalar suffixes (`_sum` and `_count`):
*   `logging_googleapis_com:user_user_tokens_sum`: Total token counts (available under Option 2).
*   `logging_googleapis_com:user_user_tokens_count`: Total request counts (available under Option 2).
*   `logging_googleapis_com:user_user_tokens`: Total request counts (available under Option 1).

### The PromQL fallback pattern
By leveraging PromQL's logical `or` fallback operator, we can design a single dashboard config that handles BOTH Option 1 and Option 2 elegantly!

1.  **Token/Request Rate over Time (Widget 2)**:
    ```promql
    sum(rate(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id) 
    or 
    sum(rate(logging_googleapis_com:user_user_tokens[1m])) by (user_id)
    ```
    *   *If Option 2 is deployed*: Renders actual token rate (Tokens/Second).
    *   *If Option 1 is deployed*: Renders request rate (Requests/Second).
    *   *Axis Label*: Updated to `"Tokens / Second (or Requests / Second)"`.

2.  **Total Consumed per User (Widget 3 - Stacked Bar)**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id) 
    or 
    sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (user_id)
    ```

3.  **API Requests count by User (Widget 4 - Line)**:
    ```promql
    sum(rate(logging_googleapis_com:user_user_tokens_count[1m])) by (user_id) 
    or 
    sum(rate(logging_googleapis_com:user_user_tokens[1m])) by (user_id)
    ```

4.  **Model Types Utilized by User (Widget 5 - Stacked Bar)**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id, model_id) 
    or 
    sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (user_id, model_id)
    ```

5.  **Total Tokens/Requests per User per Model (Widget 6 - Table Summary)**:
    We'll configure `"outputFullDuration": true` inside the chart and use the dynamic `${__interval}` range:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum[${__interval}])) by (user_id, model_id) 
    or 
    sum(increase(logging_googleapis_com:user_user_tokens[${__interval}])) by (user_id, model_id)
    ```

6.  **Total Invocations/Tokens by Model (Widget 7 - Stacked Bar)**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (model_id) 
    or 
    sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (model_id)
    ```

---

## 📋 Comprehensive Checklist of File Adjustments Needed

| File Path | Description of Necessary Changes |
| :--- | :--- |
| `geap-monitoring-dashboard-v2.json` | 1. Migrate all 6 metric widgets from standard filters to robust, fallback PromQL queries.<br>2. Update title names, descriptions, and Y-axis labels to dynamically reflect either Tokens or Requests depending on setup.<br>3. Set `"outputFullDuration": true` for Widget 6 (Table Summary) to work beautifully with dynamic timeframe selector. |
| `user-tokens-audit-log.yaml` | 1. Update filter to match exact camelCase method names (`GenerateContent` and `Predict`) rather than lowercase.<br>2. Add Apache 2.0 Google license header. |
| `user-tokens-proxy.yaml` | 1. Add explicit parentheses to filter logic to avoid operator precedence ambiguities:<br>`(resource.type="global" OR resource.type="cloud_run_revision") AND jsonPayload.event="gemini_call"`<br>2. Add Apache 2.0 Google license header. |
| `HOW_TO_COLLECT_USER_DATA.md` | 1. Refactor FastAPI proxy code to instantiate the GenAI Client dynamically inside the route handler with incoming project/location params.<br>2. Update proxy response mapping to return the exact structure expected by client runtimes.<br>3. Update guide notes to explain PromQL improvements and dynamic fallback features in Dashboard v2. |
| `USER_AND_USAGE_TRACKING_GUIDE.md` | 1. Update guide notes to reflect PromQL integration, fallback behavior, and metric updates in Dashboard v2. |
