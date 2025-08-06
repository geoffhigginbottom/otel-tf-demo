resource "null_resource" "patch_frontend_proxy_apply" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} <<'REMOTE'
        set -e
        export KUBECONFIG=/home/ubuntu/.kube/config

        echo "Patching service to type LoadBalancer..."
        kubectl patch svc frontend-proxy -n default -p '{"spec": {"type": "LoadBalancer"}}'

        echo "Waiting for LoadBalancer Ingress hostname..."
        for i in {1..30}; do
          LB_HOSTNAME=$(kubectl get svc frontend-proxy -n default -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
          if [[ "$LB_HOSTNAME" != "null" ]]; then
            echo "LoadBalancer is available: $LB_HOSTNAME"
            echo "$LB_HOSTNAME" > ~/frontend-lb.txt
            break
          fi
          echo "Still waiting... ($i)"
          sleep 10
        done

        if [[ ! -s ~/frontend-lb.txt ]]; then
          echo "ERROR: LoadBalancer hostname not available after waiting."
          exit 1
        fi
REMOTE
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
      "kubectl patch svc frontend-proxy -n default -p '{\"spec\": {\"type\": \"ClusterIP\"}}'"
    EOT
  }

  triggers = {
    admin_ip         = var.eks_admin_server_eip
    private_key_path = var.private_key_path
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks-admin-server-eip-assoc,
    null_resource.astro_shop_helm_install
  ]
}

resource "null_resource" "get_lb_hostname" {
  depends_on = [null_resource.patch_frontend_proxy_apply]

  provisioner "local-exec" {
    command = <<EOT
      scp -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${var.eks_admin_server_eip}:~/frontend-lb.txt ./frontend-lb.txt
    EOT
  }
}

data "local_file" "frontend_lb_hostname" {
  depends_on = [null_resource.get_lb_hostname]
  filename   = "${path.root}/frontend-lb.txt"
}
