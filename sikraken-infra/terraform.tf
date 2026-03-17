# Dedicated terraform file deciding what version of terraform to use and what provider to install for configuring terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }

  required_version = ">= 1.2"
}
