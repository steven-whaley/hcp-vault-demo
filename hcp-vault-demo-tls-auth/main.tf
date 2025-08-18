

### Set up a PKI root and intermediate Issuers
resource "vault_mount" "pki" {
  path        = "pki"
  type        = "pki"
  description = "PKI root CA"

  default_lease_ttl_seconds = 315360000
  max_lease_ttl_seconds     = 315360000
}

resource "vault_pki_secret_backend_root_cert" "root" {
  depends_on            = [vault_mount.pki]
  backend               = vault_mount.pki.path
  type                  = "internal"
  common_name           = "Vault.lab Root CA"
  ttl                   = "315360000"
  format                = "pem"
  private_key_format    = "der"
  key_type              = "rsa"
  key_bits              = 4096
  exclude_cn_from_sans  = true
  ou                    = "Vault Lab"
  organization          = "HashiCorp, Inc"
}

resource "vault_pki_secret_backend_config_urls" "root_urls" {
  backend = vault_mount.pki.path
  issuing_certificates = [
    "http://127.0.0.1:8200/v1/pki/ca",
  ]
  crl_distribution_points = [
    "http://127.0.0.1:8200/v1/pki/crl"
  ]
}

resource "vault_mount" "pki_int" {
  path        = "pki_int"
  type        = "pki"
  description = "PKI intermediate issuer to issue PKI certificates for TLS auth"

  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = 2592000
}

resource "vault_pki_secret_backend_config_urls" "int_urls" {
  backend = vault_mount.pki.path
  issuing_certificates = [
    "http://127.0.0.1:8200/v1/pki_int/ca",
  ]
  crl_distribution_points = [
    "http://127.0.0.1:8200/v1/pki_int/crl"
  ]
}

resource "vault_pki_secret_backend_intermediate_cert_request" "int_csr" {
  depends_on  = [vault_mount.pki_int]
  backend     = vault_mount.pki_int.path
  type        = "internal"
  common_name = "Vault.lab Intermediate CA"
  key_bits = 4096
}

resource "vault_pki_secret_backend_root_sign_intermediate" "int_sign" {
  backend              = vault_mount.pki.path
  csr                  = vault_pki_secret_backend_intermediate_cert_request.int_csr.csr
  common_name          = "Vault.lab Intermediate CA"
  exclude_cn_from_sans = true
  ou                   = "Vault Lab"
  organization         = "HashiCorp, Inc"
  revoke               = true
}

resource "vault_pki_secret_backend_intermediate_set_signed" "int_set" {
  backend     = vault_mount.pki_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.int_sign.certificate
}

resource "vault_pki_secret_backend_role" "service_role" {
  backend          = vault_mount.pki_int.path
  name             = "service_role"
  ttl              = 86400
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["service-*.service.vault.lab"]
  allow_subdomains = false
  allow_glob_domains = true
}

## Create TLS Auth method
resource "vault_auth_backend" "service_cert" {
  type = "cert"
  path = "service_cert"

  tune {
    max_lease_ttl      = "90000s"
    listing_visibility = "unauth"
  }
}

resource "vault_cert_auth_backend_role" "service_auth" {
    name           = "service_auth"
    certificate    = vault_pki_secret_backend_root_sign_intermediate.int_sign.certificate
    backend        = vault_auth_backend.service_cert.path
    allowed_common_names  = ["service-*.service.vault.lab"]
    token_ttl      = 300
    token_max_ttl  = 600
    token_policies = ["default", "${vault_policy.service_policy.name}"]
}

# KV Secrets Engine and KV secrets

resource "vault_mount" "secrets" {
  path        = "secrets"
  type        = "kv-v2"
  description = "KV v2 secrets engine"
}

resource "vault_kv_secret_v2" "service-a" {
  mount                      = vault_mount.secrets.path
  name                       = "service-a.service.vault.lab/secret"
  cas                        = 1
  delete_all_versions        = false
  data_json                  = jsonencode(
  {
    username       = "user",
    password       = "notarealpassword"
  }
  )
  custom_metadata {
    max_versions = 5
    data = {
      service = "service-a"
    }
  }
}

resource "vault_kv_secret_v2" "service-b" {
  mount                      = vault_mount.secrets.path
  name                       = "service-b.service.vault.lab/secret"
  cas                        = 1
  delete_all_versions        = false
  data_json                  = jsonencode(
  {
    username       = "user",
    password       = "notarealpassword"
  }
  )
  custom_metadata {
    max_versions = 5
    data = {
      service = "service-b"
    }
  }
}

# Create policies for vault agent to access PKI and service secrets

resource "vault_policy" "service_policy" {
  name = "service-policy"

  policy = <<EOT
path "secrets/data/{{identity.entity.aliases.${vault_auth_backend.service_cert.accessor}.name}}/*" {
  capabilities = ["create", "update", "patch", "read", "delete", "list"]
}

path "secrets/metadata/{{identity.entity.aliases.${vault_auth_backend.service_cert.accessor}.name}}/*" {
  capabilities = ["create", "update", "patch", "read", "delete", "list"]
}

path "secrets/subkeys/{{identity.entity.aliases.${vault_auth_backend.service_cert.accessor}.name}}/*" {
  capabilities = ["create", "update", "patch", "read", "delete", "list"]
}

path "pki_int/issue/service_role" {
  capabilities = ["create", "update", "read"]
}
EOT
}

# Create AWS Instance

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key"
  public_key = var.public_key
}

module "ec2-security-group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "ec2-access"
  description = "Allow connection to Vault API and SSH from external"
  vpc_id      = data.tfe_outputs.hcp_vault_demo_init.values.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]

  egress_with_cidr_blocks = [
    {
      from_port = 8200
      to_port = 8200
      protocol = "tcp"
      description = "Allow egress to HCP Vault API"
      cidr_blocks = data.tfe_outputs.hcp_vault_demo_init.values.hvn_cidr
    }
  ]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["https-443-tcp", "http-80-tcp"]
}


resource "aws_instance" "vault-server" {
  ami           = data.aws_ami.aws_linux_hvm2.id
  instance_type = "t3.micro"

  key_name                    = aws_key_pair.ec2_key.key_name
  monitoring                  = true
  subnet_id                   = data.tfe_outputs.hcp_vault_demo_init.values.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.ec2-security-group.security_group_id]
  user_data                   = templatefile("${path.module}/user_data.tftpl", { vault_address = data.tfe_outputs.hcp_vault_demo_init.values.vault_priv_url, vault_token = hcp_vault_cluster_admin_token.terraform.token  })
  tags = {
    Name = "hcp-vault-demo"
  }
}