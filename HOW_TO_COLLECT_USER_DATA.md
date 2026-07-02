# ☕ How to Collect Developer User Data Natively for Antigravity & GeminiCLI

Because **Antigravity** (`agy`) and **GeminiCLI** are local CLI tools running on developer machines, their requests flow directly to Vertex AI / Agent Platform (GEAP). 

Instead of hosting and managing a custom proxy server on Cloud Run, we can use GEAP's native **Request-Response Logging (via `PublisherModelConfig`)** to automatically log exact input, output, and cached token sizes directly to a central **BigQuery table** and **OpenTelemetry (OTel)** logging stream with **zero custom proxy code!**

---

## 🔒 Security Advantage: Native GCP IAM Pre-Auth

*   **100% Pre-Auth Enforced**: Developers authenticate locally using standard Google credentials (`gcloud auth application-default login`). Direct GCP IAM permissions control whether they can call the model.
*   **Zero-Bypass Logging**: Because logging is enabled at the platform level on the base foundation models, **every single call is audited and logged asynchronously inside Google's infrastructure**. Developers cannot bypass or turn off this tracking by changing local endpoint variables.

---

## 🛠️ Step-by-Step Native Setup

### Step 1: Enable Request-Response Logging on Base Models

Select one of the two standard platform configuration patterns below to enable logging on a base model (such as `gemini-2.5-flash`):

#### Pattern A: Via REST API / curl (Recommended)
Create a file named `request.json` with the following configuration (replace `{PROJECT_ID}` with your project ID):
```json
{
  "publisherModelConfig": {
    "loggingConfig": {
      "enabled": true,
      "samplingRate": 1.0,
      "bigqueryDestination": {
        "outputUri": "bq://{PROJECT_ID}.vertex_logs.request_response_logs"
      },
      "enableOtelLogging": true
    }
  }
}
```

Then run the `curl` command corresponding to your model's endpoint type:

* **For Regional Models (e.g., `gemini-2.5-flash` in `us-central1`)**:
  ```bash
  curl -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d @request.json \
    "https://us-central1-aiplatform.googleapis.com/v1beta1/projects/{PROJECT_ID}/locations/us-central1/publishers/google/models/gemini-2.5-flash:setPublisherModelConfig"
  ```

* **For Global Models (e.g., `gemini-3.5-flash` on the Global Endpoint)**:
  Use the global `aiplatform.googleapis.com` API domain and specify location `global`:
  ```bash
  curl -X POST \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d @request.json \
    "https://aiplatform.googleapis.com/v1beta1/projects/{PROJECT_ID}/locations/global/publishers/google/models/gemini-3.5-flash:setPublisherModelConfig"
  ```

#### Pattern B: Via Python SDK (Vertex AI Preview)
Run this Python snippet inside your environment:
```python
import vertexai
from vertexai.preview.generative_models import GenerativeModel

PROJECT_ID = "coffee-and-codey"

# For standard regional models:
# LOCATION = "us-central1"
# MODEL_NAME = "gemini-2.5-flash"

# For global models:
LOCATION = "global"
MODEL_NAME = "gemini-3.5-flash"

# Initialize Vertex AI SDK
vertexai.init(project=PROJECT_ID, location=LOCATION)

# Initialize target base foundation model
model = GenerativeModel(MODEL_NAME)

# Enable native logging to BigQuery and OpenTelemetry
model.set_request_response_logging_config(
    enabled=True,
    sampling_rate=1.0,
    bigquery_destination=f"bq://{PROJECT_ID}.vertex_logs.request_response_logs",
    enable_otel_logging=True
)
print(f"Native request-response logging successfully configured for {MODEL_NAME} on {LOCATION}!")
```

---

### Step 2: Transition the `user_tokens` Log-Based Metric

Once `enableOtelLogging` is active, Vertex AI writes structured OpenTelemetry logs to Cloud Logging on every model call. 

Update your custom GCM log-based metric `user_tokens` to extract exact token sizes from these native OpenTelemetry logs by running:

```bash
gcloud logging metrics update user_tokens --config-from-file=user-tokens-proxy.yaml
```

*   **How it works**: This instructs GCM to look for OpenTelemetry logs on the `PublisherModel` resource, extract the `totalTokens` payload value, and store them as a GCM `DISTRIBUTION` histogram.
*   **Result**: Dashboard v2's PromQL fallback queries automatically detect these distribution metrics, switching your charts from plotting simple request counts to plotting **exact, high-fidelity token volumes!**

---

### Step 3: Zero-Config Client Setup for Developers

Because logging is serverless and enforced on the platform itself, developers do **not** need to route traffic through any custom proxies or override endpoints:

```bash
# REJECT / REMOVE any custom proxy endpoint settings!
unset VERTEX_API_ENDPOINT

# Developers simply authenticate normally
gcloud auth application-default login
```

Every `agy` or `GeminiCLI` request they make will automatically flow safely to Vertex AI, be authenticated natively via GCP IAM, and be recorded inside your audit and token tables!

---

## 💰 Cost Considerations

To prevent billing surprises, administrators should consider the following cost structures:

1.  **BigQuery Storage & Ingestion**: BigQuery charges a tiny fee for data storage ($0.02/GiB/month) and ingestion. Since the first **10 GiB/month** is completely free under BigQuery's free tier, tracking logs for teams of up to several hundred developers will cost **$0.00**.
2.  **Cloud Logging (OTel Streams)**: Standard log ingestion in GCP is free for the first **50 GiB/month** per project. Beyond that, it is $0.50 per GiB.
3.  **Adaptive Sampling Rate**: For large engineering groups with high volumes, you can set `samplingRate` to a fraction (e.g. `0.1` for 10% sampling) under `loggingConfig`. This reduces data ingestion and storage volumes by 90% while still providing statistically precise usage distributions on your dashboard!
