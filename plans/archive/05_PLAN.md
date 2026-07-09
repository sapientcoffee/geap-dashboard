# ☕ Stage 5: Execution Planning

This execution plan breaks down the user cost and token tracking dashboard enhancement into vertical implementation slices, identifying sequential and parallelizable tasks.

---

## 1. Vertical Implementation Slices

### Slice 1: Legacy Widget Migration (Robust Fallbacks) [Serial]
*   **Objective**: Upgrade all 6 existing widgets in `geap-monitoring-dashboard-v2.json` to use the PromQL `or` logical fallback operator to natively support both Option 1 (No-Code Audit Logs) and Option 2 (Native OTel Logging).
*   **Contract**: Correctly formats GCM-compatible JSON, preserving existing chart styling (`plotType`, `targetAxis`, labels).

### Slice 2: Real-Time User Cost Widgets [Serial]
*   **Objective**: Add the **Developer Cost over Time** xyChart line widget and **Developer Total Cost Summary Table** timeSeriesTable widget at the bottom of the grid in `geap-monitoring-dashboard-v2.json`.
*   **Contract**: Correct PromQL math with blended exact and request-count multipliers. Explicit currency labels (`"currency": "USD"`) in the summary table.

### Slice 3: Validation and Code Quality [Serial]
*   **Objective**: Verify JSON syntax correctness and configuration safety using Python JSON checkers.
*   **Contract**: Valid JSON payload, compiling against GCM layout structure schema.

### Slice 4: Documentation Synchronization [Serial]
*   **Objective**: Reflect the new cost-tracking features and blended metrics in `USER_AND_USAGE_TRACKING_GUIDE.md` and `walkthrough.md`.
*   **Contract**: Accurate pricing explanation matching spec.

### Slice 5: BigQuery Identity-Join Cost view [Serial]
*   **Objective**: Build and package automated SQL view schema and deployment scripts for high-fidelity cost attribution reports in BigQuery.
*   **Contract**: Correct Standard GoogleSQL syntax using `JSON_VALUE`. Automate view compilation via standard `bq query`.

---

## 2. Implementation Checklist

- [x] **Task 1: Migrate Existing Widgets to Fallbacks**
  - Update `geap-monitoring-dashboard-v2.json` widgets 2 to 7 with dual PromQL `or` expressions.
- [x] **Task 2: Implement Real-Time User Cost Widgets**
  - Add "Real-Time Estimated Cost (USD) per User (Over Time)" widget.
  - Add "Total Estimated Cost (USD) per User (Selected Timeframe)" table widget.
- [x] **Task 3: Run Validation & Verification**
  - Run Python syntax compile checks on the updated `geap-monitoring-dashboard-v2.json` file.
- [x] **Task 4: Update Reference Guides & Walkthrough**
  - Document user-level cost calculations in `USER_AND_USAGE_TRACKING_GUIDE.md`.
  - Compile proof walkthrough inside `walkthrough.md` and `08_WALKTHROUGH.md`.
- [x] **Task 5: Implement BigQuery SQL View and Deploy Scripts**
  - Create standard SQL view file `create_user_cost_attribution_view.sql`.
  - Create standard shell deployment script `deploy_bq_view.sh` and make executable.

