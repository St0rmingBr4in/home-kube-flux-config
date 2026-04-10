variable "digitalocean_token" {
  description = "DigitalOcean personal access token"
  type        = string
  sensitive   = true
}

variable "inlet_droplet_name" {
  description = "Name of the inlet DigitalOcean droplet"
  type        = string
  default     = "inlet"
}
