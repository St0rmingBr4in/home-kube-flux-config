# Manages HCP Terraform workspaces for the St0rmingBr4in homelab.
#
# Import commands (run once):
#   terraform import tfe_workspace.tfe                    St0rmingBr4in/tfe
#   terraform import tfe_workspace.homelab                St0rmingBr4in/homelab
#   terraform import tfe_workspace.homelab_datadog        St0rmingBr4in/homelab-datadog
#   terraform import tfe_workspace.homelab_digitalocean   St0rmingBr4in/homelab-digitalocean
#   terraform import tfe_workspace_settings.tfe                    St0rmingBr4in/tfe
#   terraform import tfe_workspace_settings.homelab                St0rmingBr4in/homelab
#   terraform import tfe_workspace_settings.homelab_datadog        St0rmingBr4in/homelab-datadog
#   terraform import tfe_workspace_settings.homelab_digitalocean   St0rmingBr4in/homelab-digitalocean
#   terraform import tfe_workspace.homelab_tailscale               St0rmingBr4in/homelab-tailscale
#   terraform import tfe_workspace_settings.homelab_tailscale      St0rmingBr4in/homelab-tailscale

locals {
  # Map of Terraform resource key → HCP Terraform workspace name.
  # Each workspace uses execution_mode = "local" (set via tfe_workspace_settings)
  # so that plan/apply run on the GitHub Actions runner, not on TFC.
  workspaces = {
    tfe                  = "tfe"                  # this workspace (manages TFE resources)
    homelab              = "homelab"              # Authentik SSO configuration
    homelab_datadog      = "homelab-datadog"      # Datadog monitors and synthetics
    homelab_digitalocean = "homelab-digitalocean" # DigitalOcean droplet + DNS
    homelab_tailscale    = "homelab-tailscale"    # Tailscale ACL and OAuth keys
    homelab_vault        = "homelab-vault"        # Vault policies and auth roles
  }
}

resource "tfe_workspace" "workspaces" {
  for_each     = local.workspaces
  name         = each.value
  organization = var.organization
}

resource "tfe_workspace_settings" "workspaces" {
  for_each       = local.workspaces
  workspace_id   = tfe_workspace.workspaces[each.key].id
  execution_mode = "local"
}
