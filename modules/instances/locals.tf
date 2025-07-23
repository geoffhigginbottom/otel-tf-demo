# Local values
locals {
  hec_metrics_token = var.splunk_ent_count != 0 ? data.external.hec_tokens[0].result["HEC-METRICS"] : var.access_token
}