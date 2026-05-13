resource "digitalocean_spaces_bucket" "argo_logs" {
  name   = "st0rmingbr4in-argo-logs"
  region = var.spaces_region
  acl    = "private"

  lifecycle {
    prevent_destroy = true
  }
}
