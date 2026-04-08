terraform {
  cloud {
    organization = "St0rmingBr4in"
    workspaces {
      name = "homelab"
    }
  }

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12"
    }
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}
