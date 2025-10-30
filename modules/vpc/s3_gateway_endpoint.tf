resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id       = aws_vpc.main_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route.main_vpc_route.route_table_id]
  


  tags = {
    Name = "s3-gateway-endpoint"
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
}
