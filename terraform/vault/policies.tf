# Policy for the argo-ci service account used by CI workflow pods.
# Grants read access to all secrets under secret/ci/*.
resource "vault_policy" "argo_ci" {
  name = "argo-ci"

  policy = <<-EOT
    path "secret/data/ci/*" {
      capabilities = ["read"]
    }
    path "secret/metadata/ci/*" {
      capabilities = ["read", "list"]
    }
  EOT
}
