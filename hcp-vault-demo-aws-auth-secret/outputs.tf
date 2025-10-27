output "ec2_public_dns" {
  value = aws_instance.my_instance.public_dns
}

