<powershell>

Get-LocalUser -Name "Administrator" | Set-LocalUser -Password (ConvertTo-SecureString -AsPlainText "${windows_server_administrator_pwd}" -Force)

# Install AWS CLI (for accessing secure S3 Buckets)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /qn
# Start-Sleep -Seconds 30  # Wait for the AWS CLI to finish installing

# Confiure MS SQL Server
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$s = new-object('Microsoft.SqlServer.Management.Smo.Server') localhost
$nm = $s.Name
$mode = $s.Settings.LoginMode
$s.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode] 'Mixed'
$s.Alter()
Restart-Service -Name MSSQLSERVER -f

Invoke-Sqlcmd -Query "CREATE LOGIN [signalfxagent] WITH PASSWORD = '${ms_sql_user_pwd}';" -ServerInstance localhost
Invoke-Sqlcmd -Query "GRANT VIEW SERVER STATE TO [${ms_sql_user}];" -ServerInstance localhost
Invoke-Sqlcmd -Query "GRANT VIEW ANY DEFINITION TO [${ms_sql_user}];" -ServerInstance localhost

# Fetch the instance's private IP DNS name
$privateIpDnsName = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/local-hostname").ToString()
# Write the DNS name to a file for verification
Set-Content -Path "C:\PrivateIpDnsName.txt" -Value $privateIpDnsName

$domain = $PrivateIpDnsName -replace "^[^.]+\.", ""

$hostname = "${hostname}"
# Write the hostname to a file for verification
Set-Content -Path "C:\Hostname.txt" -Value $hostname

$fqdn = "$hostname.$domain"
# Write the fqdn to a file for verification
Set-Content -Path "C:\fqdn.txt" -Value $fqdn

# # Install OTel Agent
# & {Set-ExecutionPolicy Bypass -Scope Process -Force;
# $script = ((New-Object System.Net.WebClient).DownloadString('https://dl.signalfx.com/splunk-otel-collector.ps1'));
# $params = @{access_token = "${access_token}";
# realm = "${realm}";
# mode = "agent";
# collector_version = "${collector_version}";
# with_dotnet_instrumentation = "0";
# deployment_env = "${environment}"};
# Invoke-Command -ScriptBlock ([scriptblock]::Create(". {$script} $(&{$args} @params)"))}

# Install OTel Agent with error handling and retries
$attempt = 0
$maxAttempts = 5
$success = $false

# Wait until no other MSI processes are running
while ((Get-Process msiexec -ErrorAction SilentlyContinue)) {
    Write-Host "Another installation is in progress. Waiting..."
    Start-Sleep -Seconds 10
}

# Proceed with installation
$msiPath = "C:\Users\Administrator\AppData\Local\Temp\Splunk\OpenTelemetry Collector\splunk-otel-collector-${collector_version}-amd64.msi"
$logPath = "C:\otel_install.log"

# Run the MSI installer with logging enabled
Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /L*V `"$logPath`"" -NoNewWindow -Wait


while ($attempt -lt $maxAttempts -and -not $success) {
    try {
        Write-Host "Attempting to download and install the Splunk OTel Collector (Attempt $($attempt + 1) of $maxAttempts)..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $script = ((New-Object System.Net.WebClient).DownloadString('https://dl.signalfx.com/splunk-otel-collector.ps1'))
        $params = @{
            access_token = "${access_token}"
            realm = "${realm}"
            mode = "agent"
            collector_version = "${collector_version}"
            with_dotnet_instrumentation = "0"
            deployment_env = "${environment}"
        }
        Invoke-Command -ScriptBlock ([scriptblock]::Create(". {$script} $(&{$args} @params)"))

        # Check if installation was successful
        if (Get-Service -Name "splunk-otel-collector" -ErrorAction SilentlyContinue) {
            Write-Host "Splunk OTel Collector installed successfully."
            $success = $true
        } else {
            Write-Host "Splunk OTel Collector installation failed, retrying..."
        }
    } catch {
        Write-Host "Error during installation: $_.Exception.Message"
    }
    $attempt++
    Start-Sleep -Seconds 15  # Wait before retrying
}

