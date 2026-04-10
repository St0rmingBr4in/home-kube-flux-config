terraform {
  cloud {
    organization = "St0rmingBr4in"
    workspaces {
      name = "homelab-digitalocean"
    }
  }

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.digitalocean_token
}
