include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/media-bucket"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  # S3 bucket names are globally unique across all of AWS, so this needs the account id too.
  name = "silpo-media-${local.env_vars.locals.account_id}"
}
