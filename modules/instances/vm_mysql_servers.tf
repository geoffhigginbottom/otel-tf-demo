resource "aws_instance" "mysql" {
  count                     = var.mysql_count
  ami                       = var.ami
  instance_type             = var.mysql_instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]
  iam_instance_profile      = var.ec2_instance_profile_name

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
    delete_on_termination = true

    tags = {
      Name                          = lower(join("-", [var.environment, "mysql", count.index + 1, "root"]))
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }
  
  tags = {
    Name = lower(join("-",[var.environment, "mysql", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "private"
  }

  provisioner "remote-exec" {
    inline = [
      ## Set Hostname
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "echo '${var.splunk_private_ip} ${var.fqdn}' | sudo tee -a /etc/hosts > /dev/null",
      
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

      ## Install AWS CLI
      "curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

      ## Sync Required Files
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_splunk_otel_collector_mysql.sh /tmp/update_splunk_otel_collector.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_mysql.sh /tmp/install_mysql.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/mysql_loadgen.py /home/ubuntu/mysql_loadgen.py",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_mysql_loadgen_py.sh /home/ubuntu/update_mysql_loadgen_py.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/mysql_loadgen_start.sh /home/ubuntu/mysql_loadgen_start.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/mysql_loadgen_stop.sh /home/ubuntu/mysql_loadgen_stop.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_splunk_universal_forwarder_mysql.sh /tmp/install_splunk_universal_forwarder.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_splunk_universal_forwarder_mysql_splunk_cloud.sh /tmp/install_splunk_universal_forwarder_splunk_cloud.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_splunk_hec_metrics.sh /tmp/update_splunk_hec_metrics.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/update_splunk_otel_logs.sh /tmp/update_splunk_otel_logs.sh",

      "aws s3 cp s3://${var.s3_bucket_name}/config_files/mysqld.cnf /tmp/mysqld.cnf",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/mysql_loadgen.service /tmp/mysql_loadgen.service",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/mysql_agent_config.yaml /tmp/agent_config.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/mysql_agent_logs_config.yaml /tmp/agent_logs_config.yaml",

      "aws s3 cp s3://${var.s3_bucket_name}/non_public_files/splunkclouduf.spl /tmp/splunkclouduf.spl",

      # "aws s3 cp s3://${var.s3_bucket_name}/scripts/xxx /tmp/xxx",
      # "aws s3 cp s3://${var.s3_bucket_name}/config_files/xxx /tmp/xxx",

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
    
      # Setup MySQL Loadgen
      # "sudo apt-get -y install python3-pip python3-venv",
      # "python3 -m venv /home/ubuntu/venv",
      # "source /home/ubuntu/venv/bin/activate",
      # "pip install --upgrade pip",
      # "pip install mysql-connector mysql-connector-python[cext]",
      # "deactivate",


      "sudo apt-get -y install python3-pip python3-venv",
      "python3 -m venv /home/ubuntu/venv",
      "/home/ubuntu/venv/bin/pip install --upgrade pip",
      "/home/ubuntu/venv/bin/pip install mysql-connector mysql-connector-python[cext]",


      "mysql -u root -p'root' -e \"CREATE DATABASE loadgen;\"",
      "mysql -u root -p'root' -e \"USE loadgen; CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) NOT NULL, email VARCHAR(100) NOT NULL);\"", # mysql -u root -p'root' -e "USE loadgen; CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) NOT NULL, email VARCHAR(100) NOT NULL);"
      "mysql -u root -p'root' -e \"USE loadgen; INSERT INTO users (username, email) VALUES ('user1', 'user1@example.com'), ('user2', 'user2@example.com');\"", # mysql -u root -p'root' -e "USE loadgen; INSERT INTO users (username, email) VALUES ('user1', 'user1@example.com'), ('user2', 'user2@example.com');"
      "mysql -u root -p'root' -e \"USE loadgen; GRANT INSERT, SELECT, CREATE, UPDATE, DELETE ON users TO '${var.mysql_user}'@'localhost';\"", # mysql -u root -p'root' -e "USE loadgen; GRANT INSERT, SELECT, CREATE, UPDATE, DELETE ON users TO 'signalfxagent'@'localhost';"

      "sudo chmod +x /home/ubuntu/mysql_loadgen.py",
      "sudo chmod +x /home/ubuntu/update_mysql_loadgen_py.sh",
      "sudo /home/ubuntu/update_mysql_loadgen_py.sh ${var.mysql_user} ${var.mysql_user_pwd}",
      "sudo chmod +x /home/ubuntu/mysql_loadgen_start.sh",
      "sudo chmod +x /home/ubuntu/mysql_loadgen_stop.sh",
      "sudo mv /tmp/mysql_loadgen.service /etc/systemd/system/mysql_loadgen.service",
      "sudo chmod +x /etc/systemd/system/mysql_loadgen.service",

      # Update MySql Logging 
      "sudo cp /tmp/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
      "sudo systemctl restart mysql",

    ## Install Otel Agent
      "sudo curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh",
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm}  -- ${var.access_token} --mode agent --collector-version ${var.collector_version} --discovery",

      "sudo mv /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.bak",
      # "sudo mv /tmp/agent_config.yaml /etc/otel/collector/agent_config.yaml",
      "sudo mv /tmp/${var.otel_logs_enabled ? "agent_logs_config.yaml" : "agent_config.yaml"} /etc/otel/collector/agent_config.yaml", # Conditional to use different config if otel_logs_enabled is true or false
      "sudo chown splunk-otel-collector:splunk-otel-collector /etc/otel/collector/agent_config.yaml",
      "sudo chmod +x /tmp/update_splunk_otel_collector.sh",
      "sudo /tmp/update_splunk_otel_collector.sh $LBURL $MYSQLUSER $MYSQLPWD",

    ## If splunk_ent_count = 0 then set a default value to prevent terraform errors
      # "SPLUNK_IP=${length(aws_instance.splunk_ent) > 0 ? aws_instance.splunk_ent[0].private_ip : "127.0.0.1"}",

   ## Deploy UF for Splunk Ent, but only if splunk_ent_count = 1 AND otel_logs_enabled is false
    <<EOT
    if [ ${var.splunk_ent_count} -eq 1 ] && [ "${var.otel_logs_enabled}" = "false" ]; then
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
      echo "Skipping: splunk_ent_count is ${var.splunk_ent_count} or otel_logs_enabled is ${var.otel_logs_enabled}"
    fi
    EOT
    ,

    ## Deloy UF for Splunk Cloud, but only if splunk_cloud_enabled = true AND otel_logs_enabled is false 
      <<EOT
      if [ ${var.splunk_cloud_enabled} = "true" ] && [ "${var.otel_logs_enabled}" = "false" ]; then
        sudo chmod +x /tmp/install_splunk_universal_forwarder_splunk_cloud.sh
        UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}
        UNIVERSAL_FORWARDER_VERSION=${var.universalforwarder_version}
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
          
      ## Enable Metrics to Splunk, but only if splunk_hec_metrics_enabled = true
      "HEC_TOKEN=\"${local.hec_metrics_token}\"",
      <<EOT
      if [ "${var.splunk_hec_metrics_enabled}" = "true" ]; then
        sudo chmod +x /tmp/update_splunk_hec_metrics.sh
        SPLUNK_IP=${var.splunk_private_ip}
        sudo /tmp/update_splunk_hec_metrics.sh $SPLUNK_IP $HEC_TOKEN
      else
        echo "Skipping as splunk_hec_metrics_enabled is false"
      fi
      EOT
      ,

      ## Enable OTel Logs Collection, but only if otel_logs_enabled = true
      <<EOT
      if [ "${var.otel_logs_enabled}" = "true" ]; then
        sudo chmod +x /tmp/update_splunk_otel_logs.sh
        sudo /tmp/update_splunk_otel_logs.sh ${var.fqdn} ${local.hec_otel_token}
      else
        echo "Skipping as otel_logs_enabled is false"
      fi
      EOT
      ,

    ## Run MySQL Loadgen Script
      "sudo systemctl daemon-reload",
      "sudo systemctl restart mysql_loadgen",

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