resource "random_pet" "vault_cluster" {
    length = 1
}

# Create HCP Project
resource "hcp_project" "vault_project" {
  name        = "HCP Vault Demo"
  description = "Project Created by hcp-vault-demo-init Terraform Workspace"
}

# Create HVN
resource "hcp_hvn" "vault_hvn" {
  project_id = hcp_project.vault_project.resource_id
  hvn_id         = "vault-hvn"
  cloud_provider = "aws"
  region         = var.region
  cidr_block     = "172.25.16.0/24"
}

# Create HCP Vault Cluster
resource "hcp_vault_cluster" "hcp_vault_demo" {
  project_id = hcp_project.vault_project.resource_id
  cluster_id = "hcp-vault-demo-${random_pet.vault_cluster.id}"
  hvn_id     = hcp_hvn.vault_hvn.hvn_id
  tier       = var.tier
  public_endpoint = true
}

# Get Vault token to auth Vault provider
resource "hcp_vault_cluster_admin_token" "terraform" {
  project_id = hcp_project.vault_project.resource_id
  cluster_id = hcp_vault_cluster.hcp_vault_demo.cluster_id
}

# Set up Okta backend to authenticate the hashicorp okta user
resource "vault_okta_auth_backend" "example" {
    depends_on = [ hcp_vault_cluster_admin_token.terraform ]
    description  = "Okta Auth backend"
    organization = "hashicorp"
    base_url = "okta.com"

    user {
        username = var.hashi_username
        policies   = ["hcp-root"]
    }
}

# Create VPC for AWS resources
module "hcp-vault-demo-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "vault-demo-vpc"
  cidr = "10.10.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnets  = ["10.10.11.0/24", "10.10.12.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
}

resource "hcp_aws_network_peering" "vault" {
  project_id = hcp_project.vault_project.resource_id
  hvn_id          = hcp_hvn.vault_hvn.hvn_id
  peering_id      = "hcp-vault-demo"
  peer_vpc_id     = module.hcp-vault-demo-vpc.vpc_id
  peer_account_id = module.hcp-vault-demo-vpc.vpc_owner_id
  peer_vpc_region = var.region
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = hcp_aws_network_peering.vault.provider_peering_id
  auto_accept               = true
}

resource "time_sleep" "wait_60s" {
  depends_on = [
    aws_vpc_peering_connection_accepter.peer
  ]
  create_duration = "60s"
}

resource "aws_vpc_peering_connection_options" "dns" {
  depends_on = [
    time_sleep.wait_60s
  ]
  vpc_peering_connection_id = hcp_aws_network_peering.vault.provider_peering_id
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "hcp_hvn_route" "hcp_vault" {
  hvn_link         = hcp_hvn.vault_hvn.self_link
  hvn_route_id     = "vault-to-internal-clients"
  destination_cidr = module.hcp-vault-demo-vpc.vpc_cidr_block
  target_link      = hcp_aws_network_peering.vault.self_link
}

resource "aws_route" "private_vault" {
  # for_each = toset(module.boundary-vpc.private_route_table_ids)
  for_each = {
    for idx, rt_id in module.hcp-vault-demo-vpc.private_route_table_ids : idx => rt_id
  }
  route_table_id            = each.value
  destination_cidr_block    = hcp_hvn.vault_hvn.cidr_block
  vpc_peering_connection_id = hcp_aws_network_peering.vault.provider_peering_id
}

resource "aws_route" "public_vault" {
  # for_each = toset(module.boundary-vpc.private_route_table_ids)
  for_each = {
    for idx, rt_id in module.hcp-vault-demo-vpc.public_route_table_ids : idx => rt_id
  }
  route_table_id            = each.value
  destination_cidr_block    = hcp_hvn.vault_hvn.cidr_block
  vpc_peering_connection_id = hcp_aws_network_peering.vault.provider_peering_id
}