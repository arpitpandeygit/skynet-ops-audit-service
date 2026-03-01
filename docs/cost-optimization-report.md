# Cost Optimization Report — skynet-ops-audit-service

**Assessment:** AIRMAN Cloud Ops Intern TA  
**Cloud Platform:** AWS (us-east-1)  
**Environments:** dev · staging · prod  
**Report Date:** 2026-03-01  
**Budget Target:** $25–$75/month (mini service, pilot-scale)

---

## 1. Workload Assumptions Used

| Parameter | Value |
|---|---|
| Daily requests | 5,000–20,000 |
| POST /events | 55% of traffic |
| GET /events | 35% of traffic |
| GET /health | 10% of traffic |
| Events stored/day | 200–2,000 |
| Payload size (POST) | 0.5–5 KB |
| Response size (GET) | 5–40 KB |
| Monthly raw event data | ~10–250 MB |
| Traffic pattern | Bursty; 70% in 10-hour window |
| Tenants | 1–3 flight academies |

---

## 2. Architecture Choices Driven by Cost

### Lambda (scale-to-zero)
Lambda was chosen specifically because it costs nothing when idle. At 5,000–20,000 requests/day (~0.06–0.23 req/s average), a running EC2 or ECS task would be idle 99% of the time and still billed hourly.

Lambda pricing: first 1M requests/month free, then $0.20/M. At 600,000 requests/month (max estimate), this is effectively **free** under the free tier for a new account, and under **$0.12/month** beyond it.

### HTTP API Gateway (not REST API)
HTTP API: **$1.00/million requests**  
REST API: **$3.50/million requests**

At 600K requests/month: HTTP = ~$0.60, REST = ~$2.10. Chosen HTTP API for 70% cost reduction. HTTP API supports JWT authorizers natively, so no Lambda authorizer cost.

### DynamoDB PAY_PER_REQUEST (not provisioned)
Provisioned: minimum ~$14/month (1 RCU + 1 WCU) with no traffic benefit.  
PAY_PER_REQUEST: ~$0.00125 per WCU, $0.00025 per RCU.

At 2,000 writes/day (~60,000/month) and 7,000 reads/day (~210,000/month):
- Write cost: 60,000 × $0.00000125 = **$0.075/month**
- Read cost: 210,000 × $0.00000025 = **$0.053/month**
- Total DynamoDB: **~$0.13–0.50/month** (well within budget)

No NAT gateway, no VPC (Lambda not placed in VPC — no reason at this scale).

### ECR Lifecycle Policy
Each ECR repository has a lifecycle policy to keep only the last 10 images. Without this, old images accumulate at $0.10/GB/month indefinitely.

```json
{ "countType": "imageCountMoreThan", "countNumber": 10, "action": { "type": "expire" } }
```

### Log Retention (Intentional)
| Environment | Lambda Logs | API Gateway Logs |
|---|---|---|
| dev | 7 days (1 week) | 7 days |
| staging | 7 days | 7 days |
| prod | 14 days | 14 days |

CloudWatch log storage: $0.03/GB ingested + $0.03/GB stored/month.  
At ~5 MB logs/day pilot scale, monthly log cost < **$0.50/month per env**.

---

## 3. Monthly Cost Estimate

### Dev Environment

| Component | Config | Est. Monthly Cost |
|---|---|---|
| Lambda | 512 MB · 10s timeout · reserved 2 · ~200K invocations | $0.00 (free tier) |
| API Gateway (HTTP) | ~200K requests | $0.20 |
| DynamoDB | PAY_PER_REQUEST, ~15K events | $0.05 |
| CloudWatch Logs | 7-day retention, ~50 MB/month | $0.15 |
| CloudWatch Alarms | 3 alarms | $0.30 |
| ECR | 1 repo, lifecycle-managed | $0.05 |
| SQS DLQ | negligible traffic | $0.00 |
| SNS | negligible (alerts only) | $0.00 |
| Budget | monitoring only | $0.00 |
| **Dev Total** | | **~$0.75–2.00/month** |

> Dev Lambda has `reserved_concurrency = 2` — prevents runaway cost from accidental traffic spikes.

### Staging Environment

| Component | Config | Est. Monthly Cost |
|---|---|---|
| Lambda | 512 MB · reserved 5 · ~100K invocations | $0.00 (free tier) |
| API Gateway | ~100K requests | $0.10 |
| DynamoDB | PAY_PER_REQUEST, ~5K events | $0.02 |
| CloudWatch Logs | 7-day retention | $0.10 |
| CloudWatch Alarms | 3 alarms | $0.30 |
| ECR | 1 repo | $0.05 |
| SQS/SNS | negligible | $0.00 |
| **Staging Total** | | **~$0.57–1.50/month** |

### Prod Environment

| Component | Config | Est. Monthly Cost |
|---|---|---|
| Lambda | 512 MB · reserved 10 · ~400K invocations | $0.00 (free tier) → $0.08 beyond |
| API Gateway | ~400K requests | $0.40 |
| DynamoDB | PAY_PER_REQUEST, ~60K events | $0.25 |
| CloudWatch Logs | 14-day retention, ~100 MB | $0.30 |
| CloudWatch Alarms | 3 alarms | $0.30 |
| ECR | 1 repo | $0.05 |
| Cognito | Essentials plan, 0 MAU currently | $0.00 |
| SQS/SNS | minimal | $0.01 |
| X-Ray tracing | Active mode, sampled traces | $0.50 |
| **Prod Total** | | **~$1.81–3.50/month** |

### All-Environment Summary

