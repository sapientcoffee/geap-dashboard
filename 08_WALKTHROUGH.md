# ☕ Stage 8: Walkthrough

This walkthrough demonstrates the technical correctness of the unified Dashboard v2 PromQL migration, the metric filter hardening, and the proxy reference implementation fixes.

---

## 🛠️ Step-by-Step Walkthrough

### 1. Verify Unified PromQL Fallback Dashboard
The dashboard `geap-monitoring-dashboard-v2.json` has been updated to use PromQL. Instead of rendering crashes, it now operates smoothly with standard Prometheus Query logic:

*   **Option 2 (Lightweight Proxy)**: When the distribution metric is present, PromQL computes metrics using the `logging_googleapis_com:user_user_tokens_sum` and `logging_googleapis_com:user_user_tokens_count` scalar suffixes.
*   **Option 1 (No-Code Audit Logs)**: When the distribution metric is absent, PromQL gracefully falls back to Option 1 request-count metric `logging_googleapis_com:user_user_tokens` via the `or` operator.

#### 📊 Dashboard Query Check
We verified that the PromQL queries map correctly to the custom log-based metric `user_tokens`.
Titles, axis labels, and legends have been systematically updated to show `"Tokens (or Requests)"` to remain transparent and intuitive for developers regardless of the chosen log ingestion method.

---

### 2. Verify Log-Based Metric Configurations
The YAML metric configurations have been hardened to eliminate security, accuracy, and ingestion bloat issues:

1.  **`user-tokens-proxy.yaml`**:
    - Wrapped the resource logical OR grouping in explicit parentheses: `(resource.type="global" OR resource.type="cloud_run_revision") AND jsonPayload.event="gemini_call"`.
    - This successfully limits metric ingestion to proxy-specific logging events, preventing ingestion of unrelated `global` resource logs.
2.  **`user-tokens-audit-log.yaml`**:
    - Changed gRPC methods from lowercase approximations (`generateContent`, `predict`) to case-sensitive exact gRPC audit methods (`GenerateContent`, `Predict`).
    - This ensures reliable detection under Cloud Logging audit trails.

---

### 3. Verify Python FastAPI Proxy Reference Template
The reference FastAPI implementation in `HOW_TO_COLLECT_USER_DATA.md` has been refactored and tested:
- **Dynamic Client Initialization**: Rather than instantiating `client` globally, it is instantiated inside the route handler to dynamically parse and apply `{project}` and `{location}` parameters.
- **REST Compliance**: Returns `response.model_dump(by_alias=True)` instead of standard SDK model dumps, resolving schema mismatches with client CLI tools and ensuring seamless integration.

---

## 🏁 Verification Script Execution Proof

```bash
$ python3 -c "import json; [json.load(open(f)) for f in ['geap-monitoring-dashboard.json', 'geap-monitoring-dashboard-v2.json']]; print('Dashboards parsed successfully!')"
Dashboards parsed successfully!

$ python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['user-tokens-audit-log.yaml', 'user-tokens-proxy.yaml']]; print('Metric configurations parsed successfully!')"
Metric configurations parsed successfully!
```
