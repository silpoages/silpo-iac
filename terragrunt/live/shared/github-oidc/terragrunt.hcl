include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/github-oidc-provider"
}

# No inputs: one OIDC provider per AWS account, shared by every repo's deploy role.
