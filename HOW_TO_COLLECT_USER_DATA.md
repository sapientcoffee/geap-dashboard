# ☕ How to Collect Developer User Data for Antigravity & GeminiCLI

Because **Antigravity** (`agy`) and **GeminiCLI** are CLI tools running on developers' local machines, their default network requests flow directly to Vertex AI without writing standard application-level logs into your central **Google Cloud Logging** system. As a result, the v2 (User Tracking) dashboard starts empty.

To populate your dashboard with per-user data, we have created two ready-to-use custom Log-Based Metric configurations. Choose one of the two standard solutions below:

---

## 🛠️ Solution 1: Enable Data Access Audit Logs (No Code Changes! ⚡)

Google Cloud natively audits every API request made to Vertex AI. Since Data Access Audit Logs are **already enabled** in your project for `aiplatform.googleapis.com` (Vertex AI API), you just need to create the log-based metric to start tracking user calls immediately.

> [!NOTE]
> Since Audit Logs do not capture payload data for privacy reasons, this tracks **Request Volume** per user rather than exact token sizes, but it still populates your v2 dashboard beautifully with developer activity!

### Step 1: Create the Log-Based Metric
Run the following `gcloud` command to create the custom metric `user_tokens` using our pre-built configuration file:

```bash
gcloud logging metrics create user_tokens --config-from-file=user-tokens-audit-log.yaml
```

This configuration automatically:
1. Filters for Data Access audit logs from `aiplatform.googleapis.com` (Vertex AI).
2. Extracts the caller's Google identity (`principalEmail`) and maps it to the `user_id` label.
3. Parses the target model name from the request resource path and maps it to the `model_id` label.

### Step 2: Test & Verify
Run some local `agy` commands or `GeminiCLI` calls. Once the logs flow in, your Dashboard v2 will automatically start plotting requests by user!

---

## 🏗️ Solution 2: Deploy a Lightweight Central Proxy (Tracks Exact Tokens! 💎)

If you want to track **both** the developer's identity **and the exact number of tokens** (input, output, cached) they are using, you can deploy a lightweight central logging proxy in your organization.

### Step 1: Deploy the Proxy on Cloud Run
Create a small Node.js or Python API proxy on Cloud Run. The proxy intercepts the `generateContent` calls, forwards them to Vertex AI, extracts the token metadata, and writes a structured JSON log containing the total tokens:

```python
# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0
import logging
from fastapi import FastAPI, Request
from google import genai

app = FastAPI()
client = genai.Client()

@app.post("/v1/projects/{project}/locations/{location}/publishers/google/models/{model_id}:generateContent")
async def proxy_generate_content(project: str, location: str, model_id: str, request: Request):
    # 1. Identify the user from their caller token or headers (e.g., identity-aware proxy)
    user_email = request.headers.get("X-Forwarded-User", "unknown@company.com")
    
    # 2. Forward call to Vertex AI
    req_body = await request.json()
    response = client.models.generate_content(model=model_id, contents=req_body.get("contents"))
    
    input_tokens = response.usage_metadata.prompt_token_count or 0
    output_tokens = response.usage_metadata.candidates_token_count or 0
    total_tokens = input_tokens + output_tokens
    
    # 3. Log user and exact token counts to Cloud Logging
    logging.info({
        "event": "gemini_call",
        "userId": user_email,
        "modelId": model_id,
        "inputTokens": input_tokens,
        "outputTokens": output_tokens,
        "totalTokens": total_tokens,
        "cachedTokens": response.usage_metadata.cached_content_token_count or 0
    })
    
    return response.model_dump()
```

### Step 2: Create the Log-Based Metric
Run the following `gcloud` command to create the distribution metric `user_tokens` using our pre-built configuration file:

```bash
gcloud logging metrics create user_tokens --config-from-file=user-tokens-proxy.yaml
```

This configuration automatically:
1. Extracts the numerical `totalTokens` field from your structured logs.
2. Tracks the custom `user_id` and `model_id` labels from the JSON payload.
3. Computes exact token sums and aggregates them on your Dashboard v2!

### Step 3: Redirect Local Tools to the Proxy
Developers configure their local shell environment to redirect traffic to your Cloud Run proxy:

```bash
export VERTEX_API_ENDPOINT="https://gemini-proxy-xxxxxx.a.run.app"
```
