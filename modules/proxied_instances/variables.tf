### AWS Variables ###
variable "region" {
  default = {}
}
variable "vpc_id" {
  default = []
}
variable "vpc_cidr_block" {
  default = []
}
variable "public_subnet_ids" {
  default = {}
}
variable "key_name" {
  default = []
}
variable "private_key_path"{
  default = []
}
variable "instance_type" {
  default = []
}
variable "ami" {
  default = {}
}
variable "windows_server_instance_type" {
  default = []
}
variable "windows_server_ami" {
  default = {}
}
variable "windows_server_administrator_pwd" {
  default =[]
}
variable "my_public_ip" {
  default = []
}
variable "ec2_instance_profile_name" {
  type = string
}
variable "s3_bucket_name" {
    default = []
  }

### SignalFX Variables ###
variable "access_token" {
  default = {}
}
variable "api_url" {
  default = {}
}
variable "realm" {
  default = {}
}
variable "collector_version" {
  default = {}
}
variable "environment" {
  default = {}
}
variable "proxied_apache_web_count" {
  default = {}
}
variable "proxied_apache_web_ids" {
  default = []
}
variable "proxied_windows_server_count" {
  default = {}
}
variable "proxied_windows_server_ids" {
  default = []
}
variable "windows_proxied_server_agent_url" {
  default = {}
}
variable "proxy_server_count" {
  default = {}
}
variable "proxy_server_ids" {
  default = []
}
variable "branch" {
  default = []
}