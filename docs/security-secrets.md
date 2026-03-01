# Security & Secrets — skynet-ops-audit-service

**Cloud Platform:** AWS (us-east-1)  
**Auth (prod):** AWS Cognito JWT  
**Secrets management:** No secrets committed; `.env.example` provided  
**IAM approach:** Least-privilege per environment

---

## 1. Secrets Handling

### No Secrets in the Repository

The repository contains **zero committed secrets**. The following files are in `.gitignore` and never committed:

```
.env
*.tfvars (except .example files)
terraform.tfstate
terraform.tfstate.backup
*.pem
*.key
```

### .env.example

A `.env.example` file is provided with placeholder values only. No real credentials appear in this file.

```dotenv
# Service Configuration
PORT=8080
APP_ENV=dev
SERVICE_NAME=skynet-ops-audit-service
LOG_LEVEL=info

# Storage
STORE_BACKEND=memory
DATABASE_URL=/tmp/events.db
DYNAMODB_TABLE=

# Features
METRICS_DEMO_ENABLED=false

# Optional Auth
API_KEY=

# Limits
MAX_EVENTS_LIMIT=100
```

### Cloud Secrets (Lambda Environment Variables)

In cloud deployments, all configuration is injected via Lambda environment variables set by Terraform. At time of deployment, no secret values (database passwords, API keys) are required — the service uses IAM role-based access for DynamoDB:

| Variable | Value in Cloud | Secret? |
|---|---|---|
| `APP_ENV` | `dev` / `staging` / `prod` | No |
| `STORE_BACKEND` | `dynamodb` | No |
| `DYNAMODB_TABLE` | `skynet-ops-audit-service-{env}` | No |
| `LOG_LEVEL` | `info` | No |
| `SERVICE_NAME` | `skynet-ops-audit-service` | No |
| `METRICS_DEMO_ENABLED` | `true` | No |


---

## 2. IAM / Access Control

### Lambda Execution Role

Each environment has a dedicated IAM role: `skynet-ops-audit-service-{env}-lambda-role`

This role follows the **principle of least privilege**. It has exactly the permissions needed and nothing more.

### Attached Policies

| Policy | Type | Permissions Granted |
|---|---|---|
| `AWSLambdaBasicExecutionRole` | AWS Managed | CloudWatch Logs: `CreateLogGroup`, `CreateLogStream`, `PutLogEvents` |
| `AWSXrayWriteOnlyAccess` | AWS Managed | X-Ray: `PutTraceSegments`, `PutTelemetryRecords`, `GetSamplingRules` |
| `skynet-ops-audit-service-{env}-dynamodb-policy` | Customer Managed | DynamoDB: `PutItem`, `GetItem`, `Query`, `Scan` on own table only |
| `skynet-ops-audit-service-{env}-dlq-policy` | Customer Managed | SQS: `SendMessage` to own DLQ only |

### DynamoDB Policy (exact scope)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-east-1:244143925680:table/skynet-ops-audit-service-prod",
        "arn:aws:dynamodb:us-east-1:244143925680:table/skynet-ops-audit-service-prod/index/*"
      ]
    }
  ]
}
```

The index ARN is included to allow `Query` on the `tenantId-index` GSI.

**Dangerous permissions NOT granted:** `dynamodb:DeleteItem`, `dynamodb:DeleteTable`, `dynamodb:DescribeTable`, `dynamodb:ListTables`, `dynamodb:*`

### DLQ Policy (exact scope)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:us-east-1:244143925680:skynet-ops-audit-service-prod-dlq"
    }
  ]
}
```

Lambda can only write to its own DLQ. Cannot read, delete, or list other queues.

### Assume Role Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Only `lambda.amazonaws.com` can assume this role. No other principals.

---

## 3. Authentication (Per Environment)

### Dev — No Auth (Open)
Dev is open for ease of testing. All endpoints are accessible without credentials.

Rate limited to 50 req/s burst=100 to prevent unintended cost.

```bash
# Dev: no auth header needed
curl https://rqivs1f7w7.execute-api.us-east-1.amazonaws.com/health
```

### Staging — No Auth (Open)
Same as dev. Used for pre-prod validation.

### Prod — JWT Auth via Amazon Cognito

Prod API Gateway uses a JWT authorizer backed by Amazon Cognito:

| Setting | Value |
|---|---|
| Cognito User Pool | `skynet-ops-audit-service-prod-user-pool` |
| User Pool ID | `us-east-1_5w47rsKmA` |
| Pool ARN | `arn:aws:cognito-idp:us-east-1:244143925680:userpool/us-east-1_5w47rsKmA` |
| Client ID | (from Terraform output) |
| JWT Audience | `skynet-api` |
| JWT Issuer | `https://cognito-idp.us-east-1.amazonaws.com/us-east-1_5w47rsKmA` |
| Hosted UI Domain | `skynet-ops-audit-service-prod-auth.auth.us-east-1.amazoncognito.com` |

All `GET /events` and `POST /events` requests to prod require a valid Cognito-issued JWT in the `Authorization: Bearer <token>` header. The `/health` endpoint intentionally bypasses the authorizer for load balancer/uptime checks.

> **Note:** The prod JWT authorizer is configured via Terraform (`enable_jwt_auth = true`). Dev/staging have `enable_jwt_auth = false` to allow unauthenticated testing.

**Getting a test token (prod):**
```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=<user>,PASSWORD=<password> \
  --client-id <CLIENT_ID> \
  --region us-east-1 \
  --query 'AuthenticationResult.IdToken' \
  --output text
```

