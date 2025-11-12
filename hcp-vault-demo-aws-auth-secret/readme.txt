sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install vault

export VAULT_NAMESPACE="admin"

vault login -method=aws role=vault-role-for-aws-ec2role

vault kv get -namespace=admin -mount="secrets" "secret"

vault read auth/aws/role/vault-role-for-aws-ec2role

