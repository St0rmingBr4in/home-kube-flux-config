variable "authentik_url" {
  description = "Base URL of the Authentik instance (e.g. https://authentik.example.com)"
  type        = string
  default     = "https://authentik.st0rmingbr4in.com"
}

variable "authentik_token" {
  description = "Authentik API token used to authenticate the Terraform provider"
  type        = string
  sensitive   = true
}
