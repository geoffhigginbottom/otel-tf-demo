resource "random_string" "lo_connect_password" {
  length           = 12
  special          = false
  # override_special = "@£$"
}

## Prevent deployment of both Splunk Ent and Splunk Cloud
resource "null_resource" "validate_scenario" {
  count = var.splunk_cloud_enabled && var.splunk_ent_count == "1" ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'Invalid configuration: splunk_cloud_enabled cannot be true when splunk_ent_count is 1.' && exit 1"
  }
}

resource "aws_instance" "splunk_ent" {
  count                     = var.splunk_ent_count
  ami                       = var.ami
  instance_type             = var.splunk_ent_inst_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
    root_block_device {
    volume_size = 32
    volume_type = "gp2"
  }
  private_ip                = var.splunk_private_ip
  key_name                  = var.key_name
  vpc_security_group_ids    = [
    aws_security_group.instances_sg.id,
    aws_security_group.splunk_ent_sg.id,
  ]
  iam_instance_profile      = var.ec2_instance_profile_name
  
  tags = {
    Name = lower(join("-",[var.environment, "splunk-enterprise", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "remote-exec" {
    inline = [
    ## Set Hostname and update
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
    
    ## Install AWS CLI
      "curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

    ## Sync Non Public Files from S3
      # "aws s3 cp s3://${var.s3_bucket_name}/scripts/xxx /tmp/xxx",
      # "aws s3 cp s3://${var.s3_bucket_name}/config_files/xxx /tmp/xxx",
      # "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${} /tmp/${}",

      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_splunk_enterprise.sh /tmp/install_splunk_enterprise.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/certs.sh /tmp/certs.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_splunk_otel_collector.sh /tmp/update_splunk_otel_collector.sh",

      "aws s3 cp s3://${var.s3_bucket_name}/config_files/splunkent_agent_config.yaml /tmp/agent_config.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/inputs.conf /tmp/inputs.conf",

      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_enterprise_license_filename} /tmp/${var.splunk_enterprise_license_filename}",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_itsi_license_filename} /tmp/${var.splunk_itsi_license_filename}",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_app_for_content_packs_filename} /tmp/${var.splunk_app_for_content_packs_filename}",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_it_service_intelligence_filename} /tmp/${var.splunk_it_service_intelligence_filename}",
      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/${var.splunk_infrastructure_monitoring_add_on_filename} /tmp/${var.splunk_infrastructure_monitoring_add_on_filename}",

    ## Create Splunk Ent Vars
      "TOKEN=${var.access_token}",
      "REALM=${var.realm}",
      "HOSTNAME=${self.tags.Name}",
      "LBURL=${aws_lb.gateway-lb.dns_name}",
      "SPLUNK_PASSWORD=${var.splunk_admin_pwd}",
      "LO_CONNECT_PASSWORD=${random_string.lo_connect_password.result}",
      "SPLUNK_ENT_VERSION=${var.splunk_ent_version}",
      "SPLUNK_FILENAME=${var.splunk_ent_filename}",
      "SPLUNK_ENTERPRISE_LICENSE_FILE=${var.splunk_enterprise_license_filename}",
      "ADD_ITSI=${var.add_itsi_splunk_enterprise}",

    ## Write env vars to file (used for debugging)
      "echo $SPLUNK_PASSWORD > /tmp/splunk_password",
      "echo $LO_CONNECT_PASSWORD > /tmp/lo_connect_password",
      "echo $SPLUNK_ENT_VERSION > /tmp/splunk_ent_version",
      "echo $SPLUNK_FILENAME > /tmp/splunk_filename",
      "echo $SPLUNK_ENTERPRISE_LICENSE_FILE > /tmp/splunk_enterprise_license_filename",
      "echo $LBURL > /tmp/lburl",
      "echo $ADD_ITSI > /tmp/add_itsi",

    ## Install Splunk
      "sudo chmod +x /tmp/install_splunk_enterprise.sh",
      "sudo /tmp/install_splunk_enterprise.sh $SPLUNK_PASSWORD $SPLUNK_ENT_VERSION $SPLUNK_FILENAME $LO_CONNECT_PASSWORD",

    ## install NFR license
      "sudo mkdir /opt/splunk/etc/licenses/enterprise",
      "sudo cp /tmp/${var.splunk_enterprise_license_filename} /opt/splunk/etc/licenses/enterprise/${var.splunk_enterprise_license_filename}.lic",
      "sudo /opt/splunk/bin/splunk restart",

    ## Create Certs
     # Create FQDN Ent Vars
      "CERTPATH=${var.certpath}",
      "PASSPHRASE=${var.passphrase}",
      "FQDN=${var.fqdn}",
      "COUNTRY=${var.country}",
      "STATE=${var.state}",
      "LOCATION=${var.location}",
      "ORG=${var.org}",
     # Run Script
      "sudo chmod +x /tmp/certs.sh",
      "sudo /tmp/certs.sh $CERTPATH $PASSPHRASE $FQDN $COUNTRY $STATE $LOCATION $ORG",
     # Create copy in /tmp for easy access for setting up Log Observer Conect
      "sudo cp /opt/splunk/etc/auth/sloccerts/mySplunkWebCert.pem /tmp/mySplunkWebCert.pem",
      "sudo chown ubuntu:ubuntu /tmp/mySplunkWebCert.pem",

    ## Install ITSI, but only if add_itsi_splunk_enterprise = true
      <<EOT
      if [ ${var.add_itsi_splunk_enterprise} = true ]; then
        ## Create Splunk Ent Vars
        SPLUNK_ITSI_LICENSE_FILE=${var.splunk_itsi_license_filename}
        SPLUNK_IT_SERVICE_INTELLIGENCE_FILENAME=${var.splunk_it_service_intelligence_filename}
        SPLUNK_INFRASTRUCTURE_MONITORING_ADD_ON_FILENAME=${var.splunk_infrastructure_monitoring_add_on_filename}
        SPLUNK_APP_FOR_CONTENT_PACKS_FILENAME=${var.splunk_app_for_content_packs_filename}

        ## Write env vars to file (used for debugging)
        echo $SPLUNK_ITSI_LICENSE_FILE > /tmp/splunk_itsi_license_file
        echo $SPLUNK_IT_SERVICE_INTELLIGENCE_FILENAME > /tmp/splunk_it_service_intelligence_filename
        echo $SPLUNK_INFRASTRUCTURE_MONITORING_ADD_ON_FILENAME >/tmp/splunk_infrastructure_monitoring_add_on_filemane
        echo $SPLUNK_APP_FOR_CONTENT_PACKS_FILENAME > /tmp/splunk_app_for_content_packs_filename

        ## install ITSI NFR license
        # sudo mkdir /opt/splunk/etc/licenses/enterprise
        sudo cp /tmp/${var.splunk_itsi_license_filename} /opt/splunk/etc/licenses/enterprise/${var.splunk_itsi_license_filename}.lic
        sudo /opt/splunk/bin/splunk restart
    
        ## install java
        sudo apt install -y default-jre
        JAVA_HOME=$(realpath /usr/bin/java)

        ## stop splunk
        sudo /opt/splunk/bin/splunk stop

        ## install apps
        wget -O /tmp/$FILENAME "https://download.splunk.com/products/splunk/releases/$VERSION/linux/$FILENAME"
        sudo tar -xvf /tmp/$SPLUNK_IT_SERVICE_INTELLIGENCE_FILENAME -C /opt/splunk/etc/apps
        sudo tar -xvf /tmp/$SPLUNK_INFRASTRUCTURE_MONITORING_ADD_ON_FILENAME -C /opt/splunk/etc/apps
        sudo tar -xvf /tmp/$SPLUNK_APP_FOR_CONTENT_PACKS_FILENAME -C /opt/splunk/etc/apps

        ## start splunk
        sudo /opt/splunk/bin/splunk start

        ## ensure inputs.conf reflects in the UI
        sudo chmod 755 -R /opt/splunk/etc/apps/itsi/local

        ## Add Modular Input
        sudo cp /opt/splunk/etc/apps/itsi/local/inputs.conf /opt/splunk/etc/apps/itsi/local/inputs.bak
        sudo cat /tmp/inputs.conf | sudo tee -a /opt/splunk/etc/apps/itsi/local/inputs.conf

        ## ensure rights are given for the content pack
        sudo chown splunk:splunk -R /opt/splunk/etc/apps

        ## restart splunk
        sudo /opt/splunk/bin/splunk restart

      else
        echo "Skipping as add_itsi_splunk_enterprise is false"
      fi
      EOT
      ,

    ## Install Otel Agent
      "sudo curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh",
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm}  -- ${var.access_token} --mode agent",
      "sudo chmod +x /tmp/update_splunk_otel_collector.sh",
      "sudo /tmp/update_splunk_otel_collector.sh $LBURL",
      "sudo mv /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.bak",
      "sudo mv /tmp/agent_config.yaml /etc/otel/collector/agent_config.yaml",
      "sudo chown splunk-otel-collector:splunk-otel-collector agent_config.yaml",
      "sudo systemctl restart splunk-otel-collector",
    ]
  }

  connection {
    host = self.public_ip
    port = 22
    type = "ssh"
    user = "ubuntu"
    private_key = file(var.private_key_path)
    agent = "true"
  }
}

output "lo_connect_password" {
  value = random_string.lo_connect_password.result
}

output "splunk_password" {
  value = var.splunk_admin_pwd
}

output "splunk_enterprise_private_ip" {
    value =  formatlist(
    "%s, %s",
    aws_instance.splunk_ent.*.tags.Name,
    aws_instance.splunk_ent.*.private_ip,
  )
}