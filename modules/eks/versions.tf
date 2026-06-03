terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    local = {
      source = "hashicorp/local"
    }
    signalfx = {
      source = "splunk-terraform/signalfx"
    }
    splunk = {
      source = "splunk/splunk"
    }
  }
}
