variable "region" {
  type        = string
  default     = "us-west-2"
  description = "The AWS region into which to deploy the HVN"
}

variable "tier" {
  type = string
  default = "dev"
  description = "The tier of HCP Vault cluster to create.  Recommend dev or standard_small for labs"
}

variable "hashi_username" {
  type = string
  description = "Your Hashicorp Okta username; i.e. first.last@hashicorp.com"
}