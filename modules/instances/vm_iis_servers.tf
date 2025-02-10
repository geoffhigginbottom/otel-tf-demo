resource "aws_instance" "iis_server" {
  count                     = var.iis_server_count
  ami                       = var.windows_server_ami
  instance_type             = var.windows_server_instance_type
  instance_initiated_shutdown_behavior = "terminate"
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]
  iam_instance_profile      = aws_iam_instance_profile.ec2_instance_profile.name
  depends_on   = [
    null_resource.sync_config_files
    ]

  user_data = templatefile("${path.module}/scripts/iis_servers_userdata.ps1.tpl", {
    hostname                          = lower(join("-", ["iis", count.index + 1]))
    access_token                      = var.access_token
    realm                             = var.realm
    collector_version                 = var.collector_version
    environment                       = var.environment
    splunk_ent_count                  = var.splunk_ent_count
    universalforwarder_url_windows    = var.universalforwarder_url_windows
    windows_server_administrator_pwd  = var.windows_server_administrator_pwd
    splunk_private_ip                 = var.splunk_private_ip
    splunk_cloud_enabled              = var.splunk_cloud_enabled
    splunk_password                   = var.splunk_admin_pwd
    gateway_lb_dns_name               = aws_lb.gateway-lb.dns_name
  })

  tags = {
    Name = lower(join("-",[var.environment, "iis", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
}

output "iis_server_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.iis_server.*.tags.Name,
    aws_instance.iis_server.*.public_ip,
    aws_instance.iis_server.*.public_dns, 
  )
}
