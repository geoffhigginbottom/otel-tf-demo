resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}_main_vpc"
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
}