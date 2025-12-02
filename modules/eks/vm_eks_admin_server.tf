resource "aws_instance" "eks_admin_server" {
  ami                       = var.ami
  instance_type             = var.instance_type
  subnet_id                 = element(var.public_subnet_ids, 0)
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.eks_admin_server.id]
 
  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
    delete_on_termination = true

    tags = {
      Name                          = lower(join("-", [var.environment, "eks-admin-server", "root"]))
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }

  tags = {
    Name = "${var.environment}-eks-admin-server"
    splunkit_environment_type     = "non-prd"
    splunkit_data_classification  = "private"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/generate_aws_config.sh"
    destination = "/tmp/generate_aws_config.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_eks_tools.sh"
    destination = "/tmp/install_eks_tools.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/astro_shop_attach_nodes.sh"
    destination = "/tmp/astro_shop_attach_nodes.sh"
  }

  provisioner "file" {
    content     = local.astro_shop_values
    destination = "/tmp/astro_shop_values.yaml"
  }

  # provisioner "file" {
  #   source      = "${path.module}/config_files/astro_shop_values.yaml"
  #   destination = "/tmp/astro_shop_values.yaml"
  # }

  provisioner "file" {
    source      = "${path.module}/otel_external_name_service/Chart.yaml"
    destination = "/tmp/otel_external_name_Chart.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/otel_external_name_service/values.yaml"
    destination = "/tmp/otel_external_name_values.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/otel_external_name_service/templates/otel_external_name_service.yaml"
    destination = "/tmp/otel_external_name_service.yaml"
  }

  depends_on = [
    aws_eks_cluster.eks_cluster
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
      "sudo sh /tmp/splunk-otel-collector.sh --realm ${var.realm}  -- ${var.access_token} --mode agent --without-instrumentation",

    ## Setup AWS Cli
      "sudo curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip",
      "sudo apt install unzip -y",
      "unzip /tmp/awscliv2.zip",
      "sudo ~/aws/install",
      "sudo chmod +x /tmp/generate_aws_config.sh",
      "AWS_ACCESS_KEY_ID=${var.aws_access_key_id}",
      "AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key}",
      "AWS_SESSION_TOKEN=${var.aws_session_token}",
      "REGION=${var.region}",
      "/tmp/generate_aws_config.sh $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY $AWS_SESSION_TOKEN $REGION",

    ## Install EKS Tools
      "sudo chmod +x /tmp/install_eks_tools.sh",
      "/tmp/install_eks_tools.sh",

    ## Setup eksutils
      "AWS_DEFAULT_REGION=${var.region}",
      "AWS_DEFAULT_OUTPUT=json",
      "EKS_CLUSTER_NAME=${var.eks_cluster_name}",
      "eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME",
      "eksctl get clusters",
      "aws eks update-kubeconfig --name $EKS_CLUSTER_NAME",

    ## Install jq
      "sudo apt-get install -y jq",
      
    ## Install K8S Integration using Splunk OTel Collector Helm Chart
      # Note the use of fullnameOverride - requried to ensure the atro-shop deployment works correctly
      "TOKEN=${var.eks_access_token}",
      "REALM=${var.realm}",
      "SPLUNK_ENDPOINT=${var.eks_splunk_endpoint}",
      "HEC_TOKEN=${var.hec_otel_k8s_token}",
      "SPLUNK_INDEX=${var.eks_splunk_index}",
      "EKS_CLUSTER_NAME=${var.eks_cluster_name}",
      "EKS_ACCESS_TOKEN=${var.eks_access_token}",
      "ENVIRONMENT=${var.environment}",
      "helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart",
      "helm repo update",
      "helm install --set cloudProvider='aws' --set distribution='eks' --set fullnameOverride='splunk-otel-collector' --set splunkObservability.accessToken=$EKS_ACCESS_TOKEN --set clusterName=$EKS_CLUSTER_NAME --set splunkObservability.realm=$REALM --set gateway.enabled='false' --set splunkObservability.profilingEnabled='true' --set splunkPlatform.endpoint=$SPLUNK_ENDPOINT --set splunkPlatform.token=$HEC_TOKEN --set splunkPlatform.index=$SPLUNK_INDEX --set environment=$ENVIRONMENT --set operatorcrds.install=true --set operator.enabled=true --set agent.discovery.enabled=true --generate-name splunk-otel-collector-chart/splunk-otel-collector",

    ## Install kubectl
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      "chmod +x ./kubectl",
      "sudo mv ./kubectl /usr/local/bin/",

    ## Prep for Astro Shop Deployment # Uses default Splunk Otel Collector Helm Chart
      "kubectl create namespace astro-shop",
      "sudo mv /tmp/astro_shop_values.yaml /home/ubuntu/astro_shop_values.yaml",
      "helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts",
      "sudo mv /tmp/astro_shop_attach_nodes.sh /home/ubuntu/astro_shop_attach_nodes.sh",
      "sudo chmod +x /home/ubuntu/astro_shop_attach_nodes.sh",

      "sudo mkdir -p /home/ubuntu/helm_otel_external_name",
      "sudo mkdir -p /home/ubuntu/helm_otel_external_name/templates",
      "sudo mv /tmp/otel_external_name_Chart.yaml /home/ubuntu/helm_otel_external_name/Chart.yaml",
      "sudo mv /tmp/otel_external_name_values.yaml /home/ubuntu/helm_otel_external_name/values.yaml",
      "sudo mv /tmp/otel_external_name_service.yaml /home/ubuntu/helm_otel_external_name/templates/otel_external_name_service.yaml",

    ## Write env vars to file (used for debugging)
      "echo $AWS_ACCESS_KEY_ID > /tmp/aws_access_key_id",
      "echo $AWS_SECRET_ACCESS_KEY > /tmp/aws_secret_access_key",
      "echo $AWS_SESSION_TOKEN > /tmp/aws_session_token",
      "echo $REGION > /tmp/region",
      "echo $EKS_CLUSTER_NAME > /tmp/eks_cluster_name",
      "echo $TOKEN > /tmp/access_token",
      "echo $REALM > /tmp/realm",
      "echo $ENVIRONMENT > /tmp/environment",

    ## Configure motd
      "sudo curl -s https://raw.githubusercontent.com/signalfx/observability-workshop/master/cloud-init/motd -o /etc/motd",
      "sudo chmod -x /etc/update-motd.d/*",

    ### Removed as now using Splunk Otel Collector Helm Chart and not OTel Contrib
     ## Deploy OTel Contrib and Prep for Astro Shop Deployment - based on https://github.com/splunk/observability-workshop/tree/main/workshop/otel-contrib-splunk-demo # Disabled as now using Splunk Otel and not contrib
      # "TOKEN=${var.eks_access_token}",
      # "REALM=${var.realm}",

      # "git clone https://github.com/splunk/observability-workshop",
      # "helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts",
      # "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      
      # "chmod +x ./kubectl",
      # "sudo mv ./kubectl /usr/local/bin/",
      # "sudo mv /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/k8s_manifests/configmap-and-secrets.yaml /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/k8s_manifests/configmap-and-secrets.original",
      # "sudo mv /tmp/configmap-and-secrets.yaml /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/k8s_manifests/configmap-and-secrets.yaml",
      # "kubectl apply -f /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/k8s_manifests/",
      
      # "mv /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/opentelemetry-demo-values.yaml /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/opentelemetry-demo-values.yaml.original",
      # "cp /tmp/opentelemetry-demo-values.yaml /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/opentelemetry-demo-values.yaml",
  

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