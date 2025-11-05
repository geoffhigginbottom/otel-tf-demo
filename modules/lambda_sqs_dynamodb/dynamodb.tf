resource "aws_dynamodb_table" "messages" {
  name           = "${var.environment}_messages"
  billing_mode   = "PROVISIONED"
  read_capacity  = 50
  write_capacity = 50
  hash_key       = "MessageId"

  attribute {
    name = "MessageId"
    type = "S"
  }

#   ttl {
#     attribute_name = "TimeToExist"
#     enabled        = false
#   }

  tags = {
    UserID = "sloth"
  }
}