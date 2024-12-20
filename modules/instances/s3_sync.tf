# resource "null_resource" "sync_windows_server_agent_config" {
#   provisioner "local-exec" {
#     command = "aws s3 cp ~/Documents/GitHub/otel-tf-demo/modules/instances/config_files/windows_server_agent_config.yaml s3://tfdemo-files/windows_server_agent_config.yaml"
#   }
# }

# resource "null_resource" "sync_config_files" {
#   provisioner "local-exec" {
#     command = "aws s3 sync ~/Documents/GitHub/otel-tf-demo/modules/instances/config_files/ s3://eu-west-3-tfdemo-files/config_files/"
#   }
# }

# resource "null_resource" "sync_scripts" {
#   provisioner "local-exec" {
#     command = "aws s3 sync ~/Documents/GitHub/otel-tf-demo/modules/instances/scripts/ s3://eu-west-3-tfdemo-files/scripts/"
#   }
# }



resource "null_resource" "sync_config_files" {
  provisioner "local-exec" {
    command = "aws s3 sync ~/Documents/GitHub/otel-tf-demo/modules/instances/config_files/ s3://eu-west-3-tfdemo-files/config_files/"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "sync_scripts" {
  provisioner "local-exec" {
    command = "aws s3 sync ~/Documents/GitHub/otel-tf-demo/modules/instances/scripts/ s3://eu-west-3-tfdemo-files/scripts/"
  }

  triggers = {
    always_run = timestamp()
  }
}
