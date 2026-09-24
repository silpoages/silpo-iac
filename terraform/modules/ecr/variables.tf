variable "name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten (MUTABLE) or not (IMMUTABLE)."
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Whether to scan images for vulnerabilities on push."
  type        = bool
  default     = true
}

variable "untagged_expire_days" {
  description = "Number of days after which untagged images are expired."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Extra tags applied to the repository."
  type        = map(string)
  default     = {}
}
