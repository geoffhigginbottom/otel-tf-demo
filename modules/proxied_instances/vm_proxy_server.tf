resource "aws_instance" "proxy_server" {
  count                     = var.proxy_server_count
  ami                       = var.ami
  instance_type             = var.instance_type
  # subnet_id                 = element(var.public_subnet_ids, count.index)
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.proxy_server.id]
  iam_instance_profile      = var.ec2_instance_profile_name

  tags = {
    Name = lower(join("-",[var.environment, "proxy-server", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "private"
  }

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
    delete_on_termination = true

    tags = {
      Name                          = lower(join("-", [var.environment, "proxy-server", count.index + 1, "root"]))
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }
 
  # provisioner "file" {
  #   source      = "${path.module}/config_files/squid.conf"
  #   destination = "/tmp/squid.conf"
  # }

  provisioner "remote-exec" {
    inline = [
    ## Set Hostname
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",

    ## Apply Updates
      "sudo apt-get update",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

    ## Install AWS CLI
      "curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

    ## Sync Required Files
    "aws s3 cp s3://${var.s3_bucket_name}/config_files/squid.conf /tmp/squid.conf",

    ## Install Proxy Server
      "sudo apt-get install squid -y",
      "sudo mv /etc/squid/squid.conf /etc/squid/squid.bak",
      "sudo mv /tmp/squid.conf /etc/squid/squid.conf",
      "sudo systemctl restart squid",

    ## Install Otel Agent
      "sudo curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh",
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm}  -- ${var.access_token} --mode agent --collector-version ${var.collector_version} --discovery",
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

output "proxy_server_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.proxy_server.*.tags.Name,
    aws_instance.proxy_server.*.public_ip,
    aws_instance.proxy_server.*.private_ip,
  )
}