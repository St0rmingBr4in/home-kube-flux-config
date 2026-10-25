resource "woodpecker_repository" "home_kube_flux_config" {
  full_name = "St0rmingBr4in/home-kube-flux-config"

  # Pipeline config is auto-discovered from .woodpecker/*.yaml — no override needed.

  # The checks pipeline mounts the woodpecker-ci-cache PVC.
  trusted = {
    volumes = true
  }

  # Never cancel master pushes: deploy steps are path-filtered, so a canceled apply is never retried.
  cancel_previous_pipeline_events = ["pull_request"]
}
