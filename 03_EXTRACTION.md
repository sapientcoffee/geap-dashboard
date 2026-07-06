# ☕ Stage 3: Extraction (Codebase Research & Fact Mapping)

This document maps out the available metric namespaces, labels, and the PromQL query structures required to implement developer-level cost tracking and per-user model breakdown widgets on Dashboard v2.

---

## 1. Metric Namespaces & Schemas

GCM exposes custom logs-based metrics under the `logging_googleapis_com` prefix in Prometheus representations.

### 1.1 Ingestion Option 1: No-Code Audit Logs
*   **Metric Name**: `logging_googleapis_com:user_user_tokens`
*   **Resource Type**: `audited_resource`
*   **Metric Type**: `DELTA` (scalar counter)
*   **Labels**:
    *   `user_id`: Principal email of caller (GCP identity).
    *   `model_id`: Model path/identifier (extracted from resource name).
*   **Behavior**: Represents request count (increments by 1 for each API call).

### 1.2 Ingestion Option 2: Native request-response logging
*   **Metric Name**: `logging_googleapis_com:user_user_tokens`
*   **Resource Type**: `aiplatform.googleapis.com/PublisherModel`
*   **Metric Type**: `DISTRIBUTION` (histogram of token counts)
*   **Synthesized Scalar Suffixes (PromQL)**:
    *   `logging_googleapis_com:user_user_tokens_sum`: Accumulates total tokens (`totalTokens` from OpenTelemetry payloads).
    *   `logging_googleapis_com:user_user_tokens_count`: Accumulates request count.
*   **Labels**:
    *   `user_id`: Authenticated email of caller.
    *   `model_id`: Model ID called.

---

## 2. Pricing Multiplier Modeling

Since `user_user_tokens_sum` accumulates total tokens (both input and output combined as `totalTokens`), we define a **Blended Pricing Multiplier** for each model type based on a typical developer workload proportion (80% input tokens, 20% output tokens):

### 2.1 Option 2 (Exact Token Counts) Blended Multipliers
1.  **Gemini 3.5 Flash**: 
    *   Input Rate: `$1.50 / 1M` ($0.00000150)
    *   Output Rate: `$9.00 / 1M` ($0.00000900)
    *   Blended Rate (80/20): **`$3.00 / 1M`** (multiplier `0.00000300`)
2.  **Gemini 3.1 Pro**:
    *   Input Rate: `$2.00 / 1M` ($0.00000200)
    *   Output Rate: `$12.00 / 1M` ($0.00001200)
    *   Blended Rate (80/20): **`$4.00 / 1M`** (multiplier `0.00000400`)
3.  **Gemini 1.5 & 2.5 Flash**:
    *   Input Rate: `$0.075 / 1M` ($0.000000075)
    *   Output Rate: `$0.30 / 1M` ($0.00000030)
    *   Blended Rate (80/20): **`$0.12 / 1M`** (multiplier `0.00000012`)
4.  **Gemini 1.5 Pro**:
    *   Input Rate: `$1.25 / 1M` ($0.00000125)
    *   Output Rate: `$5.00 / 1M` ($0.00000500)
    *   Blended Rate (80/20): **`$2.00 / 1M`** (multiplier `0.00000200`)

### 2.2 Option 1 (No-Code Audit Logs) Fallback Cost-Per-Request Multipliers
Since Option 1 only records request counts, we assume an average developer conversation size of **5,000 tokens** per invocation to compute cost estimates:
1.  **Gemini 3.5 Flash**: `5,000 tokens * 0.00000300 = $0.015` per request (multiplier `0.015`)
2.  **Gemini 3.1 Pro**: `5,000 tokens * 0.00000400 = $0.020` per request (multiplier `0.020`)
3.  **Gemini 1.5 & 2.5 Flash**: `5,000 tokens * 0.00000012 = $0.0006` per request (multiplier `0.0006`)
4.  **Gemini 1.5 Pro**: `5,000 tokens * 0.00000200 = $0.010` per request (multiplier `0.010`)

---

## 3. PromQL Math & Vector Union Design

### 3.1 The PromQL Addition Trap
When adding multiple vectors (e.g., `A + B + C`), if any operand is empty/null (e.g., no user has called `gemini-3.1-pro` yet, so that term evaluates to nothing), the entire addition evaluates to empty. 

### 3.2 Mitigation Pattern
By preserving the `model_id` label in our inner queries, joining them with the `or` operator (which forms a union of all active series), and then summing the result `by (user_id)` at the outermost layer, we can aggregate costs perfectly without losing series due to missing operands!

```promql
sum(
  (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*gemini-3.5-flash.*"}[${__interval}])) by (user_id, model_id) * 0.00000300) or
  (sum(increase(logging_googleapis_com:user_user_tokens_sum{model_id=~".*gemini-3.1-pro.*"}[${__interval}])) by (user_id, model_id) * 0.00000400) or
  ...
) by (user_id)
```
Since the `model_id` labels are distinct, the `or` union retains all present series for a given user, and the outer `sum(...) by (user_id)` aggregates them safely.

---

## 4. GCM Schema Fields

To render tables responsive to time ranges selected in GCM dashboards, we must use:
- `"outputFullDuration": true`: Instructs GCM to output a single scalar value summed over the chosen time range.
- `[${__interval}]` range vector: Directs GCM to aggregate values over the dashboard's active duration window.

---

## 5. Location Auditing & GCM Metrics Extraction Fact
*   **The Global Location Auditing Gap**: Calls made to the logical `locations/global` endpoint do not publish Data Access `DATA_READ` audit logs to Cloud Logging.
*   **Regional Endpoint Auditing**: Regional endpoints (such as `locations/us-central1`) write complete Data Access audit logs containing caller identities (`principalEmail`).
*   **Metric Mapping**: The custom log-based metric `user_tokens` under Option 1 (No-Code Audit Logs) filters by `protoPayload.serviceName="aiplatform.googleapis.com"`. Since global calls do not write audit logs, they are invisible to the metric filter and do not appear in GCM timeseries, resulting in blank lines on GCM Dashboard v2. Shifting calls to regional locations (like `us-central1`) ensures 100% of invocations are tracked.
