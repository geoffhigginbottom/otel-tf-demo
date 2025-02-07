resource "aws_instance" "ms_sql" {
  count                     = var.ms_sql_count
  ami                       = var.ms_sql_ami
  instance_type             = var.ms_sql_instance_type
  instance_initiated_shutdown_behavior = "terminate"
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]
  iam_instance_profile      = aws_iam_instance_profile.ec2_instance_profile.name
  depends_on   = [
    null_resource.sync_config_files
    ]

  user_data = templatefile("${path.module}/scripts/ms_sql_servers_userdata.ps1.tpl", {
    hostname                          = lower(join("-", ["ms-sql", count.index + 1]))
    access_token                      = var.access_token
    realm                             = var.realm
    collector_version                 = var.collector_version
    environment                       = var.environment
    splunk_ent_count                  = var.splunk_ent_count
    universalforwarder_url_windows    = var.universalforwarder_url_windows
    windows_server_administrator_pwd  = var.windows_server_administrator_pwd
    splunk_private_ip                 = var.splunk_private_ip
    splunk_cloud_enabled              = var.splunk_cloud_enabled
    splunk_password                   = random_string.splunk_password.result
    gateway_lb_dns_name               = aws_lb.gateway-lb.dns_name
    ms_sql_user                       = var.ms_sql_user
    ms_sql_user_pwd                   = var.ms_sql_user_pwd
  })

  tags = {
    Name = lower(join("-",[var.environment, "ms-sql", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
}

output "ms_sql_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.ms_sql.*.tags.Name,
    aws_instance.ms_sql.*.public_ip,
    aws_instance.ms_sql.*.public_dns,
  )
}
