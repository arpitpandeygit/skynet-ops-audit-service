# Observability & Monitoring — skynet-ops-audit-service

**Cloud Platform:** AWS (us-east-1)  
**Logging:** CloudWatch Logs (structured JSON via Pino)  
**Metrics:** CloudWatch Metrics (Lambda native + custom metric filter)  
**Tracing:** AWS X-Ray (Active mode)  
**Alerting:** CloudWatch Alarms → SNS → Email

---

## 1. Logging

### Structured JSON Logs (Pino)

All application logs are emitted as structured JSON via the `pino` library. Each log line includes:

```json
{
  "level": 30,
  "time": "2026-03-01T14:12:52.865Z",
  "service": "skynet-ops-audit-service",
  "environment": "dev",
  "eventId": "evt_01abc123def456",
  "msg": "Event stored"
}
```

Pino level integers map to: `10=trace · 20=debug · 30=info · 40=warn · 50=error · 60=fatal`

The `level=50` threshold is used by the CloudWatch metric filter to count application-level errors (see Section 3).

### Log Groups


| Log Group                                          | Retention | Environment |
| -------------------------------------------------- | --------- | ----------- |
| `/aws/lambda/skynet-ops-audit-service-dev`         | 7 days    | dev         |
| `/aws/apigateway/skynet-ops-audit-service-dev`     | 7 days    | dev         |
| `/aws/lambda/skynet-ops-audit-service-staging`     | 7 days    | staging     |
| `/aws/apigateway/skynet-ops-audit-service-staging` | 7 days    | staging     |
| `/aws/lambda/skynet-ops-audit-service-prod`        | 14 days   | prod        |
| `/aws/apigateway/skynet-ops-audit-service-prod`    | 14 days   | prod        |


Retention is intentionally short for dev/staging (cost control and minimal debugging window). Prod is 14 days to support incident investigation across a billing cycle.

### Log Level Configuration

Log level is set via the `LOG_LEVEL` environment variable. Deployed values:


| Environment | LOG_LEVEL | Rationale                                    |
| ----------- | --------- | -------------------------------------------- |
| dev         | `info`    | Debug noise avoided in long-running Lambda   |
| staging     | `info`    | Matches prod behavior                        |
| prod        | `info`    | Avoids high-volume debug log ingestion costs |


To temporarily enable debug logging in prod:

```bash
aws lambda update-function-configuration \
  --function-name skynet-ops-audit-service-prod \
  --environment Variables='{LOG_LEVEL=debug,...}' \
  --region us-east-1
```

Revert immediately after use to avoid CloudWatch cost spike.

### API Gateway Access Logs

API Gateway stages are configured to emit access logs with the following fields:

```json
{
  "requestId": "$context.requestId",
  "status": "$context.status",
  "routeKey": "$context.routeKey",
  "ip": "$context.identity.sourceIp",
  "latency": "$context.responseLatency",
  "error": "$context.error.message"
}
```

These logs land in the `/aws/apigateway/skynet-ops-audit-service-{env}` log groups.

### Sample Log Queries (CloudWatch Logs Insights)

**All errors in the last hour:**

```
fields @timestamp, @message
| filter @message like /error/
| sort @timestamp desc
| limit 50
```

**Events stored per 5 minutes:**

```
fields @timestamp
| filter msg = "Event stored"
| stats count() by bin(5m)
```

**Slow requests (duration > 1s from API Gateway logs):**

```
fields @timestamp, latency, routeKey, status
| filter latency > 1000
| sort latency desc
| limit 20
```

**Errors by tenantId:**

```
fields @timestamp, tenantId, msg
| filter level = 50
| stats count() as errorCount by tenantId
| sort errorCount desc
```

---

## 2. Metrics

### Native Lambda Metrics (AWS/Lambda namespace)

These are automatically collected by CloudWatch for every Lambda function:


| Metric                 | Description                              | Monitored                           |
| ---------------------- | ---------------------------------------- | ----------------------------------- |
| `Invocations`          | Total function calls                     | Yes (via alarm on Errors/Throttles) |
| `Errors`               | Failed invocations                       | **Alarmed**                         |
| `Duration`             | Execution time (ms)                      | **Alarmed**                         |
| `Throttles`            | Requests rejected due to concurrency cap | **Alarmed**                         |
| `ConcurrentExecutions` | Live executions at a point in time       | Visible in console                  |
| `DeadLetterErrors`     | Failures sending to DLQ                  | Visible in console                  |


### Custom Application Metric

A CloudWatch Metric Filter is deployed on the Lambda log group to count application-level errors (Pino `level=50`):

```
Filter pattern: { $.level = 50 }
Metric name:    ApplicationErrors
Namespace:      Custom/Lambda
Value:          1 (count per match)
```

