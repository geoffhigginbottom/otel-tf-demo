# Note the use of fullnameOverride - requried to ensure the atro-shop deployment works correctly
locals {
  use_enterprise = var.splunk_ent_count == 1 && var.instances_enabled == true

  helm_distribution = var.eks_fargate_enabled ? "eks/fargate" : "eks"

  # Fargate has no agent DaemonSet; the chart gateway Deployment is the cluster OTLP receiver.
  # eks_otel_gateway_enabled=false still skips the EC2 agent->gateway hop but apps need this service.
  helm_gateway_enabled       = var.eks_fargate_enabled || var.eks_otel_gateway_enabled
  helm_gateway_replica_count = var.eks_fargate_enabled && !var.eks_otel_gateway_enabled ? 1 : (var.eks_fargate_enabled ? min(var.eks_otel_gateway_replica_count, 2) : var.eks_otel_gateway_replica_count)

  helm_gateway_set_flags = join(" ", [
    "--set gateway.enabled='${local.helm_gateway_enabled}'",
    "--set gateway.replicaCount=${local.helm_gateway_replica_count}",
  ])

  fargate_wait_command = var.eks_fargate_enabled ? "/home/ubuntu/wait_for_fargate_profiles.sh ${var.eks_cluster_name} ${var.region} ${var.eks_cluster_name}-coredns ${var.eks_cluster_name}-default ${var.eks_cluster_name}-kube-system" : "true"
}

resource "aws_instance" "eks_admin_server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = element(var.public_subnet_ids, 0)
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.eks_admin_server.id]
  iam_instance_profile   = aws_iam_instance_profile.eks_client_profile.name

  root_block_device {
    volume_size           = 16
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name                         = lower(join("-", [var.environment, "eks-admin-server", "root"]))
      splunkit_environment_type    = "non-prd"
      splunkit_data_classification = "private"
    }
  }

  tags = {
    Name                         = "${var.environment}-eks-admin-server"
    splunkit_environment_type    = "non-prd"
    splunkit_data_classification = "private"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/eks-s3-sync.sh"
    destination = "/home/ubuntu/eks-s3-sync.sh"
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    null_resource.map_admin_vm_role,
    null_resource.sync_eks_non_public_config_to_s3,
    null_resource.sync_eks_scripts_to_s3,
    null_resource.wait_for_s3_config_sync,
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

      ## EKS S3 sync helper (scripts, static YAML, rendered Helm values)
      "echo 'S3_BUCKET=${var.s3_bucket_name}' > /home/ubuntu/eks-s3.env",
      "echo 'AWS_REGION=${var.region}' >> /home/ubuntu/eks-s3.env",
      "echo 'EKS_HOME=/home/ubuntu' >> /home/ubuntu/eks-s3.env",
      "sudo chmod +x /home/ubuntu/eks-s3-sync.sh",
      "sudo ln -sf /home/ubuntu/eks-s3-sync.sh /usr/local/bin/eks-s3-sync",
      "/home/ubuntu/eks-s3-sync.sh pull",

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
      "sudo chmod +x /home/ubuntu/astro_shop_attach_fargate.sh",
      "sudo chmod +x /home/ubuntu/patch_fargate_otel_endpoint.sh",
      "sudo chmod +x /home/ubuntu/patch_fargate_coredns.sh",
      "sudo chmod +x /home/ubuntu/patch_fargate_workloads.sh",
      "sudo chmod +x /home/ubuntu/wait_for_fargate_profiles.sh",
      "kubectl apply -f /home/ubuntu/secrets.yaml",
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
      "echo '${local.helm_upgrade_command}' > /home/ubuntu/o11y_deployment_command",

      ## Splunk OTel Collector Helm chart is installed by null_resource.otel_collector_deploy

      ## Configure motd
      "sudo curl -s https://raw.githubusercontent.com/signalfx/observability-workshop/master/cloud-init/motd -o /etc/motd",
      "sudo chmod -x /etc/update-motd.d/*",
      "echo '' | sudo tee -a /etc/motd > /dev/null",
      "echo 'EKS config sync: eks-s3-sync pull   (after terraform apply / eks-s3-push)' | sudo tee -a /etc/motd > /dev/null",
      "echo 'S3 bucket: ${var.s3_bucket_name}' | sudo tee -a /etc/motd > /dev/null",
    ]
  }

  connection {
    host        = self.public_ip
    port        = 22
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    agent       = "true"
    timeout     = "5m"
  }
}
