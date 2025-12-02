data "external" "aws_creds" {
  program = ["bash", "${path.module}/get-creds.sh"]
}

locals {
  access_key_id     = data.external.aws_creds.result["access_key_id"]
  secret_access_key = data.external.aws_creds.result["secret_access_key"]
  session_token     = data.external.aws_creds.result["session_token"]
}