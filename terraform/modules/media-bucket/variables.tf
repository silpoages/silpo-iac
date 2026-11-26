variable "name" {
  description = "Bucket name. S3 bucket names are globally unique across all of AWS, so include something account-specific (e.g. the account id)."
  type        = string
}

variable "noncurrent_version_expiration_days" {
  description = "Days an overwritten or deleted object's previous version is kept (restorable) before S3 removes it for good."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
