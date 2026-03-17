resource "aws_iam_role" "github_ecr_role" {
  name = "${var.project_prefix}-github-actions-ecr-role"
  max_session_duration = 14400

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Condition = { # Security measure ensuring that the audience actually comes from AWS and that the subject the Web identity with the role it assumes is from a given repo
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:environment:${var.github_environment}" 
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecr_policy" {
  name = "${var.project_prefix}-github-actions-ecr-policy"
  role = aws_iam_role.github_ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = module.ecr.repository_arn
      }
    ]
  })
}

resource "aws_iam_role" "github_batch_role" {
  name = "${var.project_prefix}-github-actions-batch-role"
  max_session_duration = 14400

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:environment:${var.github_environment}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "batch_policy" {
  name = "${var.project_prefix}-github-actions-batch-policy"
  role = aws_iam_role.github_batch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "batch:SubmitJob"
        Resource = "arn:aws:batch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:job-queue/${var.project_prefix}-test-run-job-queue"
      },
      {
        Effect = "Allow"
        Action = "batch:SubmitJob"
        Resource = [
          "arn:aws:batch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:job-definition/${var.project_prefix}-sikraken-test-run-job-def",
          "arn:aws:batch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:job-definition/${var.project_prefix}-sikraken-test-run-job-def:*",
          "arn:aws:batch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:job-definition/${var.project_prefix}-generate-report-job-def",
          "arn:aws:batch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:job-definition/${var.project_prefix}-generate-report-job-def:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "batch:DescribeJobs",
          "batch:TerminateJob"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "github_lambda_role" {
  name = "${var.project_prefix}-github-actions-lambda-role"
  max_session_duration = 14400

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com" # Building ARN for GitHub OIDC provider
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:environment:${var.github_environment}" 
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_prefix}-github-actions-lambda-policy"
  role = aws_iam_role.github_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = module.lambda_function.lambda_function_arn 
    }]
  })
}