---

## 4. Container Security

### Base Image

```dockerfile
FROM public.ecr.aws/lambda/nodejs:20
```

Using the official AWS Lambda Node.js 20 base image from ECR Public Gallery. This image is maintained by AWS and regularly updated with security patches.

### Non-Root Execution

The AWS Lambda runtime runs the handler function as a non-root user by default. No additional `USER` instruction is needed.

### Production Dependencies Only

```dockerfile
RUN npm install --omit=dev
```

Development dependencies (`nodemon`, etc.) are excluded from the production container image, reducing the attack surface.

### Image Scanning on Push

ECR repositories are configured with `scan_on_push = true`:

```hcl
image_scanning_configuration {
  scan_on_push = true
}
```

After each `docker push`, ECR automatically scans the image for known CVEs using Amazon Inspector. Check scan results in ECR Console → Repository → Image → Vulnerabilities tab.

### No Sensitive Files in Image

The `Dockerfile` copies only:
- `package*.json` (for `npm install`)
- `src/` directory (application code)

The `.dockerignore` file excludes:
```
.env
.git
node_modules
*.tfvars
data/
tests/
```

No secrets, no credentials, no state files enter the image.

---

## 5. API Security

### Input Validation

All `POST /events` requests are validated by `src/middleware/validation.middleware.js` before reaching the service layer:

| Rule | Enforcement |
|---|---|
| Required fields (`type`, `tenantId`, `severity`, `message`, `source`) | 400 if missing |
| `tenantId` non-empty string | 400 if empty |
| `message` non-empty string | 400 if empty |
| `severity` must be `info`, `warning`, `error`, or `critical` | 400 if invalid |
| Invalid JSON body | 400 (Express `SyntaxError` handler in `app.js`) |

### API Gateway Throttling

Per-environment rate limits prevent abuse and cost spikes:

| Environment | Rate Limit (req/s) | Burst Limit |
|---|---|---|
| dev | 50 | 100 |
| staging | 50 | 100 |
| prod | 20 | 40 |

Requests exceeding the burst limit receive a `429 Too Many Requests` response.

### CORS Configuration

| Environment | Allowed Origins |
|---|---|
| dev | `*` (any origin) |
| staging | `*` (any origin) |
| prod | `https://yourdomain.com` (restrict to your actual domain) |

Production CORS must be updated in `terraform.tfvars`:
```hcl
cors_allowed_origins = ["https://app.yourairman.com"]
```

### HTTPS Only

API Gateway HTTP API enforces HTTPS for all endpoints. The underlying Lambda function has no direct internet exposure — it is only invocable through the API Gateway execution ARN.

---

## 6. DynamoDB Table Security

### Deletion Protection (Prod Only)

The prod DynamoDB table has deletion protection enabled:
```hcl
deletion_protection_enabled = true  # prod only
```

This prevents accidental `terraform destroy` or `aws dynamodb delete-table` from destroying production data.

### Encryption at Rest

DynamoDB tables use AWS-owned encryption keys by default (AES-256). This is enabled automatically and costs nothing.

### No Public Access

DynamoDB is accessed exclusively by the Lambda execution role. There is no public endpoint or internet-accessible connection string.

### Point-in-Time Recovery

PITR is not enabled in the current pilot deployment (cost: ~$0.20/GB/month of backups). For a production system handling audit data for compliance, PITR should be enabled:

```hcl
# Add to dynamodb module for prod
point_in_time_recovery {
  enabled = true
}
```

---

## 7. GitHub Actions / CI-CD Security

The `cicd` Terraform module provisions a GitHub Actions IAM role using OIDC federation (no long-lived AWS access keys):

```hcl
Principal = {
  Federated = "arn:aws:iam::244143925680:oidc-provider/token.actions.githubusercontent.com"
}
Condition = {
  StringLike = {
    "token.actions.githubusercontent.com:sub" = "repo:arpitpandeygit/skynet-ops-audit-service:*"
  }
}
```

This means:
- No AWS `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` stored in GitHub Secrets
- The role is only assumable by GitHub Actions running from the specific repository
- If the OIDC token is compromised, it expires within minutes

---

## 8. Terraform State Security

| Security Control | Implementation |
|---|---|
| State encrypted at rest | S3 bucket: `server_side_encryption = AES256` |
| State versioned | S3 versioning enabled (recover from accidental overwrites) |
| Public access blocked | `block_public_acls = true`, `restrict_public_buckets = true` |
| State lock | DynamoDB table `skynet-ops-terraform-locks` (prevents concurrent applies) |

No one can access the Terraform state file without IAM credentials to the `244143925680` account. The state may contain sensitive values (ARNs, table names) — treat the bucket accordingly.

---

## 9. Known Limitations and Improvements

| Limitation | Current State | Recommended Improvement |
|---|---|---|
| No WAF | API Gateway has no AWS WAF attached | Add AWS WAF with rate-based rule for IP-level protection |
| PITR disabled | DynamoDB PITR off (cost optimization for pilot) | Enable for prod when compliance requires it |
| SNS subscriptions unconfirmed | Email alert subscriptions pending confirmation | Confirm email subscriptions to activate alarm delivery |
| Cognito prod domain | Placeholder domain in prod tfvars | Set real `jwt_issuer` domain before go-live |
| No VPC | Lambda not in VPC | Acceptable for this service; add VPC + VPC endpoint for DynamoDB if strict network isolation required |
| Admin CI/CD role | GitHub Actions role has `AdministratorAccess` | Scope down to specific services (ECR, Lambda, API Gateway) for production |
