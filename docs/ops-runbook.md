# Ops Runbook — skynet-ops-audit-service

**Cloud Platform:** AWS (us-east-1)  
**Primary contact:** arpitxid@gmail.com  
**Availability target:** ~99.0% (pilot)  
**Last updated:** 2026-03-01

---

## Quick Reference

| Resource | Value |
|---|---|
| Dev API | `https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com` |
| Dev Lambda | `skynet-ops-audit-service-dev` |
| Prod Lambda | `skynet-ops-audit-service-prod` |
| Prod DynamoDB | `skynet-ops-audit-service-prod` |
| Prod Cognito Pool | `us-east-1_5w47rsKmA` |
| AWS Account | `244143925680` |
| Region | `us-east-1` |
| Terraform State Bucket | `skynet-ops-terraform-state-244143925680` |
| Alarm SNS Topic (prod) | `skynet-ops-audit-service-prod-alarms` |

---

## Scenario 1 — Service Down / Health Checks Failing

### Symptoms
- `GET /health` returns non-200, times out, or returns connection error
- CloudWatch alarm `skynet-ops-audit-service-prod-lambda-errors` fires
- API Gateway returning 5XX to callers

### Diagnostic Steps

**Step 1 — Confirm the failure**
```bash
curl -sv https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/health
```

**Step 2 — Check Lambda function state**
```bash
aws lambda get-function \
  --function-name skynet-ops-audit-service-prod \
  --region us-east-1 \
  --query 'Configuration.[State,StateReason,LastUpdateStatus]'
```

Healthy output: `["Active", null, "Successful"]`

**Step 3 — Check recent Lambda errors in CloudWatch**
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/skynet-ops-audit-service-prod \
  --start-time $(date -d '30 minutes ago' +%s)000 \
  --filter-pattern "ERROR" \
  --region us-east-1 \
  --query 'events[*].message' \
  --output text | head -30
```

**Step 4 — Check if DynamoDB is reachable**
```bash
aws dynamodb describe-table \
  --table-name skynet-ops-audit-service-prod \
  --region us-east-1 \
  --query 'Table.TableStatus'
```

Expected: `"ACTIVE"`

**Step 5 — Check Lambda concurrency limits**
```bash
aws lambda get-function-concurrency \
  --function-name skynet-ops-audit-service-prod \
  --region us-east-1
```

If `ReservedConcurrentExecutions = 0`, the function is throttled to zero — a misconfiguration.

### Resolution Options

**A — Container image issue (bad deploy)**
```bash
# Roll back to previous known-good image
# Get previous image digest from ECR
aws ecr describe-images \
  --repository-name skynet-ops-audit-service-prod \
  --region us-east-1 \
  --query 'sort_by(imageDetails, &imagePushedAt)[-2].imageDigest' \
  --output text

# Roll back Lambda to previous digest
aws lambda update-function-code \
  --function-name skynet-ops-audit-service-prod \
  --image-uri 244143925680.dkr.ecr.us-east-1.amazonaws.com/skynet-ops-audit-service-prod@sha256:<PREVIOUS_DIGEST> \
  --region us-east-1
```

**B — Lambda in failed state — force redeploy**
```bash
# Re-push current image to force Lambda update
aws lambda update-function-code \
  --function-name skynet-ops-audit-service-prod \
  --image-uri 244143925680.dkr.ecr.us-east-1.amazonaws.com/skynet-ops-audit-service-prod:latest \
  --region us-east-1

# Wait for update to complete
aws lambda wait function-updated \
  --function-name skynet-ops-audit-service-prod \
  --region us-east-1
```

**C — DynamoDB table deleted or inaccessible**
Check IAM role policy attachment:
```bash
aws iam list-attached-role-policies \
  --role-name skynet-ops-audit-service-prod-lambda-role \
  --region us-east-1
```

Ensure `skynet-ops-audit-service-prod-dynamodb-policy` is attached. If missing, re-run `terraform apply` for prod.

**D — API Gateway misconfiguration**
Check that Lambda integration is intact:
```bash
aws apigatewayv2 get-integrations \
  --api-id <API_ID> \
  --region us-east-1
