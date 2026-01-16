data "tfe_outputs" "hcp_vault_demo_init" {
  organization = "swhashi"
  workspace    = "hcp-vault-demo-init"
}

resource "hcp_vault_cluster_admin_token" "terraform" {
  project_id = data.tfe_outputs.hcp_vault_demo_init.values.hcp_project
  cluster_id = data.tfe_outputs.hcp_vault_demo_init.values.cluster_id
}