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
      version = "~> 2026.2"
    }
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}
