# AWS Auth Configuration
provider "aws" {
  region     = lookup(var.aws_region, var.region)
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

provider "signalfx" {
  auth_token = var.access_token
  api_url    = var.api_url
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

module "dashboards" {
  source           = "./modules/dashboards"
  count            = var.dashboards_enabled ? 1 : 0
  region           = lookup(var.aws_region, var.region)
  environment      = var.environment
  det_prom_tags_id = module.detectors.*.detector_promoting_tags_id
}

module "detectors" {
  source             = "./modules/detectors"
  count              = var.detectors_enabled ? 1 : 0
  notification_email = var.notification_email
  soc_integration_id = var.soc_integration_id
  soc_routing_key    = var.soc_routing_key
  region             = lookup(var.aws_region, var.region)
  environment        = var.environment
}

module "vpc" {
  source                = "./modules/vpc"
  vpc_name              = var.environment
  vpc_cidr_block        = var.vpc_cidr_block
  subnet_count          = var.subnet_count
  region                = lookup(var.aws_region, var.region)
  environment           = var.environment
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
}

module "aws_ecs" {
  source                = "./modules/aws_ecs"
  count                 = var.ecs_cluster_enabled ? 1 : 0
  region                = lookup(var.aws_region, var.region)
  access_token          = var.access_token
  realm                 = var.realm
  environment           = var.environment
  ecs_app_port          = var.ecs_app_port
  ecs_health_check_path = var.ecs_health_check_path
  ecs_app_image         = var.ecs_app_image
  ecs_container_name    = var.ecs_container_name
  ecs_fargate_cpu       = var.ecs_fargate_cpu
  ecs_fargate_memory    = var.ecs_fargate_memory
  ecs_app_count         = var.ecs_app_count
  ecs_az_count          = var.ecs_az_count
}

module "eks" {
  source                = "./modules/eks"
  count                 = var.eks_cluster_enabled ? 1 : 0
  region                = lookup(var.aws_region, var.region)
  environment           = var.environment
  smart_agent_version   = var.smart_agent_version
  access_token          = var.access_token
  realm                 = var.realm
  vpc_id                = module.vpc.vpc_id
  vpc_cidr_block        = var.vpc_cidr_block
  public_subnet_ids     = module.vpc.public_subnet_ids
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  instance_type         = var.instance_type
  ami                   = data.aws_ami.latest-ubuntu.id
  key_name              = var.key_name
  private_key_path      = var.private_key_path
  eks_cluster_name      = join("_", [var.environment, "eks_cluster"])
  eks_access_token      = var.eks_access_token
  eks_splunk_endpoint   = var.eks_splunk_endpoint
  eks_hec_token         = var.eks_hec_token
  eks_splunk_index      = var.eks_splunk_index
}

module "eks_fargate" {
  source                   = "./modules/eks_fargate"
  count                    = var.eks_fargate_cluster_enabled ? 1 : 0
  region                   = lookup(var.aws_region, var.region)
  environment              = var.environment
  smart_agent_version      = var.smart_agent_version
  access_token             = var.access_token
  realm                    = var.realm
  eks_fargate_cluster_name = join("-", [var.environment, "eks-fargate"])
}

module "phone_shop" {
  source                = "./modules/phone_shop"
  count                 = var.phone_shop_enabled ? 1 : 0
  region_wrapper_python = lookup(var.region_wrapper_python, var.region)
  region_wrapper_nodejs = lookup(var.region_wrapper_nodejs, var.region)
  access_token          = var.access_token
  region                = lookup(var.aws_region, var.region)
  vpc_id                = module.vpc.vpc_id
  vpc_cidr_block        = var.vpc_cidr_block
  environment           = var.environment
  realm                 = var.realm
  smart_agent_version   = var.smart_agent_version
  instance_type         = var.instance_type
  key_name              = var.key_name
  private_key_path      = var.private_key_path
  public_subnet_ids     = module.vpc.public_subnet_ids
  ami                   = data.aws_ami.latest-ubuntu.id
}

module "lambda_sqs_dynamodb" {
  source                = "./modules/lambda_sqs_dynamodb"
  count                 = var.lambda_sqs_dynamodb_enabled ? 1 : 0
  region_wrapper_python = lookup(var.region_wrapper_python, var.region)
  access_token          = var.access_token
  region                = lookup(var.aws_region, var.region)
  vpc_id                = module.vpc.vpc_id
  vpc_cidr_block        = var.vpc_cidr_block
  environment           = var.environment
  realm                 = var.realm
  smart_agent_version   = var.smart_agent_version
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  key_name              = var.key_name
  private_key_path      = var.private_key_path
  instance_type         = var.instance_type
  public_subnet_ids     = module.vpc.public_subnet_ids
  ami                   = data.aws_ami.latest-ubuntu.id
  my_public_ip          = "${chomp(data.http.my_public_ip.response_body)}"
}

module "proxied_instances" {
  source                           = "./modules/proxied_instances"
  count                            = var.proxied_instances_enabled ? 1 : 0
  access_token                     = var.access_token
  api_url                          = var.api_url
  realm                            = var.realm
  environment                      = var.environment
  region                           = lookup(var.aws_region, var.region)
  vpc_id                           = module.vpc.vpc_id
  vpc_cidr_block                   = var.vpc_cidr_block
  public_subnet_ids                = module.vpc.public_subnet_ids
  key_name                         = var.key_name
  private_key_path                 = var.private_key_path
  instance_type                    = var.instance_type
  ami                              = data.aws_ami.latest-ubuntu.id
  proxied_apache_web_count         = var.proxied_apache_web_count
  proxied_windows_server_count     = var.proxied_windows_server_count
  windows_server_administrator_pwd = var.windows_server_administrator_pwd
  windows_proxied_server_agent_url = var.windows_proxied_server_agent_url
  windows_server_instance_type     = var.windows_server_instance_type
  windows_server_ami               = data.aws_ami.windows-server.id
  collector_version                = var.collector_version
  proxy_server_count               = var.proxy_server_count
  my_public_ip                     = "${chomp(data.http.my_public_ip.response_body)}"
}

module "instances" {
  source                           = "./modules/instances"
  count                            = var.instances_enabled ? 1 : 0
  access_token                     = var.access_token
  api_url                          = var.api_url
  realm                            = var.realm
  smart_agent_version              = var.smart_agent_version
  environment                      = var.environment
  region                           = lookup(var.aws_region, var.region)
  vpc_id                           = module.vpc.vpc_id
  vpc_cidr_block                   = var.vpc_cidr_block
  public_subnet_ids                = module.vpc.public_subnet_ids
  key_name                         = var.key_name
  private_key_path                 = var.private_key_path
  instance_type                    = var.instance_type
  mysql_instance_type              = var.mysql_instance_type
  gateway_instance_type            = var.gateway_instance_type
  ami                              = data.aws_ami.latest-ubuntu.id
  gateway_count                    = var.gateway_count
  haproxy_count                    = var.haproxy_count
  mysql_count                      = var.mysql_count
  mysql_user                       = var.ms_sql_user
  mysql_user_pwd                   = var.ms_sql_user_pwd
  ms_sql_count                     = var.ms_sql_count
  ms_sql_user                      = var.ms_sql_user
  ms_sql_user_pwd                  = var.ms_sql_user_pwd
  ms_sql_instance_type             = var.ms_sql_instance_type
  ms_sql_ami                       = data.aws_ami.ms-sql-server.id
  iis_server_count                 = var.iis_server_count
  windows_server_administrator_pwd = var.windows_server_administrator_pwd
  windows_server_instance_type     = var.windows_server_instance_type
  windows_server_ami               = data.aws_ami.windows-server.id
  apache_web_count                 = var.apache_web_count
  splunk_cloud_enabled             = var.splunk_cloud_enabled
  splunk_cloud_hec_token           = var.splunk_cloud_hec_token
  splunk_admin_pwd                 = var.splunk_admin_pwd
  splunk_ent_count                 = var.splunk_ent_count
  splunk_ent_version               = var.splunk_ent_version
  splunk_ent_filename              = var.splunk_ent_filename
  splunk_enterprise_files_local_path = var.splunk_enterprise_files_local_path
  splunk_enterprise_license_filename = var.splunk_enterprise_license_filename
  splunk_ent_inst_type             = var.splunk_ent_inst_type
  universalforwarder_filename      = var.universalforwarder_filename
  universalforwarder_url           = var.universalforwarder_url
  universalforwarder_url_windows   = var.universalforwarder_url_windows
  my_public_ip                     = "${chomp(data.http.my_public_ip.response_body)}"
  splunk_ent_eip                   = var.splunk_ent_eip
  splunk_private_ip                = var.splunk_private_ip
  collector_version                = var.collector_version
  aws_access_key_id                = var.aws_access_key_id
  aws_secret_access_key            = var.aws_secret_access_key
}

module "itsi_o11y_cp" {
  source                                           = "./modules/itsi_o11y_cp"
  count                                            = var.itsi_o11y_cp_enabled ? 1 : 0
  access_token                                     = var.access_token
  api_url                                          = var.api_url
  realm                                            = var.realm
  environment                                      = var.environment
  region                                           = lookup(var.aws_region, var.region)
  vpc_id                                           = module.vpc.vpc_id
  vpc_cidr_block                                   = var.vpc_cidr_block
  public_subnet_ids                                = module.vpc.public_subnet_ids
  key_name                                         = var.key_name
  private_key_path                                 = var.private_key_path
  instance_type                                    = var.instance_type
  ami                                              = data.aws_ami.latest-ubuntu.id
  splunk_itsi_count                                = var.splunk_itsi_count
  splunk_itsi_inst_type                            = var.splunk_itsi_inst_type
  splunk_itsi_version                              = var.splunk_itsi_version
  splunk_itsi_filename                             = var.splunk_itsi_filename
  splunk_itsi_files_local_path                     = var.splunk_itsi_files_local_path
  splunk_itsi_license_filename                     = var.splunk_itsi_license_filename
  splunk_app_for_content_packs_filename            = var.splunk_app_for_content_packs_filename
  splunk_it_service_intelligence_filename          = var.splunk_it_service_intelligence_filename
  splunk_synthetic_monitoring_add_on_filename      = var.splunk_synthetic_monitoring_add_on_filename
  splunk_infrastructure_monitoring_add_on_filename = var.splunk_infrastructure_monitoring_add_on_filename
}

### Instances Outputs ###
output "OTEL_Gateway_Servers" {value = var.gateway_count > 0 ? module.instances.*.gateway_details : null}
output "HAProxy_Servers" {value = var.haproxy_count > 0 ? module.instances.*.haproxy_details : null}
output "MySQL_Servers" {value = var.mysql_count > 0 ? module.instances.*.mysql_details : null}
output "MS_SQL_Servers" {value = var.ms_sql_count > 0 ? module.instances.*.ms_sql_details : null}
output "Apache_Web_Servers" {value = var.apache_web_count > 0 ? module.instances.*.apache_web_details : null}
output "IIS_Servers" {value = var.iis_server_count > 0 ? module.instances.*.iis_server_details : null}

output "collector_lb_dns" {value = var.instances_enabled ? module.instances.*.gateway_lb_int_dns : null}
output "SQS_Test_Server" {value = var.lambda_sqs_dynamodb_enabled ? module.lambda_sqs_dynamodb.*.sqs_test_server_details : null}

### Proxied Instances Outputs ###
output "Proxied_Apache_Web_Servers" {value = var.proxied_instances_enabled ? module.proxied_instances.*.proxied_apache_web_details : null}
output "Proxied_Windows_Servers" {value = var.proxied_instances_enabled ? module.proxied_instances.*.proxied_windows_server_details : null}
output "Proxy_Server" {value = var.proxied_instances_enabled ? module.proxied_instances.*.proxy_server_details : null}

### Phone Shop Outputs ###
output "Phone_Shop_Server" {value = var.phone_shop_enabled ? module.phone_shop.*.phone_shop_server_details : null}

### ECS Outputs ###
output "ECS_ALB_hostname" {value = var.ecs_cluster_enabled ? module.aws_ecs.*.ecs_alb_hostname : null}

### Splunk Enterprise Outputs ###
output "splunk_password" {value = (var.splunk_ent_count > 0 || var.splunk_cloud_enabled == true) ? module.instances.*.splunk_password : null}
output "lo_connect_password" {value = var.splunk_ent_count > 0 ? module.instances.*.lo_connect_password : null}
output "splunk_enterprise_private_ip" {value = var.splunk_ent_count > 0 ? module.instances.*.splunk_enterprise_private_ip : null}
output "splunk_url" {value = var.splunk_ent_count > 0 ? module.instances.*.splunk_ent_urls : null}

### Splunk ITSI Outputs ###
output "Splunk_ITSI_Server" {value = var.itsi_o11y_cp_enabled ? module.itsi_o11y_cp.*.splunk_itsi_details : null}
output "Splunk_ITSI_Password" {value = var.itsi_o11y_cp_enabled ? module.itsi_o11y_cp.*.splunk_itsi_password : null}
output "Splunk_ITSI_URL" {value = var.itsi_o11y_cp_enabled ? module.itsi_o11y_cp.*.splunk_itsi_urls : null}

### Detector Outputs
output "detector_promoting_tags_id" {value = var.detectors_enabled ? module.detectors.*.detector_promoting_tags_id : null}

### EKS Outputs ###
# output "eks_cluster_endpoint" {value = var.eks_cluster_enabled ? module.eks.*.eks_cluster_endpoint : null}
output "eks_admin_server" {value = var.eks_cluster_enabled ? module.eks.*.eks_admin_server_details : null}
