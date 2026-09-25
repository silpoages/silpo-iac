variable "domain_name" {
  description = "Root domain name (e.g. \"silpoages.com\"). Must already have a public Route53 hosted zone — created automatically if the domain is registered through Route53, or created by hand (and delegated at the registrar via this module's name_servers output) otherwise."
  type        = string
}

variable "web_domain_names" {
  description = "Domain names covered by the web (CloudFront) certificate. The first entry is the certificate's primary domain_name; the rest become subject_alternative_names."
  type        = list(string)
}

variable "api_domain_name" {
  description = "Domain name covered by the API (ALB) certificate, e.g. \"api.silpoages.com\"."
  type        = string
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
