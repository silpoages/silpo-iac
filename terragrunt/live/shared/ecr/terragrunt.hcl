include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/ecr"
}

inputs = {
  name = "silpo-backend"

  # MUTABLE: the api unit always deploys the "latest" tag and the new CI deploy job
  # re-pushes it on every merge to main — IMMUTABLE would reject the second push onward.
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  untagged_expire_days = 14
}
