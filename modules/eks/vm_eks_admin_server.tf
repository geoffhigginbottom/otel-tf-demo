resource "aws_instance" "eks_admin_server" {
  ami                       = var.ami
  instance_type             = var.instance_type
  subnet_id                 = element(var.public_subnet_ids, 0)
  key_name                  = var.key_name
  vpc_security_group_ids    = [
    aws_security_group.eks_admin_server.id,
  ]
 
  tags = {
    Name = "${var.environment}_eks_admin_server"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/generate_aws_config.sh"
    destination = "/tmp/generate_aws_config.sh"
  }

  # provisioner "file" {
  #   source      = "${path.module}/scripts/generate_values.sh"
  #   destination = "/tmp/generate_values.sh"
  # }

  provisioner "file" {
    source      = "${path.module}/scripts/install_eks_tools.sh"
    destination = "/tmp/install_eks_tools.sh"
  }

  provisioner "file" {
    source      = "${path.module}/config_files/opentelemetry-demo-values.yaml"
    destination = "/tmp/opentelemetry-demo-values.yaml"
  }

   provisioner "file" {
    content     = local.configmap_and_secrets
    destination = "/tmp/configmap-and-secrets.yaml"
  }

  # provisioner "file" {
  #   source      = "${path.module}/config_files/deployment.yaml"
  #   destination = "/home/ubuntu/deployment.yaml"
  # }

  depends_on = [
    aws_eks_cluster.demo
  ]

# remote-exec
  provisioner "remote-exec" {
    inline = [
    ## Set Hostname
      "sudo sed -i 's/127.0.0.1.*/127.0.0.1 ${self.tags.Name}.local ${self.tags.Name} localhost/' /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      
    ## Update
      "sudo apt-get update",
      "sudo apt-get upgrade -y",

    ## Install Otel Agent
      "sudo curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh",
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm}  -- ${var.access_token} --mode agent --without-fluentd",

    ## Setup AWS Cli
      "sudo curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip /tmp/awscliv2.zip",
      "sudo ~/aws/install",
      "sudo chmod +x /tmp/generate_aws_config.sh",
      "AWS_ACCESS_KEY_ID=${var.aws_access_key_id}",
      "AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key}",
      "REGION=${var.region}",
      "/tmp/generate_aws_config.sh $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY $REGION",

    ## Install EKS Tools
      "sudo chmod +x /tmp/install_eks_tools.sh",
      "/tmp/install_eks_tools.sh",
      # "ENVIRONMENT=${var.environment}",
      # "sudo chmod +x /tmp/generate_values.sh",
      # "/tmp/generate_values.sh $ENVIRONMENT", #is this still needed as hotrod has been removed

    ## Setup eksutils
      "AWS_DEFAULT_REGION=${var.region}",
      "AWS_DEFAULT_OUTPUT=json",
      "EKS_CLUSTER_NAME=${var.eks_cluster_name}",
      "eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME",
      "eksctl get clusters",
      "aws eks update-kubeconfig --name $EKS_CLUSTER_NAME",

    # ## Install K8S Integration using Splunk OTel Collector Helm Chart
    #   "TOKEN=${var.eks_access_token}",
    #   "REALM=${var.realm}",
    #   "EKS_CLUSTER_NAME=${var.eks_cluster_name}",
    #   "SPLUNK_ENDPOINT=${var.eks_splunk_endpoint}",
    #   "HEC_TOKEN=${var.hec_otel_k8s_token}",
    #   "SPLUNK_INDEX=${var.eks_splunk_index}",
    #   "EKS_ACCESS_TOKEN=${var.eks_access_token}",
    #   "ENVIRONMENT=${var.environment}",
    #   "helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart",
    #   "helm repo update",
    #   "helm install --set cloudProvider='aws' --set distribution='eks' --set splunkObservability.accessToken=$EKS_ACCESS_TOKEN --set clusterName=$EKS_CLUSTER_NAME --set splunkObservability.realm=$REALM --set gateway.enabled='false' --set splunkObservability.profilingEnabled='true' --set splunkPlatform.endpoint=$SPLUNK_ENDPOINT --set splunkPlatform.token=$HEC_TOKEN --set splunkPlatform.index=$SPLUNK_INDEX --set environment=$ENVIRONMENT --generate-name splunk-otel-collector-chart/splunk-otel-collector",


    ## Deploy Hot Rod
      # "kubectl apply -f /home/ubuntu/deployment.yaml",
      # "sudo chmod +x /home/ubuntu/deploy_hotrod.sh",
      # "sudo chmod +x /home/ubuntu/delete_hotrod.sh",
      
    # # Deploy Astro Shop
    #   "git clone https://github.com/splunk/observability-workshop",
    #   "helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts",
    #   "helm install astro-shop-demo open-telemetry/opentelemetry-demo --values /home/ubuntu/observability-workshop/workshop/oteldemo/otel-demo.yaml",
    #   "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
    #   "chmod +x ./kubectl",
    #   "sudo mv ./kubectl /usr/local/bin/",
    #   "kubectl patch svc astro-shop-demo-frontendproxy -n default -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'",

    # Deploy OTel Contrib and Prep for Astro Shop Deployment - based on https://github.com/splunk/observability-workshop/tree/main/workshop/otel-contrib-splunk-demo
      "TOKEN=${var.eks_access_token}",
      "REALM=${var.realm}",

      "git clone https://github.com/splunk/observability-workshop",
      "helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts",
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      
      "chmod +x ./kubectl",
      "sudo mv ./kubectl /usr/local/bin/",
      "sudo mv /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/k8s_manifests/configmap-and-secrets.yaml /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/k8s_manifests/configmap-and-secrets.original",
      "sudo mv /tmp/configmap-and-secrets.yaml /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/k8s_manifests/configmap-and-secrets.yaml",
      "kubectl apply -f /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/k8s_manifests/",
      
      "mv /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/opentelemetry-demo-values.yaml /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/opentelemetry-demo-values.yaml.original",
      "cp /tmp/opentelemetry-demo-values.yaml /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/opentelemetry-demo-values.yaml",
      
      ### Astro Shop is now deployed via astro_shop_helm.tf and patched via patch_frontend_proxy.tf ###
      ### This enables Terraform to control the lifecycle of these resources ###
      # "helm install astro-shop open-telemetry/opentelemetry-demo --values /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/opentelemetry-demo-values.yaml",
      # "kubectl patch svc frontend-proxy -n default -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'",
      # kubectl patch svc frontend-proxy -n default -p '{"spec": {"type": "LoadBalancer"}}' # version for console testing

    # ## Cleanup script for Helm and Service Patch
    #   "sudo echo '#!/bin/bash\nhelm delete astro-shop --namespace default\nkubectl patch svc frontend-proxy -n default -p '{\"spec\": {\"type\": \"ClusterIP\"}}'' > /usr/local/bin/cleanup.sh",
    #   "sudo chmod +x /usr/local/bin/cleanup.sh",
    #   "sudo echo '[Unit]\nDescription=Cleanup Helm and Patch Service on Shutdown\nDefaultDependencies=no\nBefore=shutdown.target reboot.target halt.target\n\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/cleanup.sh\nRemainAfterExit=yes\n\n[Install]\nWantedBy=halt.target reboot.target shutdown.target' > /etc/systemd/system/helm-cleanup.service",
    #   "sudo systemctl enable helm-cleanup.service",

    ## Write env vars to file (used for debugging)
      "echo $AWS_ACCESS_KEY_ID > /tmp/aws_access_key_id",
      "echo $AWS_SECRET_ACCESS_KEY > /tmp/aws_secret_access_key",
      "echo $REGION > /tmp/region",
      "echo $EKS_CLUSTER_NAME > /tmp/eks_cluster_name",
      "echo $TOKEN > /tmp/access_token",
      "echo $REALM > /tmp/realm",
      "echo $ENVIRONMENT > /tmp/environment",

    ## Configure motd
      "sudo curl -s https://raw.githubusercontent.com/signalfx/observability-workshop/master/cloud-init/motd -o /etc/motd",
      "sudo chmod -x /etc/update-motd.d/*",

    ]
  }

  connection {
    host = self.public_ip
    type = "ssh"
    user = "ubuntu"
    private_key = file(var.private_key_path)
    agent = "true"
  }
}

output "eks_admin_server_details" {
  value =  formatlist(
    "%s, %s", 
    aws_instance.eks_admin_server.*.tags.Name,
    # aws_instance.eks_admin_server.*.public_ip,
    aws_eip_association.eks-admin-server-eip-assoc.*.public_ip,
  )
}