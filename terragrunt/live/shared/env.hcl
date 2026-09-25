locals {
  environment = "shared"
  aws_region  = "sa-east-1"

  # TODO: replace with the real AWS account ID this is deployed into. Used to namespace the
  # Terraform state bucket so it doesn't collide with anyone else's.
  account_id = "000000000000"
}
