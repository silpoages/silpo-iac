include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/dns"
}

inputs = {
  # silpoages.com must already have a public Route53 hosted zone before this can apply.
  # Registering it through Route53 (AWS Console/CLI — a real purchase, so not something
  # Terraform does) creates that zone automatically. If it ends up registered elsewhere
  # instead, create the zone by hand and delegate to it using this stack's name_servers output.
  domain_name = "silpoages.com"

  web_domain_names = ["silpoages.com", "www.silpoages.com"]
  api_domain_name  = "api.silpoages.com"
}