```

**Recovery verification:**
```bash
curl -s https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/health | jq '.status'
# Expected: "ok"
```

---

## Scenario 2 — Latency Spike

### Symptoms
- CloudWatch alarm `skynet-ops-audit-service-prod-lambda-duration` fires (threshold: > 2000 ms avg)
- Callers reporting slow responses
- `/metrics-demo?mode=slow` was accidentally called in a loop

### Diagnostic Steps

**Step 1 — Identify duration trend**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=skynet-ops-audit-service-prod \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average Maximum \
  --region us-east-1
```

**Step 2 — Check DynamoDB latency**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name SuccessfulRequestLatency \
  --dimensions Name=TableName,Value=skynet-ops-audit-service-prod Name=Operation,Value=PutItem \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average \
  --region us-east-1
```

**Step 3 — Check for cold starts**
In CloudWatch Logs Insights:
```
fields @timestamp, @initDuration, @duration
| filter @type = "REPORT"
| filter @initDuration > 0
| sort @timestamp desc
| limit 20
```

**Step 4 — Identify the cause**
- If DynamoDB latency is normal and Lambda duration is high → likely a cold start wave or a bug in the code path
- If DynamoDB latency is high → DynamoDB service issue (check AWS Service Health dashboard)
- If `/metrics-demo?mode=slow` is generating traffic → see resolution B

### Resolution

**A — Cold start spike** (DynamoDB latency normal, only first invocations slow)
No action required — subsequent invocations will be fast. Monitor for 10 minutes.

If cold starts are unacceptable for prod, add provisioned concurrency:
```bash
aws lambda put-provisioned-concurrency-config \
  --function-name skynet-ops-audit-service-prod \
  --qualifier '$LATEST' \
  --provisioned-concurrent-executions 2 \
  --region us-east-1
```
Note: This adds ~$4/month cost. Remove after pilot if not needed.

**B — Metrics demo slow mode running unintentionally**
Disable the endpoint temporarily:
```bash
aws lambda update-function-configuration \
  --function-name skynet-ops-audit-service-prod \
  --environment Variables='{...,METRICS_DEMO_ENABLED=false}' \
  --region us-east-1
```

Or rate-limit at API Gateway (throttle burst limit already set to 40 for prod).

**C — DynamoDB Scan on large table (GET /events without tenantId)**
If `tenantId` is not provided, the store performs a full table scan. At large data volumes, add a mandatory `tenantId` filter or implement pagination more aggressively.

---

## Scenario 3 — Sudden Cost Spike

### Symptoms
- AWS Budget alert fires (80% or 100% of monthly cap reached unexpectedly)
- Unusually high Lambda invocations in CloudWatch
- DynamoDB showing unexpected write volume

### Diagnostic Steps

**Step 1 — Check current month spend**
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1
```

**Step 2 — Check Lambda invocation count**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=skynet-ops-audit-service-prod \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 3600 \
  --statistics Sum \
  --region us-east-1
```

**Step 3 — Check CloudWatch log ingestion volume**
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/skynet-ops-audit-service \
  --region us-east-1 \
  --query 'logGroups[*].[logGroupName, storedBytes]'
```

**Step 4 — Check DLQ depth (failed events)**
```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/244143925680/skynet-ops-audit-service-prod-dlq \
  --attribute-names ApproximateNumberOfMessages \
  --region us-east-1
```

### Resolution

**A — Runaway invocations (bot/misconfigured client hammering the API)**
Apply emergency throttling at API Gateway:
```bash
# Reduce burst limit to near zero temporarily
aws apigatewayv2 update-stage \
  --api-id <API_ID> \
  --stage-name '$default' \
  --default-route-settings '{"ThrottlingBurstLimit":5,"ThrottlingRateLimit":2}' \
  --region us-east-1
```

Then restore via Terraform after investigation:
```bash
terraform apply -var-file="terraform.tfvars"
```

**B — Lambda reserved concurrency exhausted, causing cost**
Cap Lambda further:
```bash
aws lambda put-function-concurrency \
  --function-name skynet-ops-audit-service-prod \
  --reserved-concurrent-executions 3 \
  --region us-east-1
```

