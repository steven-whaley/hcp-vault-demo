terraform {
  required_version = ">= 1.0"
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.109.0"
    }
    vault = {
      version = "~> 5.1"
      source  = "hashicorp/vault"
    }
    okta ={
      version = "~> 6.5"
      source = "okta/okta"
    }
  }
  cloud {
    organization = "swhashi"
    workspaces {
      project = "HCP Vault Demos"
      name = "hcp-vault-demo-okta-oidc"
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

provider "okta" {
    org_name = "integrator-6015579"
    base_url = "okta.com"
}