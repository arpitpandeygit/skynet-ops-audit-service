# skynet-ops-audit-service

A cloud-native operational audit event service built for the AIRMAN Skynet ecosystem. Deployed on AWS as a containerized Lambda function behind API Gateway, with DynamoDB storage, structured logging, CloudWatch alarms, and full Terraform IaC across three environments.

---

## Architecture Overview

```
Internet
   │
   ▼
API Gateway (HTTP API)
   │  Throttling: 50 req/s (dev), 20 req/s (prod)
   │  JWT Auth: enabled on prod (Cognito)
   ▼
AWS Lambda (Container Image)
   │  512 MB · 10s timeout · X-Ray tracing
   │  Reserved concurrency: 2 (dev) / 5 (staging) / 10 (prod)
   ▼
DynamoDB (PAY_PER_REQUEST)
   │  Table: skynet-ops-audit-service-{env}
   │  GSI: tenantId-index (tenantId + storedAt)
   ▼
SQS Dead Letter Queue (on async failure)
   │
CloudWatch Logs + Metric Alarms → SNS → Email
   │
AWS Budgets (per-env monthly cap)
```

**Infrastructure as Code:** Terraform (modular, multi-environment)  
**State backend:** S3 + DynamoDB locking  
**CI/CD:** GitHub Actions with OIDC (no long-lived keys)  
**Container registry:** ECR (lifecycle policy: keep last 10 images)

---

## Live Endpoints (Dev)


| Endpoint     | URL                                                                   |
| ------------ | --------------------------------------------------------------------- |
| Health       | `https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/health`       |
| POST /events | `https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events`       |
| GET /events  | `https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events`       |
| Metrics Demo | `https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/metrics-demo` |


> **Prod** endpoints are protected by Cognito JWT. Obtain a token from the Cognito User Pool before calling prod.

---

## Repository Structure

```
skynet-ops-audit-service/
├── src/
│   ├── app.js                          # Express app init
│   ├── config.js                       # Env-var config
│   ├── server.js                       # Local HTTP server entry
│   ├── lambda.js                       # Lambda handler (serverless-http)
│   ├── controllers/
│   │   ├── health.controller.js
│   │   ├── events.controller.js
│   │   └── metrics.controller.js
│   ├── middleware/
│   │   ├── auth.middleware.js          # Optional API key auth
│   │   ├── error.middleware.js
│   │   └── validation.middleware.js
│   ├── routes/
│   │   ├── health.routes.js
│   │   └── events.routes.js            # /events + /metrics-demo
│   ├── services/
│   │   └── event.service.js            # Store-agnostic service layer
│   └── store/
│       ├── memory.store.js             # In-memory (local/test)
│       ├── sqlite.store.js             # SQLite (local persistent)
│       └── dynamodb.store.js           # DynamoDB (cloud)
├── infra/
│   └── terraform/
│       ├── bootstrap/                  # S3 state bucket + DynamoDB lock table
│       ├── modules/
│       │   ├── apigateway/
│       │   ├── alerts/
│       │   ├── budget/
│       │   ├── cicd/
│       │   ├── cognito/
│       │   ├── dlq/
│       │   ├── dynamodb/
│       │   ├── ecr/
│       │   ├── iam/
│       │   ├── lambda/
│       │   └── monitoring/
│       ├── envs/
│       │   ├── dev/
│       │   ├── staging/
│       │   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── providers.tf
├── Dockerfile
├── .dockerignore
├── .env.example
├── nodemon.json
├── package.json
├── scripts/
│   ├── run-local.sh
│   └── test-local.sh
├── docs/
│   ├── cost-optimization-report.md
│   ├── observability-monitoring.md
│   ├── ops-runbook.md
│   └── security-secrets.md
├── sample_events.json
├── submission_checklist.md
└── README.md
```

---

## Prerequisites


| Tool      | Version | Required for          |
| --------- | ------- | --------------------- |
| Node.js   | 20.x    | Local dev             |
| Docker    | 24+     | Build & run container |
| Terraform | ≥ 1.5.0 | Infrastructure        |
| AWS CLI   | v2      | Cloud operations      |
| jq        | any     | Response formatting   |


---

## Local Setup

### 1. Clone and install

