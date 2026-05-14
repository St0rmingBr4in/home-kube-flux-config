locals {
  # KV v2 mount name used for all homelab secrets.
  vault_kv_mount = "secret"

  # Path prefix under which CI workflow secrets are stored.
  # Secrets here are read by the argo-ci Vault role at workflow runtime.
  vault_ci_path_prefix = "ci"
}

# Policy for Woodpecker CI pipeline step pods.
# Grants read access to all secrets under secret/ci/*.
resource "vault_policy" "ci" {
  name = "ci-read"

  policy = <<-EOT
    path "${local.vault_kv_mount}/data/${local.vault_ci_path_prefix}/*" {
      capabilities = ["read"]
    }
    path "${local.vault_kv_mount}/metadata/${local.vault_ci_path_prefix}/*" {
      capabilities = ["read", "list"]
    }
  EOT
}
