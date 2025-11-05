resource "aws_instance" "proxied_windows_server" {
  count                     = var.proxied_windows_server_count
  ami                       = var.windows_server_ami
  instance_type             = var.windows_server_instance_type
  instance_initiated_shutdown_behavior = "terminate"
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.proxied_instances_sg.id]
  iam_instance_profile      = var.ec2_instance_profile_name

  user_data = templatefile("${path.module}/userdata/proxied_windows_server_userdata.ps1.tpl", {
    hostname                          = lower(join("-", ["prox-win", count.index + 1]))
    access_token                      = var.access_token
    realm                             = var.realm
    s3_bucket_name                    = var.s3_bucket_name
    collector_version                 = var.collector_version
    environment                       = var.environment
    windows_server_administrator_pwd  = var.windows_server_administrator_pwd
    proxy_server_private_ip           = aws_instance.proxy_server[0].private_ip
  })

  tags = {
    Name = lower(join("-",[var.environment, "prox-win", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }

  root_block_device {
    volume_size = 80
    volume_type = "gp3"
    encrypted   = true
    delete_on_termination = true

    tags = {
      Name                          = lower(join("-", [var.environment, "prox-win", count.index + 1, "root"]))
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }
}

output "proxied_windows_server_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.proxied_windows_server.*.tags.Name,
    aws_instance.proxied_windows_server.*.public_ip,
    aws_instance.proxied_windows_server.*.public_dns, 
  )
}
