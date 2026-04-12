# Kubernetes auth role for CI workflow pods.
# Bound to the argo-ci ServiceAccount in the argo namespace.
# Workflow pods exchange their projected SA token for a Vault token at runtime.
resource "vault_kubernetes_auth_backend_role" "argo_ci" {
  backend                          = "kubernetes"
  role_name                        = "argo-ci"
  bound_service_account_names      = ["argo-ci"]
  bound_service_account_namespaces = ["argo"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.argo_ci.name]
}
