variable "okta_org_name" {
  description = "Okta org subdomain (the part before the base_url). For 'trial-000000.okta.com' this is 'trial-000000'."
  type        = string
}

variable "okta_base_url" {
  description = "Okta base domain. 'okta.com' for production/trial orgs, 'oktapreview.com' for preview orgs."
  type        = string
  default     = "okta.com"
}

variable "okta_client_id" {
  description = "Application (client) ID of the Okta OAuth service app used for API access (private_key_jwt). Not a secret, but operator-specific, so kept in git-ignored tfvars."
  type        = string
}

variable "okta_scopes" {
  description = "Okta API scopes granted to the service app. Must be granted in the Okta Admin console or token requests fail with consent_required. The .manage scopes already include read."
  type        = list(string)
  default = [
    "okta.users.manage",
    "okta.groups.manage",
  ]
}

variable "okta_private_key_file" {
  description = "File name (relative to this module) of the PEM (PKCS#8) RSA private key whose public half is registered on the Okta service app. Git-ignored."
  type        = string
  default     = "okta_api_key.pem"
}

variable "okta_private_key_id" {
  description = "Optional key id (kid) of the registered public key. Leave null to let Okta match by key material."
  type        = string
  default     = null
}
