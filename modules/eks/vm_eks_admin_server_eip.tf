resource "aws_eip_association" "eks_admin_server_eip_assoc" {
  instance_id   = aws_instance.eks_admin_server.id
  public_ip     = var.eks_admin_server_eip 
}

output "eks_admin_server_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.eks_admin_server.*.tags.Name,
    # aws_instance.eks_admin_server.*.public_ip,
    aws_eip_association.eks_admin_server_eip_assoc.*.public_ip,
  )
}