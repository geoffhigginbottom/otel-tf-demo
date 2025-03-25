resource "aws_instance" "mysql" {
  count                     = var.mysql_count
  ami                       = var.ami
  instance_type             = var.mysql_instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]
  iam_instance_profile      = var.ec2_instance_profile_name

  tags = {
    Name = lower(join("-",[var.environment, "mysql", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "remote-exec" {
    inline = [
      ## Set Hostname
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

      ## Install AWS CLI
      "curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

      ## Sync Required Files
      "aws s3 cp s3://eu-west-3-tfdemo-files/scripts/update_splunk_otel_collector_mysql.sh /tmp/update_splunk_otel_collector.sh",
      "aws s3 cp s3://eu-west-3-tfdemo-files/scripts/install_mysql.sh /tmp/install_mysql.sh",
      "aws s3 cp s3://eu-west-3-tfdemo-files/scripts/install_splunk_universal_forwarder_mysql.sh /tmp/install_splunk_universal_forwarder.sh",
      "aws s3 cp s3://eu-west-3-tfdemo-files/scripts/install_splunk_universal_forwarder_mysql_splunk_cloud.sh /tmp/install_splunk_universal_forwarder_splunk_cloud.sh",
      
      "aws s3 cp s3://eu-west-3-tfdemo-files/config_files/mysql_agent_config.yaml /tmp/agent_config.yaml",
      
      "aws s3 cp s3://eu-west-3-tfdemo-files/non_public_files/splunkclouduf.spl /tmp/splunkclouduf.spl",

      # "aws s3 cp s3://eu-west-3-tfdemo-files/scripts/xxx /tmp/xxx",
      # "aws s3 cp s3://eu-west-3-tfdemo-files/config_files/xxx /tmp/xxx",

      "TOKEN=${var.access_token}",
      "REALM=${var.realm}",
      "HOSTNAME=${self.tags.Name}",
      "LBURL=${aws_lb.gateway-lb.dns_name}",
      "MYSQLUSER=${var.mysql_user}",
      "MYSQLPWD=${var.mysql_user_pwd}",

    ## Install MySQL
      "sudo chmod +x /tmp/install_mysql.sh",
      "sudo /tmp/install_mysql.sh",
      "sudo mysql -u root -p'root' -e \"CREATE USER '${var.mysql_user}'@'localhost' IDENTIFIED BY '${var.mysql_user_pwd}';\"",
      "sudo mysql -u root -p'root' -e \"GRANT USAGE ON *.* TO '${var.mysql_user}'@'localhost';\"",
      "sudo mysql -u root -p'root' -e \"GRANT SELECT ON *.* TO '${var.mysql_user}'@'localhost';\"",
      "sudo mysql -u root -p'root' -e \"GRANT REPLICATION CLIENT ON *.* TO '${var.mysql_user}'@'localhost';\"",
    
    # Install Otel Agent
      "sudo curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh",
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm}  -- ${var.access_token} --mode agent --collector-version ${var.collector_version} --discovery",

      "sudo mv /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.bak",
      "sudo mv /tmp/agent_config.yaml /etc/otel/collector/agent_config.yaml",
      "sudo chown splunk-otel-collector:splunk-otel-collector agent_config.yaml",
      "sudo chmod +x /tmp/update_splunk_otel_collector.sh",
      "sudo /tmp/update_splunk_otel_collector.sh $LBURL $MYSQLUSER $MYSQLPWD",

    ## If splunk_ent_count = 0 then set a default value to prevent terraform errors
      # "SPLUNK_IP=${length(aws_instance.splunk_ent) > 0 ? aws_instance.splunk_ent[0].private_ip : "127.0.0.1"}",

    ## Deloy UF for Splunk Ent, but only if splunk_ent_count = 1
      <<EOT
      if [ ${var.splunk_ent_count} -eq 1 ]; then
        sudo chmod +x /tmp/install_splunk_universal_forwarder.sh
        UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}
        UNIVERSAL_FORWARDER_VERSION=${var.universalforwarder_version}
        PASSWORD=${var.splunk_admin_pwd}
        SPLUNK_IP=${var.splunk_private_ip}
        PRIVATE_DNS=${self.private_dns}
        /tmp/install_splunk_universal_forwarder.sh $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_VERSION $PASSWORD $SPLUNK_IP $PRIVATE_DNS

        ## Write env vars to file (used for debugging)
        echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME
        echo $UNIVERSAL_FORWARDER_VERSION > /tmp/UNIVERSAL_FORWARDER_VERSION
        echo $PASSWORD > /tmp/UNIVERSAL_FORWARDER_PASSWORD
        echo $SPLUNK_IP > /tmp/SPLUNK_IP
        echo $PRIVATE_DNS > /tmp/PRIVATE_DNS
      else
        echo "Skipping as splunk_ent_count is 0"
      fi
      EOT
      ,

    ## Deloy UF for Splunk Cloud, but only if splunk_cloud_enabled = true
      <<EOT
      if [ "${var.splunk_cloud_enabled}" = "true" ]; then
        sudo chmod +x /tmp/install_splunk_universal_forwarder_splunk_cloud.sh
        UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}
        UNIVERSAL_FORWARDER_VERSION=${var.universalforwarder_version},
        PASSWORD=${var.splunk_admin_pwd}
        PRIVATE_DNS=${self.private_dns}
        /tmp/install_splunk_universal_forwarder_splunk_cloud.sh $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_VERSION $PASSWORD $PRIVATE_DNS

        ## Write env vars to file (used for debugging)
        echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME
        echo $UNIVERSAL_FORWARDER_VERSION > /tmp/UNIVERSAL_FORWARDER_VERSION
        echo $PASSWORD > /tmp/UNIVERSAL_FORWARDER_PASSWORD
        echo $PRIVATE_DNS > /tmp/PRIVATE_DNS
      else
        echo "Skipping as splunk_cloud_enabled is false"
      fi
      EOT
      ,
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

output "mysql_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.mysql.*.tags.Name,
    aws_instance.mysql.*.public_ip,
  )
}