variable "authentik_url" {
  type    = string
  default = "https://authentik.st0rmingbr4in.com"
}

variable "authentik_token" {
  type      = string
  sensitive = true
}
