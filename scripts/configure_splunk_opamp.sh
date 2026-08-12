#! /bin/bash
# Configure Splunk Enterprise for OpAMP collector management and create auth token

PASSWORD=$1
SERVER_CONF=/opt/splunk/etc/system/local/server.conf
TOKEN_FILE=/tmp/opamp_token.json
S_CLI="sudo -u splunk LD_LIBRARY_PATH=/opt/splunk/lib /opt/splunk/bin/splunk"

if [ -z "$PASSWORD" ]; then
  echo "Usage: $0 <splunk_admin_password>"
  exit 1
fi

if [ -f "$TOKEN_FILE" ]; then
  token=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE')).get('token',''))" 2>/dev/null || true)
  if [ -n "$token" ]; then
    echo "OpAMP token already configured at $TOKEN_FILE"
    exit 0
  fi
fi

mkdir -p "$(dirname "$SERVER_CONF")"
touch "$SERVER_CONF"

needs_restart=false

if ! grep -q '^\[data_management\]' "$SERVER_CONF" 2>/dev/null; then
  cat >> "$SERVER_CONF" <<'EOF'

[data_management]
otel_collector_management_enabled = true
EOF
  needs_restart=true
elif ! grep -q 'otel_collector_management_enabled = true' "$SERVER_CONF"; then
  if grep -q 'otel_collector_management_enabled' "$SERVER_CONF"; then
    sed -i 's/otel_collector_management_enabled = .*/otel_collector_management_enabled = true/' "$SERVER_CONF"
  else
    sed -i '/^\[data_management\]/a otel_collector_management_enabled = true' "$SERVER_CONF"
  fi
  needs_restart=true
else
  echo "OpAMP data_management already enabled in server.conf"
fi

if [ "$needs_restart" = true ]; then
  echo "Restarting Splunk to enable OpAMP collector management..."
  systemctl restart Splunkd
else
  echo "Skipping Splunk restart; server.conf already configured"
fi

wait_for_splunk_api() {
  echo "Waiting for Splunk API (8089) to respond..."
  for i in {1..30}; do
    if curl -k -s https://localhost:8089/services/server/info > /dev/null; then
      echo "Splunk API is UP!"
      return 0
    fi
    echo "Still waiting for API... ($i/30)"
    sleep 5
  done
  echo "ERROR: Splunk API did not become available in time"
  return 1
}

get_kvstore_status() {
  local status=""

  status=$(curl -sk -u admin:"$PASSWORD" \
    "https://localhost:8089/services/kvstore/status?output_mode=json" 2>/dev/null \
    | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    content = data['entry'][0]['content']
    current = content.get('current', content)
    print(current.get('status', ''))
except Exception:
    print('')
" 2>/dev/null)

  if [ "$status" = "ready" ]; then
    echo "ready"
    return
  fi

  if $S_CLI show kvstore-status -auth admin:"$PASSWORD" 2>/dev/null | grep -E '^[[:space:]]+status[[:space:]]*:' | grep -qi 'ready'; then
    echo "ready"
    return
  fi

  echo "${status:-starting}"
}

wait_for_kvstore() {
  echo "Waiting for KV Store to be ready (required for token auth)..."
  for i in {1..60}; do
    status=$(get_kvstore_status)
    if [ "$status" = "ready" ]; then
      echo "KV Store is ready!"
      # Token auth can lag KV Store status briefly after a restart
      sleep 15
      return 0
    fi
    echo "KV Store status: ${status:-unknown} ($i/60)"
    sleep 10
  done
  echo "ERROR: KV Store did not become ready in time"
  return 1
}

create_opamp_token() {
  curl -sk -u admin:"$PASSWORD" -X POST \
    "https://localhost:8089/services/authorization/tokens?output_mode=json" \
    --data name=admin \
    --data audience=general \
    --data-urlencode expires_on=+30d
}

parse_token() {
  python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['entry'][0]['content']['token'])
except Exception:
    print('')
" 2>/dev/null
}

wait_for_splunk_api || exit 1
wait_for_kvstore || exit 1

echo "Creating OpAMP authentication token..."
token=""
response=""
for attempt in {1..18}; do
  response=$(create_opamp_token)
  token=$(parse_token <<< "$response")
  if [ -n "$token" ]; then
    break
  fi
  if echo "$response" | grep -qi "KVStore is not ready"; then
    echo "Token auth waiting on KV Store, retrying ($attempt/18)..."
    sleep 10
    continue
  fi
  echo "Token creation attempt $attempt failed: $response"
  sleep 10
done

if [ -z "$token" ]; then
  echo "Failed to create OpAMP token"
  echo "$response"
  exit 1
fi

echo "{\"token\":\"$token\"}" > "$TOKEN_FILE"
chmod 644 "$TOKEN_FILE"
echo "OpAMP token written to $TOKEN_FILE"
