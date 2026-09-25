locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id  = local.env_vars.locals.account_id
  aws_region  = local.env_vars.locals.aws_region
  environment = local.env_vars.locals.environment
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket  = "silpo-terraform-state-${local.account_id}"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = local.aws_region
    encrypt = true

    # Native S3 locking (via conditional writes) — no DynamoDB table needed.
    use_lockfile = true

    # Terragrunt creates the bucket above on first `terragrunt apply --backend-bootstrap` if
    # it doesn't exist yet. See the root README's bootstrap steps.
    s3_bucket_tags = {
      Project   = "silpo"
      ManagedBy = "terragrunt"
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = {
          Project     = "silpo"
          Environment = "${local.environment}"
          ManagedBy   = "terragrunt"
        }
      }
    }
  EOF
}
