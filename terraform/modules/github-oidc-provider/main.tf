# One per AWS account — GitHub's own OIDC issuer, shared by every repo's deploy role (e.g.
# static-site's github_oidc_provider_arn input). Don't create a second one of these.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = var.tags
}
