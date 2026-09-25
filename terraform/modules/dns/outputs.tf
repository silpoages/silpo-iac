output "zone_id" {
  description = "Route53 hosted zone ID for domain_name."
  value       = data.aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Authoritative name servers for the hosted zone (set these at the registrar if it isn't Route53 itself)."
  value       = data.aws_route53_zone.this.name_servers
}

output "web_certificate_arn" {
  description = "Validated ACM certificate ARN for web_domain_names — feeds static-site's certificate_arn input."
  value       = aws_acm_certificate_validation.web.certificate_arn
}

output "api_certificate_arn" {
  description = "Validated ACM certificate ARN for api_domain_name — feeds ecs-service's certificate_arn input."
  value       = aws_acm_certificate_validation.api.certificate_arn
}
