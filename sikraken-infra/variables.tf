# Storing variables that can be referenced in other files

variable "s3_bucket_name" {
  description = "Globally unique name for the S3 output bucket (e.g. my-sikraken-outputs)"
  type        = string
}

variable "s3_bucket_benchmarks_name" {
  description = "Globally unique name for the benchmarks S3 bucket (e.g. my-testcomp-benchmarks)"
  type        = string
}

variable "project_prefix" {
  description = "Unique prefix for AWS resource names to avoid conflicts (e.g. sikraken1)"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in format ORG/REPO or USERNAME/REPOSITORY containing the pipeline (e.g. IsaiahA17/SikrakenDevOps)"
  type        = string
}

variable "github_environment" {
  description = "GitHub Actions environment name in pipeline (e.g. Batch)"
  type        = string
}

variable "use_placeholder_image" { 
  description = "Set to true on first deployment before images have been pushed"
  type        = bool
  default     = true
}

variable "default_benchmark_category" {
  description = "Default benchmark category to run (e.g. ECA, chris)"
  type        = string
}