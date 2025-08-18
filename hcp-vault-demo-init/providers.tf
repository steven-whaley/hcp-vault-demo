terraform {
  required_version = ">= 1.0"
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.109.0"
    }
    aws = {
      version = "~> 6.0"
      source  = "hashicorp/aws"
    }
    vault = {
      version = "~> 5.1"
      source  = "hashicorp/vault"
    }
  }
  cloud {
    organization = "swhashi"
    workspaces {
      project = "HCP Vault Demos"
      name = "hcp-vault-demo-init"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "vault" {
    address = hcp_vault_cluster.hcp_vault_demo.vault_public_endpoint_url
    token = hcp_vault_cluster_admin_token.terraform.token
    namespace = "admin"
}