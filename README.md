# Splunk Observability Terraform Demo

## Introduction

This is a collection of Terraform Modules which can be used to deploy a test environment into a new AWS VPC.  The purpose is to enable you to deploy some typical AWS resources, and at the same time, deploy Splunk Infrastructure Monitoring and Splunk Application Performance Monitoring, combining "Infrastructure as Code" with "Monitoring as Code". The aim is to provide fully configured working examples to supplement the official Splunk documentation.

## Requirements

To use this repo, you need an active AWS account. Where possible resources that qualify for the free tier are used by default to enable deployment to AWS trial accounts with minimal costs.

You will also need a Splunk Infrastructure Monitoring Account. Some modules leverage the Splunk APM features so ideally you will also have APM enabled on your Splunk environment.

The "Detectors" Module requires a Splunk On-Call account with an active integration to Splunk IM, enabling end to end testing of both "Monitoring" and "Incident Response".

## Setup

After cloning the repo, you need to generate and configure a terraform.tfvars file that will be unique to you and will not be synced back to the repo (if you are contributing to this repo).

Copy the included terraform.tfvars.example file to terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Update the contents of terraform.tfvars replacing any value contained within <> to suit your environment.  Note some values have been pre-populated with typical values, ensure you review every setting and update as appropriate.

Any value can be removed or commented out with a #, by doing so Terraform will prompt you for the appropriate value at run time.

The following describes each section of terraform.tfvars:

### terraform.tfvars

#### Enable / Disable Modules

There are a number of core modules which are always deployed such as VPC and S3, but the modules listed under the 'Enable / Disable Modules' comment can be activated by changing the values from the default of "false" to "true".

You will find more information about each Module at the end of this document.

There are generally no interdependencies between modules, so you can deploy almost any combination, but if enabling Dashboards, you should also enable Detectors.  The 'EKS Cluster', 'ECS Cluster' and 'Phone Shop' modules all have APM enabled and are instrumented to emit Traces.

The quantities of each EC2 Instance deployed as part of the 'Instances & Proxied Instances' Modules are also controlled here. You can deploy any quantity of most types, but you should always deploy at least 1 Gateway (Instances Module), which gets deployed behind an AWS ALB, and is used by the Instances to send in their metrics to the Splunk IM Platform. When using the Proxied Instances Module, again you must always deploy 1 Proxy Server.

```yaml
# This file contains all the settings which are unique to each deployment and it
# should NOT be stored in a public source control system as it contains sensitive information
# If values are commented out and there is no default setting, you will be prompted for them at run time, 
# this way you can choose to store the information in this file, or enter it at run time.

### Enable / Disable Modules
eks_cluster_enabled         = false
ecs_cluster_enabled         = false
instances_enabled           = false
proxied_instances_enabled   = false
itsi_o11y_cp_enabled        = false
phone_shop_enabled          = false
lambda_sqs_dynamodb_enabled = false
dashboards_enabled          = false
detectors_enabled           = false
splunk_cloud_enabled        = false

## Instance Quantities ##

gateway_count = "2" # min 1 : max = subnet_count - there should always be at least one as Target Groups require one
apache_web_count = "1"
haproxy_count = "1"
mysql_count = "1"
ms_sql_count = "1"
iis_server_count = "0"
splunk_ent_count = "0" # If also deploying ITSI ensure the versions are compatible
add_itsi_splunk_enterprise = false # Install ITSI on Splunk Enterprise - Should be FALSE if using Splunk Cloud

## Proxied Instances Quantities ##

proxy_server_count = "1" # only one is required, used as a yes/no parameter
proxied_apache_web_count = "1"
proxied_windows_server_count = "1"

```

#### AWS Variables

This section details the parameters required by AWS such as Region (see below for more info on this), VPC settings, SSH Auth Key, and authentication to your AWS account.

#### Region

When you run the deployment terraform will prompt you for a Region, however if you enable the setting here, and populate it with a numerical value representing your preferred AWS Region, it will save you having to enter a value on each run. The settings for this are controlled via variables.tf, but the valid options are:

- 1: eu-west-1
- 2: eu-west-3
- 3: eu-central-1
- 4: us-east-1
- 5: us-east-2
- 6: us-west-1
- 7: us-west-2
- 8: ap-southeast-1
- 9: ap-southeast-2
- 10: sa-east-1

```yaml
## Region Settings ##
#region = "<REGION>"
```

#### VPC Settings

A new VPC is created and is used by all the modules with the exception of the ECS Cluster Module which creates its own VPC.  The number of subnets is controlled by the 'subnet_count' parameter, and defaults to 2 which should be sufficient for most test cases.

Two sets of subnets will be created, a Private and a Public Subnet, so by default 4 subnets will be created. Each Subnet will be created using a CIDR allocated from the 'vpc_cidr_block', so by default the 1st subnet will use 172.32.0.0/24, the 2nd subnet will use 172.32.1.0/24 etc.

