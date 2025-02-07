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
variable "gateway_instance_type" {
  default = []
}
variable "mysql_instance_type" {
  default = []
}
variable "ms_sql_instance_type" {
  default = []
}
variable "windows_server_instance_type" {
  default = []
}
variable "ami" {
  default = {}
}
variable "ms_sql_ami" {
  default = {}
}
variable "windows_server_ami" {
  default = {}
}
variable "my_public_ip" {
  default = []
}
variable "splunk_ent_eip" {
  default = []
}
variable "splunk_private_ip" {
  default = []
}

### SignalFX Variables ###
variable "access_token" {
  default = []
}
variable "api_url" {
  default = []
}
variable "realm" {
  default = []
}
variable "smart_agent_version" {
  default = []
}
variable "otelcol_version" {
  default = []
}
variable "collector_version" {
  default = {}
}
variable "ballast" {
  default = []
}
variable "environment" {
  default = []
}
variable "gateway_count" {
  default = {}
}
variable "haproxy_count" {
  default = {}
}
variable "mysql_count" {
  default = {}
}
variable "mysql_user" {
  default = []
}
variable "mysql_user_pwd" {
  default = []
}
variable "ms_sql_count" {
  default = {}
}
variable "ms_sql_user" {
  default = []
}
variable "ms_sql_user_pwd" {
  default = []
}
variable "iis_server_count" {
  default = {}
}
variable "windows_server_administrator_pwd" {
  default =[]
}
variable "apache_web_count" {
  default = {}
}
variable "branch" {
  default = []
}


### Splunk Enterprise Variables ###
variable "splunk_cloud_enabled" {
  type    = bool
  default = false
}
variable "splunk_cloud_hec_token" {
  default = {}
}
variable "splunk_ent_count" {
  default = {}
}
variable "splunk_ent_version" {
  default = {}
}
variable "splunk_ent_filename" {
  default = {}
}
variable "splunk_ent_inst_type" {
  default = {}
}
variable "universalforwarder_filename" {
  default = {}
}
variable "universalforwarder_url" {
  default = {}
}
variable "universalforwarder_url_windows" {
  default = {}
}
variable "splunk_enterprise_files_local_path" {
  default = {}
}
variable "splunk_enterprise_license_filename" {
  default = {}
}
# variable "splunk_password" {
#   default = {}
# }