#! /bin/bash
# Version 3.0
## Configure the otel agent to use the Gateway via the internal address of the LB
## Optional: $2=SPLUNK_ENTERPRISE_URL $3=SPLUNK_OPAMP_TOKEN (with Bearer prefix)

LBURL=$1
SPLUNK_ENTERPRISE_URL=$2
SPLUNK_OPAMP_TOKEN=$3

CONFIG_FILE="/etc/otel/collector/splunk-otel-collector.conf"
AGENT_CONFIG="/etc/otel/collector/agent_config.yaml"

if [ -z "$1" ]; then
  printf "LB URL not set, exiting ...\n"
  exit 1
else
  printf "LB URL Variable Detected...\n"
fi

cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

append_if_missing() {
  local key=$1
  local value=$2
  if ! grep -q "^${key}=" "$CONFIG_FILE"; then
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

append_if_missing SPLUNK_GATEWAY_URL "$LBURL"

if [ -n "$2" ] && [ -n "$3" ]; then
  printf "Configuring Splunk Enterprise OpAMP...\n"
  append_if_missing SPLUNK_ENTERPRISE_URL "$SPLUNK_ENTERPRISE_URL"
  append_if_missing SPLUNK_OPAMP_TOKEN "$SPLUNK_OPAMP_TOKEN"
  sed -i 's/^  # - opamp\/splunk_enterprise/  - opamp\/splunk_enterprise/' "$AGENT_CONFIG"
fi

systemctl restart splunk-otel-collector
