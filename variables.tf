## Enable/Disable Modules - Values are set in terraform.tfvars ###
  variable "eks_cluster_enabled" {
    type = bool
  }
  variable "eks_fargate_cluster_enabled" {
    type = bool
  }
  variable "ecs_cluster_enabled" {
    type = bool
  }
  variable "instances_enabled" {
    type = bool
  }
  variable "proxied_instances_enabled" {
    type = bool
  }
  variable "phone_shop_enabled" {
    type = bool
  }
  variable "lambda_sqs_dynamodb_enabled" {
    type = bool
  }
  variable "dashboards_enabled" {
    type = bool
  }
  variable "detectors_enabled" {
    type = bool
  }
  variable "splunk_hec_metrics_enabled" {
    type    = bool
    default = false
  }


### AWS Variables ###
  variable "profile" {
    type    = string
    default = ""
  }
  variable "aws_access_key_id" {
    type    = string
    default = ""
  }
  variable "aws_secret_access_key" {
    type    = string
    default = ""
  }
  variable "vpc_id" {
    type    = string
    default = ""
  }
  variable "vpc_name" {
    type    = string
    default = ""
  }
  variable "vpc_cidr_block" {
    type    = string
    default = ""
  }
  variable "public_subnet_ids" {
    default = {}
  }
  variable "private_subnet_ids" {
    type = list(string)
    default = []
  }
  variable "subnet_count" {
    type = number
  }
  variable "key_name" {
    type    = string
    default = ""
  }

  variable "private_key_path" {
    type    = string
    default = ""
  }

  variable "instance_type" {
    type    = string
    default = ""
  }

  variable "gateway_instance_type" {
    type    = string
    default = ""
  }

  variable "mysql_instance_type" {
    type    = string
    default = ""
  }

  variable "ms_sql_instance_type" {
    type    = string
    default = ""
  }

  variable "windows_server_instance_type" {
    type    = string
    default = ""
  }

  variable "aws_api_gateway_deployment_retailorder_invoke_url" {
    type = string
    default = ""
  }
  variable "my_public_ip" {
    type = string
    default = ""
  }
  variable "splunk_ent_eip" {
    type    = string
    default = ""
  }

  variable "splunk_private_ip" {
    type    = string
    default = ""
  }

  variable "s3_bucket_name" {
    type    = string
    default = ""
  }


## EKS Variables ##
  variable "eks_cluster_name" {
    type    = string
    default = ""
  }
  variable "eks_access_token" {
    type    = string
    default = ""
  }
  variable "eks_splunk_endpoint" {
    type    = string
    default = ""
  }
  variable "splunk_ent_url_hec" {
    type    = string
    default = ""
  }
  variable "eks_splunk_index" {
    type    = string
    default = ""
  }
  variable "eks_instance_type" {
    type    = string
    default = ""
  }
  variable "eks_ami_type" {
    type    = string
    default = ""
  }
  variable "eks_admin_server_eip" {
    type    = string
    default = ""
  }

### Certificate Vars ###
  variable "certpath" {
    type    = string
    default = ""
  }

  variable "passphrase" {
    type    = string
    default = ""
  }

  variable "fqdn" {
    type    = string
    default = ""
  }

  variable "country" {
    type    = string
    default = ""
  }

  variable "state" {
    type    = string
    default = ""
  }

  variable "location" {
    type    = string
    default = ""
  }

  variable "org" {
    type    = string
    default = ""
  }


## EKS-Fargate Variables ##
  variable "eks_fargate_cluster_name" {
    type    = string
    default = ""
  }

## AWS_ECS Variables ##
  variable "ecs_app_port" {
    type        = number
    description = "Port exposed by the docker image to redirect traffic to"
    default     = 8080
  }
  variable "ecs_az_count" {
    type        = number
    description = "Number of AZs to cover in a given region"
    default     = "2"
  }
  variable "ecs_health_check_path" {
    type        = string
    description = "Path used by ALB for Health Checks"
    default     = "/"
  }
  variable "ecs_app_image" {
    type        = string
    description = "Docker image to run in the ECS cluster"
    default     = "jaegertracing/example-hotrod"
  }
  variable "ecs_container_name" {
    type        = string
    description = "Name of the container deployed in ECS"
    default     = "hotrod"
  }
  variable "ecs_fargate_cpu" {
    type        = number
    description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
    default     = "1024"
  }
  variable "ecs_fargate_memory" {
    type        = number
    description = "Fargate instance memory to provision (in MiB)"
    default     = "2048"
  }
  variable "ecs_app_count" {
    type        = number
    description = "Number of docker containers to run"
    default     = 3
  }

