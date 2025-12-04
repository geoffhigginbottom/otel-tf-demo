resource "aws_security_group" "instances_sg" {
  name          = "${var.environment}_Instances SG"
  description   = "Allow ingress traffic between Instances and Egress to Internet"
  vpc_id        = var.vpc_id

  ## Allow all traffic between group members
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  ## Allow SSH - required for Terraform
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # cidr_blocks = ["${var.my_public_ip}/32"]
    # cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = var.insecure_sg_rules ? ["0.0.0.0/0"] : ["${var.my_public_ip}/32"]
  }

  ## Allow RDP - Enable Windows Remote Desktop
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    # cidr_blocks = ["${var.my_public_ip}/32"]
    # cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = var.insecure_sg_rules ? ["0.0.0.0/0"] : ["${var.my_public_ip}/32"]
  }

  ## Allow WinRM - Enable Windows Remote Desktop
  ingress {
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    # cidr_blocks = ["${var.my_public_ip}/32"]
    # cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = var.insecure_sg_rules ? ["0.0.0.0/0"] : ["${var.my_public_ip}/32"]
  }

  ## Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # cidr_blocks = ["${var.my_public_ip}/32"]
    # cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = var.insecure_sg_rules ? ["0.0.0.0/0"] : ["${var.my_public_ip}/32"]
  }

  ## Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "splunk_ent_sg" {
  name          = "${var.environment}_Splunk Ent SG"
  description   = "Allow access to Splunk Enterprise UI via Internet"
  vpc_id        = var.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    # cidr_blocks = ["${var.my_public_ip}/32"]
    cidr_blocks = var.insecure_sg_rules ? ["0.0.0.0/0"] : ["${var.my_public_ip}/32"]
  }

  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    # cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.vpc_cidr_block}"] # this should allow HEC from within VPC
  }

# Log Observer Connect to Splunk Enterprise HEC https://help.splunk.com/en/splunk-observability-cloud/manage-data/view-splunk-platform-logs/set-up-log-observer-connect-for-splunk-cloud-platform
  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = [
      "108.128.26.145/32", "34.250.243.212/32", "54.171.237.247/32",
      "3.73.240.7/32", "18.196.129.64/32", "3.126.181.171/32",
      "13.41.86.83/32", "52.56.124.93/32", "35.177.204.133/32",
      "34.199.200.84/32", "52.20.177.252/32", "52.201.67.203/32", "54.89.1.85/32",
      "44.230.152.35/32", "44.231.27.66/32", "44.225.234.52/32", "44.230.82.104/32",
      "35.247.113.38/32", "35.247.32.72/32", "35.247.86.219/32"
    ]
    security_groups = [
      aws_security_group.instances_sg.id
    ]
  }
}