This distinguishes **application errors** (bad data, service logic failures) from **Lambda platform errors** (timeouts, OOM) captured by the native `Errors` metric.

**Screenshot location:** CloudWatch → Log Groups → `/aws/lambda/skynet-ops-audit-service-{env}` → Metric Filters tab

### API Gateway Metrics (AWS/ApiGateway namespace)

Detailed metrics are enabled on all API Gateway stages:


| Metric               | Description                                       |
| -------------------- | ------------------------------------------------- |
| `Count`              | Total API requests                                |
| `4XXError`           | Client errors (validation failures, bad requests) |
| `5XXError`           | Server errors                                     |
| `Latency`            | End-to-end request latency (ms)                   |
| `IntegrationLatency` | Time Lambda takes to respond                      |


To view in console: CloudWatch → Metrics → AWS/ApiGateway → filter by `ApiId=rqivs1f7w7`

---

## 3. CloudWatch Alarms

Nine alarms are deployed across three environments. All are currently in **OK** state.

### Dev Alarms


| Alarm Name                                      | Metric          | Threshold     | Period | Rationale                                         |
| ----------------------------------------------- | --------------- | ------------- | ------ | ------------------------------------------------- |
| `skynet-ops-audit-service-dev-lambda-errors`    | Errors (Sum)    | ≥ 5 per 5 min | 5 min  | Permissive threshold for dev experimentation      |
| `skynet-ops-audit-service-dev-lambda-duration`  | Duration (Avg)  | > 3000 ms     | 5 min  | Relaxed latency — cold starts acceptable in dev   |
| `skynet-ops-audit-service-dev-lambda-throttles` | Throttles (Sum) | ≥ 1 per 5 min | 5 min  | Immediate notice if reserved concurrency=2 is hit |


### Staging Alarms


| Alarm Name                                          | Metric          | Threshold     | Period | Rationale                                        |
| --------------------------------------------------- | --------------- | ------------- | ------ | ------------------------------------------------ |
| `skynet-ops-audit-service-staging-lambda-errors`    | Errors (Sum)    | ≥ 5 per 5 min | 5 min  | Same as dev — staging is pre-prod validation     |
| `skynet-ops-audit-service-staging-lambda-duration`  | Duration (Avg)  | > 3000 ms     | 5 min  | Test realistic latency before prod               |
| `skynet-ops-audit-service-staging-lambda-throttles` | Throttles (Sum) | ≥ 1 per 5 min | 5 min  | Validate concurrency settings before prod deploy |


### Prod Alarms ← Tighter thresholds


| Alarm Name                                       | Metric          | Threshold         | Period | Rationale                                                       |
| ------------------------------------------------ | --------------- | ----------------- | ------ | --------------------------------------------------------------- |
| `skynet-ops-audit-service-prod-lambda-errors`    | Errors (Sum)    | ≥ **3** per 5 min | 5 min  | Tighter: 3 consecutive Lambda errors is a real issue            |
| `skynet-ops-audit-service-prod-lambda-duration`  | Duration (Avg)  | > **2000 ms**     | 5 min  | Spec target: POST /events < 500 ms typical, 2 s avg is degraded |
| `skynet-ops-audit-service-prod-lambda-throttles` | Throttles (Sum) | ≥ 1 per 5 min     | 5 min  | Any throttle in prod is a capacity misconfiguration             |


All alarms have `treat_missing_data = notBreaching` — no alarm fires when there is zero traffic (e.g., overnight).

### Alarm Notification Channel

All alarms publish to an SNS topic per environment:


| SNS Topic                                 | Subscriber                                      |
| ----------------------------------------- | ----------------------------------------------- |
| `skynet-ops-audit-service-dev-alarms`     | [arpitxid@gmail.com](mailto:arpitxid@gmail.com) |
| `skynet-ops-audit-service-staging-alarms` | [arpitxid@gmail.com](mailto:arpitxid@gmail.com) |
| `skynet-ops-audit-service-prod-alarms`    | [arpitxid@gmail.com](mailto:arpitxid@gmail.com) |


> **Action required:** Confirm SNS email subscriptions to activate alarm notifications. Until confirmed, alarms trigger but no email is delivered.

---

## 4. Distributed Tracing (X-Ray)

Lambda X-Ray tracing is set to `Active` mode on all environments. This means:

- Every Lambda invocation produces a trace segment
- Trace data flows to X-Ray service map
- Subsegments can be added manually with `aws-xray-sdk` if needed

**Viewing traces:**
Console → AWS X-Ray → Traces → filter by function name `skynet-ops-audit-service-{env}`

IAM permission `AWSXrayWriteOnlyAccess` is attached to the Lambda execution role.

At pilot traffic volumes, X-Ray cost is ~$0.50/month. This is acceptable for a pilot service where distributed tracing adds significant debugging value.

