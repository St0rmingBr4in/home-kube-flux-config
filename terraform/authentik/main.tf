terraform {
  cloud {
    organization = "St0rmingBr4in"
    workspaces {
      name = "homelab-authentik"
    }
  }

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "authentik" {
  url   = "https://authentik.${local.base_domain}"
  token = var.authentik_token
}

provider "vault" {
  address = "https://vault.${local.base_domain}"
  token   = var.vault_token
}
