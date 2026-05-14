locals {
  # Mount path of the Kubernetes auth method in Vault.
  vault_k8s_backend = "kubernetes"

  # CI service account name and namespace; must match the woodpecker-pipeline
  # ServiceAccount created in argocd/applications/infrastructure/woodpecker/.
  ci_service_account_name      = "woodpecker-pipeline"
  ci_service_account_namespace = "woodpecker"

  # Maximum lifetime (seconds) for Vault tokens issued to CI pods.
  # Set to 3600 (1 h) to cover the longest expected pipeline runtime.
  ci_token_ttl = 3600
}

# Kubernetes auth role for Woodpecker CI pipeline step pods.
# Bound to the woodpecker-pipeline ServiceAccount in the woodpecker namespace.
# Step pods exchange their projected SA token for a Vault token at runtime.
resource "vault_kubernetes_auth_backend_role" "woodpecker_ci" {
  backend                          = local.vault_k8s_backend
  role_name                        = "woodpecker-ci"
  bound_service_account_names      = [local.ci_service_account_name]
  bound_service_account_namespaces = [local.ci_service_account_namespace]
  token_ttl                        = local.ci_token_ttl
  token_policies                   = [vault_policy.ci.name]
}
