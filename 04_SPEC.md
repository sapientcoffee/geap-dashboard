# ☕ Stage 4: Technical Specification

This technical specification details the architectural, query, and codebase improvements to migrate Developer AI Tools: User Token Tracker Dashboard (v2) to PromQL, harden the log-based metrics, and fix Python proxy reference templates.

---

## 1. Dashboard v2 PromQL Migration Design

Standard GCM filter widgets in `geap-monitoring-dashboard-v2.json` will be replaced with `prometheusQuery` elements.

### 1.1 Metric Translation Maps
In PromQL, GCP translates the custom log-based metric `logging.googleapis.com/user/user_tokens` to:
*   Metric Name: `logging_googleapis_com:user_user_tokens`
*   Labels:
    *   `metric.labels.user_id` $\rightarrow$ `user_id`
    *   `metric.labels.model_id` $\rightarrow$ `model_id`

For `DISTRIBUTION` metrics (Option 2), PromQL exposes these scalar suffixes:
*   `logging_googleapis_com:user_user_tokens_sum`: Accumulates total tokens.
*   `logging_googleapis_com:user_user_tokens_count`: Accumulates request count.

### 1.2 The Fallback Schema Pattern
To ensure the dashboard works seamlessly under both schemas, every chart utilizes the PromQL `or` operator.
```promql
<Option_2_Distribution_Query> or <Option_1_Scalar_Query>
```
If Option 2 is deployed, the first operand returns data and is displayed. If Option 2 is not deployed, the first operand returns an empty vector, and PromQL falls back to evaluating the second operand (Option 1's request-count data).

---

## 2. Updated Widget Queries Spec

### Widget 2: Token (or Request) Consumption Rate (Over Time)
*   **Widget Type**: `xyChart` (Line)
*   **PromQL Query**:
    ```promql
    sum(rate(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id) or sum(rate(logging_googleapis_com:user_user_tokens[1m])) by (user_id)
    ```
*   **Axes & Legend**:
    *   Title: `"Token Consumption (or Requests) by User (Over Time)"`
    *   Y-Axis Label: `"Rate / Second"`
    *   Description: Displays actual token ingestion rate per second (Option 2) or request rate per second (Option 1).

### Widget 3: Total Tokens (or Requests) Consumed per User
*   **Widget Type**: `xyChart` (Stacked Bar)
*   **PromQL Query**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id) or sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (user_id)
    ```
*   **Axes & Legend**:
    *   Title: `"Total Tokens (or Requests) Consumed per User"`
    *   Y-Axis Label: `"Total Count (Tokens or Requests)"`

### Widget 4: API Requests Count by User
*   **Widget Type**: `xyChart` (Line)
*   **PromQL Query**:
    ```promql
    sum(rate(logging_googleapis_com:user_user_tokens_count[1m])) by (user_id) or sum(rate(logging_googleapis_com:user_user_tokens[1m])) by (user_id)
    ```
*   **Axes & Legend**:
    *   Title: `"API Request Count by User (Rate)"`
    *   Y-Axis Label: `"Requests / Second"`

### Widget 5: Model Types Utilized per User
*   **Widget Type**: `xyChart` (Stacked Bar)
*   **PromQL Query**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (user_id, model_id) or sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (user_id, model_id)
    ```
*   **Axes & Legend**:
    *   Title: `"Model Types Utilized by User"`
    *   Y-Axis Label: `"Total Count (Tokens or Requests)"`

### Widget 6: Total Tokens (or Requests) Consumed per User per Model (Table Summary)
*   **Widget Type**: `timeSeriesTable` with `"outputFullDuration": true`
*   **PromQL Query**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum[${__interval}])) by (user_id, model_id) or sum(increase(logging_googleapis_com:user_user_tokens[${__interval}])) by (user_id, model_id)
    ```
*   **Settings**: `"outputFullDuration": true` allows aggregation over the exact selected timeframe window.

### Widget 7: Total Invocations (or Tokens) by Model (All Users)
*   **Widget Type**: `xyChart` (Stacked Bar)
*   **PromQL Query**:
    ```promql
    sum(increase(logging_googleapis_com:user_user_tokens_sum[1m])) by (model_id) or sum(increase(logging_googleapis_com:user_user_tokens[1m])) by (model_id)
    ```
*   **Axes & Legend**:
    *   Title: `"Total Tokens (or Requests) Consumed by Model (All Users)"`
    *   Y-Axis Label: `"Total Count (Tokens or Requests)"`

---

## 3. Log-Based Metric Hardening Spec

### 3.1 `user-tokens-proxy.yaml` (Option 2)
Add explicit parentheses to ensure strict logical order of evaluation and prevent matching all `global` logs:
```yaml
filter: '(resource.type="global" OR resource.type="cloud_run_revision") AND jsonPayload.event="gemini_call"'
```

### 3.2 `user-tokens-audit-log.yaml` (Option 1)
Replace case-insensitive approximations with exact case-sensitive gRPC methods to guarantee future-proof execution on Cloud Logging:
```yaml
filter: 'logName:"cloudaudit.googleapis.com%2Fdata_access" AND protoPayload.serviceName="aiplatform.googleapis.com" AND (protoPayload.methodName:"GenerateContent" OR protoPayload.methodName:"Predict")'
```

---

## 4. Ingestion & Proxy Refactoring Spec

### 4.1 Python FastAPI Logging Proxy Code Refactoring
In `HOW_TO_COLLECT_USER_DATA.md`, modify the Python FastAPI reference implementation:
1.  **Dynamic Client Initialization**: Move client initialization inside the route handler to dynamically parse and apply `{project}` and `{location}` from the request path.
2.  **API Schema Compliance**: Ensure the proxy response structure perfectly maps back to standard Vertex AI JSON REST format so that local tools (`agy`, `GeminiCLI`) do not experience runtime failures.

```python
@app.post("/v1/projects/{project}/locations/{location}/publishers/google/models/{model_id}:generateContent")
async def proxy_generate_content(project: str, location: str, model_id: str, request: Request):
    # 1. Identify user
    user_email = request.headers.get("X-Forwarded-User", "unknown@company.com")
    
    # 2. Instantiate Client Dynamically for the given Project and Location
    client = genai.Client(vertexai=True, project=project, location=location)
    
    # 3. Read body and call Vertex AI
    req_body = await request.json()
    response = client.models.generate_content(
        model=model_id,
        contents=req_body.get("contents"),
        config=req_body.get("config")
    )
    
    # 4. Extract token sizes and cache stats
    input_tokens = response.usage_metadata.prompt_token_count or 0
    output_tokens = response.usage_metadata.candidates_token_count or 0
    total_tokens = input_tokens + output_tokens
    
    # 5. Log metrics
    logging.info({
        "event": "gemini_call",
        "userId": user_email,
        "modelId": model_id,
        "inputTokens": input_tokens,
        "outputTokens": output_tokens,
        "totalTokens": total_tokens,
        "cachedTokens": response.usage_metadata.cached_content_token_count or 0
    })
    
    # 6. Return response in standard Vertex AI REST JSON format
    return response.model_dump(by_alias=True)
```
Using `by_alias=True` ensures Pydantic outputs camelCase field names matching the standard Vertex AI REST API schema exactly.
