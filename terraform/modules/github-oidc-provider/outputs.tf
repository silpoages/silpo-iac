output "arn" {
  description = "ARN of the GitHub Actions OIDC provider, consumed by other modules' github_oidc_provider_arn input (e.g. static-site)."
  value       = aws_iam_openid_connect_provider.github.arn
}
