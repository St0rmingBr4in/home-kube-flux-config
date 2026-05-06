variable "authentik_token" {
  description = "Authentik API token used to authenticate the Terraform provider"
  type        = string
  sensitive   = true
}

variable "vault_token" {
  description = "Vault token used to write generated secrets (e.g. OIDC client secrets)"
  type        = string
  sensitive   = true
}
