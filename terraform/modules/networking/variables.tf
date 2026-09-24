variable "name" {
  description = "Name prefix applied to every resource created by this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ (same order as var.azs)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ (same order as var.azs)."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateway(s) so private subnets can reach the internet."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all AZs instead of one per AZ (cheaper, less resilient)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
