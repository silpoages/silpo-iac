output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID of the ALB (for alias records)."
  value       = aws_lb.this.zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "service_security_group_id" {
  description = "Security group ID attached to the ECS tasks (use as the RDS ingress source)."
  value       = aws_security_group.service.id
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role."
  value       = aws_iam_role.task.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront's own default *.cloudfront.net domain fronting the ALB with HTTPS. Null unless enable_cloudfront is true (and no real domain_name/certificate_arn is set)."
  value       = local.create_cloudfront ? aws_cloudfront_distribution.api[0].domain_name : null
}

output "deploy_role_arn" {
  description = "ARN of the IAM role the GitHub repo's CI assumes via OIDC to deploy. Null if github_oidc_provider_arn wasn't set."
  value       = local.create_deploy_role ? aws_iam_role.deploy[0].arn : null
}

output "smtp_username_secret_arn" {
  description = "ARN of the Secrets Manager secret for SMTP_USERNAME. Its value is a placeholder — set the real username with `aws secretsmanager put-secret-value`."
  value       = aws_secretsmanager_secret.smtp_username.arn
}

output "smtp_password_secret_arn" {
  description = "ARN of the Secrets Manager secret for SMTP_PASSWORD. Its value is a placeholder — set the real password with `aws secretsmanager put-secret-value`."
  value       = aws_secretsmanager_secret.smtp_password.arn
}
