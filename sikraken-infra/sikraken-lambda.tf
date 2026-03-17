module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${var.project_prefix}-outputs-processor"
  lambda_role   = aws_iam_role.lambda_execution_role.arn
  description   = "Locates most recent sikraken benchmark in a given test run category and S3 Bucket as JSON events from the pipeline it's invoked from and returns the URLs of the category report and category comparison .html files "
  handler       = "output_report_url.lambda_handler"
  runtime       = "python3.13"
  create_role   = false

  source_path = "./lambda-functions/output_report_url"
}