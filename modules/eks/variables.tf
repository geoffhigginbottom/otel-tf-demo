### SignalFX Variables ###
variable "access_token" {
  default = []
}
variable "environment" {
  default = []
}
variable "realm" {
  default = []
}
# variable "smart_agent_version" {
#   default = []
# }

### AWS Variables ###
variable "region" {
  default = {}
}
variable "aws_access_key_id" {
  default = []
}
variable "aws_secret_access_key" {
  default = []
}
variable "instance_type" {
  default = []
}
variable "eks_instance_type" {
  default = {}
}
variable "eks_ami_type" {
  default = {}
}
variable "ami" {
  default = {}
}
variable "key_name" {
  default = []
}
variable "private_key_path"{
  default = []
}
variable "public_subnet_ids" {
  default = []
}
variable "vpc_id" {
  default = []
}
variable "vpc_cidr_block" {
  default = {}
}
variable "eks_cluster_name" {
  default = {}
}
variable "eks_cluster_endpoint" {
  default = {}
}
variable "eks_access_token" {
  default = {}
}
variable "eks_splunk_endpoint" {
  default = {}
}
variable "eks_hec_token" {
  default = {}
}
variable "eks_splunk_index" {
  default = {}
}