locals {
  environment = "shared"
  aws_region  = "us-east-2"

  # AWS account ID this is deployed into. Used to namespace the Terraform state bucket so it
  # doesn't collide with anyone else's.
  account_id = "222234418556"
}
