resource "aws_instance" "windows_server" {
  count                     = var.windows_server_count
  ami                       = var.windows_server_ami
  instance_type             = var.windows_server_instance_type
  instance_initiated_shutdown_behavior = "terminate"
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]
  iam_instance_profile      = aws_iam_instance_profile.ec2_instance_profile.name
  depends_on   = [
    # null_resource.sync_windows_server_agent_config,
    null_resource.sync_config_files
    ]

  user_data = <<EOF
  <powershell>
  $logPath = "C:\Users\Administrator\Documents\user_data_log.txt"

  Get-LocalUser -Name "Administrator" | Set-LocalUser -Password (ConvertTo-SecureString -AsPlainText "${var.windows_server_administrator_pwd}" -Force)

  # Install AWS CLI (for accessing secure S3 Buckets)
  msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /qn
  # Start-Sleep -Seconds 30  # Wait for the AWS CLI to finish installing

  # Install IIS
  Install-WindowsFeature Web-Server -IncludeManagementTools

  # Download IIS Files
  $env:Path += ";C:\Program Files\Amazon\AWSCLIV2"
  aws s3 cp s3://eu-west-3-tfdemo-files/config_files/iis/index.html C:\inetpub\wwwroot\index.html
  aws s3 cp s3://eu-west-3-tfdemo-files/config_files/iis/contact.html C:\inetpub\wwwroot\contact.html
  aws s3 cp s3://eu-west-3-tfdemo-files/config_files/iis/style.css C:\inetpub\wwwroot\style.css

  # Install OTel Agent
  & {Set-ExecutionPolicy Bypass -Scope Process -Force;
  $script = ((New-Object System.Net.WebClient).DownloadString('https://dl.signalfx.com/splunk-otel-collector.ps1'));
  $params = @{access_token = "${var.access_token}";
  realm = "${var.realm}";
  mode = "agent"};
  collector_version = "${var.collector_version}";
  with_dotnet_instrumentation = "0";
  deployment_env = "${var.environment}";
  Invoke-Command -ScriptBlock ([scriptblock]::Create(". {$script} $(&{$args} @params)"))}

  $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\splunk-otel-collector"
  $valueName = "Environment"
  $newValue = @(
      "SPLUNK_ACCESS_TOKEN=${var.access_token}",
      "SPLUNK_API_URL=https://api.${var.realm}.signalfx.com",
      "SPLUNK_BUNDLE_DIR=C:\Program Files\Splunk\OpenTelemetry Collector\agent-bundle",
      "SPLUNK_CONFIG=C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml",
      "SPLUNK_HEC_TOKEN=${var.access_token}",
      "SPLUNK_HEC_URL=https://ingest.${var.realm}.signalfx.com/v1/log",
      "SPLUNK_INGEST_URL=https://ingest.${var.realm}.signalfx.com",
      "SPLUNK_REALM=${var.realm}",
      "SPLUNK_TRACE_URL=https://ingest.${var.realm}.signalfx.com/v2/trace",
      "SPLUNK_GATEWAY_URL=${aws_lb.gateway-lb.dns_name}"
  )

  # Check if the registry key exists
  if (Test-Path $registryPath) {
      # Update the registry value
      Set-ItemProperty -Path $registryPath -Name $valueName -Value $newValue -Type MultiString
      Write-Host "Registry value '$valueName' updated successfully."
  } else {
      Write-Host "Registry path '$registryPath' does not exist."
  }

  # Download custom agent_config.yaml file
  $env:Path += ";C:\Program Files\Amazon\AWSCLIV2"
  Move-Item -Path "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml" -Destination "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.bak"
  aws s3 cp s3://eu-west-3-tfdemo-files/config_files/windows_server_agent_config.yaml "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"

  Stop-Service splunk-otel-collector
  Start-Service splunk-otel-collector

  Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0
  Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0

  # Install Splunk UF for Splunk Enterprise
  if (${var.splunk_ent_count} -eq 1) {
    # Asynchronously download the MSI
    Start-Job {
        Invoke-WebRequest -Uri ${var.universalforwarder_url_windows} -OutFile "C:\Users\Administrator\Documents\splunkforwarder.msi"
    }

    # Wait for the job to complete
    $job = Get-Job | Where-Object {$_.State -eq 'Running'}
    Wait-Job $job

    Start-Process "msiexec.exe" -ArgumentList "/i ""C:\Users\Administrator\Documents\splunkforwarder.msi"" RECEIVING_INDEXER=${var.splunk_private_ip}:9997 AGREETOLICENSE=Yes WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 SPLUNKUSERNAME=SplunkAdmin SPLUNKPASSWORD=${random_string.splunk_password.result} INSTALLDIR=""C:\Program Files\SplunkUniversalForwarder"" /qn" -NoNewWindow -Wait
  }

  # Install Splunk UF for Splunk Cloud
  if ("${var.splunk_cloud_enabled}" -eq "true") {
  # Asynchronously download the MSI
    Start-Job {
        Invoke-WebRequest -Uri ${var.universalforwarder_url_windows} -OutFile "C:\Users\Administrator\Documents\splunkforwarder.msi"
    }

    # Wait for the job to complete
    $job = Get-Job | Where-Object {$_.State -eq 'Running'}
    Wait-Job $job

    Start-Process "msiexec.exe" -ArgumentList "/i ""C:\Users\Administrator\Documents\splunkforwarder.msi"" AGREETOLICENSE=Yes WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 SPLUNKUSERNAME=SplunkAdmin SPLUNKPASSWORD=${random_string.splunk_password.result} INSTALLDIR=""C:\Program Files\SplunkUniversalForwarder"" /qn" -NoNewWindow -Wait
  }

  # Download SplunkCloud Auth File
  if ("${var.splunk_cloud_enabled}" -eq "true") {
    aws s3 cp s3://eu-west-3-tfdemo-files/config_files/splunkclouduf.spl C:\Users\Administrator\Documents\splunkclouduf.spl
  }

  # Install SplunCloud Credentials Package
  if ("${var.splunk_cloud_enabled}" -eq "true") {
    Set-Location "C:\Program Files\SplunkUniversalForwarder\bin"
    & .\splunk.exe install app "C:\Users\Administrator\Documents\splunkclouduf.spl" -auth "SplunkAdmin:${random_string.splunk_password.result}"
    & .\splunk.exe restart
  }
  
  "User data script completed." | Out-File -FilePath $logPath -Append
  </powershell>
  EOF

  tags = {
    Name = lower(join("-",[var.environment, "windows", count.index + 1]))
    Environment = lower(var.environment)
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
}

output "windows_server_details" {
  value =  formatlist(
    "%s, %s, %s", 
    aws_instance.windows_server.*.tags.Name,
    aws_instance.windows_server.*.public_ip,
    aws_instance.windows_server.*.public_dns, 
  )
}