```bash
git clone https://github.com/arpitpandeygit/skynet-ops-audit-service.git
cd skynet-ops-audit-service
npm install
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env as needed — defaults work for local dev with in-memory store
```

### 3. Run locally (Node.js)

```bash
npm run dev
# or
bash scripts/run-local.sh
```

Service starts at `http://localhost:8080`

### 4. Run locally (Docker)

```bash
docker build -t skynet-ops-audit-service .

docker run -p 9000:8080 \
  -e APP_ENV=dev \
  -e STORE_BACKEND=memory \
  -e LOG_LEVEL=info \
  -e METRICS_DEMO_ENABLED=true \
  skynet-ops-audit-service
```

> When running as Lambda container image locally, use AWS RIE (Runtime Interface Emulator) for full fidelity.

---

## Testing Endpoints

### Health check

```bash
curl -s https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/health | jq
```

**Expected response:**

```json
{
  "status": "ok",
  "service": "skynet-ops-audit-service",
  "environment": "dev",
  "timestamp": "2026-03-01T14:12:52.865Z",
  "store": "dynamodb"
}
```

---

### POST /events — ingest an audit event

```bash
curl -s -X POST https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events \
  -H "Content-Type: application/json" \
  -d '{
    "type": "roster_update",
    "tenantId": "academy_001",
    "severity": "info",
    "message": "Instructor schedule adjusted for morning slot",
    "source": "skynet-api",
    "metadata": {
      "instructorId": "ins_014",
      "studentCountAffected": 3
    },
    "occurredAt": "2026-03-01T09:00:00Z"
  }' | jq
```

**Expected response (201):**

```json
{
  "success": true,
  "eventId": "evt_01HQX8M3Y9A6R",
  "storedAt": "2026-03-01T09:01:00Z"
}
```

---

### POST /events — validation rejection (400)

```bash
curl -s -X POST https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events \
  -H "Content-Type: application/json" \
  -d '{
    "type": "roster_update",
    "tenantId": "academy_001",
    "severity": "invalid_severity",
    "message": "test",
    "source": "cli"
  }' | jq
```

**Expected response (400):**

```json
{
  "error": "Invalid severity"
}
```

---

### POST /events — missing required field (400)

```bash
curl -s -X POST https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events \
  -H "Content-Type: application/json" \
  -d '{
    "type": "roster_update",
    "tenantId": "academy_001"
  }' | jq
```

---

### GET /events — list all events

```bash
curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events" | jq
```

### GET /events — filter by tenant and severity

```bash
curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events?tenantId=academy_001&severity=warning&limit=10" | jq
```

### GET /events — filter by type with pagination

```bash
curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events?type=dispatch_approved&limit=5&offset=0" | jq
```

**Expected response (200):**

```json
{
  "items": [ ... ],
  "total": 3,
  "limit": 5,
  "offset": 0
}
```

---

### GET /metrics-demo — observability testing

```bash
# Default (success)
curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/metrics-demo" | jq

# Simulate 500 error
curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/metrics-demo?mode=error" | jq

# Simulate slow response (1–3 sec delay)
curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/metrics-demo?mode=slow" | jq

# Burst log lines
curl -s "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/metrics-demo?mode=burst" | jq
```

**Observed responses:**

```json
{ "status": "metrics-demo-ok" }
{ "error": "Simulated error" }
{ "status": "slow-response", "delay": 1987 }
{ "status": "burst-logs-emitted" }
```

---

### Bulk-seed sample events

```bash
# Load all sample events from the provided JSON file
cat sample_events.json | jq -c '.[]' | while read event; do
  curl -s -X POST https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/events \
    -H "Content-Type: application/json" \
    -d "$event" | jq '.eventId'
done
```

---

## Environment Variables


