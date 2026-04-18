# Policy for the argo-ci service account used by CI workflow pods.
# Grants read access to all secrets under secret/ci/*.
resource "vault_policy" "argo_ci" {
  name = "argo-ci"

  # Sole authentication mechanism for all CI workflow pods; destroying this
  # policy breaks every CI pipeline immediately.
  lifecycle {
    prevent_destroy = true
  }

  policy = <<-EOT
    path "secret/data/ci/*" {
      capabilities = ["read"]
    }
    path "secret/metadata/ci/*" {
      capabilities = ["read", "list"]
    }
  EOT
}
