include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/static-site"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  # S3 bucket names are globally unique across all of AWS, so this needs the account id too.
  name = "silpo-web-${local.env_vars.locals.account_id}"

  # silpo-web is a Vite/React SPA using client-side routing (react-router-dom) — unknown
  # paths must fall back to index.html instead of S3's raw 403/404.
  spa_fallback = true
}
