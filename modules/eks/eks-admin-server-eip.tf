resource "aws_eip_association" "eks-admin-server-eip-assoc" {
  instance_id   = aws_instance.eks_admin_server.id
  public_ip     = var.eks_admin_server_eip 
}
