# ☕ Stage 5: Execution Plan

This document establishes the physical tasks and verification steps to implement the specified dashboard enhancements, metric hardening, and proxy improvements.

---

## 📅 Task Checklist

We divide the execution into 5 discrete tasks. Tasks 2, 3, and 4 have no mutual dependencies and can be worked on in parallel.

### Phase 1: Core Dashboard Updates
- [ ] **Task 1: Migrate Dashboard v2 to Fallback PromQL [Serial]**
  - Update `geap-monitoring-dashboard-v2.json`.
  - Replace all widget metric filters with `prometheusQuery` blocks using the `or` fallback scheme.
  - Update all chart titles, axis labels, and descriptions to be transparent about Token vs. Request values.
  - Set `"outputFullDuration": true` on Widget 6 (Table Summary).

### Phase 2: Ingestion Hardening
- [ ] **Task 2: Harden Log-Based Metrics configs [Parallel]**
  - Update `user-tokens-audit-log.yaml` with case-sensitive gRPC method names: `GenerateContent`, `Predict`. Add Apache 2.0 license header using `google-license-manager`.
  - Update `user-tokens-proxy.yaml` with explicit grouping parentheses: `(resource.type="global" OR resource.type="cloud_run_revision") AND jsonPayload.event="gemini_call"`. Add Apache 2.0 license header using `google-license-manager`.

- [ ] **Task 3: Refactor Logging Proxy & Guide [Parallel]**
  - Update FastAPI Python proxy template in `HOW_TO_COLLECT_USER_DATA.md` to use dynamic client instantiation and camelCase alias output.
  - Update `HOW_TO_COLLECT_USER_DATA.md` notes to explain Dashboard v2's new PromQL fallback features.

- [ ] **Task 4: Update Usage Tracking Guide [Parallel]**
  - Update `USER_AND_USAGE_TRACKING_GUIDE.md` notes to reflect PromQL integration, fallback logic, and metric corrections in Dashboard v2.

### Phase 3: Verification & Compilation
- [ ] **Task 5: Schema Validation & Compilation Checks [Serial]**
  - Verify that both `geap-monitoring-dashboard.json` and `geap-monitoring-dashboard-v2.json` parse as valid JSON.
  - Run plugin/compilation checks if applicable to verify dashboard schema compatibility.

---

## 🚦 Verification Plan

We will verify every task using local file validation:
1.  **JSON Schema Check**: Validate JSON structure of `geap-monitoring-dashboard-v2.json`.
2.  **YAML Syntax Check**: Validate YAML structure of `user-tokens-audit-log.yaml` and `user-tokens-proxy.yaml`.
3.  **Documentation Review**: Read through `HOW_TO_COLLECT_USER_DATA.md` and `USER_AND_USAGE_TRACKING_GUIDE.md` to ensure zero broken links, perfect markdown syntax, and complete reference accuracy.