| Variable               | Required    | Default                    | Description                                        |
| ---------------------- | ----------- | -------------------------- | -------------------------------------------------- |
| `PORT`                 | No          | `8080`                     | Server port (local only)                           |
| `APP_ENV` / `NODE_ENV` | No          | `dev`                      | Environment name                                   |
| `SERVICE_NAME`         | No          | `skynet-ops-audit-service` | Appears in logs and health response                |
| `LOG_LEVEL`            | No          | `info`                     | Pino log level (`debug`, `info`, `warn`, `error`)  |
| `STORE_BACKEND`        | No          | `memory`                   | Storage driver: `memory`, `sqlite`, `dynamodb`     |
| `DATABASE_URL`         | No          | `/tmp/events.db`           | SQLite path (ignored for DynamoDB)                 |
| `DYNAMODB_TABLE`       | Yes (cloud) | —                          | DynamoDB table name                                |
| `METRICS_DEMO_ENABLED` | No          | `false`                    | Enable `/metrics-demo` endpoint                    |
| `API_KEY`              | No          | —                          | Optional static API key auth (header: `x-api-key`) |
| `MAX_EVENTS_LIMIT`     | No          | `100`                      | Max allowed `limit` query param                    |


Copy `.env.example` to `.env` — no secret values are ever committed.

---

## Infrastructure Deployment

### Bootstrap (one-time, per AWS account)

Creates the S3 state bucket and DynamoDB lock table:

```bash
cd infra/terraform/bootstrap
terraform init
terraform apply
```

### Deploy an environment

```bash
cd infra/terraform/envs/dev

# Initialise backend
terraform init

# Validate
terraform validate

# Preview changes
terraform plan -var-file="terraform.tfvars"

# Apply
terraform apply -var-file="terraform.tfvars"
```

### View outputs after apply

```bash
terraform output
# api_endpoint         = "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/"
# lambda_function_name = "skynet-ops-audit-service-dev"
# dynamodb_table_name  = "skynet-ops-audit-service-dev"
# ecr_repository_url   = "244143925680.dkr.ecr.us-east-1.amazonaws.com/skynet-ops-audit-service-dev"
```

### Build and push container image

```bash
# Authenticate ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  244143925680.dkr.ecr.us-east-1.amazonaws.com

# Build
docker build -t skynet-ops-audit-service-dev .

# Tag
docker tag skynet-ops-audit-service-dev:latest \
  244143925680.dkr.ecr.us-east-1.amazonaws.com/skynet-ops-audit-service-dev:latest

# Push
docker push \
  244143925680.dkr.ecr.us-east-1.amazonaws.com/skynet-ops-audit-service-dev:latest

# Update Lambda with new image
aws lambda update-function-code \
  --function-name skynet-ops-audit-service-dev \
  --image-uri 244143925680.dkr.ecr.us-east-1.amazonaws.com/skynet-ops-audit-service-dev:latest \
  --region us-east-1
```

---

## Teardown

### Destroy a single environment

```bash
cd infra/terraform/envs/dev
terraform destroy -var-file="terraform.tfvars"
```

> **Prod note:** `enable_deletion_protection = true` on the prod DynamoDB table. You must disable this first before destroying:
>
> ```bash
> terraform apply -var-file="terraform.tfvars" -var="enable_deletion_protection=false"
> terraform destroy -var-file="terraform.tfvars"
> ```

### Manual cleanup checklist after destroy

- ECR images purged (lifecycle policy retains up to 10, `aws ecr delete-repository --force`)
- CloudWatch log groups deleted (retained 7–14 days by Terraform, may persist briefly)
- SNS subscriptions confirmed as removed
- S3 state bucket emptied then deleted (if full teardown)
- DynamoDB lock table deleted (bootstrap resources)
- Budgets removed from AWS Console (not always destroyed by Terraform)

---

## AWS Resources Created


| Service               | Resource                                     | Environments       |
| --------------------- | -------------------------------------------- | ------------------ |
| Lambda                | `skynet-ops-audit-service-{env}`             | dev, staging, prod |
| API Gateway           | `skynet-ops-audit-service-{env}` (HTTP)      | dev, staging, prod |
| DynamoDB              | `skynet-ops-audit-service-{env}`             | dev, staging, prod |
| DynamoDB              | `skynet-ops-terraform-locks`                 | shared             |
| ECR                   | `skynet-ops-audit-service-{env}`             | dev, staging, prod |
| SQS                   | `skynet-ops-audit-service-{env}-dlq`         | dev, staging, prod |
| SNS                   | `skynet-ops-audit-service-{env}-alarms`      | dev, staging, prod |
| CloudWatch Alarms     | errors / duration / throttles                | dev, staging, prod |
| CloudWatch Log Groups | lambda + apigateway                          | dev, staging, prod |
| IAM Role              | `skynet-ops-audit-service-{env}-lambda-role` | dev, staging, prod |
| IAM Policies          | dynamodb-policy, dlq-policy                  | dev, staging, prod |
| Cognito User Pool     | `skynet-ops-audit-service-prod-user-pool`    | prod only          |
| S3                    | `skynet-ops-terraform-state-244143925680`    | shared             |
| AWS Budgets           | per-env monthly budget                       | dev, staging, prod |


