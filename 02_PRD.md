# ☕ Stage 2: Product Requirements Document (PRD)

## 1. Product Overview & Context

This product consists of Developer AI Tools Monitoring Dashboards and custom log-based metric templates that provide team leads and platform administrators visibility into model invocations, token consumption, response speeds, cost, and rate-limit experiences of developers calling the Vertex AI/Agent Platform (GEAP) API. 

This enhancement extends **Dashboard v2 (User Token Tracker)** to support fine-grained, real-time developer-level cost tracking and clear model-specific token breakdowns.

---

## 2. Problem Statement

1.  **Dashboard Empty/Missing Data**: Standard local developer SDK or CLI (`agy`, `GeminiCLI`) calls directly query Vertex AI. Because Google Cloud does not natively write prompt payloads or token count metadata to standard Cloud Logging for privacy/security reasons, standard time-series dashboards are empty by default.
2.  **Lack of Developer Cost Attribution**: While administrators can track aggregate cost trends in Dashboard v1, they cannot see real-time estimated costs mapped directly to individual developers in Dashboard v2. This makes it impossible to quickly identify which specific user is driving high spend or to perform real-time internal billing allocations.
3.  **Ambiguity in Per-User Model Token Utilization**: While request rates are visible, a dedicated, high-fidelity view of exact token consumption per user, clearly broken down by model type, is missing. This is critical for assessing model selection efficiency across different engineering teams.
4.  **Global Endpoint Audit Limitations**: In addition to standard payload omissions, calls targeting the logical `locations/global` multi-region endpoint do not write standard `DATA_READ` audit logs to Cloud Logging. This means GCM custom log-based metrics cannot extract user emails, causing user tracker dashboards to remain completely blank.

---

## 3. Goals & Non-Goals

### Goals
*   **Real-time Developer Cost Attribution**: Add real-time cost charts (over time) and tables (timeframe-responsive summaries) to Dashboard v2 to track estimated spend (in USD) for each individual developer.
*   **Per-User Token Breakdown by Model**: Provide explicit, dedicated visualizations demonstrating exactly how many tokens (or fallback request volumes) each developer consumed on each specific model.
*   **Zero-Crash PromQL Fallbacks**: Retain and expand the unified PromQL fallback scheme (`or` operator) to support both Audit Log counters (Option 1) and exact distribution metrics (Option 2) seamlessly across all new widgets.
*   **Standardized Blended Pricing**: Implement correct standard price multipliers for developer models (Gemini 3.5 Flash, 3.1 Pro, etc.) scaled by typical workload splits for unified `totalTokens` tracking.
*   **Regional Endpoint Configuration Guidance**: Document the mandatory client-side regional configuration for tools like the Antigravity CLI (`agy`) to ensure consistent data access audit logs are written for GCM and BigQuery user tracking.

### Non-Goals
*   Querying official Google Cloud billing invoices directly (we track estimated costs based on ingestion metrics).
*   Supporting tracking of unauthenticated requests (all calls are traced back to a verified corporate Google account email via IAM).

---

## 4. Key Personas & Target Users

*   **Engineering Leads & Budget Owners**: Need clear, real-time dashboards to understand which developers are calling which models, how many tokens they are consuming, and how much their activity is costing the organization in real-time.
*   **Platform / DevOps Engineers**: Need robust, low-overhead dashboards that automatically work under either ingestion architecture (Audit Logs vs. Native request-response logs).

---

## 5. Requirements & Acceptance Criteria

### In-Scope
*   **Developer Cost-over-Time Widget**: A new XYChart (Line) in Dashboard v2 plotting real-time estimated USD cost per minute per user.
*   **Developer Total Cost Summary Widget**: A new TimeSeriesTable with `outputFullDuration: true` displaying the cumulative USD cost for each developer over the selected timeframe with an explicit `"USD"` currency column.
*   **Enhanced Per-User Model Breakdowns**: Refine and rename the per-user model breakdown tables and charts to make per-user token volumes by model incredibly prominent and easy to read.

### Acceptance Criteria

| ID | Requirement | Acceptance Criteria |
| :--- | :--- | :--- |
| **AC-1** | **No GCM Crashes** | Dashboard v2 renders cleanly with no errors when queried against a `DISTRIBUTION` metric schema (Option 2). |
| **AC-2** | **Dynamic Fallback** | All charts on Dashboard v2 automatically display exact token metrics if the native OTel metric exists, and fall back to request volumes if it does not. |
| **AC-3** | **Pre-Auth Enforced** | All local tools authenticate developers using native Google Cloud IAM (e.g. ADC) before a model request is processed. |
| **AC-4** | **Developer Cost Over Time** | Line chart dynamically sums and plots estimated USD cost per minute per user using correct pricing formulas. |
| **AC-5** | **Developer Total Cost Summary** | A timeframe-responsive table sums and lists total USD cost per user, displaying user IDs, total costs, and an explicit `"USD"` currency column. |
| **AC-6** | **Per-User Token Consumption** | Dedicated table and bar chart clearly show exact token count consumption per user, broken down by model ID. |
