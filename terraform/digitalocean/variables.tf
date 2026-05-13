variable "digitalocean_token" {
  description = "DigitalOcean personal access token"
  type        = string
  sensitive   = true
}

variable "spaces_access_id" {
  description = "DigitalOcean Spaces access key ID"
  type        = string
  sensitive   = true
}

variable "spaces_secret_key" {
  description = "DigitalOcean Spaces secret access key"
  type        = string
  sensitive   = true
}

variable "spaces_region" {
  description = "DigitalOcean Spaces region for the Argo logs bucket"
  type        = string
  default     = "ams3"
}
