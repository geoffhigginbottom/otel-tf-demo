#! /bin/bash
# Version 2.0
## Configure the otel agent to send metrics to Splunk HEC

SPLUNK_IP=$1
HEC_TOKEN=$2

# Check if the SPLUNK_IP is provided
if [ -z "$SPLUNK_IP" ]; then
  echo "Usage: $0 <SPLUNK_IP>"
  exit 1
fi

# Create backup of the original configuration file
cp /etc/otel/collector/splunk-otel-collector.conf /etc/otel/collector/splunk-otel-collector.hec-bak


# Path to the config file
CONFIG_FILE="/etc/otel/collector/splunk-otel-collector.conf"

# New values
NEW_URL="http://${SPLUNK_IP}:8088/services/collector"
NEW_TOKEN="${HEC_TOKEN}"

# Replace SPLUNK_HEC_URL
sed -i "s|^SPLUNK_HEC_URL=.*|SPLUNK_HEC_URL=${NEW_URL}|" "$CONFIG_FILE"

# Replace SPLUNK_HEC_TOKEN
sed -i "s|^SPLUNK_HEC_TOKEN=.*|SPLUNK_HEC_TOKEN=${NEW_TOKEN}|" "$CONFIG_FILE"

# Restart the Splunk OpenTelemetry Collector service to apply changes
systemctl restart splunk-otel-collector