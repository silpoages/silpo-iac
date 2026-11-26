variable "tags" {
  description = "Extra tags applied to the OIDC provider."
  type        = map(string)
  default     = {}
}
