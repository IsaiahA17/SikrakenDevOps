module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = "${var.project_prefix}-images"
  repository_image_tag_mutability = "MUTABLE"

  repository_read_write_access_arns = [aws_iam_role.github_ecr_role.arn] 
  
  # images stored in ECR expire everyday if they have no tag as pushed images 
  # with identical tags seem to also create untagged images which aren't important 
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        "rulePriority": 1,
        "selection": {
            "tagStatus": "untagged",
            "countType": "sinceImagePushed",
            "countUnit": "days",
            "countNumber": 1
        },
        "action": {
            "type": "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
  }
}