**C — Log level accidentally set to DEBUG**
```bash
# Check current environment variables
aws lambda get-function-configuration \
  --function-name skynet-ops-audit-service-prod \
  --region us-east-1 \
  --query 'Environment.Variables.LOG_LEVEL'

# Set back to info
aws lambda update-function-configuration \
  --function-name skynet-ops-audit-service-prod \
  --environment Variables='{...,LOG_LEVEL=info}' \
  --region us-east-1
```

---

## Scenario 4 — DB / Storage Issue

### Symptoms
- `POST /events` returns 500 errors
- CloudWatch Lambda logs show DynamoDB exception
- `GET /events` returns empty results unexpectedly

### Diagnostic Steps

**Step 1 — Confirm table status**
```bash
aws dynamodb describe-table \
  --table-name skynet-ops-audit-service-prod \
  --region us-east-1 \
  --query 'Table.[TableStatus, BillingModeSummary]'
```

Expected: `["ACTIVE", {...}]`

**Step 2 — Check DynamoDB service health**
Visit: https://health.aws.amazon.com/health/status → DynamoDB → us-east-1

**Step 3 — Confirm IAM policy still attached**
```bash
aws iam list-attached-role-policies \
  --role-name skynet-ops-audit-service-prod-lambda-role \
  --query 'AttachedPolicies[*].PolicyName'
```

Expected policies:
- `AWSLambdaBasicExecutionRole`
- `AWSXrayWriteOnlyAccess`
- `skynet-ops-audit-service-prod-dynamodb-policy`
- `skynet-ops-audit-service-prod-dlq-policy`

**Step 4 — Check DLQ for failed items**
```bash
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/244143925680/skynet-ops-audit-service-prod-dlq \
  --max-number-of-messages 5 \
  --region us-east-1
```

### Resolution

**A — DynamoDB throttling (unlikely on PAY_PER_REQUEST, but possible during regional degradation)**
Wait for AWS service restoration. Check Service Health Dashboard.

**B — IAM policy accidentally detached**
Re-run Terraform:
```bash
cd infra/terraform/envs/prod
terraform apply -var-file="terraform.tfvars" -target=module.skynet_ops.module.iam
```

**C — Table accidentally deleted (dev/staging only — prod has deletion_protection=true)**
Re-provision:
```bash
terraform apply -var-file="terraform.tfvars" -target=module.skynet_ops.module.dynamodb
```

Then redeploy Lambda to reinitialise connection:
```bash
aws lambda update-function-configuration \
  --function-name skynet-ops-audit-service-dev \
  --description "force-update-$(date +%s)" \
  --region us-east-1
```

---

## Scenario 5 — Bad Deployment / Rollback

### Symptoms
- New container image deployed and service returns errors
- Lambda function in `Failed` state after image update
- Health check fails after deploy

### Rollback Procedure

**Step 1 — Identify the last working image digest**
```bash
aws ecr describe-images \
  --repository-name skynet-ops-audit-service-prod \
  --region us-east-1 \
  --query 'sort_by(imageDetails, &imagePushedAt)' \
  --output table
```

**Step 2 — Roll Lambda back to previous image**
```bash
PREVIOUS_DIGEST=$(aws ecr describe-images \
  --repository-name skynet-ops-audit-service-prod \
  --region us-east-1 \
  --query 'sort_by(imageDetails, &imagePushedAt)[-2].imageDigest' \
  --output text)

aws lambda update-function-code \
  --function-name skynet-ops-audit-service-prod \
  --image-uri 244143925680.dkr.ecr.us-east-1.amazonaws.com/skynet-ops-audit-service-prod@sha256:${PREVIOUS_DIGEST} \
  --region us-east-1

# Wait for update
aws lambda wait function-updated \
  --function-name skynet-ops-audit-service-prod \
  --region us-east-1
```

**Step 3 — Verify health**
```bash
sleep 10
curl -s https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/health | jq
```

**Step 4 — Document the incident**
- Record what changed between working and broken image
- Create a fix in a new branch; do not re-push to `main` until tested in dev→staging

