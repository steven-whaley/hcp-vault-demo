output "vault_url" {
    value = hcp_vault_cluster.hcp_vault_demo.vault_public_endpoint_url
}

output "vault_priv_url" {
    value = hcp_vault_cluster.hcp_vault_demo.vault_private_endpoint_url
}

output "hcp_project" {
    value = hcp_project.vault_project.resource_id
}

output "cluster_id" {
    value = hcp_vault_cluster.hcp_vault_demo.cluster_id
}

output "vpc_id" {
    value = module.hcp-vault-demo-vpc.vpc_id
}

output "private_subnets" {
    value = module.hcp-vault-demo-vpc.private_subnets
}

output "public_subnets" {
    value = module.hcp-vault-demo-vpc.public_subnets
}

output "hvn_cidr" {
    value = hcp_hvn.vault_hvn.cidr_block 
}