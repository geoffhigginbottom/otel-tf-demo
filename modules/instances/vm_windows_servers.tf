resource "aws_instance" "windows_server" {
  count                     = var.windows_server_count
  ami                       = var.windows_server_ami
  instance_type             = var.windows_server_instance_type
  instance_initiated_shutdown_behavior = "terminate"
  subnet_id                 = "${var.public_subnet_ids[ count.index % length(var.public_subnet_ids) ]}"
  key_name                  = var.key_name
  vpc_security_group_ids    = [aws_security_group.instances_sg.id]

  user_data = <<EOF
  <powershell>
  $logPath = "C:\Users\Administrator\user_data_log.txt"

  Get-LocalUser -Name "Administrator" | Set-LocalUser -Password (ConvertTo-SecureString -AsPlainText "${var.windows_server_administrator_pwd}" -Force)

  # Install AWS CLI (for accessing secure S3 Buckets)
  msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /qn
  Start-Sleep -Seconds 30  # Wait for the AWS CLI to finish installing

  # Install OTel Agent
  & {Set-ExecutionPolicy Bypass -Scope Process -Force;
  $script = ((New-Object System.Net.WebClient).DownloadString('https://dl.signalfx.com/splunk-otel-collector.ps1'));
  $params = @{access_token = "${var.access_token}";
  realm = "${var.realm}";
  mode = "agent"};
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

  # Invoke-WebRequest -Uri ${var.windows_server_agent_url} -OutFile "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
  # Stop-Service splunk-otel-collector
  # Start-Service splunk-otel-collector

  Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0
  Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0

  # Install IIS
  Install-WindowsFeature Web-Server -IncludeManagementTools

  # Install Splunk UF
  Invoke-WebRequest -Uri https://download.splunk.com/products/universalforwarder/releases/9.3.1/windows/splunkforwarder-9.3.1-0b8d769cb912-x64-release.msi -OutFile "C:\splunkforwarder.msi"
  Start-Process "msiexec.exe" -ArgumentList "/i C:\splunkforwarder.msi AGREETOLICENSE=Yes WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 SPLUNKUSERNAME=SplunkAdmin SPLUNKPASSWORD=Ch@ng3d! INSTALLDIR=`"C:\Program Files\SplunkUniversalForwarder`" /qn" -NoNewWindow -Wait

  # Download Splunk Cloud Credentials Package (AWS CLI install should have completed by now)
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
  $env:AWS_ACCESS_KEY_ID="${var.aws_access_key_id}"
  $env:AWS_SECRET_ACCESS_KEY="${var.aws_secret_access_key}"
  $env:AWS_DEFAULT_REGION="${var.region}"
  aws s3 cp s3://tfdemo-files/splunkclouduf.spl C:\splunkclouduf.spl

  # Download custom agent_config.yaml file
  aws s3 cp s3://tfdemo-files/windows_server_agent_config.yaml C:\windows_server_agent_config.yaml
  Move-Item -Path "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml" -Destination "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.bak"
  Move-Item -Path "C:\windows_server_agent_config.yaml" -Destination "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
  Stop-Service splunk-otel-collector
  Start-Service splunk-otel-collector

  # Download IIS Files
  aws s3 cp s3://tfdemo-files/iis/index.html C:\inetpub\wwwroot\index.html
  aws s3 cp s3://tfdemo-files/iis/contact.html C:\inetpub\wwwroot\contact.html
  aws s3 cp s3://tfdemo-files/iis/style.css C:\inetpub\wwwroot\style.css

  # Install SplunCloud Credentials Package
  Set-Location "C:\Program Files\SplunkUniversalForwarder\bin"
  & .\splunk.exe install app "C:\splunkclouduf.spl" -auth "SplunkAdmin:Ch@ng3d!"
  & .\splunk.exe restart
  
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
