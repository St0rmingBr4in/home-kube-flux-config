resource "woodpecker_repository" "home_kube_flux_config" {
  full_name = "St0rmingBr4in/home-kube-flux-config"

  # Pipeline config is auto-discovered from .woodpecker/*.yaml — no override needed.
}

# trigger
# test
