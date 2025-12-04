resource "aws_security_group" "eks_cluster" {
  name                = "${var.environment}_eks_cluster_sg"
  description         = "Cluster communication with worker nodes"
  vpc_id              = var.vpc_id

  egress {
    from_port         = 0
    to_port           =  0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  ingress {
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = [var.vpc_cidr_block]
  }
}

resource "aws_security_group" "eks_admin_server" {
  name                = "${var.environment}_eks_admin_server_sg"
  description         = "Used by EKS Admins Server for Remote access via SSH and to allow outbound internet access"
  vpc_id              = var.vpc_id

  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    # cidr_blocks       = ["0.0.0.0/0"]
    cidr_blocks = var.insecure_sg_rules ? ["0.0.0.0/0"] : ["${var.my_public_ip}/32"]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "frontend_proxy_sg" {
  name                = "${var.environment}_frontend_proxy_sg"
  description         = "Allow access to the Astro Shop frontend proxy"
  vpc_id              = var.vpc_id

  ingress {
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    # cidr_blocks       = ["0.0.0.0/0"]
    cidr_blocks = var.insecure_sg_rules ? ["0.0.0.0/0"] : ["${var.my_public_ip}/32"]
  }

  ingress {
    from_port         = 8080
    to_port           = 8080
    protocol          = "tcp"
    cidr_blocks       = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "cluster_worker_nodes_sg" {
  name                = "${var.environment}_cluster_worker_nodes_sg"
  description         = "Used by the cluster worker nodes"
  vpc_id              = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

#Load Balancer → worker node communication
  ingress {
    from_port         = 30080
    to_port           = 30080
    protocol          = "tcp"
    security_groups = [
      "${aws_security_group.frontend_proxy_sg.id}"
    ]
  }

# API server → kubelet communication
  ingress {
    from_port         = 10250
    to_port           = 65535
    protocol          = "tcp"
    cidr_blocks       = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}