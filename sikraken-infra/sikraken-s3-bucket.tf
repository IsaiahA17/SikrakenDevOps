# code for S3 Bucket in AWS using a module
module "s3_bucket_outputs" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.s3_bucket_name # bucket name change

  control_object_ownership = true # Allows for ownership of objects in S3
  object_ownership         = "BucketOwnerEnforced" # Ownership is set to the bucket's owner

  block_public_acls       = false #Options that need to be turned off in order to allow certain objects to be publicly accessible
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  versioning = {
    enabled = false # Allows for versioning of objects stored in the bucket
  }

  attach_policy = true 
  policy = jsonencode({ # Adding a policy to make it so that .html, .i and .log files are public so that they can be opened from the pipeline
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadSpecificFileTypes"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = [
        "arn:aws:s3:::${var.s3_bucket_name}/*.html", # Only need name since S3 Bucket names are globally unique
        "arn:aws:s3:::${var.s3_bucket_name}/*.i",
        "arn:aws:s3:::${var.s3_bucket_name}/*.log"
      ]
    }]
  })
}

module "s3_bucket_benchmarks" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.s3_bucket_benchmarks_name #bucket name change

  control_object_ownership = true # Allows for ownership of objects in S3
  object_ownership         = "BucketOwnerEnforced" # Ownership is set to the bucket's owner

  versioning = {
    enabled = false # Allows for versioning of objects stored in the bucket
  }
}