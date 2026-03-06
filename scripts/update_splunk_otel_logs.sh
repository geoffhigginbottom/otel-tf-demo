#! /bin/bash
# Version 1.1
## Configure the otel agent to send Logs to Splunk via HEC and OTLP

SPLUNK_FQDN=$1
HEC_TOKEN=$2

# Check if both SPLUNK_FQDN and HEC_TOKEN are provided
if [ -z "$SPLUNK_FQDN" ] || [ -z "$HEC_TOKEN" ]; then
  echo "Usage: $0 <SPLUNK_FQDN> <HEC_TOKEN>"
  exit 1
fi

# Path to the config file
CONFIG_FILE="/etc/otel/collector/splunk-otel-collector.conf"

# Create backup of the original configuration file
cp /etc/otel/collector/splunk-otel-collector.conf /etc/otel/collector/splunk-otel-collector.otel_logs_bak


# Replace SPLUNK_HEC_URL
sed -i "s|^SPLUNK_HEC_URL=.*|SPLUNK_HEC_URL=https://${SPLUNK_FQDN}:8088/services/collector|" "$CONFIG_FILE"

# Replace SPLUNK_HEC_TOKEN
sed -i "s|^SPLUNK_HEC_TOKEN=.*|SPLUNK_HEC_TOKEN=${HEC_TOKEN}|" "$CONFIG_FILE"


# Append additional configuration lines
echo "SPLUNK_FILE_STORAGE_EXTENSION_PATH=/tmp" >> "$CONFIG_FILE"
echo "SPLUNK_OTLP_URL=${SPLUNK_FQDN}" >> "$CONFIG_FILE"

# Restart the Splunk OpenTelemetry Collector service to apply changes
systemctl restart splunk-otel-collector
