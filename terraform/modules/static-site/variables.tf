variable "name" {
  description = "Name prefix applied to the bucket and related resources. Must be globally unique as an S3 bucket name, so it's used as-is for the bucket name."
  type        = string
}

variable "default_root_object" {
  description = "Object served for the root path (\"/\")."
  type        = string
  default     = "index.html"
}

variable "spa_fallback" {
  description = "Whether to route 403/404 responses from S3 (e.g. a client-side route with no matching object) back to default_root_object with a 200, for single-page apps using client-side routing."
  type        = bool
  default     = true
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 (North America + Europe only) is the cheapest and enough for this project's audience."
  type        = string
  default     = "PriceClass_100"
}

variable "aliases" {
  description = "Custom domain names (CNAMEs) for the distribution. Requires certificate_arn. Leave empty to only serve from the default *.cloudfront.net domain."
  type        = list(string)
  default     = []
}

variable "certificate_arn" {
  description = "ACM certificate ARN (must be in us-east-1, regardless of the distribution's other resources' region) for the aliases above. Leave null to use the default CloudFront certificate."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
