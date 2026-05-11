terraform {
  cloud {
    organization = "St0rmingBr4in"
    workspaces {
      name = "tfe"
    }
  }

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.76"
    }
  }
}

provider "tfe" {
  organization = "St0rmingBr4in"
}
