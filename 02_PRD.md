# ☕ Stage 2: Product Requirements Document (PRD)

## 1. Product Overview & Context

This product consists of Developer AI Tools Monitoring Dashboards and custom log-based metric templates that provide team leads and platform administrators visibility into model invocations, token consumption, response speeds, cost, and rate-limit experiences of developers calling the Vertex AI/Agent Platform (GEAP) API.

## 2. Problem Statement

While Dashboard v1 (Aggregate Cost & Usage) has been migrated to PromQL, Dashboard v2 (User Token Tracker) uses standard GCM filters with incompatible metrics and aggregation aligners, resulting in:
1.  **Dashboard Crash**: If the lightweight proxy (Option 2) is used, the metric `user_tokens` is a `DISTRIBUTION`. Plotting a distribution metric on a standard line/bar chart using standard GCM filters and `ALIGN_RATE`/`ALIGN_SUM` crashes Google Cloud Monitoring.
2.  **Misleading Displays**: If no-code audit logs (Option 1) are used, the metric is an `INT64` counter representing request counts. However, the charts display these counts on "Token Consumption" charts with "Tokens" as the axis units, leading users to believe they are consuming single-digit token amounts.
3.  **Ambiguity & Potential Drift**: Small bugs and omissions in the configuration files (`user-tokens-proxy.yaml`, `user-tokens-audit-log.yaml`) and proxy documentation lead to operator precedence risks, case-sensitivity issues, and API mismatches.

## 3. Goals & Non-Goals

### Goals
*   **Zero-Crash Dashboard v2**: Ensure Dashboard v2 renders 100% of the time, regardless of whether Option 1 (Audit log) or Option 2 (Proxy) is deployed.
*   **Dynamic Fallback Support**: Build a single Dashboard v2 configuration file using PromQL that dynamically detects which metric schema is active (Proxy vs. Audit Logs), plotting exact token volumes if available, and gracefully falling back to request volumes otherwise.
*   **Clear and Correct Labeling**: Clearly label axes and titles so that the viewer always understands whether they are seeing actual token counts or request counts.
*   **Robust Configuration Templates**: Fix operator precedence and case-sensitivity issues in log-based metric templates.
*   **Premium Proxy Reference Code**: Provide a clean, robust FastAPI template in `HOW_TO_COLLECT_USER_DATA.md` that correctly parses project/location and matches raw Vertex AI REST response payloads.

### Non-Goals
*   Deploying live cloud infrastructure automatically (we are maintaining the dashboard and metric templates).
*   Rewriting Dashboard v1 (which is fully functional and migrated).

## 4. Key Personas & Target Users

*   **Platform / DevOps Engineers**: Need robust, crash-free dashboards to monitor Developer AI API activity, predict rate limits, and isolate user-induced latency bottlenecks.
*   **Engineering Leads & Budget Owners**: Need clear, accurate, and non-misleading visual data on token consumption and request distributions across team members to manage costs and allocate chargebacks.

## 5. Requirements & Acceptance Criteria

### In-Scope
*   **Dashboard v2 Migration**: Upgrade `geap-monitoring-dashboard-v2.json` to PromQL. Use PromQL's `or` logical fallback pattern to support both `DISTRIBUTION` and `INT64` metric schemas.
*   **Metric Schema Adjustments**: Add explicit parentheses and update method cases in `user-tokens-proxy.yaml` and `user-tokens-audit-log.yaml` for maximum robustness.
*   **Documentation Alignments**: Ensure `HOW_TO_COLLECT_USER_DATA.md` and `USER_AND_USAGE_TRACKING_GUIDE.md` describe the updated PromQL fallback behavior and fix proxy Python deficiencies.

### Acceptance Criteria

| ID | Requirement | Acceptance Criteria |
| :--- | :--- | :--- |
| **AC-1** | **No GCM Crashes** | Dashboard v2 renders cleanly with no errors when queried against a `DISTRIBUTION` metric schema (Option 2). |
| **AC-2** | **Dynamic Fallback** | All charts on Dashboard v2 automatically display exact token metrics if `logging_googleapis_com:user_user_tokens_sum` exists, and automatically fall back to request volume metrics (`logging_googleapis_com:user_user_tokens`) if it does not. |
| **AC-3** | **Transparent Labeling** | Every chart title and Y-axis label clearly indicates that it is plotting "Tokens (or Requests if using No-Code Audit Logs)" so the user is never misled. |
| **AC-4** | **Config Robustness** | Ingestion templates are fully valid, include explicit logical grouping parentheses, and use correct case-sensitive gRPC method names. |
| **AC-5** | **Proxy Reliability** | Python FastAPI code in `HOW_TO_COLLECT_USER_DATA.md` instantiates client dynamically with project/location parameters and conforms with raw Vertex AI JSON REST format. |
