variable "enterprise_app_client_id" {
  description = "Application (client) ID of the Enterprise Application that is the SSO assignment target. The azuread provider resolves this to a Service Principal object_id."
  type        = string
}