if (-not $success) {
    Write-Host "Failed to install Splunk OTel Collector after $maxAttempts attempts."
    exit 1
}

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
    "SPLUNK_TRACE_URL=https://ingest.${realm}.signalfx.com/v2/trace",
    "SPLUNK_SQL_USER=${ms_sql_user}",
    "SPLUNK_SQL_USER_PWD=${ms_sql_user_pwd}",
    "SPLUNK_GATEWAY_URL=${gateway_lb_dns_name}"
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
aws s3 cp s3://eu-west-3-tfdemo-files/config_files/ms_sql_agent_config.yaml "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"

Stop-Service splunk-otel-collector
Start-Service splunk-otel-collector

Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -name IsInstalled -Value 0

# Install Splunk UF for Splunk Enterprise
if (${splunk_ent_count} -eq 1) {
# Asynchronously download the MSI
Start-Job {
    Invoke-WebRequest -Uri ${universalforwarder_url_windows} -OutFile "C:\Users\Administrator\Documents\splunkforwarder.msi"
}

# Wait for the job to complete
$job = Get-Job | Where-Object {$_.State -eq 'Running'}
Wait-Job $job

Start-Process "msiexec.exe" -ArgumentList "/i ""C:\Users\Administrator\Documents\splunkforwarder.msi"" RECEIVING_INDEXER=${splunk_private_ip}:9997 AGREETOLICENSE=Yes WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 SPLUNKUSERNAME=SplunkAdmin SPLUNKPASSWORD=${splunk_password} INSTALLDIR=""C:\Program Files\SplunkUniversalForwarder"" /qn" -NoNewWindow -Wait

# Create the inputs.conf file to create hostname metadata
$splunk_home = "C:\Program Files\SplunkUniversalForwarder"
$filePath = "$splunk_home\etc\system\local\inputs.conf"
$fileContent = @"
[WinEventLog://System]
_meta = host.name::$privateIpDnsName

[WinEventLog://Security]
_meta = host.name::$privateIpDnsName

[WinEventLog://Application]
_meta = host.name::$privateIpDnsName
"@
Set-Content -Path $filePath -Value $fileContent -Encoding UTF8
}

# Install Splunk UF for Splunk Cloud
if ("${splunk_cloud_enabled}" -eq "true") {
# Asynchronously download the MSI
Start-Job {
    Invoke-WebRequest -Uri ${universalforwarder_url_windows} -OutFile "C:\Users\Administrator\Documents\splunkforwarder.msi"
}

# Wait for the job to complete
$job = Get-Job | Where-Object {$_.State -eq 'Running'}
Wait-Job $job

Start-Process "msiexec.exe" -ArgumentList "/i ""C:\Users\Administrator\Documents\splunkforwarder.msi"" AGREETOLICENSE=Yes WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 SPLUNKUSERNAME=SplunkAdmin SPLUNKPASSWORD=${splunk_password} INSTALLDIR=""C:\Program Files\SplunkUniversalForwarder"" /qn" -NoNewWindow -Wait

# Create the inputs.conf file to create hostname metadata
$filePath = "$splunk_home\etc\system\local\inputs.conf"
$fileContent = @"
[WinEventLog://System]
_meta = host.name::$privateIpDnsName

[WinEventLog://Security]
_meta = host.name::$privateIpDnsName

[WinEventLog://Application]
_meta = host.name::$privateIpDnsName
"@
Set-Content -Path $filePath -Value $fileContent -Encoding UTF8

# Download SplunkCloud Auth File
if ("${splunk_cloud_enabled}" -eq "true") {
  aws s3 cp s3://eu-west-3-tfdemo-files/config_files/splunkclouduf.spl C:\Users\Administrator\Documents\splunkclouduf.spl
}

# Install SplunCloud Credentials Package
if ("${splunk_cloud_enabled}" -eq "true") {
  Set-Location "C:\Program Files\SplunkUniversalForwarder\bin"
  & .\splunk.exe install app "C:\Users\Administrator\Documents\splunkclouduf.spl" -auth "SplunkAdmin:${splunk_password}"
  & .\splunk.exe restart
}
}

Rename-Computer -NewName $hostname -Force
Restart-Computer -Force

</powershell>