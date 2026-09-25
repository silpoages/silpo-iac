include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/static-site"
}

dependency "dns" {
  config_path = "../dns"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    zone_id             = "Z00000000000000000"
    web_certificate_arn = "arn:aws:acm:us-east-1:000000000000:certificate/00000000-0000-0000-0000-000000000000"
  }
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

  aliases         = ["silpoages.com", "www.silpoages.com"]
  certificate_arn = dependency.dns.outputs.web_certificate_arn
  zone_id         = dependency.dns.outputs.zone_id
}
