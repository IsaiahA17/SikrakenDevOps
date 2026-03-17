# Configuring OIDC for GitHub Actions to be able to interact with AWS resources

module "iam_oidc_provider" {
  source = "terraform-aws-modules/iam/aws//modules/iam-oidc-provider"
  version = "6.4.0"

  url = "https://token.actions.githubusercontent.com"

  tags = {
    Terraform = "true"
  }
}