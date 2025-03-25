<powershell>

# Set Administrator Password
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password (ConvertTo-SecureString -AsPlainText "${windows_server_administrator_pwd}" -Force)

# Set Proxy
[System.Environment]::SetEnvironmentVariable("http_proxy","http://${proxy_server_private_ip}:8080","Machine")
[System.Environment]::SetEnvironmentVariable("https_proxy","http://${proxy_server_private_ip}:8080","Machine")
[System.Environment]::SetEnvironmentVariable("no_proxy","169.254.169.254","Machine")
netsh winhttp set proxy "${proxy_server_private_ip}:8080"

Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -name ProxyServer -Value "http://${proxy_server_private_ip}:8080"
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -name ProxyEnable -Value 1

# Install AWS CLI (for accessing secure S3 Buckets)
# Set Proxy for PowerShell Web Requests
$proxy = New-Object System.Net.WebProxy("http://${proxy_server_private_ip}:8080", $true)
$webClient = New-Object System.Net.WebClient
$webClient.Proxy = $proxy

# Download AWS CLI Installer
$awsCliInstaller = "C:\Windows\Temp\AWSCLIV2.msi"
$webClient.DownloadFile("https://awscli.amazonaws.com/AWSCLIV2.msi", $awsCliInstaller)

# Install AWS CLI from local file
Start-Process -FilePath msiexec.exe -ArgumentList "/i $awsCliInstaller /qn" -NoNewWindow -Wait

# Verify installation
$awsVersion = & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" --version
Write-Host "AWS CLI Installed: $awsVersion"

# Install OTel Agent
$source = "https://github.com/signalfx/splunk-otel-collector/releases/download/v${collector_version}/splunk-otel-collector-${collector_version}-amd64.msi"
    $dest = "C:\Windows\Temp\splunk-otel-collector-${collector_version}-amd64.msi"
    $WebClient = New-Object System.Net.WebClient
    $WebProxy = New-Object System.Net.WebProxy("http://${proxy_server_private_ip}:8080",$true)
    $WebClient.Proxy = $WebProxy
    $WebClient.DownloadFile($source,$dest)
    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\Windows\Temp\splunk-otel-collector-${collector_version}-amd64.msi /quiet'

$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\splunk-otel-collector"
$valueName = "Environment"
$newValue = @(
    "SPLUNK_ACCESS_TOKEN=${access_token}",
    "SPLUNK_API_URL=https://api.${realm}.signalfx.com",
    "SPLUNK_BUNDLE_DIR=C:\Program Files\Splunk\OpenTelemetry Collector\agent-bundle",
    "SPLUNK_CONFIG=C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml",
    "SPLUNK_HEC_TOKEN=${access_token}",
    "SPLUNK_HEC_URL=https://ingest.${realm}.signalfx.com/v1/log",
    "SPLUNK_INGEST_URL=https://ingest.${realm}.signalfx.com",
    "SPLUNK_REALM=${realm}",
    "SPLUNK_TRACE_URL=https://ingest.${realm}.signalfx.com/v2/trace"
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
$env:HTTPS_PROXY = "http://${proxy_server_private_ip}:8080"
$env:HTTP_PROXY = "http://${proxy_server_private_ip}:8080"
$env:NO_PROXY = "169.254.169.254"
aws s3 cp s3://${s3_bucket_name}/config_files/proxied_windows_server_agent_config.yaml "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"

Stop-Service splunk-otel-collector
Start-Service splunk-otel-collector

Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0

Rename-Computer -NewName $hostname -Force
Restart-Computer -Force

</powershell>