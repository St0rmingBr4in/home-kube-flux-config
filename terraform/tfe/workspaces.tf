# Manages HCP Terraform workspaces for the St0rmingBr4in homelab.
# The `tfe` and `homelab` workspaces already exist and are imported below.
#
# Import existing workspaces:
#   terraform import tfe_workspace.tfe St0rmingBr4in/tfe
#   terraform import tfe_workspace.homelab St0rmingBr4in/homelab
#   terraform import tfe_workspace.homelab_datadog St0rmingBr4in/homelab-datadog

resource "tfe_workspace" "tfe" {
  name           = "tfe"
  organization   = var.organization
  execution_mode = "local"
}

resource "tfe_workspace" "homelab" {
  name           = "homelab"
  organization   = var.organization
  execution_mode = "local"
}

resource "tfe_workspace" "homelab_datadog" {
  name           = "homelab-datadog"
  organization   = var.organization
  execution_mode = "local"
}
