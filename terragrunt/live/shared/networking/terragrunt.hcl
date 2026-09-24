include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/networking"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  name = "silpo-${local.env_vars.locals.environment}"

  azs = [
    "${local.env_vars.locals.aws_region}a",
    "${local.env_vars.locals.aws_region}b",
  ]

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  # No NAT gateway: the API (ecs-service) runs in the public subnets instead, which avoids
  # the ~US$35/month NAT gateway cost at this traffic level. RDS stays in the private subnets
  # and never needs outbound internet access. See the root README for the full trade-off.
  enable_nat_gateway = false
}
