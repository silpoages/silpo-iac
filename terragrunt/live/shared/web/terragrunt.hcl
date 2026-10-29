include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/static-site"
}

dependency "github_oidc" {
  config_path = "../github-oidc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    arn = "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
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

  # No domain yet — served from CloudFront's own default *.cloudfront.net domain (aliases,
  # certificate_arn and zone_id left at their null/empty defaults). Still HTTPS: that default
  # domain comes with its own CloudFront-issued certificate, no ACM cert needed.

  # Lets silpo-web's own CI assume a deploy role via OIDC (no long-lived AWS keys in GitHub
  # secrets) to sync dist/ to this bucket and invalidate the CloudFront distribution.
  github_oidc_provider_arn = dependency.github_oidc.outputs.arn
  github_repo              = "silpoages/silpo-web"
  github_deploy_branch     = "master"
}
