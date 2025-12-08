locals {
  use_enterprise = var.splunk_ent_count == 1 && var.instances_enabled == true

  helm_command_enterprise = "helm install --set cloudProvider='aws' --set distribution='eks' --set fullnameOverride='splunk-otel-collector' --set splunkObservability.accessToken=$EKS_ACCESS_TOKEN --set clusterName=$EKS_CLUSTER_NAME --set splunkObservability.realm=$REALM --set gateway.enabled='false' --set splunkObservability.profilingEnabled='true' --set splunkPlatform.endpoint=$SPLUNK_ENDPOINT --set splunkPlatform.token=$HEC_TOKEN --set splunkPlatform.index=$SPLUNK_INDEX --set environment=$ENVIRONMENT --set operatorcrds.install=true --set operator.enabled=true --set agent.discovery.enabled=true --generate-name splunk-otel-collector-chart/splunk-otel-collector"

  helm_command_basic = "helm install --set cloudProvider='aws' --set distribution='eks' --set fullnameOverride='splunk-otel-collector' --set splunkObservability.accessToken=$EKS_ACCESS_TOKEN --set clusterName=$EKS_CLUSTER_NAME --set splunkObservability.realm=$REALM --set gateway.enabled='false' --set splunkObservability.profilingEnabled='true' --set environment=$ENVIRONMENT --set operatorcrds.install=true --set operator.enabled=true --set agent.discovery.enabled=true --generate-name splunk-otel-collector-chart/splunk-otel-collector"

  # Final chosen command
  helm_command = local.use_enterprise ? local.helm_command_enterprise : local.helm_command_basic
}


resource "aws_instance" "eks_admin_server" {
  ami                       = var.ami
  instance_type             = var.instance_type
  subnet_id                 = element(var.public_subnet_ids, 0)
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.eks_admin_server.id]
  iam_instance_profile      = aws_iam_instance_profile.eks_client_profile.name
 
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
    aws_eks_cluster.eks_cluster,
    null_resource.map_admin_vm_role
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

    ## Install EKS Tools
      "sudo chmod +x /tmp/install_eks_tools.sh",
      "/tmp/install_eks_tools.sh",

    ## Setup eksutils
      "AWS_DEFAULT_REGION=${var.region}",
      # "AWS_DEFAULT_OUTPUT=json",
      "EKS_CLUSTER_NAME=${var.eks_cluster_name}",
      "eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME --region $AWS_DEFAULT_REGION",
      "eksctl get clusters --region $AWS_DEFAULT_REGION",
      "aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_DEFAULT_REGION",

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
      # "helm install --set cloudProvider='aws' --set distribution='eks' --set fullnameOverride='splunk-otel-collector' --set splunkObservability.accessToken=$EKS_ACCESS_TOKEN --set clusterName=$EKS_CLUSTER_NAME --set splunkObservability.realm=$REALM --set gateway.enabled='false' --set splunkObservability.profilingEnabled='true' --set splunkPlatform.endpoint=$SPLUNK_ENDPOINT --set splunkPlatform.token=$HEC_TOKEN --set splunkPlatform.index=$SPLUNK_INDEX --set environment=$ENVIRONMENT --set operatorcrds.install=true --set operator.enabled=true --set agent.discovery.enabled=true --generate-name splunk-otel-collector-chart/splunk-otel-collector",
      "${local.helm_command}", # See locals block at top of file for command selection logic

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