---

## Scenario 6 — Accidental Public Exposure / Security Misconfiguration

### Symptoms
- Unexpected high traffic on prod (possible unauthorized access)
- Cognito JWT auth was disabled on prod inadvertently
- IAM role was given overly broad permissions

### Immediate Response

**Step 1 — Check current JWT auth status on prod API**
```bash
aws apigatewayv2 get-routes \
  --api-id <PROD_API_ID> \
  --region us-east-1 \
  --query 'Items[*].[RouteKey, AuthorizationType, AuthorizerId]'
```

Expected for prod: `["$default", "JWT", "<AUTHORIZER_ID>"]`

If `NONE` is shown: JWT auth is disabled. Restore immediately via Terraform:
```bash
cd infra/terraform/envs/prod
terraform apply -var-file="terraform.tfvars"
```

**Step 2 — Check for unauthorized IAM access**
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
  --region us-east-1 \
  --query 'Events[*].[EventTime, Username, CloudTrailEvent]' \
  --output text
```

**Step 3 — Temporarily restrict API (emergency)**
If unauthorized access is confirmed, restrict API Gateway throttle to zero:
```bash
aws apigatewayv2 update-stage \
  --api-id <PROD_API_ID> \
  --stage-name '$default' \
  --default-route-settings '{"ThrottlingBurstLimit":0,"ThrottlingRateLimit":0}' \
  --region us-east-1
```

**Step 4 — Review Lambda execution role permissions**
```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::244143925680:policy/skynet-ops-audit-service-prod-dynamodb-policy \
  --version-id v1 \
  --query 'PolicyVersion.Document'
```

Ensure only `dynamodb:PutItem`, `dynamodb:GetItem`, `dynamodb:Query`, `dynamodb:Scan` are present. No wildcard actions.

**Step 5 — Rotate credentials (if API_KEY was exposed)**
If static API_KEY was in use and potentially leaked:
```bash
# Generate new key and update Lambda environment
NEW_KEY=$(openssl rand -hex 24)
aws lambda update-function-configuration \
  --function-name skynet-ops-audit-service-prod \
  --environment Variables='{...,API_KEY='"$NEW_KEY"'}' \
  --region us-east-1

echo "New API Key: $NEW_KEY"
# Distribute securely to authorized callers
```

**Step 6 — Restore and verify security posture**
```bash
# Restore rate limits
terraform apply -var-file="terraform.tfvars"

# Confirm JWT auth is back
curl -s https://<PROD_API>/events -H "Authorization: Bearer invalid_token"
# Expected: 401 Unauthorized
```

---

## General Health Check Script

Save and run this to verify full service health across environments:

```bash
#!/bin/bash
# health-check.sh

DEV_URL="https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com"
ENVS=("dev")

for ENV in "${ENVS[@]}"; do
  echo "=== Checking $ENV ==="
  
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DEV_URL/health")
  if [ "$STATUS" -eq 200 ]; then
    echo "✅ /health → $STATUS OK"
  else
    echo "❌ /health → $STATUS FAILED"
  fi

  EVENTS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DEV_URL/events")
  if [ "$EVENTS_STATUS" -eq 200 ]; then
    echo "✅ /events → $EVENTS_STATUS OK"
  else
    echo "❌ /events → $EVENTS_STATUS FAILED"
  fi

  echo ""
done

echo "Lambda States:"
for ENV in dev staging prod; do
  STATE=$(aws lambda get-function \
    --function-name skynet-ops-audit-service-$ENV \
    --region us-east-1 \
    --query 'Configuration.State' \
    --output text 2>/dev/null)
  echo "  skynet-ops-audit-service-$ENV: $STATE"
done

echo ""
echo "DynamoDB Table States:"
for ENV in dev staging prod; do
  STATE=$(aws dynamodb describe-table \
    --table-name skynet-ops-audit-service-$ENV \
    --region us-east-1 \
    --query 'Table.TableStatus' \
    --output text 2>/dev/null)
  echo "  skynet-ops-audit-service-$ENV: $STATE"
done
```
