# AIRMAN Skynet Cloud Ops Intern Assessment — Submission Checklist

> Candidate: Arpit Pandey

---

## 1) Candidate & Submission Info

- **Name:** Arpit Pandey
- **Email:** **[arpitpandey175ad@gmail.com](mailto:arpitpandey175ad@gmail.com)**
- **Chosen Cloud Platform:** AWS (us-east-1)
- **Assessment Level Submitted:** Level 1  and Level 2 B and D
- **Level 2 Option Chosen (if any):** B AND D
- **GitHub Repo Link:** [https://github.com/arpitpandeygit/skynet-ops-audit-service](https://github.com/arpitpandeygit/skynet-ops-audit-service)
- **Submission Date (UTC):** 2026-03-01

---

## 2) What I Implemented (Summary)

### Level 1

- Mini service (`GET /health`, `POST /events`, `GET /events`, `GET /metrics-demo`)
- Dockerized service (container image, FROM public.ecr.aws/lambda/nodejs:20)
- Cloud deployment — **real cloud deployment** on AWS (Lambda + API Gateway + DynamoDB), all 3 environments live
- Infrastructure as Code — Terraform modular (10+ modules: lambda, apigateway, dynamodb, ecr, iam, monitoring, alerts, budget, dlq, cognito, cicd)
- Cost optimization report (`docs/cost-optimization-report.md`)
- Observability setup — CloudWatch Logs (structured JSON), 9 CloudWatch Alarms, X-Ray tracing, metric filters, API Gateway access logs
- Security/secrets approach — IAM least-privilege, no secrets committed, `.env.example`, optional Cognito JWT auth (prod), ECR image scanning
- Ops runbook (`docs/ops-runbook.md`) — 6 scenarios covered
- README with setup + teardown (`README.md`)

### Level 2

#### Option B — CI/CD for Safe Cloud Deployments

- CI/CD pipeline via GitHub Actions OIDC role (cicd Terraform module) — no long-lived AWS access keys stored in GitHub - Secrets; role assumed via token.actions.githubusercontent.com federated identity scoped to repo:arpitpandeygit/skynet-ops-audit-service:*
- IAM role provisioned with AmazonEC2ContainerRegistryFullAccess for ECR push and AdministratorAccess for Terraform apply — scoped by OIDC condition to the specific repo
- Deploy pipeline: docker build → docker push to ECR → aws lambda update-function-code → aws lambda wait - function-updated — deterministic image promotion per environment
- ECR lifecycle policy enforces max 10 images per repo — prevents registry accumulation between CI runs
- Environment promotion order enforced: dev → staging → prod, each with its own Terraform state backend (dev/terraform.tfstate, staging/terraform.tfstate, prod/terraform.tfstate) in S3 — no cross-environment state bleed
- Rollback documented: prior ECR image digest retrieved via aws ecr describe-images sort and re-targeted via aws lambda update-function-code --image-uri ...@sha256:  (docs/ops-runbook.md Scenario 5)

#### Option D — Multi-Environment Blueprint with Cost Governance

- Three fully independent environments (dev / staging / prod) deployed from a single reusable Terraform root module (infra/terraform/main.tf) with per-env terraform.tfvars — identical module, different parameters
- Per-environment security posture: enable_jwt_auth = false (dev/staging) vs enable_jwt_auth = true + Cognito JWT authorizer (prod); enable_deletion_protection = false (dev/staging) vs true (prod DynamoDB)
- Per-environment Lambda tuning: reserved_concurrency = 2 (dev) / 5 (staging) / 10 (prod); lambda_error_threshold = 10/5/3; lambda_duration_threshold = 5000/3000/2000 ms
- Per-environment API throttling: rate_limit = 100, burst = 200 (dev) / 50, 100 (staging) / 20, 40 (prod) — tighter prod controls prevent runaway cost and abuse
- Per-environment log retention: 3 days (dev) / 7 days (staging) / 14 days (prod) — intentionally minimized for cost control
- Per-environment AWS Budgets: dev $50/month / staging $20/month / prod $50/month — each with 80% + 100% email alerts provisioned via budget Terraform module
- Remote state isolation: each environment uses a separate S3 key (dev/, staging/, prod/) + shared DynamoDB lock table (skynet-ops-terraform-locks) — concurrent applies across envs are safe
- CORS lockdown by environment: cors_allowed_origins = ["*"] (dev/staging) → ["[https://yourdomain.com"]](https://yourdomain.com"]) (prod)
- Full cost governance documented in docs/cost-optimization-report.md — per-component cost math, 12 cost traps, teardown checklist

---

## 3) Repository Structure (actual paths)

### Service Code

- Service path: `src/`
- Main entry file: `src/server.js` (local), `src/lambda.js` (Lambda handler)
- Local run command: `npm run dev` or `bash scripts/run-local.sh`

### Docker

- Dockerfile path: `Dockerfile`
- `.dockerignore` path: `.dockerignore`

### Infrastructure as Code

- IaC tool used: **Terraform**
- IaC root path: `infra/terraform/`
- Bootstrap (state bucket + lock table): `infra/terraform/bootstrap/`
- Root module: `infra/terraform/main.tf`
- Environment config files: `infra/terraform/envs/dev/terraform.tfvars`, `infra/terraform/envs/staging/terraform.tfvars`, `infra/terraform/envs/prod/terraform.tfvars`

### Docs

- README path: `README.md`
- Cost report path: `docs/cost-optimization-report.md`
- Runbook path: `docs/ops-runbook.md`
- Observability notes path: `docs/observability-monitoring.md`
- Security/secrets notes path: `docs/security-secrets.md`

### Sample Data

- Sample events: `sample_events.json` (20 events across 3 tenants and all event types)

---

## 4) Local Run Instructions

### Prerequisites

- Docker installed
- Node.js 20.x installed
- Terraform ≥ 1.5.0 installed
- AWS CLI v2 installed + credentials configured
- jq installed (for pretty-printing curl responses)

### Local Setup

```bash
git clone https://github.com/arpitpandeygit/skynet-ops-audit-service.git
cd skynet-ops-audit-service
npm install
cp .env.example .env
```

### Run Service Locally

```bash
# Option A: Node.js directly (in-memory store)
npm run dev

# Option B: Docker
docker build -t skynet-ops-audit-service .
docker run -p 9000:8080 \
  -e APP_ENV=dev \
  -e STORE_BACKEND=memory \
  -e LOG_LEVEL=info \
  -e METRICS_DEMO_ENABLED=true \
  skynet-ops-audit-service
```

### Test Endpoints Locally

```bash
# Health
curl -s http://localhost:8080/health | jq

# Post event
curl -X POST http://localhost:8080/events \
  -H "Content-Type: application/json" \
  -d '{"type":"roster_update","tenantId":"academy_001","severity":"info","message":"Test event","source":"cli-test"}' | jq

# Get events
curl -s "http://localhost:8080/events?limit=5" | jq

# Metrics demo
curl -s "http://localhost:8080/metrics-demo?mode=slow" | jq
```

---

## 5) API Endpoint Checklist (Functional Validation)

### Health

- `GET /health` works — returns `{"status":"ok","service":"skynet-ops-audit-service","environment":"dev","timestamp":"...","store":"dynamodb"}`

**Live test result:**

```
https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/health
→ 200 {"status":"ok","service":"skynet-ops-audit-service","environment":"dev","timestamp":"2026-03-01T14:12:52.865Z","store":"dynamodb"}
```

### Events

- `POST /events` stores an event — returns 201 with `eventId` and `storedAt`
- `GET /events` returns events — returns paginated list with `items`, `total`, `limit`, `offset`
- Validation rejects bad payloads — returns 400 on missing fields, invalid severity, invalid JSON

**Live test results:**

```
POST /events (valid)      → 201 {"success":true,"eventId":"evt_...","storedAt":"..."}
POST /events (bad JSON)   → 400 {"error":"Invalid JSON"}
POST /events (bad sev)    → 400 {"error":"Invalid severity"}
POST /events (missing)    → 400 {"error":"Missing required fields"}
GET /events               → 200 {"items":[],"total":0,"limit":20,"offset":0}
GET /events?tenantId=...  → 200 filtered results
```

### Optional

- `GET /metrics-demo` implemented
- Route can simulate latency/errors for observability testing

**Live test results:**

```
GET /metrics-demo              → 200 {"status":"metrics-demo-ok"}
GET /metrics-demo?mode=error   → 500 {"error":"Simulated error"}
GET /metrics-demo?mode=slow    → 200 {"status":"slow-response","delay":1987}
GET /metrics-demo?mode=burst   → 200 {"status":"burst-logs-emitted"}
```

---

## 6) Cloud Deployment Summary

### Deployment Type

- **Real cloud deployment** — service is live and publicly accessible on AWS

### Cloud Services Used


| Category           | Service                           | Resource                                                          |
| ------------------ | --------------------------------- | ----------------------------------------------------------------- |
| Compute            | AWS Lambda                        | `skynet-ops-audit-service-{dev,staging,prod}`                     |
| API Layer          | AWS API Gateway (HTTP API)        | `skynet-ops-audit-service-{env}`                                  |
| Storage/DB         | Amazon DynamoDB (PAY_PER_REQUEST) | `skynet-ops-audit-service-{env}` + GSI                            |
| Container Registry | Amazon ECR                        | `skynet-ops-audit-service-{env}` (lifecycle: keep last 10 images) |
| Logging            | Amazon CloudWatch Logs            | 6 log groups (lambda + apigateway per env)                        |
| Monitoring         | Amazon CloudWatch Alarms          | 9 alarms (3 per env)                                              |
| Metrics            | CloudWatch Metric Filters         | Custom `ApplicationErrors` metric                                 |
| Tracing            | AWS X-Ray                         | Active mode on all Lambda functions                               |
| Alerting           | Amazon SNS                        | 3 topics (per env)                                                |
| Error Handling     | Amazon SQS                        | 3 DLQs (per env)                                                  |
| Auth               | Amazon Cognito                    | 1 User Pool (prod only)                                           |
| Secrets / Config   | Lambda Environment Variables      | No secrets manager needed (IAM role auth)                         |
| Budgeting          | AWS Budgets                       | 3 budgets: dev $50, staging $20, prod $50                         |
| IAM                | IAM Roles + Policies              | Least-privilege per env (4 policies each)                         |
| State              | Amazon S3                         | `skynet-ops-terraform-state-244143925680`                         |
| State Lock         | Amazon DynamoDB                   | `skynet-ops-terraform-locks`                                      |
| CI/CD              | IAM OIDC Provider                 | GitHub Actions role (no long-lived keys)                          |


### Why I Chose This Architecture

- **Lambda over ECS/EC2:** At 5,000–20,000 requests/day, Lambda costs near-zero (scale-to-zero). An always-on EC2/ECS task would cost $15–30/month idle.
- **HTTP API Gateway over REST API:** 70% cheaper per million requests ($1.00 vs $3.50). Supports JWT authorizers natively.
- **DynamoDB PAY_PER_REQUEST:** No minimum provisioned cost. At pilot scale, actual cost is cents/month.
- **ECR + container image:** Consistent environment between local Docker and Lambda. No zip packaging complexity.
- **Terraform modular:** Each environment is independently deployable and configurable. Modules are reusable across dev/staging/prod with different variables.

### Pilot Cost-Awareness Notes

- Dev Lambda: `reserved_concurrency = 2` — prevents unintended cost from traffic spikes
- Log retention: 7 days (dev/staging), 14 days (prod) — intentional to control CloudWatch storage cost
- ECR lifecycle policy: keeps only last 10 images — prevents registry storage accumulation
- No VPC / NAT Gateway: Lambda runs without VPC; NAT Gateway would cost ~$32/month minimum
- Budgets with email alerts on Day 1 — never surprised by spend
- Estimated actual cost: ~$3.57–7.50/month across all 3 environments (current: $0.00)

---

## 7) Cost Optimization Report

See full report: `[docs/cost-optimization-report.md](docs/cost-optimization-report.md)`

### Cost Estimate Summary


| Environment | Budget Cap     | Estimated Monthly | Status                   |
| ----------- | -------------- | ----------------- | ------------------------ |
| dev         | $50/month      | ~$0.75–2.00       | ✅ Healthy ($0.00 actual) |
| staging     | $20/month      | ~$0.57–1.50       | ✅ Healthy ($0.00 actual) |
| prod        | $50/month      | ~$1.81–3.50       | ✅ Healthy ($0.00 actual) |
| **Total**   | **$120/month** | **~$3.13–7.00**   | ✅ Under $75 target       |


### Cost Controls Implemented

- AWS Budgets: 3 monthly budgets with 80% + 100% email alerts
- Billing alerts: SNS + email per environment
- Tags for cost tracking: `Project`, `Environment`, `CostCenter`, `ManagedBy`
- Log retention policy: 7 days dev/staging, 14 days prod
- Non-prod scale-to-zero: Lambda inherently scales to zero
- Lambda reserved concurrency: 2 (dev), 5 (staging), 10 (prod) — cost cap
- ECR lifecycle policy: max 10 images per repo
- No NAT Gateway, no idle EC2, no ALB
- Teardown instructions provided in README

### Common Cost Traps Accounted For

1. Idle compute instances — eliminated by Lambda
2. Overprovisioned managed databases — DynamoDB PAY_PER_REQUEST
3. Excessive logging volume — `info` level in all cloud envs
4. NAT gateway charges — Lambda not in VPC; no NAT needed
5. Static IPs / load balancers left running — not used
6. Container registry image accumulation — ECR lifecycle policy (max 10)
7. Cross-region traffic — all resources in us-east-1
8. Snapshots and unattached disks — no EBS volumes
9. Cognito over-provisioning — enabled only for prod
10. X-Ray over-sampling — Active mode (sampled, not 100%)
11. CloudWatch alarm cost — only 9 alarms across 3 envs ($0.10/alarm/month)
12. SNS notification cost — free tier covers pilot alert volume

---

## 8) Observability & Monitoring

See full notes: `[docs/observability-monitoring.md](docs/observability-monitoring.md)`

### Logging

- Structured logs implemented (Pino JSON logger)
- Log level configurable via `LOG_LEVEL` env var
- Sample logs: every `POST /events` emits `{"level":30,"eventId":"evt_...","msg":"Event stored",...}`

### Metrics

- Request latency: CloudWatch `Duration` metric on all Lambda functions
- Error count / error rate: CloudWatch `Errors` metric + custom `ApplicationErrors` metric filter (Pino level=50)
- Traffic volume: CloudWatch `Invocations` metric; API Gateway `Count` metric
- Health signal: `GET /health` endpoint; API Gateway `4XXError` + `5XXError` metrics

### Alerts

**Alert #1 — Lambda Error Rate**

- Dev: Errors ≥ 5 per 5-minute window
- Prod: Errors ≥ 3 per 5-minute window
- Rationale: 3 consecutive Lambda failures in 5 minutes indicates a real service issue, not noise

**Alert #2 — Lambda Latency**

- Dev: Avg Duration > 3000 ms per 5-minute window
- Prod: Avg Duration > 2000 ms per 5-minute window
- Rationale: Spec target is POST /events < 500 ms. 2s avg indicates severe degradation (DynamoDB issue, cold start wave, or logic bug)

**Alert #3 — Lambda Throttles** (bonus)

- All envs: Throttles ≥ 1 per 5-minute window
- Rationale: Any throttle means reserved concurrency is exhausted. Immediate alert needed to increase capacity or investigate traffic source.

### Evidence

- CloudWatch Alarms: 9 alarms across 3 environments, all in **OK** state (screenshot required)
- CloudWatch Log Groups: 6 groups with retention policies (screenshot required)
- Metric filter `ApplicationErrors` deployed on all Lambda log groups (screenshot required)

---

## 9) Security / Secrets / IAM

See full notes: `[docs/security-secrets.md](docs/security-secrets.md)`

### Secrets

- No secrets committed to repo (`.env`, credentials, state files in `.gitignore`)
- `.env.example` included with placeholder values only
- Secrets management: No database passwords needed — IAM role-based DynamoDB access

### IAM / Access Control

- Service permissions listed: DynamoDB (PutItem, GetItem, Query, Scan), SQS (SendMessage), CloudWatch Logs, X-Ray
- Least-privilege approach: Customer-managed policies scoped to exact table ARN and DLQ ARN
- Dangerous overbroad permissions identified: No `dynamodb:`*, no `s3:`*, no `iam:*` anywhere in Lambda role

### Security Basics

- Container hardening: Non-root Lambda runtime, `npm install --omit=dev`, ECR `scan_on_push = true`
- Public exposure / ingress controls: API Gateway HTTPS only; throttling at gateway level; CORS restricted to specific origins (prod); JWT auth enabled on prod

---

## 10) Ops Runbook

See full runbook: `[docs/ops-runbook.md](docs/ops-runbook.md)`

**Runbook file path:** `docs/ops-runbook.md`

### Covered Scenarios

- Service down / health checks failing
- Latency spike
- Sudden cost spike
- DB/storage issue
- Bad deployment / rollback
- Accidental public exposure / misconfiguration

---

## 11) IaC Validation / Reproducibility

### Terraform

- `terraform init` works (S3 backend + DynamoDB lock configured)
- `terraform validate` works (all modules valid)
- `terraform plan` works (confirmed during deployment)
- Variables documented in `variables.tf` per env and root module
- Outputs documented: `api_endpoint`, `lambda_function_name`, `dynamodb_table_name`, `ecr_repository_url`

**Confirmed outputs (dev):**

```
api_endpoint         = "https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/"
dynamodb_table_name  = "skynet-ops-audit-service-dev"
ecr_repository_url   = "244143925680.dkr.ecr.us-east-1.amazonaws.com/skynet-ops-audit-service-dev"
lambda_function_name = "skynet-ops-audit-service-dev"
```

### Teardown

- Destroy/cleanup steps documented in `README.md#teardown`
- Resource cleanup caveats noted:
  - CloudWatch log groups are deleted after their retention period (7–14 days), not immediately on `terraform destroy`
  - Prod DynamoDB has `deletion_protection_enabled = true` — must disable before destroy
  - ECR images require `--force` flag or manual purge before repository deletion
  - SNS subscription confirmations are automatically cancelled on topic deletion
  - S3 state bucket must be manually emptied before deletion

---

## 12) Known Limitations / Trade-offs

1. **DynamoDB Scan without tenantId filter:** `GET /events` without a `tenantId` query parameter performs a full table scan. At large event volumes this becomes slow and costly. Future fix: require `tenantId` on GET or implement a GSI on `storedAt` for newest-first full listing.
2. **No PITR on DynamoDB:** Point-in-time recovery is disabled to minimize cost for pilot. Should be enabled before production go-live for audit trail integrity requirements.
3. **In-memory store loses data on restart:** The `memory` store (local dev default) is non-persistent. Acceptable for local testing only — cloud deployments use DynamoDB.
4. **SNS email subscriptions unconfirmed:** The alarm SNS topics have pending email subscriptions. Until confirmed, CloudWatch alarms fire but no email is delivered. Action: confirm the subscription emails from [arpitxid@gmail.com](mailto:arpitxid@gmail.com).
5. **Cognito prod domain placeholder:** The prod `jwt_issuer` in `terraform.tfvars` references a placeholder domain. The Cognito user pool and client exist and are correctly provisioned, but a real production setup would require updating the Cognito Hosted UI domain and configuring real users.

---

## 13) AI Tool Usage Disclosure

### AI tools used

- Chatgpt — used for Code files tuning
- Chatgpt — used for documentation drafting and boilerplate structuring

### What I used AI for

- Drafting initial documentation structure and markdown files
- Generating curl command examples based on my actual deployed endpoints and responses
- Cross-checking Terraform module completeness against the spec requirements

### What I manually verified / tested

- All live curl commands against the deployed dev API (all responses shown in README are real)
- All Terraform modules — written, applied, and validated manually (`terraform validate`, `terraform plan`, `terraform apply`)
- All CloudWatch alarms — verified in console (all 9 shown as OK)
- All AWS resources — confirmed live in AWS Console (Lambda, DynamoDB, ECR, SQS, SNS, Cognito, Budgets)
- The full `terraform destroy` and re-`terraform apply` cycle was tested at least once per environment

---

## 14) Final Notes

This submission covers Level 1 and Level 2 (B and D) of the assessment. Key design philosophy throughout:

- Chose the simplest cloud-native architecture that meets the spec — Lambda + HTTP API + DynamoDB is the minimum viable serverless stack on AWS, and it is genuinely the right choice for 5,000–20,000 req/day at pilot scale.
- Did not over-engineer for 99.99% — the 99.0% pilot target is appropriate and guides every decision (no multi-AZ, no read replicas, no ALB).
- All three environments (dev, staging, prod) are live and independently configurable, demonstrating real multi-environment ops thinking and not just a single throwaway deployment.
- Terraform modules are genuinely reusable — the same root module produces dev/staging/prod with different variable files, including environment-specific security posture (JWT auth only in prod).
- Cost is actively managed: budgets, alerts, reserved concurrency caps, log retention policies, and ECR lifecycle policies are all in place from Day 1.
- CI/CD is secure by design — GitHub Actions uses OIDC federation (no stored AWS credentials), ECR lifecycle policies prevent image accumulation, and rollback to any prior image digest is documented and tested.
- Multi-environment is not cosmetic — dev/staging/prod differ in concurrency limits, alarm thresholds, API throttling, log retention, CORS policy, JWT auth enforcement, and DynamoDB deletion protection, all driven by the same Terraform module with environment-specific variable files.

