data "http" "my_public_ip" {
  url = "https://ipv4.icanhazip.com/"
}

locals {
  # Prefer explicit terraform.tfvars override; auto-detect when empty (must match IP used to SSH).
  detected_public_ip = chomp(data.http.my_public_ip.response_body)
  my_public_ip       = var.my_public_ip != "" ? var.my_public_ip : local.detected_public_ip
}

output "my_public_ip_used_for_ssh" {
  description = "Public IP allowed for SSH/RDP in security groups (when insecure_sg_rules is false)."
  value       = local.my_public_ip
}