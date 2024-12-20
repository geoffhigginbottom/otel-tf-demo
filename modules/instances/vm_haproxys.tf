resource "aws_instance" "haproxy" {
  count                     = var.haproxy_count
  ami                       = var.ami
  instance_type             = var.instance_type
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  root_block_device {
    volume_size = 16
    volume_type = "gp2"
  }
  ebs_block_device {
    device_name = "/dev/xvdg"
    volume_size = 10
    volume_type = "gp2"
  }
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]

  tags = {
    Name = lower(join("-",[var.environment, "haproxy", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
 
  provisioner "file" {
    source      = "${path.module}/scripts/install_haproxy.sh"
    destination = "/tmp/install_haproxy.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/update_splunk_otel_collector.sh"
    destination = "/tmp/update_splunk_otel_collector.sh"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/haproxy_agent_config.yaml"
    destination = "/tmp/agent_config.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_splunk_universal_forwarder_haproxy.sh"
    destination = "/tmp/install_splunk_universal_forwarder.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_splunk_universal_forwarder_haproxy_splunk_cloud.sh"
    destination = "/tmp/install_splunk_universal_forwarder_splunk_cloud.sh"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/splunkclouduf.spl"
    destination = "/tmp/splunkclouduf.spl"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

      "sudo mkdir /media/data",
      "sudo echo 'type=83' | sudo sfdisk /dev/xvdg",
      "sudo mkfs.ext4 /dev/xvdg1",
      "sudo mount /dev/xvdg1 /media/data",

      "TOKEN=${var.access_token}",
      "REALM=${var.realm}",
      "HOSTNAME=${self.tags.Name}",
      "LBURL=${aws_lb.gateway-lb.dns_name}",
      
    ## Install HA Proxy
      "sudo chmod +x /tmp/install_haproxy.sh",
      "sudo /tmp/install_haproxy.sh",
    
    ## Install Otel Agent
      "sudo curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh",
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm}  -- ${var.access_token} --mode agent --collector-version ${var.collector_version} --discovery",
      "sudo chmod +x /tmp/update_splunk_otel_collector.sh",
      "sudo /tmp/update_splunk_otel_collector.sh $LBURL",
      "sudo mv /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.bak",
      "sudo mv /tmp/agent_config.yaml /etc/otel/collector/agent_config.yaml",
      "sudo chown splunk-otel-collector:splunk-otel-collector -R /media/data/logs",
      "sudo systemctl restart splunk-otel-collector",
    ## If splunk_ent_count = 0 then set a default value to prevent terraform errors
      "SPLUNK_IP=${length(aws_instance.splunk_ent) > 0 ? aws_instance.splunk_ent[0].private_ip : "127.0.0.1"}",

    ## Deloy UF for Splunk Ent, but only if splunk_ent_count = 1
      <<EOT
      if [ ${var.splunk_ent_count} -eq 1 ]; then
        sudo chmod +x /tmp/install_splunk_universal_forwarder.sh
        UNIVERSAL_FORWARDER_FILENAME=${var.universalforwarder_filename}
        UNIVERSAL_FORWARDER_URL=${var.universalforwarder_url}
        PASSWORD=${random_string.splunk_password.result}
        /tmp/install_splunk_universal_forwarder.sh $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_URL $PASSWORD $SPLUNK_IP

        ## Write env vars to file (used for debugging)
        echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME
        echo $UNIVERSAL_FORWARDER_URL > /tmp/UNIVERSAL_FORWARDER_URL
        echo $PASSWORD > /tmp/UNIVERSAL_FORWARDER_PASSWORD
        echo $SPLUNK_IP > /tmp/SPLUNK_IP
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
        UNIVERSAL_FORWARDER_URL=${var.universalforwarder_url}
        PASSWORD=${random_string.splunk_password.result}
        /tmp/install_splunk_universal_forwarder_splunk_cloud.sh $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_URL $PASSWORD

        ## Write env vars to file (used for debugging)
        echo $UNIVERSAL_FORWARDER_FILENAME > /tmp/UNIVERSAL_FORWARDER_FILENAME
        echo $UNIVERSAL_FORWARDER_URL > /tmp/UNIVERSAL_FORWARDER_URL
        echo $PASSWORD > /tmp/UNIVERSAL_FORWARDER_PASSWORD
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

output "haproxy_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.haproxy.*.tags.Name,
    aws_instance.haproxy.*.public_ip,
  )
}