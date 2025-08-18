data "tfe_outputs" "hcp_vault_demo_init" {
  organization = "swhashi"
  workspace    = "hcp-vault-demo-init"
}

resource "hcp_vault_cluster_admin_token" "terraform" {
  project_id = data.tfe_outputs.hcp_vault_demo_init.values.hcp_project
  cluster_id = data.tfe_outputs.hcp_vault_demo_init.values.cluster_id
}

data "aws_ami" "aws_linux_hvm2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
