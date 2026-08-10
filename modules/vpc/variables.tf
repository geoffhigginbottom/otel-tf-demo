### AWS Variables ###
variable "region" {
  default = {}
}
variable "aws_access_key_id" {
  default = []
}
variable "aws_secret_access_key" {
  default = []
}
variable "environment" {
  default = []
}
variable "vpc_name" {
  default = []
}
variable "vpc_cidr_block" {
  default = []
}
variable "subnet_count" {
  type    = number
}

variable "nat_gateway_enabled" {
  description = "Create a NAT gateway and route private subnets through it (required for EKS Fargate)."
  type        = bool
  default     = false
}