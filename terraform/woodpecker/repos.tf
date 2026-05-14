resource "woodpecker_repository" "home_kube_flux_config" {
  owner      = "St0rmingBr4in"
  name       = "home-kube-flux-config"
  is_trusted = true

  # Pipeline config is auto-discovered from .woodpecker/*.yaml — no override needed.
}
