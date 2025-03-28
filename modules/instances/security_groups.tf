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
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow RDP - Enable Windows Remote Desktop
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow WinRM - Enable Windows Remote Desktop
  ingress {
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ## Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # cidr_blocks = ["${var.my_public_ip}/32"]
    cidr_blocks = ["0.0.0.0/0"]
  }

  ## Allow Trace data direct to Gateway Nodes
  ingress {
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
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
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = [
      "108.128.26.145/32",
      "34.250.243.212/32",
      "54.171.237.247/32"
    ]
  }

  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    # cidr_blocks = ["${var.my_public_ip}/32"]
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }
}