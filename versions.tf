terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    signalfx = {
      source = "splunk-terraform/signalfx"
      version = "~> 9.0"
    }
    splunk = {
      source = "splunk/splunk"
      version = "~> 1.0"
    }
  }
  required_version = "~> 1.13"
}