| Env | Budget Cap | Est. Actual | Headroom |
|---|---|---|---|
| dev | $50/month | ~$1–2 | >95% |
| staging | $20/month | ~$0.57–1.50 | >92% |
| prod | $50/month | ~$2–4 | >92% |
| **Total** | **$120/month** | **~$3.57–7.50/month** | |

**Well within the $25–75/month assessment target.** Actual spend confirmed at $0.00 for all three environments at time of this report (see AWS Budgets screenshots).

---

## 4. Cost Controls Implemented

### Budgets and Alerts
Three AWS Budget monitors are active:

| Budget | Cap | Alert at 80% | Alert at 100% | Email |
|---|---|---|---|---|
| skynet-ops-audit-service-dev-monthly-budget | $50 | $40 → email | $50 → email | arpitxid@gmail.com |
| skynet-ops-audit-service-staging-monthly-budget | $20 | $16 → email | $20 → email | arpitxid@gmail.com |
| skynet-ops-audit-service-prod-monthly-budget | $50 | $40 → email | $50 → email | arpitxid@gmail.com |

Budget ARNs provisioned via the `budget` Terraform module. Alerts fire to email on Day 1 before runaway spend occurs.

### Resource Tags for Cost Tracking
All resources are tagged:
```hcl
Project     = "skynet-ops-audit-service"
Environment = "dev" | "staging" | "prod"
ManagedBy   = "terraform"
CostCenter  = "engineering"   # Lambda resources
```

These tags enable Cost Explorer filtering by environment or project to isolate spend.

### Lambda Reserved Concurrency (Cost Cap)
| Environment | Reserved Concurrency |
|---|---|
| dev | 2 |
| staging | 5 |
| prod | 10 |

Reserved concurrency caps the maximum parallel Lambda executions, preventing an accidental traffic spike from generating thousands of concurrent invocations and unexpected cost.

### Non-Prod Scale-to-Zero
Lambda inherently scales to zero — no invocations = zero Lambda cost. Unlike ECS or EC2, there is no "idle running" charge. Dev and staging cost nothing when not receiving traffic.

### Log Retention Policy
CloudWatch log storage at pilot scale is cheap but unbounded retention is a trap. Retention is set at the minimum useful period per environment (7 days dev/staging, 14 days prod). Logs older than this are automatically deleted.

### ECR Image Lifecycle Policy
Without lifecycle rules, each `docker push` accumulates images indefinitely. The lifecycle policy expires any images beyond the 10 most recent, preventing silent storage accumulation.

### Terraform State in S3 (not Terraform Cloud)
Using S3 + DynamoDB for state storage instead of Terraform Cloud keeps state management within the AWS account at near-zero cost (S3 negligible, DynamoDB PAY_PER_REQUEST lock table = cents).

---

## 5. Common Cost Traps Accounted For

1. **Idle compute instances** — Avoided entirely by choosing Lambda (scale-to-zero).

2. **Overprovisioned managed databases** — DynamoDB PAY_PER_REQUEST instead of provisioned capacity. No RDS minimum instance cost (~$15/month minimum for smallest RDS).

3. **Excessive log volume** — Log level set to `info` (not `debug`) in all cloud environments. Debug logging in `debug` would produce 10× more log data and ingestion cost.

4. **NAT gateway charges** — Lambda is NOT placed in a VPC. NAT gateway costs ~$32/month at minimum. Not needed for this service.

5. **Static IPs / Elastic IPs** — Not used. API Gateway provides DNS directly. No EIP sitting idle.

6. **Load balancer left running** — Not applicable. API Gateway HTTP API replaces ALB at lower cost for Lambda integrations.

7. **Snapshots and unattached disks** — No EBS volumes used anywhere. Lambda ephemeral storage (512 MB) is included in Lambda pricing.

8. **Container registry image accumulation** — ECR lifecycle policy set on all 3 repos: max 10 images retained.

9. **Cross-region traffic** — All resources in a single region (us-east-1). No cross-region replication for this pilot.

10. **Cognito over-provisioning** — Cognito Essentials plan, only enabled for prod. Dev and staging use no JWT auth — no Cognito cost.

11. **X-Ray trace volume** — X-Ray Active tracing on Lambda is sampled (not 100%). At low pilot traffic, trace volume cost is negligible (~$0.50/month).

12. **Unconfirmed SNS subscriptions** — SNS email subscriptions pending confirmation do not incur message delivery cost until confirmed. Alert noted in console; no impact on cost until confirmed.

---

## 6. Teardown / Cleanup Procedure

Full teardown steps are documented in [`README.md`](../README.md#teardown).

Key cost-incurring resources to verify are removed after teardown:
- Lambda functions (check for lingering reserved concurrency)
- API Gateway stages
- DynamoDB tables (prod has deletion protection — must disable first)
- CloudWatch log groups (auto-deleted after retention period)
- ECR repositories (use `--force` flag to clear images)
- SNS subscriptions
- Budgets (verify in console — may not auto-delete)
- S3 state bucket (must empty before delete)

---

## 7. Cost Optimization Opportunities (Future)

If the service graduates from pilot to production at higher scale:

- **DynamoDB Auto-scaling** — At sustained high write volume, switch to provisioned with auto-scaling to reduce per-request cost.
- **CloudFront in front of API Gateway** — Caches GET /health and GET /events responses at edge, reducing Lambda invocations.
- **Lambda ARM (Graviton2)** — Same container, `architecture = "arm64"`, ~20% cheaper per GB-second.
- **Savings Plans** — At 12+ months of sustained Lambda usage, Compute Savings Plans provide up to 17% discount.
- **Log export to S3** — For compliance-required long-term log retention, export to S3 Glacier at $0.004/GB vs CloudWatch at $0.03/GB.
