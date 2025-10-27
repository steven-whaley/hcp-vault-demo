locals {
  my_email = split("/", data.aws_caller_identity.current.arn)[2]
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key"
  public_key = var.public_key
}

# EC2 IAM role for authenticating with Vault
resource "aws_iam_role" "vault_target_iam_role" {
  name               = "aws-ec2role-for-vault-authmethod"
  assume_role_policy = data.aws_iam_policy_document.client_policy.json
}

resource "aws_iam_role_policy_attachment" "security_compute" {
  role       = aws_iam_role.vault_target_iam_role.name
  policy_arn = data.aws_iam_policy.security_compute_access.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "demo_profile"
  role = aws_iam_role.vault_target_iam_role.name
}

resource "aws_security_group" "security_group" {
  name = "allow-all-sg"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_instance" {
  ami                         = data.aws_ami.aws_linux_hvm2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  vpc_security_group_ids      = [aws_security_group.security_group.id]
  key_name = aws_key_pair.ec2_key.key_name
  tags = {
    Name = "hcp-vault-demo-aws-auth-secret"
  }
}

#AWS Auth Method resources
resource "aws_iam_user" "vault_mount_user" {
  name                 = "demo-${local.my_email}"
  permissions_boundary = data.aws_iam_policy.demo_user_permissions_boundary.arn
  force_destroy        = true
}

resource "aws_iam_user_policy_attachment" "vault_mount_user" {
  user       = aws_iam_user.vault_mount_user.name
  policy_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
}

resource "aws_iam_access_key" "vault_mount_user" {
  user = aws_iam_user.vault_mount_user.name
}

# AWS Secrets Engine Resources
data "aws_iam_policy_document" "vault_dynamic_iam_user_policy" {
  statement {
    sid       = "VaultDemoUserDescribeEC2Regions"
    actions   = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}

data "aws_iam_role" "vault_target_iam_role" {
  name = "vault-assumed-role-credentials-demo"
}