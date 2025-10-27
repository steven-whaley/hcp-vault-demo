variable "region" {
  type        = string
  description = "The region to create instrastructure in"
  default     = "us-west-2"
}

variable "public_key" {
  type        = string
  description = "Public key to log into AWS instance"
}