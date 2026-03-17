data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_security_group" "default_security_group" {
  name   = "default"
  vpc_id = data.aws_vpc.default_vpc.id #.id is a resource that's unique for the cloud provider
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}