variable "authentik_token" {
  description = "Authentik API token used to authenticate the Terraform provider"
  type        = string
  sensitive   = true
}
