variable "name" {
  description = "Name prefix applied to the cluster, service, task definition and related resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB and ECS service are created."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the Application Load Balancer."
  type        = list(string)
}

variable "task_subnet_ids" {
  description = <<-EOT
    Subnet IDs for the ECS Fargate tasks. Pass public subnets with assign_public_ip=true to
    avoid the cost of a NAT gateway (tasks are still only reachable through the ALB, since the
    service security group only allows inbound from it) — the recommended default at low
    traffic. Pass private subnets with assign_public_ip=false if a NAT gateway is provisioned.
  EOT
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Whether Fargate tasks get a public IP. Must be true if task_subnet_ids are public subnets with no NAT gateway."
  type        = bool
  default     = true
}

variable "image" {
  description = "Full container image URI (e.g. <ecr_repository_url>:<tag>)."
  type        = string
}

variable "container_port" {
  description = "Port the application listens on inside the container."
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "HTTP path the ALB target group uses for health checks."
  type        = string
  default     = "/health"
}

variable "cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of tasks to run."
  type        = number
  default     = 1
}

variable "environment_variables" {
  description = "Plain (non-secret) environment variables passed to the container."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Environment variables sourced from Secrets Manager or SSM Parameter Store."
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []
}

variable "secret_arns" {
  description = "ARNs the task execution role is allowed to read (Secrets Manager secrets / SSM parameters referenced in var.secrets)."
  type        = list(string)
  default     = []
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Leave null to only serve HTTP (e.g. before a domain is verified)."
  type        = string
  default     = null
}

variable "api_base_url_override" {
  description = "Explicit API_BASE_URL env var value (e.g. https://api.silpo.app once a domain exists). Defaults to the ALB's own DNS name, over HTTPS if certificate_arn is set."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days for the task's log group."
  type        = number
  default     = 30
}

variable "enable_container_insights" {
  description = "Whether to enable ECS Container Insights (extra CloudWatch metrics cost)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
