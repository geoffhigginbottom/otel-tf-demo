resource "aws_instance" "gateway" {
  count                     = var.gateway_count
  ami                       = var.ami
  instance_type             = var.gateway_instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]
  iam_instance_profile      = var.ec2_instance_profile_name

  ### needed for Splunk Golden Image to enable SSH
  ### the 'ssh connection' should use the same user
  # user_data = file("${path.module}/scripts/userdata.sh")


  tags = {
    Name = lower(join("-",[var.environment, "gateway", count.index + 1]))
    Environment = lower(var.environment)
    role = "collector"
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
      "aws s3 cp s3://${var.s3_bucket_name}/config_files/gateway_config.yaml /tmp/gateway_config.yaml",

      # "aws s3 cp s3://${var.s3_bucket_name}/scripts/xxx /tmp/xxx",
      # "aws s3 cp s3://${var.s3_bucket_name}/config_files/xxx /tmp/xxx",


    ## Install Otel Agent     
      "sudo curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh",
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm} -- ${var.access_token} --mode gateway --collector-version ${var.collector_version}",
      ## Move gateway_config.yaml to /etc/otel/collector and update permissions,
      "sudo cp /etc/otel/collector/gateway_config.yaml /etc/otel/collector/gateway_config.bak",
      "sudo cp /tmp/gateway_config.yaml /etc/otel/collector/gateway_config.yaml",
      "sudo chown -R splunk-otel-collector:splunk-otel-collector /etc/otel/collector/gateway_config.yaml",
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

output "gateway_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.gateway.*.tags.Name,
    aws_instance.gateway.*.public_ip,
  )
}