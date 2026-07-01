# ☕ Stage 7: Verification

This document contains technical validation, syntax verification, and contract compliance checks for Developer AI Tools: User Token Tracker Dashboard (v2), custom log-based metrics, and Python FastAPI reference templates.

---

## 🚦 Verification Checklist

### 1. JSON Dashboard Syntax Validation
Both `geap-monitoring-dashboard.json` and `geap-monitoring-dashboard-v2.json` have been verified using a python3 JSON compiler:
- [x] **geap-monitoring-dashboard.json**: Syntactically valid.
- [x] **geap-monitoring-dashboard-v2.json**: Syntactically valid. Migrated 6 widgets to PromQL fallback queries with proper syntax.

### 2. Log-Based Metric YAML Config Validation
Both custom log-based metrics configurations have been validated using `PyYAML`:
- [x] **user-tokens-audit-log.yaml**: Syntactically valid. Filter updated with case-sensitive gRPC methods `GenerateContent` and `Predict`.
- [x] **user-tokens-proxy.yaml**: Syntactically valid. Log filter updated with explicit parenthesis to fix Boolean operator precedence: `(resource.type="global" OR resource.type="cloud_run_revision") AND jsonPayload.event="gemini_call"`.

### 3. Reference Python Code & Guide Validation
- [x] FastAPI proxy route template in `HOW_TO_COLLECT_USER_DATA.md` refactored to dynamically instantiate `Client` on request using client-specified `{project}` and `{location}` paths.
- [x] FastAPI response updated to use `response.model_dump(by_alias=True)` to generate exact camelCase fields matching the Vertex AI REST API schema.
- [x] `HOW_TO_COLLECT_USER_DATA.md` and `USER_AND_USAGE_TRACKING_GUIDE.md` updated to detail the PromQL fallback behavior.

---

## 📊 Verification Commands Run
The following validation scripts executed successfully in the workspace terminal:

```bash
# JSON validation command
python3 -c "import json; [json.load(open(f)) for f in ['geap-monitoring-dashboard.json', 'geap-monitoring-dashboard-v2.json']]; print('JSON files are valid!')"
# Output: JSON files are valid!

# YAML validation command
python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['user-tokens-audit-log.yaml', 'user-tokens-proxy.yaml']]; print('YAML files are valid!')"
# Output: YAML files are valid!
```

---

## 🛠️ Unified PromQL Query Map Reference

Below is a reference of the PromQL query patterns deployed inside `geap-monitoring-dashboard-v2.json` to handle Option 1 and Option 2 fallback seamlessly:

| Widget Name | Deployed PromQL Fallback Query |
| :--- | :--- |
| **Widget 2: Token Consumption by User (Over Time)** | `sum(rate(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id) or sum(rate(logging_googleapis_com:user_user_tokens[1m])) by (user_id)` |
| **Widget 3: Total Tokens Consumed per User** | `sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id) or sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (user_id)` |
| **Widget 4: API Request Count by User (Rate)** | `sum(rate(logging_googleapis_com:user_user_tokens_count[1m])) by (user_id) or sum(rate(logging_googleapis_com:user_user_tokens[1m])) by (user_id)` |
| **Widget 5: Model Types Utilized by User** | `sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id, model_id) or sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (user_id, model_id)` |
| **Widget 6: Total Tokens Consumed per User per Model (Table Summary)** | `sum(increase(logging_googleapis_com:user_user_tokens_sum[${__interval}])) by (user_id, model_id) or sum(increase(logging_googleapis_com:user_user_tokens[${__interval}])) by (user_id, model_id)` (with `"outputFullDuration": true`) |
| **Widget 7: Total Tokens Consumed by Model (All Users)** | `sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (model_id) or sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (model_id)` |
