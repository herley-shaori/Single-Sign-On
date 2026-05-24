provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "sso"
      Scope     = "shared"
    }
  }
}
