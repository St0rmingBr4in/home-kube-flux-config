terraform {
  cloud {
    organization = "St0rmingBr4in"
    workspaces {
      name = "homelab-woodpecker"
    }
  }
  required_providers {
    woodpecker = {
      source  = "Kichiyaki/woodpecker"
      version = "~> 0.5"
    }
  }
}

provider "woodpecker" {
  server = "https://woodpecker.st0rmingbr4in.com"
  token  = var.woodpecker_token
}
