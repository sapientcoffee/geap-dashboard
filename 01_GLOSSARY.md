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
| **Lightweight Proxy (Option 2)** | An ingestion pattern that routes local developer calls through a central FastAPI logging proxy to log exact input, output, and cached token sizes for 100% precise cost attribution. | Ingestion |
| **`user_tokens` Metric** | The custom Google Cloud log-based metric representing developer activity. Under Option 1, it is a scalar `INT64` counter. Under Option 2, it is a `DISTRIBUTION` histogram. | Ingestion |
| **Distribution Metric** | A GCM metric type that stores values in exponential range buckets (histograms) rather than as single numbers. Cannot be plotted on standard Line or Bar charts without scalar extraction (e.g., percentiles, or PromQL `_sum` suffixes). | GCM |
| **`_sum` / `_count` Suffixes** | Synthesised PromQL metrics (e.g. `user_tokens_sum`, `user_tokens_count`) exposed by GCM to extract scalar sums and sample counts from distribution metrics. | GCM |
| **Timeframe Scaling** | Dynamic calculation of cumulative values (e.g., total cost, total tokens) over the user's selected dashboard window. Powered by GCM's `"outputFullDuration": true` and PromQL's `[${__interval}]` variable. | GCM |
| **`outputFullDuration`** | A GCM dashboard parameter that aggregates time series values across the entire selected active timeframe into a single cumulative number instead of a time series chart. | GCM |
