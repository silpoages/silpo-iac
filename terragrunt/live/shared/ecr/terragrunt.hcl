include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/ecr"
}

inputs = {
  name                 = "silpo-backend"
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
  untagged_expire_days = 14
}
