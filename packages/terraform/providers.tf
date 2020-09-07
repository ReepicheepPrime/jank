terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "ReepicheepPrime"

    workspaces {
      name = "jank"
    }
  }
}

provider "aws" {
  version = "~> 3.0"
  region  = "us-east-1"
}