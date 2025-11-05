terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    signalfx = {
      source = "splunk-terraform/signalfx"
    }
    splunk = {
      source = "splunk/splunk"
    }
  }
}
