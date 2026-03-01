############################################
# ASSUME ROLE POLICY (ONLY STS)
############################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-${var.environment}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

############################################
# BASIC EXECUTION ROLE (LOGS)
############################################

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

############################################
# XRAY
############################################

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

############################################
# DYNAMODB ACCESS POLICY
############################################

data "aws_iam_policy_document" "dynamodb_policy" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]

    resources = [
      var.dynamodb_table_arn,
      "${var.dynamodb_table_arn}/index/*"
    ]
  }
}

resource "aws_iam_policy" "dynamodb_policy" {
  name   = "${var.project_name}-${var.environment}-dynamodb-policy"
  policy = data.aws_iam_policy_document.dynamodb_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

############################################
# DLQ POLICY (SEPARATE POLICY)
############################################

data "aws_iam_policy_document" "dlq_policy" {
  statement {
    effect = "Allow"

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      var.dlq_arn
    ]
  }
}

resource "aws_iam_policy" "dlq_policy" {
  name   = "${var.project_name}-${var.environment}-dlq-policy"
  policy = data.aws_iam_policy_document.dlq_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_dlq_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dlq_policy.arn
}
