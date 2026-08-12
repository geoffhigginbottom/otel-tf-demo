#! /bin/bash
# Version 3.0
## Configure the otel agent to use the Gateway via the internal address of the LB
## $1=LBURL $2=MYSQL_USER $3=MYSQL_USER_PWD
## Optional: $4=SPLUNK_ENTERPRISE_URL $5=SPLUNK_OPAMP_TOKEN (with Bearer prefix)

LBURL=$1
MYSQL_USER=$2
MYSQL_USER_PWD=$3
SPLUNK_ENTERPRISE_URL=$4
SPLUNK_OPAMP_TOKEN=$5

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
append_if_missing SPLUNK_DISCOVERY_RECEIVERS_mysql_CONFIG_username "$MYSQL_USER"
append_if_missing SPLUNK_DISCOVERY_RECEIVERS_mysql_CONFIG_password "$MYSQL_USER_PWD"

if [ -n "$4" ] && [ -n "$5" ]; then
  printf "Configuring Splunk Enterprise OpAMP...\n"
  append_if_missing SPLUNK_ENTERPRISE_URL "$SPLUNK_ENTERPRISE_URL"
  append_if_missing SPLUNK_OPAMP_TOKEN "$SPLUNK_OPAMP_TOKEN"
  sed -i 's/^  # - opamp\/splunk_enterprise/  - opamp\/splunk_enterprise/' "$AGENT_CONFIG"
fi

systemctl restart splunk-otel-collector
