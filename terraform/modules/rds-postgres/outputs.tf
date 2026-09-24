output "db_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "db_instance_address" {
  description = "Hostname of the RDS instance."
  value       = aws_db_instance.this.address
}

output "db_instance_port" {
  description = "Port the RDS instance listens on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the default database."
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "Security group ID attached to the RDS instance."
  value       = aws_security_group.this.id
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding connection details."
  value       = aws_secretsmanager_secret.this.arn
}
