resource "aws_instance" "proxied_apache_web" {
  count                     = var.proxied_apache_web_count
  ami                       = var.ami
  instance_type             = var.instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  # root_block_device {
  #   volume_size = 16
  #   volume_type = "gp2"
  # }
  # ebs_block_device {
  #   device_name = "/dev/xvdg"
  #   volume_size = 8
  #   volume_type = "gp2"
  # }
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.proxied_instances_sg.id]
  iam_instance_profile      = var.ec2_instance_profile_name

  tags = {
    Name = lower(join("-",[var.environment, "proxied-apache", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  provisioner "remote-exec" {
    inline = [
    ## Set Proxy in Current Session
      "export http_proxy=http://${aws_instance.proxy_server[0].private_ip}:8080",
      "export https_proxy=http://${aws_instance.proxy_server[0].private_ip}:8080",
      "export no_proxy=169.254.169.254",
    
    ## Persist Proxy Settings
      "sudo sed -i '$ a http_proxy=http://${aws_instance.proxy_server[0].private_ip}:8080/' /etc/environment",
      "sudo sed -i '$ a https_proxy=http://${aws_instance.proxy_server[0].private_ip}:8080/' /etc/environment",
      "sudo sed -i '$ a no_proxy=169.254.169.254' /etc/environment",

    ## Set Hostname
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",

    ## Apply Updates
      "sudo apt-get update",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

      # "sudo mkdir /media/data",
      # "sudo echo 'type=83' | sudo sfdisk /dev/xvdg",
      # "sudo mkfs.ext4 /dev/xvdg1",
      # "sudo mount /dev/xvdg1 /media/data",
      # "sudo mkdir /media/data/logs",
      # "sudo mkdir /media/data/logs/otel",

      ## Install AWS CLI
      "curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

      ## Sync Required Files
      "aws s3 cp s3://${var.s3_bucket_name}/scripts/install_apache_web_server.sh /tmp/install_apache_web_server.sh",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/proxied_apache_web_agent_config.yaml /tmp/agent_config.yaml",
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/service-proxy.conf /tmp/service-proxy.conf",
    
      # "aws s3 cp s3://${var.s3_bucket_name}/scripts/xxx /tmp/xxx",
      # "aws s3 cp s3://${var.s3_bucket_name}/config_files/xxx /tmp/xxx",

      "TOKEN=${var.access_token}",
      "REALM=${var.realm}",
      "HOSTNAME=${self.tags.Name}",

    ## Install Apache
      "sudo chmod +x /tmp/install_apache_web_server.sh",
      "sudo /tmp/install_apache_web_server.sh",

    ## Install Otel Agent
      "sudo curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh",
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm}  -- ${var.access_token} --mode agent --collector-version ${var.collector_version} --discovery",
      "sudo mv /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.bak",
      "sudo mv /tmp/agent_config.yaml /etc/otel/collector/agent_config.yaml",
      "sudo chown splunk-otel-collector:splunk-otel-collector agent_config.yaml",
      "sudo chown root:root /tmp/service-proxy.conf",
      "sudo mv /tmp/service-proxy.conf /etc/systemd/system/splunk-otel-collector.service.d/service-proxy.conf",
      "sudo sed -i '$ a Environment=\"HTTP_PROXY=http://${aws_instance.proxy_server[0].private_ip}:8080\"' /etc/systemd/system/splunk-otel-collector.service.d/service-proxy.conf",
      "sudo sed -i '$ a Environment=\"HTTPS_PROXY=http://${aws_instance.proxy_server[0].private_ip}:8080\"' /etc/systemd/system/splunk-otel-collector.service.d/service-proxy.conf",
      "sudo systemctl daemon-reload",
      "sudo systemctl restart splunk-otel-collector",
    ]
  }

  connection {
    host = self.public_ip
    type = "ssh"
    user = "ubuntu"
    private_key = file(var.private_key_path)
    agent = "true"
  }
}

output "proxied_apache_web_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.proxied_apache_web.*.tags.Name,
    aws_instance.proxied_apache_web.*.public_ip,
  )
}