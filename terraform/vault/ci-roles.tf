# Per-step-group roles so a compromised tool only reaches its own secrets;
# bound to the same-named ServiceAccounts in argocd/applications/infrastructure/woodpecker/pipeline-rbac.yaml.
locals {
  ci_roles = {
    woodpecker-tf-tfe          = { read = ["ci/terraform-cloud"], write = [] }
    woodpecker-tf-authentik    = { read = ["ci/terraform-cloud", "ci/authentik"], write = ["authentik/*"] }
    woodpecker-tf-datadog      = { read = ["ci/terraform-cloud", "ci/datadog"], write = [] }
    woodpecker-tf-digitalocean = { read = ["ci/terraform-cloud", "ci/digitalocean"], write = [] }
    woodpecker-tf-tailscale    = { read = ["ci/terraform-cloud", "ci/tailscale"], write = [] }
    woodpecker-tf-vault        = { read = ["ci/terraform-cloud", "ci/vault"], write = [] }
    woodpecker-tf-woodpecker   = { read = ["ci/terraform-cloud", "ci/woodpecker-tf"], write = [] }
    woodpecker-ansible         = { read = ["ci/ansible", "ci/datadog", "ci/tailscale", "inlet/socks"], write = [] }
    woodpecker-image-build     = { read = ["ci/docker"], write = [] }
    woodpecker-notify          = { read = ["ci/datadog"], write = [] }
  }
}

resource "vault_policy" "ci_role" {
  for_each = local.ci_roles
  name     = each.key

  policy = join("\n", concat(
    [for p in each.value.read : <<-EOT
      path "${local.vault_kv_mount}/data/${p}" {
        capabilities = ["read"]
      }
    EOT
    ],
    [for p in each.value.write : <<-EOT
      path "${local.vault_kv_mount}/data/${p}" {
        capabilities = ["create", "read", "update", "delete"]
      }
      path "${local.vault_kv_mount}/metadata/${p}" {
        capabilities = ["read", "list", "delete"]
      }
    EOT
    ],
    # The Terraform Vault provider mints a child token before writing.
    length(each.value.write) > 0 ? [<<-EOT
      path "auth/token/create" {
        capabilities = ["update"]
      }
    EOT
    ] : [],
  ))
}

resource "vault_kubernetes_auth_backend_role" "ci_role" {
  for_each                         = local.ci_roles
  backend                          = local.vault_k8s_backend
  role_name                        = each.key
  bound_service_account_names      = [each.key]
  bound_service_account_namespaces = [local.ci_service_account_namespace]
  token_ttl                        = local.ci_token_ttl
  token_policies                   = [vault_policy.ci_role[each.key].name]
}