Note: The ECS Cluster Module will create its own unique VPC and Subnets and creates a Fargate deployment.  At present all the variables controlling this are contained within the ECS Cluster modules variables.tf file (modules/aws_ecs/variables.tf).

```yaml
## VPC Settings ##
vpc_cidr_block        = "172.32.0.0/16"
subnet_count          = "2" 
```

#### Auth Settings

Terraform needs to authenticate with AWS in order to create the resources and also access each instance using a Key Pair.  Create a user such as "Terraform" within AWS and attach "AdministratorAccess" policy.  Add the access_key details to enable your local terraform to authenticate using this account.  Ensure there is a Key Pair created in each region you intend to use so that terraform can login to each ec2 instance to run commands.

```yaml
## Auth Settings ##
key_name              = "<NAME>"
private_key_path      = "~/.ssh/id_rsa"
aws_access_key_id     = "<ACCCESS_KEY_ID>>"
aws_secret_access_key = "<SECRET_ACCESS_KEY>>"
```

#### Misc Instance Types

Most instances will use the following default flavours unless their configuration specifically overrides these.

```yaml
## Misc Instance Types ##
instance_type           = "t2.large"
gateway_instance_type   = "t2.small"
```

#### S3

S3 is used to store a number of files that are used by the instances, so create an S3 bucket and then enter its name here.

```yaml
## S3 ##
s3_bucket_name          = "<BUCKET_NAME>"
```

There are three folders that get synchronized into this bucket at run time (there is no need to manually create these in the bucket):

- config_files
- scripts
- non_public_files

The contents of config_files and scripts are included in the repo, but the non_public_files folder will need to be created in the root of your local repo and populated before your 1st run of terraform.  The non_public_files folder stores files that are not publicly available so you will need to download these from splunkbase / sharepoint and place them in the non_public_files folder.  This folder does not get stored in github.

The following files need to be added from Spunk Base (these will need updating on a regular basis):

