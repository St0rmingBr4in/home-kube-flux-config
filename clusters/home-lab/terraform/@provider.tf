terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.84.0"
    }
  }
}

provider "google" {
  credentials = file("creds.json") # TODO: sops provider

  project = "driven-current-399517"
  region  = "europe-west1"
  zone    = "europe-west1-b"
}

resource "google_compute_network" "vpc_network" {
  name = "vpc-clusterv2"
}
