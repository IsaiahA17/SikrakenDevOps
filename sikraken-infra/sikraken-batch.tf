# Meaning of certain values such as bid_percentage can be found on official documentation of AWS CLI for batch 

module "batch" {
  source = "terraform-aws-modules/batch/aws"
  create_instance_iam_role = false  # created my own so no need
  create_service_iam_role  = false  
  create_spot_fleet_iam_role = true
  spot_fleet_iam_role_name   = "${var.project_prefix}-spot-fleet-role"
  instance_iam_role_name = aws_iam_role.ecs_instance_role.name

  compute_environments = {
    ec2_spot = {
      name_prefix = "ec2_spot"

      compute_resources = {
        instance_role       = aws_iam_instance_profile.ecs_instance_profile.arn
        type                = "SPOT"
        allocation_strategy = "SPOT_PRICE_CAPACITY_OPTIMIZED"
        bid_percentage      = 100

        min_vcpus      = 0
        max_vcpus      = 256
        desired_vcpus  = 0
        instance_types = ["r5.xlarge", "r5a.xlarge", "r6a.xlarge", "r6i.xlarge", "r7a.xlarge", "r7i.xlarge"]

        security_group_ids = [data.aws_security_group.default_security_group.id] 
        subnets            = data.aws_subnets.default_subnets.ids
      }
    }
  }

  # Job queues and scheduling policies
  job_queues = { # only one job queue but more can be used if needed
    sikraken_job_queue = {
      name     = "${var.project_prefix}-test-run-job-queue"
      state    = "ENABLED"
      priority = 1

      create_scheduling_policy = false

      compute_environment_order = { # only using one compute environment but more can be used
        1 = {
          compute_environment_key = "ec2_spot"
        }
      }
    }
  }

  job_definitions = {
    sikraken_test_run_job_def = {
      name           = "${var.project_prefix}-sikraken-test-run-job-def"
      propagate_tags = true

      # Values correspond to registering a batch job on aws cli 
      container_properties = jsonencode({
        # adding default public image on first deployment as placeholder, once pipeline is run the configuration will have to be applied again
        # May find alternative or script this to make things easier for user   
        image   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/${var.project_prefix}-images:batch-sikraken" 
        jobRoleArn = aws_iam_role.ecs_task_execution_role.arn
        executionRoleArn = aws_iam_role.ecs_task_execution_role.arn
        environment = [
        { name = "CORES",        value = "1" },
        { name = "STACK_SIZE_GB", value = "3" },
        { name = "CATEGORY",     value = var.default_benchmark_category },
        { name = "TIMESTAMP",    value = "0" },
        { name = "MODE",         value = "release" },
        { name = "BUDGET",       value = "900" },
        { name = "TASK_COUNT",   value = "4" },
        { name = "TASK_INDEX",   value = "0" }
        ]
        resourceRequirements = [
        { type = "VCPU", value = "1" },
        { type = "MEMORY", value = "3072" }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {}
        }
      })

      attempt_duration_seconds = 60
      retry_strategy = {
        attempts = 5
        evaluate_on_exit = {
          retry_error = {
            action       = "RETRY"
            on_exit_code = 1
          }
          exit_success = {
            action       = "EXIT"
            on_exit_code = 0
          }
        }
      }
      tags = {
        JobDefinition = "${var.project_prefix}-sikraken-test-run-job-def"
      }
    }

    generate_report = {
    name           = "${var.project_prefix}-generate-report-job-def"
    propagate_tags = true

    retry_strategy = {
      attempts = 1
    }

    container_properties = jsonencode({
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/${var.project_prefix}-images:batch-report"
      jobRoleArn       = aws_iam_role.ecs_task_execution_role.arn
      executionRoleArn = aws_iam_role.ecs_task_execution_role.arn

      environment = [
      { name = "CATEGORY",      value = var.default_benchmark_category },
      { name = "S3_BUCKET_NAME", value = module.s3_bucket_outputs.s3_bucket_id } #Replace with non hardcoded values
      ]

      resourceRequirements = [
      { type = "VCPU",   value = "1" },
      { type = "MEMORY", value = "3072" }
      ]
    })

    tags = {
        JobDefinition = "${var.project_prefix}-generate-report"
    }
    }
  }

  tags = {
    Terraform   = "true"
  }
  }