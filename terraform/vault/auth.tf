locals {
  # Mount path of the Kubernetes auth method in Vault.
  vault_k8s_backend = "kubernetes"

  # CI service account name and namespace; must match the Argo Workflows
  # ServiceAccount created in argocd/applications/argo-workflows/.
  ci_service_account_name      = "argo-ci"
  ci_service_account_namespace = "argo"

  # Maximum lifetime (seconds) for Vault tokens issued to CI pods.
  # Set to 3600 (1 h) to cover the longest expected workflow runtime.
  ci_token_ttl = 3600
}

# Kubernetes auth role for CI workflow pods.
# Bound to the argo-ci ServiceAccount in the argo namespace.
# Workflow pods exchange their projected SA token for a Vault token at runtime.
resource "vault_kubernetes_auth_backend_role" "argo_ci" {
  backend                          = local.vault_k8s_backend
  role_name                        = local.ci_service_account_name
  bound_service_account_names      = [local.ci_service_account_name]
  bound_service_account_namespaces = [local.ci_service_account_namespace]
  token_ttl                        = local.ci_token_ttl
  token_policies                   = [vault_policy.argo_ci.name]

  # Sole authentication mechanism for all CI workflow pods; destroying this
  # role breaks every CI pipeline immediately.
  lifecycle {
    prevent_destroy = true
  }
}
