# ☕ Sophisticated User & Usage Tracking Guide

Yes! It is absolutely possible to track specific users, teams, and usage details. To achieve this level of sophistication, we must go beyond platform-level aggregate metrics. 

We have deployed a second, advanced dashboard to your Google Cloud project:
👉 **[geap-monitoring-dashboard-v2.json](geap-monitoring-dashboard-v2.json)**

Here are the two industry-standard patterns to implement per-user and per-team tracking:

---

## 🏗️ Pattern A: Real-Time Dashboards (Custom Log-Based Metrics)

To populate your dashboard with per-user data, we have configured and created the log-based metric **`user_tokens`** directly in your project. It queries your Cloud Logging entries and extracts the custom fields and labels.

### 🛠️ Solution A1: No-Code Audit Logs (Request Counts) - *DEPLOYED!* ⚡
If you want to track developer request counts without changing any code or CLI configuration:
1. We verified that **Vertex AI Data Access Audit Logs are already enabled** in your project `coffee-and-codey` for `aiplatform.googleapis.com`.
2. We deployed the log-based metric `user_tokens` using our pre-built configuration:
   👉 **[user-tokens-audit-log.yaml](user-tokens-audit-log.yaml)**
3. When any developer runs local `agy` or `GeminiCLI` commands, the audit logs will automatically capture their email (`user_id`) and the model called (`model_id`), feeding them into Dashboard v2!

### 🏗️ Solution A2: Central Proxy (Exact Token Counts) 💎
If you want to track exact input, output, and cached token totals:
1. Deploy the lightweight Cloud Run proxy (detailed in [HOW_TO_COLLECT_USER_DATA.md](HOW_TO_COLLECT_USER_DATA.md)).
2. Update your `user_tokens` metric to extract exact token distributions from proxy JSON logs using our configuration:
   👉 **[user-tokens-proxy.yaml](user-tokens-proxy.yaml)**
   ```bash
   gcloud logging metrics update user_tokens --config-from-file=user-tokens-proxy.yaml
   ```

---

## 📊 Pattern B: Cost & Billing Allocation (Vertex Request Labels)

If your goal is financial auditing, chargeback, or cost attribution, Vertex AI natively supports **request-level metadata labels**. When you add labels to a `generateContent` request, they automatically propagate to **Cloud Billing** and are exported to **BigQuery**.

### Step 1: Add Labels to your API Requests
Simply include a `labels` dictionary containing user and department details directly inside your API client configuration:

```python
from google import genai

client = genai.Client()
response = client.models.generate_content(
    model='gemini-2.5-flash',
    contents='Summarize this document...',
    config={
        "labels": {
            "user_id": "rob_edwards_altostrat_com",
            "department": "sales_engineering",
            "environment": "production"
        }
    }
)
```

> [!IMPORTANT]
> Label keys must start with a lowercase letter and can only contain lowercase letters, numbers, underscores, and dashes (up to 63 characters). 
> **Note**: Labels are forwarded to Cloud Billing for standard Pay-As-You-Go pricing; requests under Provisioned Throughput are not tracked this way.

### Step 2: Query Cost by User in BigQuery
Once your Google Cloud Billing export to BigQuery is enabled, you can run SQL queries to get a down-to-the-penny report of how much money each user is spending on Gemini models:

```sql
SELECT 
  labels.value AS user_id,
  sku.description AS model_sku,
  SUM(usage.amount) AS total_tokens,
  SUM(cost) AS total_cost_usd
FROM 
  `your-project.billing.gcp_billing_export_v1_XXXXXX`,
  UNNEST(labels) as labels
WHERE 
  service.description = "Vertex AI"
  AND labels.key = "user_id"
GROUP BY 1, 2
ORDER BY total_cost_usd DESC;
```

You can then connect this BigQuery dataset directly to **Looker Studio** to create clean, shareable monthly financial reports.

