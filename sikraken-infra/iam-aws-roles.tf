resource "aws_iam_role" "lambda_execution_role" { # IAM roles can be attached to services and are given a set of permissions, either pre made or custom
  name = "${var.project_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_execution_policy" { #Creating custom permissions for Lambda role
  name = "${var.project_prefix}-lambda-execution-policy"
  role = aws_iam_role.lambda_execution_role.id # ID of what Lambda resource to attach to (resource above)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = module.s3_bucket_outputs.s3_bucket_arn
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${module.s3_bucket_outputs.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${module.lambda_function.lambda_cloudwatch_log_group_arn}:*"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_prefix}-ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "${var.project_prefix}-ecs-task-s3-policy"
  role = aws_iam_role.ecs_task_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        module.s3_bucket_outputs.s3_bucket_arn,
        "${module.s3_bucket_outputs.s3_bucket_arn}/*",
        module.s3_bucket_benchmarks.s3_bucket_arn,
        "${module.s3_bucket_benchmarks.s3_bucket_arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_prefix}-ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_access_policy" {
  name = "${var.project_prefix}-ECSAccessPolicy"
  role = aws_iam_role.ecs_task_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowPassRoleForECSTasks"
      Effect = "Allow"
      Action = "iam:PassRole"
      Resource = [
        aws_iam_role.ecs_task_execution_role.arn,
        aws_iam_role.ecs_instance_role.arn
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" { #Using an AWS managed policy rather than a custom one
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" { #instance profiles are what's used to pass IAM roles to EC2 instances
  name = "${var.project_prefix}-ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}
