### SignalFX Variables ###
variable "access_token" {
    type    = string
    default = ""
  }

variable "environment" {
    type    = string
    default = ""
  }

variable "realm" {
    type    = string
    default = ""
  }

### AWS Variables ###
variable "region" {
    type    = string
    default = ""
  }

variable "aws_access_key_id" {
    type    = string
    default = ""
  }

variable "aws_secret_access_key" {
    type    = string
    default = ""
  }

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "eks_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "eks_ami_type" {
  type    = string
  default = ""
}

variable "ami" {
    type    = string
    default = ""
  }

variable "key_name" {
    type    = string
    default = ""
  }

variable "private_key_path" {
    type    = string
    default = ""
  }

variable "public_subnet_ids" {
  type    = list(string)
  default = []
}

variable "vpc_id" {
    type    = string
    default = ""
  }

variable "vpc_cidr_block" {
    type    = string
    default = ""
  }

variable "eks_cluster_name" {
    type    = string
    default = ""
  }

variable "eks_cluster_endpoint" {
    type    = string
    default = ""
  }

variable "eks_access_token" {
    type    = string
    default = ""
  }

variable "eks_splunk_endpoint" {
    type    = string
    default = ""
  }

variable "hec_otel_k8s_token" {
  type    = string
  default = ""
}

variable "eks_splunk_index" {
    type    = string
    default = ""
  }

variable "fqdn" {
    type    = string
    default = ""
  }

  variable "eks_admin_server_eip" {
    type    = string
    default = ""
  }