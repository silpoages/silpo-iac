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
    repository_url = "000000000000.dkr.ecr.sa-east-1.amazonaws.com/silpo-backend"
    repository_arn = "arn:aws:ecr:sa-east-1:000000000000:repository/silpo-backend"
  }
}

dependency "github_oidc" {
  config_path = "../github-oidc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    arn = "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
  }
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    secret_arn = "arn:aws:secretsmanager:sa-east-1:000000000000:secret:mock-db-secret"
  }
}

dependency "web" {
  config_path = "../web"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    distribution_domain_name = "d000000000000.cloudfront.net"
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
    # No custom domain yet — this is CloudFront's own default *.cloudfront.net domain for the
    # web unit, used to build the password-reset link sent by email.
    { name = "WEB_APP_URL", value = "https://${dependency.web.outputs.distribution_domain_name}" },
    { name = "EMAIL_PROVIDER", value = "smtp" },
    { name = "SMTP_HOST", value = "smtp.gmail.com" },
    { name = "SMTP_PORT", value = "587" },
    # Must be the same mailbox as the real smtp_username secret (see
    # secrets.tfvars.example). Gmail (and most SMTP providers) reject a From address that
    # doesn't match the authenticated account, so keep these two in sync.
    { name = "EMAIL_FROM", value = "Silpo <silpoages@gmail.com>" },
  ]

  secrets = [
    { name = "POSTGRES_HOST", value_from = "${dependency.rds.outputs.secret_arn}:host::" },
    { name = "POSTGRES_PORT", value_from = "${dependency.rds.outputs.secret_arn}:port::" },
    { name = "POSTGRES_DB", value_from = "${dependency.rds.outputs.secret_arn}:dbname::" },
    { name = "POSTGRES_USER", value_from = "${dependency.rds.outputs.secret_arn}:username::" },
    { name = "POSTGRES_PASSWORD", value_from = "${dependency.rds.outputs.secret_arn}:password::" },
  ]

  secret_arns = [dependency.rds.outputs.secret_arn]

  # No domain yet — the ALB serves plain HTTP on its own *.elb.amazonaws.com name
  # (domain_name/certificate_arn/zone_id left at their null defaults).

  # Lets silpo-backend's own CI assume a deploy role via OIDC (no long-lived AWS keys in
  # GitHub secrets) to push a new image and force this service to redeploy it.
  github_oidc_provider_arn = dependency.github_oidc.outputs.arn
  github_repo              = "silpoages/silpo-backend"
  github_deploy_branch     = "main"
  ecr_repository_arn       = dependency.ecr.outputs.repository_arn
}
