output "bucket_name" {
  description = "Name of the S3 bucket holding the site's build output."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "distribution_id" {
  description = "CloudFront distribution ID (needed to create cache invalidations on deploy)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "Default *.cloudfront.net domain the site is served from."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "deploy_role_arn" {
  description = "ARN of the IAM role the GitHub repo's CI assumes via OIDC to deploy. Null if github_oidc_provider_arn wasn't set."
  value       = local.create_deploy_role ? aws_iam_role.deploy[0].arn : null
}
