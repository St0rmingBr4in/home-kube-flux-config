# Manages HCP Terraform workspaces for the St0rmingBr4in homelab.
#
# Import commands (run once):
#   terraform import tfe_workspace.tfe           St0rmingBr4in/tfe
#   terraform import tfe_workspace.homelab       St0rmingBr4in/homelab
#   terraform import tfe_workspace.homelab_datadog St0rmingBr4in/homelab-datadog
#   terraform import tfe_workspace_settings.tfe           St0rmingBr4in/tfe
#   terraform import tfe_workspace_settings.homelab       St0rmingBr4in/homelab
#   terraform import tfe_workspace_settings.homelab_datadog St0rmingBr4in/homelab-datadog

locals {
  workspaces = {
    tfe             = "tfe"
    homelab         = "homelab"
    homelab_datadog = "homelab-datadog"
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
