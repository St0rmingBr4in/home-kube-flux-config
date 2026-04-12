variable "vault_address" {
  description = "Vault server address"
  type        = string
  default     = "https://vault.st0rmingbr4in.com"
}

variable "vault_token" {
  description = "Vault root or management token"
  type        = string
  sensitive   = true
}
