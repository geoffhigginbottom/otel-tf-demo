# Local values
# locals {
#   hec_metrics_token = var.splunk_ent_count != 0 ? data.external.hec_tokens[0].result["HEC-METRICS"] : var.access_token
#   hec_otel_token = var.splunk_ent_count != 0 ? data.external.hec_tokens[0].result["HEC-OTEL"] : var.access_token
# }


locals {
  hec_metrics_token = var.splunk_ent_count != 0 ? lookup(data.external.hec_tokens[0].result, "OTEL-METRICS", var.access_token) : var.access_token
  hec_otel_token    = var.splunk_ent_count != 0 ? lookup(data.external.hec_tokens[0].result, "OTEL-LOGS", var.access_token) : var.access_token
}
