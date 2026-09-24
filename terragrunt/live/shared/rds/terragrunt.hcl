include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/rds-postgres"
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    vpc_cidr_block     = "10.0.0.0/16"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  name = "silpo-${local.env_vars.locals.environment}"

  vpc_id     = dependency.networking.outputs.vpc_id
  subnet_ids = dependency.networking.outputs.private_subnet_ids

  # No dedicated app security group is passed here (would create a cycle with the ecs-service
  # unit); access is scoped to the VPC's own CIDR instead, which is enough given both RDS and
  # the app run inside this one VPC.
  allowed_cidr_blocks = [dependency.networking.outputs.vpc_cidr_block]

  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  max_allocated_storage   = 20
  multi_az                = false
  backup_retention_period = 3
  deletion_protection     = true
  skip_final_snapshot     = false
}
