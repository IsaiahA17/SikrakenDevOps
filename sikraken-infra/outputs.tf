# File for declaring outputs in terminal, needed as they will be relevant to be used as environment variables for the actions pipeline

output "ecr_access_role_arn" { 
  description = "ARN for ECR_ACCESS_ROLE_ARN secret in GitHub Actions"
  value       = aws_iam_role.github_ecr_role.arn
}

output "batch_access_role_arn" {
  description = "ARN for BATCH_ACCESS_ROLE_ARN secret in GitHub Actions"
  value       = aws_iam_role.github_batch_role.arn
}

output "lambda_access_role_arn" { 
  description = "ARN for LAMBDA_ACCESS_ROLE_ARN secret environment variable in GitHub Actions"
  value       = aws_iam_role.github_lambda_role.arn
}

output "lambda_function_name" {
  description = "Name for LAMBDA_NAME secret environment variable in GitHub Actions"
  value       = module.lambda_function.lambda_function_name
}

output "job_queue_arn" { 
  description = "ARN for JOB_QUEUE_ARN secret environment variable in GitHub Actions"
  value       = module.batch.job_queues["sikraken_job_queue"].arn
}

output "sikraken_job_definition_arn" {
  description = "ARN for SIKRAKEN_JOB_DEFINITION environment variable in GitHub Actions"
  value       = module.batch.job_definitions["sikraken_test_run_job_def"].arn
}

output "report_job_definition_arn" {
  description = "ARN for REPORT_JOB_DEFINITION environment variable in GitHub Actions"
  value       = module.batch.job_definitions["generate_report"].arn
}

output "ecr_repository_name" { 
  description = "ECR repository name for pushing images from the pipeline and is ECR_REPOSITORY_NAME in GitHub Actions"
  value       = module.ecr.repository_name
}

output "sikraken_output_s3_bucket_name" {
  description = "Name for S3_BUCKET_NAME environment variable in GitHub Actions"
  value       = module.s3_bucket_outputs.s3_bucket_id
}

output "testcomp_benchmarks_s3_bucket_name" {
  description = "Name for TESTCOMP_S3_BUCKET_NAME environment variable in GitHub Actions"
  value       = module.s3_bucket_benchmarks.s3_bucket_id
}