## Ubuntu AMI ##
  data "aws_ami" "latest-ubuntu" {
    most_recent = true
    owners      = ["099720109477"] # This is the owner id of Canonical who owns the official aws ubuntu images

    filter {
      name = "name"
      # values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
      values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
      # values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }
  }

## MS SQL Server AMI ##
  data "aws_ami" "ms-sql-server" {
    most_recent = true
    owners      = ["801119661308"]

    filter {
      name   = "name"
      values = ["Windows_Server-2022-English-Full-SQL_2022_Standard-*"]
    }

    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }
  }

  ## Windows Server AMI ##
  ## List available amis by runnging the following:
  ## aws ec2 describe-images --owners 801119661308 --filters "Name=platform,Values=windows" "Name=name,Values=*English*"
  data "aws_ami" "windows-server" {
    most_recent = true
    owners      = ["801119661308"]

    filter {
      name   = "name"
      # values = ["Windows_Server-2019-English-Full-ContainersLatest-*"]
      # values = ["Windows_Server-2022-English-Full-*"]
      values = ["Windows_Server-2022-English-Full-Base-*"]
    }

    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }
  }




### Instance Count Variables ###
  variable "gateway_count" {
    type = number
  }

  variable "haproxy_count" {
    type = number
  }

  variable "mysql_count" {
    type = number
  }

  variable "mysql_user" {
    type    = string
    default = ""
  }

  variable "mysql_user_pwd" {
    type    = string
    default = ""
  }

  variable "ms_sql_count" {
    type = number
  }
  variable "ms_sql_user" {
    type    = string
    default = ""
  }

  variable "ms_sql_user_pwd" {
    type    = string
    default = ""
  }

  variable "iis_server_count" {
    type = number
  }

  variable "windows_server_administrator_pwd" {
    type    = string
    default = ""
  }

  variable "apache_web_count" {
    type = number
  }
  variable "splunk_cloud_enabled" {
    type    = bool
    default = false
  }
  variable "splunk_ent_count" {
    type = number
  }
  variable "proxied_apache_web_count" {
    type = number
  }
  variable "proxied_windows_server_count" {
    type = number
  }
  variable "proxy_server_count" {
    type = number
  }

  variable "region" {
    type = string
    description = "Select region (1:eu-west-1, 2:eu-west-3, 3:eu-central-1, 4:us-east-1, 5:us-east-2, 6:us-west-1, 7:us-west-2, 8:ap-southeast-1, 9:ap-southeast-2, 10:sa-east-1 )"
  }

  variable "aws_region" {
    description = "Provide the desired region"
    default = {
      "1"  = "eu-west-1"
      "2"  = "eu-west-3"
      "3"  = "eu-central-1"
      "4"  = "us-east-1"
      "5"  = "us-east-2"
      "6"  = "us-west-1"
      "7"  = "us-west-2"
      "8"  = "ap-southeast-1"
      "9"  = "ap-southeast-2"
      "10" = "sa-east-1"
    }
  }

