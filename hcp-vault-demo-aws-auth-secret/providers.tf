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
      name = "hcp-vault-demo-aws-auth-secret"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "vault" {
    address = data.tfe_outputs.hcp_vault_demo_init.values.vault_url
    token = hcp_vault_cluster_admin_token.terraform.token
    namespace = "admin"
}