# Note the use of fullnameOverride - requried to ensure the atro-shop deployment works correctly
locals {
  use_enterprise = var.splunk_ent_count == 1 && var.instances_enabled == true

  helm_command_enterprise = join(" ", [
    "helm install",
    "--set cloudProvider='aws'",
    "--set distribution='eks'",
    "--set fullnameOverride='splunk-otel-collector'",
    "--set splunkObservability.accessToken='${var.eks_access_token}'",
    "--set clusterName='${var.eks_cluster_name}'",
    "--set splunkObservability.realm='${var.realm}'",
    "--set gateway.enabled='false'",
    "--set splunkObservability.profilingEnabled='true'",
    "--set splunkObservability.infrastructureMonitoringEventsEnabled=true",
    # "--set logsEngine=otel",
    "--set splunkObservability.secureAppEnabled=true",
    "--set splunkPlatform.endpoint='http://${var.splunk_private_ip}:8088'",
    "--set splunkPlatform.token='${var.hec_otel_k8s_token}'",
    "--set splunkPlatform.index='${var.eks_splunk_index}'",
    "--set environment='${var.environment}'",
    "--generate-name splunk-otel-collector-chart/splunk-otel-collector",
    "-f splunk-astronomy-shop-values.yaml"
  ])

  helm_command_basic = join(" ", [
    "helm install",
    "--set cloudProvider='aws'",
    "--set distribution='eks'",
    "--set fullnameOverride='splunk-otel-collector'",
    "--set splunkObservability.accessToken='${var.eks_access_token}'",
    "--set clusterName='${var.eks_cluster_name}'",
    "--set splunkObservability.realm='${var.realm}'",
    "--set gateway.enabled='false'",
    "--set splunkObservability.profilingEnabled='true'",
    "--set splunkObservability.infrastructureMonitoringEventsEnabled=true",
    # "--set logsEngine=otel",
    "--set splunkObservability.secureAppEnabled=true",
    "--set environment='${var.environment}'",
    "--generate-name splunk-otel-collector-chart/splunk-otel-collector",
    "-f splunk-astronomy-shop-values.yaml"
  ])

  # Final command
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
    destination = "/home/ubuntu/install_eks_tools.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/astro_shop_attach_nodes.sh"
    destination = "/home/ubuntu/astro_shop_attach_nodes.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/config_files/secrets.yaml.tpl", {
      hec_otel_k8s_token = var.hec_otel_k8s_token
      splunk_private_ip  = var.splunk_private_ip
      eks_access_token   = var.eks_access_token
      rum_token          = var.rum_access_token
      hec_token          = var.hec_otel_k8s_token
      hec_url            = "http://${var.splunk_private_ip}:8088/services/collector/event"
      aws_lb_dns_name    = aws_lb.frontend_proxy_lb.dns_name
      environment        = var.environment
    })
    destination = "/home/ubuntu/secrets.yaml"
  }

    provisioner "file" {
    source      = "${path.module}/config_files/TEST-splunk-astronomy-shop-1.4.0-test.yaml"
    destination = "/home/ubuntu/splunk-astronomy-shop.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/config_files/splunk-astronomy-shop-1.4.0-values.yaml.tpl", {
      eks_access_token   = var.eks_access_token
      realm              = var.realm
    })
    destination = "/home/ubuntu/splunk-astronomy-shop-values.yaml"
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
      "sudo chmod +x /home/ubuntu/install_eks_tools.sh",
      "/home/ubuntu/install_eks_tools.sh",

    ## Setup eksutils
      "AWS_DEFAULT_REGION=${var.region}",
      # "AWS_DEFAULT_OUTPUT=json",
      "EKS_CLUSTER_NAME=${var.eks_cluster_name}",
      "eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME --region $AWS_DEFAULT_REGION",
      "eksctl get clusters --region $AWS_DEFAULT_REGION",
      "aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_DEFAULT_REGION",

    ## Install jq
      "sudo apt-get install -y jq",


    ## Install kubectl
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      "chmod +x ./kubectl",
      "sudo mv ./kubectl /usr/local/bin/",

    ## Prep for Astro Shop Deployment
      "sudo chmod +x /home/ubuntu/astro_shop_attach_nodes.sh",
      "kubectl apply -f secrets.yaml",
      "mkdir -p /home/ubuntu/k8s-manifests",

    ## Write env vars to file (used for debugging)
      "echo $REGION > /home/ubuntu/region",
      "echo $EKS_CLUSTER_NAME > /home/ubuntu/eks_cluster_name",
      "echo $EKS_ACCESS_TOKEN > /home/ubuntu/eks_access_token",
      "echo $TOKEN > /home/ubuntu/access_token",
      "echo $REALM > /home/ubuntu/realm",
      "echo $ENVIRONMENT > /home/ubuntu/environment",
      "echo $SPLUNK_ENDPOINT > /home/ubuntu/splunk_endpoint",
      "echo $SPLUNK_PRIVATE_IP > /home/ubuntu/splunk_private_ip",
      "echo $HEC_TOKEN > /home/ubuntu/hec_token",
      "echo $SPLUNK_INDEX > /home/ubuntu/splunk_index",
      "echo '${local.helm_command}' > /home/ubuntu/o11y_deployment_command",

    ## Install K8S Integration using Splunk OTel Collector Helm Chart
      "helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart",
      "helm repo update",
      "${local.helm_command}", # See locals block at top of file for command selection logic

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
