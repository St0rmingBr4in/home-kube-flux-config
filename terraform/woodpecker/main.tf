terraform {
  cloud {
    organization = "St0rmingBr4in"
    workspaces {
      name = "homelab-woodpecker"
    }
  }

  required_providers {
    woodpecker = {
      source  = "adduc/woodpecker"
      version = "~> 0.4"
    }
  }
}

provider "woodpecker" {
  server = "https://woodpecker.st0rmingbr4in.com"
  token  = var.woodpecker_token
}
