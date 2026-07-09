# ☕ Stage 1: Ubiquitous Glossary

This glossary defines the ubiquitous language for the Developer AI Tools Monitoring Dashboards to align terms and definitions across metrics, ingestion options, and dashboard components.

---

## 📖 Glossary of Terms

| Term | Definition | Context / Scope |
| :--- | :--- | :--- |
| **Developer AI Tools** | Productivity tools and command line clients (e.g., `agy` / Antigravity, `GeminiCLI`) used by developers to make interactive or background model calls. | Global |
| **Agent Platform (GEAP)** | Google Enterprise Agent Platform / Vertex AI model endpoint infrastructure serving GenAI models. | Global |
| **PromQL** | Prometheus Query Language. The modern, standard language used in Google Cloud Monitoring (GCM) to query and scale time-series metrics. | GCM |
| **MQL** | Monitoring Query Language. The legacy and now deprecated GCM-specific query language. | GCM |
| **No-Code Audit Logs (Option 1)** | An ingestion pattern that tracks developer request counts and model selections by intercepting Vertex AI API activity logs (Data Access Audit Logs), requiring no client code changes but capturing request volume rather than exact token sizes due to privacy. | Ingestion |
| **Native Request-Response Logging (Option 2)** | A platform-level ingestion pattern that logs standard model request and response payloads natively on Vertex AI/GEAP base models into BigQuery and/or OpenTelemetry, tracking exact input, output, and cached token sizes per call without any custom proxy. | Ingestion |
| **`PublisherModelConfig`** | The native Google Cloud configuration resource used to set platform-level settings (such as logging and telemetry) on base foundation models like `gemini-2.5-flash`. | GEAP API |
| **`setPublisherModelConfig`** | The Vertex AI API endpoint used to dynamically enable, update, or disable request-response logging and telemetry configurations for base models. | GEAP API |
| **`BigQueryDestination`** | The structured BigQuery output table destination configured under the model logging policy where Google Cloud writes detailed JSON request and response payloads. | GEAP API |
| **`user_tokens` Metric** | The custom Google Cloud log-based metric representing developer activity. Under Option 1, it is a scalar `INT64` counter. Under Option 2, it is a `DISTRIBUTION` histogram parsed from native OpenTelemetry logs. | Ingestion |
| **Distribution Metric** | A GCM metric type that stores values in exponential range buckets (histograms) rather than as single numbers. Cannot be plotted on standard Line or Bar charts without scalar extraction (e.g., percentiles, or PromQL `_sum` suffixes). | GCM |
| **`_sum` / `_count` Suffixes** | Synthesised PromQL metrics (e.g. `user_tokens_sum`, `user_tokens_count`) exposed by GCM to extract scalar sums and sample counts from distribution metrics. | GCM |
| **Timeframe Scaling** | Dynamic calculation of cumulative values (e.g., total cost, total tokens) over the user's selected dashboard window. Powered by GCM's `"outputFullDuration": true` and PromQL's `[${__interval}]` variable. | GCM |
| **`outputFullDuration`** | A GCM dashboard parameter that aggregates time series values across the entire selected active timeframe into a single cumulative number instead of a time series chart. | GCM |
| **Total Per-User Cost** | The sum of real-time estimated costs (in USD) incurred by an individual user, computed by multiplying model types and token consumption rates (or request counts) against standard list prices. | Financial |
| **Blended Pricing Rate** | An estimated rate applied to a unified `totalTokens` count (which sums input and output tokens) based on an assumed typical developer workload proportion (e.g., 80% input tokens, 20% output tokens). | Financial |
| **Per-User Token Consumption by Model** | Fine-grained developer-level tracking of exact token counts (or request counts if under fallback) grouped both by user identity and model ID over time. | Ingestion |
| **Regional Endpoint Routing** | Directing model API calls through regional locations (e.g. `us-central1`) to ensure standard Cloud Logging audit trails are generated. | Ingestion |
| **locations/global Auditing Limitation** | The logical multi-region endpoint `global` does not write standard `DATA_READ` audit logs to Cloud Logging, preventing user mapping on GCM. | Ingestion |
| **settings.json Configuration** | Local file at `~/.gemini/antigravity-cli/settings.json` where developers specify target GCP project and regional locations (e.g. `us-central1`). | Configuration |
| **`user_cost_attribution_report`** | The consolidated BigQuery reporting SQL view which merges payload logs with IAM data access audit events, enabling user-level financial calculations. | Database View |
| **Identity Join** | An `INNER JOIN` in BigQuery connecting `request_response_logs` and `data_access` on the `request_id` field to map unredacted prompt/token sizes back to authenticated corporate emails. | Database View |

