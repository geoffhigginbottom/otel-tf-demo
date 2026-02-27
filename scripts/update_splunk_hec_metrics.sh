#! /bin/bash
# Version 2.1
## Configure the otel agent to send metrics to Splunk HEC

SPLUNK_FQDN=$1
HEC_METRICS_TOKEN=$2

# Check if the SPLUNK_FQDN is provided
if [ -z "$SPLUNK_FQDN" ]; then
  echo "Usage: $0 <SPLUNK_FQDN>"
  exit 1
fi

# Create backup of the original configuration file
cp /etc/otel/collector/splunk-otel-collector.conf /etc/otel/collector/splunk-otel-collector.hec-bak


# Path to the config file
CONFIG_FILE="/etc/otel/collector/splunk-otel-collector.conf"
AGENT_FILE="/etc/otel/collector/agent_config.yaml"

# New values
NEW_URL="https://${SPLUNK_FQDN}:8088/services/collector"
NEW_TOKEN="${HEC_METRICS_TOKEN}"

# Replace SPLUNK_HEC_URL
sed -i "s|^SPLUNK_HEC_URL=.*|SPLUNK_HEC_URL=${NEW_URL}|" "$CONFIG_FILE"

# # Replace SPLUNK_HEC_TOKEN
# sed -i "s|^SPLUNK_HEC_TOKEN=.*|SPLUNK_HEC_TOKEN=${NEW_TOKEN}|" "$CONFIG_FILE"

# Add SPLUNK_HEC_METRICS_TOKEN if it doesn't exist
if ! grep -q "^SPLUNK_HEC_METRICS_TOKEN=" "$CONFIG_FILE"; then
  echo "SPLUNK_HEC_METRICS_TOKEN=${NEW_TOKEN}" >> "$CONFIG_FILE"
else
  sed -i "s|^SPLUNK_HEC_METRICS_TOKEN=.*|SPLUNK_HEC_METRICS_TOKEN=${NEW_TOKEN}|" "$CONFIG_FILE"
fi

# Activate the splunk_hec/metrics exporter in the agent config if not already active
TARGET_FILE="$AGENT_FILE"

# Check if file exists
if [ -f "$TARGET_FILE" ]; then
    # Use | as delimiter to avoid escaping the / in splunk_hec/metrics
    # This specifically targets the 6-space indentation
    sed -i 's|      # - splunk_hec/metrics|      - splunk_hec/metrics|' "$TARGET_FILE"
    echo "Successfully uncommented splunk_hec/metrics in $TARGET_FILE"
else
    echo "Error: $TARGET_FILE not found."
fi

# Restart the Splunk OpenTelemetry Collector service to apply changes
systemctl restart splunk-otel-collector