# Gets data for AWS Account ID and region wherever need such as ARNs (The format used involves the AWS account holder's ID and region)

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}