---

## Screenshots Folder


| #   | What to Screenshot                           | Console Path                                               |
| --- | -------------------------------------------- | ---------------------------------------------------------- |
| 1   | API Gateway — dev stage invoke URL           | API Gateway → APIs → skynet-ops-audit-service-dev → Stages |
| 2   | Lambda functions list (all 3 envs)           | Lambda → Functions                                         |
| 3   | Lambda prod — image URI + config             | Lambda → skynet-ops-audit-service-prod → Image tab         |
| 4   | DynamoDB tables list (all 4)                 | DynamoDB → Tables                                          |
| 5   | DynamoDB prod — deletion protection ON       | DynamoDB → skynet-ops-audit-service-prod → Overview        |
| 6   | ECR repositories list (all 3)                | ECR → Private repositories                                 |
| 7   | CloudWatch Alarms — all 9, all OK            | CloudWatch → Alarms                                        |
| 8   | CloudWatch Log Groups — all 6 with retention | CloudWatch → Log Groups                                    |
| 9   | SQS DLQ queues (all 3)                       | SQS → Queues                                               |
| 10  | SNS topics (all 3)                           | SNS → Topics                                               |
| 11  | Cognito — prod user pool overview            | Cognito → User pools → prod                                |
| 12  | AWS Budgets — all 3 budgets healthy          | Billing → Budgets                                          |
| 13  | S3 — terraform state bucket (3 folders)      | S3 → skynet-ops-terraform-state-244143925680               |
| 14  | curl output — GET /health (live)             | Terminal                                                   |
| 15  | curl output — POST /events (live 201)        | Terminal                                                   |
| 16  | curl output — GET /events (with results)     | Terminal                                                   |
| 17  | curl output — metrics-demo all 4 modes       | Terminal                                                   |
| 18  | curl output — 400 on bad payload             | Terminal                                                   |
| 19  | CloudWatch — Lambda invocation metrics graph | CloudWatch → Metrics → Lambda                              |
| 20  | CloudWatch Logs Insights — sample log query  | CloudWatch → Logs Insights                                 |


---

## Key Design Decisions

**Why Lambda over ECS/EC2?**  
At 5,000–20,000 requests/day (~0.2 req/s average), Lambda's scale-to-zero fits perfectly. No idle compute cost. Cold starts are acceptable for a pilot audit service — not a user-facing critical path.

**Why DynamoDB PAY_PER_REQUEST?**  
At pilot scale (200–2,000 events/day), provisioned capacity would waste money. On-demand billing charges only for what's used. Estimated read/write cost: under $1/month at pilot volume.

**Why HTTP API Gateway over REST API?**  
HTTP API costs ~$1/million vs REST API's ~$3.50/million. For a pilot service, this is a 70% cost saving with no feature loss at our scale.

**Why a DLQ?**  
Lambda async failures (retried 2×) go to the SQS DLQ, giving visibility into poison-pill events without losing them.

**Why separate IAM policies per permission?**  
Least-privilege design: the Lambda role only gets DynamoDB (4 specific actions on its own table), SQS SendMessage to its own DLQ, CloudWatch Logs, and X-Ray. No wildcards.

---

## Cost Summary

See `[docs/cost-optimization-report.md](docs/cost-optimization-report.md)` for full breakdown.

**Estimated monthly spend (all 3 envs):** ~$18–35/month  
**Budgets set:** dev $50 / staging $20 / prod $50

---

## Tech Stack

- **Runtime:** Node.js 20 (Lambda container image)
- **Framework:** Express 5 + serverless-http
- **Storage:** DynamoDB (cloud) / SQLite / in-memory (local)
- **Logging:** Pino (structured JSON)
- **IaC:** Terraform ≥ 1.5, modular
- **Auth (prod):** AWS Cognito JWT
- **Observability:** CloudWatch Logs + Metric Alarms + X-Ray

