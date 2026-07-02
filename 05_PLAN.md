# ☕ Stage 5: Execution Plan

This document establishes the physical tasks and verification steps to implement the native exact token tracking model configuration, dashboard enhancements, and comprehensive guidance updates.

---

## 📅 Task Checklist

We divide the execution into 5 discrete tasks. Tasks 2, 3, and 4 have no mutual dependencies and can be worked on in parallel.

### Phase 1: Core Dashboard Updates
- [x] **Task 1: Migrate Dashboard v2 to Fallback PromQL [Serial]**
  - Verify that `geap-monitoring-dashboard-v2.json` contains appropriate `prometheusQuery` blocks.
  - Ensure all chart titles, axis labels, and descriptions are transparent about Token vs. Request values.
  - Set `"outputFullDuration": true` on Widget 6 (Table Summary).

### Phase 2: Ingestion Hardening (Native Ingestion)
- [x] **Task 2: Harden Log-Based Metrics configs [Parallel]**
  - Verify `user-tokens-audit-log.yaml` with case-sensitive gRPC methods.
  - Update `user-tokens-proxy.yaml` with the OpenTelemetry log filter `resource.type="aiplatform.googleapis.com/PublisherModel" AND jsonPayload.body.name="gemini_call"` and value extractor `jsonPayload.body.totalTokens`. Ensure Apache 2.0 license headers are correct.

- [x] **Task 3: Rewrite Logging Guide [Parallel]**
  - Completely rewrite `HOW_TO_COLLECT_USER_DATA.md`. Remove custom proxy instructions.
  - Add native setup documentation using python-sdk and REST APIs (`setPublisherModelConfig`), detailed OpenTelemetry structures, and specific cost optimization steps.

- [x] **Task 4: Update Usage Tracking Guide [Parallel]**
  - Completely rewrite `USER_AND_USAGE_TRACKING_GUIDE.md`. 
  - Add native GEAP logging schemas, details about GCP IAM pre-auth security advantages, specific SQL queries to join payload logs with audit logs, and cost metrics tables.

### Phase 3: Verification & Compilation
- [x] **Task 5: Schema Validation & Compilation Checks [Serial]**
  - Verify JSON parsing of `geap-monitoring-dashboard-v2.json`.
  - Verify YAML parsing of `user-tokens-audit-log.yaml` and `user-tokens-proxy.yaml`.
  - Conduct thorough verification of all documentation for layout, typos, references, and completeness.
