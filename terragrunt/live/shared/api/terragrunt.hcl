include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/ecs-service"

  # secrets.tfvars is git-ignored (see .gitignore's *.tfvars) and only read if it exists, so
  # `terragrunt apply` works fine before it's created too. Copy secrets.tfvars.example to
  # secrets.tfvars and fill in the real value.
  extra_arguments "secrets" {
    commands = ["plan", "apply"]
    optional_var_files = [
      "${get_terragrunt_dir()}/secrets.tfvars",
    ]
  }
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id            = "vpc-00000000000000000"
    public_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
}

dependency "ecr" {
  config_path = "../ecr"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    repository_url = "000000000000.dkr.ecr.us-east-1.amazonaws.com/silpo-backend"
  }
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:mock-db-secret"
  }
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  name = "silpo-${local.env_vars.locals.environment}"

  vpc_id            = dependency.networking.outputs.vpc_id
  public_subnet_ids = dependency.networking.outputs.public_subnet_ids

  # Tasks run in the public subnets (no NAT gateway) — they're still only reachable through
  # the ALB, since the service security group only allows inbound from the ALB's own security
  # group. See the root README for the cost trade-off.
  task_subnet_ids  = dependency.networking.outputs.public_subnet_ids
  assign_public_ip = true

  image          = "${dependency.ecr.outputs.repository_url}:latest"
  container_port = 8000

  # Smallest Fargate size: traffic is a handful of concurrent users, essentially idle most of
  # the day.
  cpu           = 256
  memory        = 512
  desired_count = 1

  environment_variables = [
    { name = "APP_ENV", value = "production" },
    { name = "API_HOST", value = "0.0.0.0" },
    { name = "API_PORT", value = "8000" },
    { name = "JWT_ALGORITHM", value = "HS256" },
    { name = "JWT_EXPIRE_MINUTES", value = "10080" },
    { name = "EMAIL_FROM", value = "Silpo <onboarding@resend.dev>" },
  ]

  secrets = [
    { name = "POSTGRES_HOST", value_from = "${dependency.rds.outputs.secret_arn}:host::" },
    { name = "POSTGRES_PORT", value_from = "${dependency.rds.outputs.secret_arn}:port::" },
    { name = "POSTGRES_DB", value_from = "${dependency.rds.outputs.secret_arn}:dbname::" },
    { name = "POSTGRES_USER", value_from = "${dependency.rds.outputs.secret_arn}:username::" },
    { name = "POSTGRES_PASSWORD", value_from = "${dependency.rds.outputs.secret_arn}:password::" },
  ]

  secret_arns = [dependency.rds.outputs.secret_arn]
}
