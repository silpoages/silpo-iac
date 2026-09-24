variable "name" {
  description = "Name prefix applied to the DB instance and related resources."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit (GiB) for RDS storage autoscaling. Set equal to allocated_storage to disable."
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the default database created on the instance."
  type        = string
  default     = "silpo"
}

variable "master_username" {
  description = "Master username for the database."
  type        = string
  default     = "silpo_admin"
}

variable "vpc_id" {
  description = "VPC ID where the DB subnet group and security group are created."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs (private) for the DB subnet group."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to the database on the Postgres port."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the database on the Postgres port (e.g. the VPC CIDR, to avoid a circular dependency with the application's security group)."
  type        = list(string)
  default     = []
}

variable "multi_az" {
  description = "Whether to deploy a standby replica in a different AZ."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the instance."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on destroy. Keep false for production."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