- [Splunk Infrastructure Monitoring Add-on](https://splunkbase.splunk.com/app/5247)
- [Splunk IT Service Intelligence](https://splunkbase.splunk.com/app/1841)
- [Splunk Add-On for OpenTelemetry Collector](https://splunkbase.splunk.com/app/7125)
- [Splunk Add-on for Unix and Linux](https://splunkbase.splunk.com/app/833)
- [Splunk App for Content Packs](https://splunkbase.splunk.com/app/5391)

The following License Files need to be added (update based on current date window):

- Splunk_Enterprise_NFR_1H_2025.xml
- Splunk_ITSI_NFR_1H_2025.xml

A SplunkCloud Universal Forwarder Auth File will be needed when deploying instances with the optional Splunk Cloud Integration enabled.

- splunkclouduf.spl

#### SOC Variables

Settings used by the Splunk On-Call Integration within Splunk IM/APM to create Incidents from the Alerts generated by Splunk IM/APM.

```yaml
### SOC Variables ###
soc_integration_id  = "<ID>"
soc_routing_key     = "<ROUTING_KEY>"
```

#### Splunk IM/APM Variables

Settings used by Splunk IM/APM for authentication, notifications and APM Environment.  An example of an Environment value would be "tf-demo", it's a simple tag used to identify and link the various components within the Splunk APM UI. Collector Versions can be found [here](https://github.com/signalfx/splunk-otel-collector/releases).

```yaml
### Splunk IM/APM Variables ###
access_token             = "<ACCESS_TOKEN>"
api_url                  = "https://api.<REALM>.signalfx.com"
realm                    = "<REALM>"
environment              = "<ENVIRONMENT>"
notification_email       = "<EMAIL>"
collector_version        = "nn.nnn.nn"
```

#### Splunk Enterprise Variables

The instances module can also deploy a Splunk Enterprise VM, and if it is deployed, then instances automatically deploy a Universal Forwarder as well.  Note that Splunk Enterprise should not be deployed if splunk_cloud_enabled is set to true as they will conflict.  You will need to update the versions of Splunk Enterprise and Universal Forwarder install files based on the version you wish to deploy.  

Note that if also deploying ITSI, ensure the Splunk Enterprise Version is compatible as ITSI often lags the latest Splunk Enterprise release.

The "splunk_ent_eip" value should be for an EIP in the region that you are using, and this in turn should be mapped to the "fqdn" value within the "certificates" section below.  This will be used to generate certificates on the Splunk Enterprise Server to enable Log Observer Connect to be used and configured with a FQDN.

The "splunk_private_ip" is set here to enable the auto deployment of Universal Forwarders, if changed it needs to be from the "vpc_cidr_block" setting above.

The "splunk_enterprise_license_filename" and all the ITSI files should be added to the non_public_files folder which gets synced with S3.

```yaml
### Splunk Enterprise Variables ###
splunk_admin_pwd                    = "<STRONG_PASSWORD>"
splunk_ent_filename                 = "splunk-9.3.3-75595d8f83ef-linux-2.6-amd64.deb"
splunk_ent_version                  = "9.3.3"
splunk_ent_inst_type                = "t2.2xlarge"
universalforwarder_filename         = "splunkforwarder-9.3.3-75595d8f83ef-linux-2.6-amd64.deb"
universalforwarder_version          = "9.3.3"
universalforwarder_url_windows      = "https://download.splunk.com/products/universalforwarder/releases/9.3.3/windows/splunkforwarder-9.3.3-75595d8f83ef-x64-release.msi"
splunk_enterprise_license_filename  = "Splunk_Enterprise_NFR_1H_2025.xml"
splunk_ent_eip                      = "<EIP>" # ensure this aligns with region setting above
splunk_private_ip                   = "172.32.2.10" # ensure this aligns with vpc_cidr_block setting above

### Certificate Vars ###
certpath    = "/opt/splunk/etc/auth/sloccerts"
passphrase  = "qwertyuiop"
fqdn        = "<FQDN>"
country     = "GB"
state       = "London"
location    = "London"
org         = "ACME"

### Splunk ITSI Variables ###
splunk_itsi_license_filename                     = "Splunk_ITSI_NFR_1H_2025.xml"
splunk_app_for_content_packs_filename            = "splunk-app-for-content-packs_190.spl" 
splunk_it_service_intelligence_filename          = "itsi-4.20.0-62084.spl"
splunk_infrastructure_monitoring_add_on_filename = "signed_5247_36428_1738861405.tar"
```

#### Windows SQL Servers Variables

The Microsoft SQL Server Instance requires Windows and SQL Admin Passwords to be set

```yaml
### MS SQL Server Variables ###
ms_sql_user                   = "signalfxagent"
ms_sql_user_pwd               = "<STRONG_PWD>"
ms_sql_instance_type          = "t3.xlarge"
```

#### Windows Servers Variables

The Microsoft Windows Server Instance requires Windows Admin Password to be set

```yaml
### Windows Server Variables ###
windows_server_administrator_pwd  = "<STRONG_PWD>"
windows_server_instance_type      = "t3.xlarge"
```

#### MySQL Server Variables

The MySQL Server Instance requires SQL User Password to be set

```yaml
### MySQL Server Variables ###
mysql_user             = "signalfxagent"
mysql_user_pwd         = "<STRONG_PWD>"
```

## Modules

Details about each module can be found below

### Instances

This module deploys some example EC2 Instances, with Splunk IM Monitors matching their role, as well as Otel Collectors. Each instance is deployed with an otel collector running in agent mode to enable Infrastructure Monitoring and is configured to send all metrics via the cluster of Otel Collectors, fronted by an AWS Load Balancer.

The following EC2 Instances can be deployed:

- Gateways
- HAProxy
- MySQL
- Microsoft SQL Server
- Microsoft Windows Server
- Apache
- Splunk Enterprise

Each Instance has Infrastructure Monitoring 'receivers' configured to match the services running on them.  The configuration for each monitor is deployed via its own specific agent_config.yaml file.

### Proxied Instances

This module deploys some sample instances which are deployed with no internet access, and are forced to use an inline-proxy for sending their metrics back to the splunk endpoints.  This introduces a number of challenges which are addressed in this module.

### Phone Shop

This is based on the Lambda components of the [Splunk Observability Workshop](https://signalfx.github.io/observability-workshop/latest/), but unlike the workshop version, is fully configured for APM.  As well as deploying the Lambda Functions fully instrumented, and their required API Gateways, the EC2 Instance 'vm_phone_shop' is configured to automatically generate random load to ensure APM Traces are generated within a couple of minutes of deployment.

### Lambda SQS DynamoDB

This module deploys a Lambda function which is triggered by an SQS queue, storing the messages from the queue into a DynamoDB table.  An EC2 Instance 'vm_sqs_test_server' is deployed and this instance contains a helper script called 'generate_send_messages' which is deployed into the ubuntu users home folder.  When run, this script places random messages into SQS, triggering the Lambda function which then removes the messages placing them into the DynamoDB table.  This enables testing of SQS triggered Lambda functions when using APM.

### Dashboards

This module creates a new Dashboard Group with an example Dashboard generated by Terraform.  The aim of this module is to simply demonstrate the methods for creating new Dashboard Groups, Charts and Dashboards, using "Monitoring as Code", in parallel with your "Infrastructure as Code" via Terraform.

### Detectors

This module creates a couple of new Detectors as basic examples of creating detectors and leveraging the integration with Splunk On-Call.  A more comprehensive list of example detectors which can be deployed using Terraform can be found [here](https://github.com/signalfx/signalfx-jumpstart).
