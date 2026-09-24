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

output "resend_api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret for RESEND_API_KEY. Its value is a placeholder — set the real key with `aws secretsmanager put-secret-value`."
  value       = aws_secretsmanager_secret.resend_api_key.arn
}