---

## 5. Health Signal Monitoring

The `GET /health` endpoint is suitable for use as a health probe. Response includes:

- `status: "ok"` (or error state)
- `store` field confirms backend (dynamodb confirmed live)
- `timestamp` confirms clock skew

**Setting up a synthetic health check (recommended for prod):**

```bash
# AWS CloudWatch Synthetics canary (or use a simple EventBridge-triggered Lambda)
# Alternatively, use Route 53 health check:
aws route53 create-health-check \
  --caller-reference "skynet-prod-health-$(date +%s)" \
  --health-check-config '{
    "FullyQualifiedDomainName": "rqivs1f7w7.execute-api.us-east-1.amazonaws.com",
    "Port": 443,
    "Type": "HTTPS",
    "ResourcePath": "/health",
    "RequestInterval": 30,
    "FailureThreshold": 2
  }'
```

---

## 6. Metrics Demo Endpoint

The `/metrics-demo` endpoint exists specifically to trigger observable behaviour for testing dashboards and alarms:


| Mode    | Command                            | Observable Effect                                                                    |
| ------- | ---------------------------------- | ------------------------------------------------------------------------------------ |
| Default | `curl .../metrics-demo`            | 200 OK, no unusual metrics                                                           |
| Error   | `curl .../metrics-demo?mode=error` | Returns 500, increments Lambda `Errors` metric, triggers alarm if repeated 3× (prod) |
| Slow    | `curl .../metrics-demo?mode=slow`  | 1–3 sec delay, visible in `Duration` metric                                          |
| Burst   | `curl .../metrics-demo?mode=burst` | Emits 5 log lines per call, visible in Logs Insights                                 |


**To trigger the duration alarm (demo):**

```bash
for i in {1..5}; do
  curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/metrics-demo?mode=slow" &
done
wait
```

Watch CloudWatch → Alarms → `*-lambda-duration` within 5 minutes.

**To trigger the error alarm (demo):**

```bash
for i in {1..6}; do
  curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/metrics-demo?mode=error"
done
```

Watch CloudWatch → Alarms → `*-lambda-errors` within 5 minutes (dev threshold: 5, prod: 3).

---

## 7. Dashboard Configuration (Recommended)

No CloudWatch dashboard is provisioned by default (cost: $3/dashboard/month). The following widgets are recommended for a manual dashboard:

**Widget 1 — Lambda Invocations (bar chart, 1h)**

```
Namespace: AWS/Lambda
Metric: Invocations
Dimensions: FunctionName = skynet-ops-audit-service-prod
Stat: Sum | Period: 5m
```

**Widget 2 — Lambda Errors (line, 1h)**

```
Namespace: AWS/Lambda
Metric: Errors
Stat: Sum | Period: 5m
```

**Widget 3 — Lambda Duration P99 (line, 1h)**

```
Namespace: AWS/Lambda
Metric: Duration
Stat: p99 | Period: 5m
```

**Widget 4 — API Gateway 4XX + 5XX (stacked area, 1h)**

```
Namespace: AWS/ApiGateway
Metrics: 4XXError, 5XXError
ApiId: rqivs1f7w7
Stat: Sum | Period: 5m
```

**Widget 5 — DynamoDB ConsumedWriteCapacityUnits (line, 1d)**

```
Namespace: AWS/DynamoDB
Metric: ConsumedWriteCapacityUnits
TableName: skynet-ops-audit-service-prod
```

**Widget 6 — Alarm Status (alarm status widget)**
All 3 prod alarms in a single status widget.

---

## 8. Screenshots to Capture for Submission


| #   | What                                                    | Where                                               |
| --- | ------------------------------------------------------- | --------------------------------------------------- |
| 1   | All 9 alarms in OK state                                | CloudWatch → Alarms → All alarms                    |
| 2   | Prod lambda-errors alarm detail (threshold + history)   | Click alarm → Detail page                           |
| 3   | All 6 log groups with retention values visible          | CloudWatch → Log Groups                             |
| 4   | Lambda error metric filter on dev log group             | Log Groups → `/aws/lambda/...-dev` → Metric Filters |
| 5   | Lambda metrics graph — Invocations + Errors over time   | CloudWatch → Metrics → Lambda                       |
| 6   | Logs Insights query result (e.g., events stored per 5m) | CloudWatch → Logs Insights                          |
| 7   | X-Ray trace map (after running some requests)           | X-Ray → Service Map                                 |
| 8   | Terminal — curl metrics-demo all 4 modes with responses | Terminal                                            |
| 9   | SNS topics list with subscription status                | SNS → Topics                                        |
| 10  | AWS Budgets — all 3 env budgets in healthy state        | Billing → Budgets                                   |