## List available at https://github.com/signalfx/lambda-layer-versions/blob/master/python/PYTHON.md ##
  variable "region_wrapper_python" {
    default = {
      "1"  = "arn:aws:lambda:eu-west-1:254067382080:layer:signalfx-lambda-python-wrapper:16"
      "2"  = "arn:aws:lambda:eu-west-3:254067382080:layer:signalfx-lambda-python-wrapper:16"
      "3"  = "arn:aws:lambda:ca-central-1:254067382080:layer:signalfx-lambda-python-wrapper:16"
      "4"  = "arn:aws:lambda:us-east-1:254067382080:layer:signalfx-lambda-python-wrapper:17"
      "5"  = "arn:aws:lambda:us-east-2:254067382080:layer:signalfx-lambda-python-wrapper:18"
      "6"  = "arn:aws:lambda:us-west-1:254067382080:layer:signalfx-lambda-python-wrapper:16"
      "7"  = "arn:aws:lambda:us-west-2:254067382080:layer:signalfx-lambda-python-wrapper:16"
      "8"  = "arn:aws:lambda:ap-southeast-1:254067382080:layer:signalfx-lambda-python-wrapper:16"
      "9"  = "arn:aws:lambda:ap-southeast-2:254067382080:layer:signalfx-lambda-python-wrapper:16"
      "10" = "arn:aws:lambda:sa-east-1:254067382080:layer:signalfx-lambda-python-wrapper:16"
    }
  }

  ## List available at https://github.com/signalfx/lambda-layer-versions/blob/master/node/NODE.md ##
  variable "region_wrapper_nodejs" {
    default = {
      "1"  = "arn:aws:lambda:eu-west-1:254067382080:layer:signalfx-lambda-nodejs-wrapper:24"
      "2"  = "arn:aws:lambda:eu-west-3:254067382080:layer:signalfx-lambda-nodejs-wrapper:24"
      "3"  = "arn:aws:lambda:eu-central-1:254067382080:layer:signalfx-lambda-nodejs-wrapper:25"
      "4"  = "arn:aws:lambda:us-east-1:254067382080:layer:signalfx-lambda-nodejs-wrapper:25"
      "5"  = "arn:aws:lambda:us-east-2:254067382080:layer:signalfx-lambda-nodejs-wrapper:25"
      "6"  = "arn:aws:lambda:us-west-1:254067382080:layer:signalfx-lambda-nodejs-wrapper:25"
      "7"  = "arn:aws:lambda:us-west-2:254067382080:layer:signalfx-lambda-nodejs-wrapper:25"
      "8"  = "arn:aws:lambda:ap-southeast-1:254067382080:layer:signalfx-lambda-nodejs-wrapper:24"
      "9"  = "arn:aws:lambda:ap-southeast-2:254067382080:layer:signalfx-lambda-nodejs-wrapper:24"
      "10" = "arn:aws:lambda:sa-east-1:254067382080:layer:signalfx-lambda-nodejs-wrapper:24"
    }
  }


### SOC Variables ###
  variable "soc_integration_id" {
    default = {}
  }
  variable "soc_routing_key" {
    default = {}
  }

### IM/APM Variables ###
  variable "access_token" {
  }
  variable "api_url" {
  }
  variable "realm" {
  }
  variable "notification_email" {
  }
  # variable "smart_agent_version" {
  # }
  variable "environment" {
    default = {}
  }
  variable "otelcol_version" {
    default = {}
  }
  variable "windows_msi_url" {
    default = {}
  }
  variable "windows_proxied_server_agent_url" {
    default = {}
  }
  variable "collector_version" {
    default = {}
  }
  variable "detector_promoting_tags_id" {
    default = {}
  }
  variable "rum_access_token" {
    default = {}
  }


### Splunk Enterprise Variables ###
  variable "splunk_admin_pwd" {
    default = {}
  }
  variable "splunk_ent_filename" {
    default = {}
  }
  variable "splunk_ent_version" {
    default = {}
  }
  variable "splunk_ent_inst_type" {
    default = {}
  }
  variable "universalforwarder_filename" {
    default = {}
  }
  variable "universalforwarder_version" {
    default = {}
  }
  variable "universalforwarder_url_windows" {
    default = {}
  }
  variable "splunk_enterprise_license_filename" {
    default = {}
  }
  variable "add_itsi_splunk_enterprise" {
    type = bool
    default = false
  }



### Splunk ITSI Variables ###
  variable "splunk_itsi_license_filename" {
    default = {}
  }
  variable "splunk_app_for_content_packs_filename" {
    default = {}
  }
  variable "splunk_it_service_intelligence_filename" {
    default = {}
  }
  variable "splunk_infrastructure_monitoring_add_on_filename" {
    default = {}
  }