locals {
  # KV v2 mount name used for all homelab secrets.
  vault_kv_mount = "secret"

  # Path prefix under which CI workflow secrets are stored.
  # Secrets here are read by the argo-ci Vault role at workflow runtime.
  vault_ci_path_prefix = "ci"
}

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
    path "${local.vault_kv_mount}/data/${local.vault_ci_path_prefix}/*" {
      capabilities = ["read"]
    }
    path "${local.vault_kv_mount}/metadata/${local.vault_ci_path_prefix}/*" {
      capabilities = ["read", "list"]
    }
  EOT
}
