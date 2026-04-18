terraform {
  cloud {
    organization = "St0rmingBr4in"
    workspaces {
      name = "homelab-vault"
    }
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "vault" {
  address = "https://vault.st0rmingbr4in.com"
  token   = var.vault_token
}
