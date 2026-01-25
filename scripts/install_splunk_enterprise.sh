#! /bin/bash
# Version 4.0 - Optimized for Ubuntu 24.04 & Splunk 10.x
# Fully Automated Non-Root Execution

PASSWORD=$1
VERSION=$2
FILENAME=$3
LO_CONNECT_PASSWORD=$4

# 1. Install Dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wget libjemalloc2 libtinfo5

# 2. Download and Install Splunk
wget -O /tmp/$FILENAME "https://download.splunk.com/products/splunk/releases/$VERSION/linux/$FILENAME"
dpkg -i /tmp/$FILENAME

# 3. THE "SAFE" LIBRARY FIX (No global ldconfig)
# We tell Systemd to give Splunk its libraries, but keep them away from the OS
# This prevents breaking system tools like 'curl' and 'python'
mkdir -p /etc/systemd/system/Splunkd.service.d
cat << EOF > /etc/systemd/system/Splunkd.service.d/libs.conf
[Service]
Environment="LD_LIBRARY_PATH=/opt/splunk/lib"
EOF

# 4. Pre-Configuration (Bypass all prompts)
mkdir -p /opt/splunk/etc/system/local
cat << EOF > /opt/splunk/etc/system/local/user-seed.conf
[user_info]
USERNAME = admin
PASSWORD = $PASSWORD
EOF
echo "v1" > /opt/splunk/etc/splunk.license.accepted
touch /opt/splunk/ftr

# 5. Permissions
chown -R splunk:splunk /opt/splunk

# 6. Enable Boot-Start (Must be done while stopped)
# We use LD_LIBRARY_PATH just for this one command
LD_LIBRARY_PATH=/opt/splunk/lib /opt/splunk/bin/splunk enable boot-start -user splunk -systemd-managed 1 --accept-license --answer-yes --no-prompt
systemctl daemon-reload

# 7. Start Splunk via Systemd
# Systemd will now use the LD_LIBRARY_PATH we set in Step 3
echo "Starting Splunk Service..."
systemctl start Splunkd

# 8. WAIT LOOP: Wait for Splunk API (8089)
echo "Waiting for Splunk API (8089) to respond..."
for i in {1..30}; do
  if curl -k -s https://localhost:8089/services/server/info > /dev/null; then
    echo "Splunk API is UP!"
    break
  fi
  echo "Still waiting for API... ($i/30)"
  sleep 5
done

# 9. Configure Splunk via CLI
# We define a variable for the Splunk CLI that includes the necessary library path
S_CLI="sudo -u splunk LD_LIBRARY_PATH=/opt/splunk/lib /opt/splunk/bin/splunk"

# Enable Token Auth
curl -k -u admin:"$PASSWORD" -X POST https://localhost:8089/services/admin/token-auth/tokens_auth -d disabled=false

# Enable Receiver
$S_CLI enable listen 9997 -auth admin:"$PASSWORD"

# Add LOC Role
curl -k -u admin:"$PASSWORD" https://localhost:8089/services/admin/roles \
  -d name=lo_connect \
  -d srchIndexesAllowed=%2A \
  -d imported_roles=user \
  -d srchJobsQuota=12 \
  -d rtSrchJobsQuota=0 \
  -d cumulativeSrchJobsQuota=12 \
  -d cumulativeRTSrchJobsQuota=0 \
  -d srchTimeWin=2592000 \
  -d srchTimeEarliest=7776000 \
  -d srchDiskQuota=1000 \
  -d capabilities=edit_tokens_own

# Add LOC User
$S_CLI add user LO-Connect -role lo_connect -password "$LO_CONNECT_PASSWORD" -auth admin:"$PASSWORD"

# Add Indexes
$S_CLI add index k8s-logs -auth admin:"$PASSWORD"
$S_CLI add index metrics -datatype metric -auth admin:"$PASSWORD"

# Enable HEC
$S_CLI http-event-collector enable -uri https://localhost:8089 -enable-ssl 1 -port 8088 -auth admin:"$PASSWORD"

# 10. Create HEC Tokens
declare -A tokens

function create_hec_token() {
  local name=$1
  local description=$2
  local index=$3

  echo "Creating or fetching token for $name..."

  token_line=$($S_CLI http-event-collector create "$name" \
    -uri https://localhost:8089 \
    -description "$description" \
    -disabled 0 \
    -index "$index" \
    -indexes "$index" \
    -auth admin:"$PASSWORD" 2>&1)

  if echo "$token_line" | grep -q 'already exists'; then
    echo "Token $name already exists, fetching existing token..."
    token_line=$($S_CLI http-event-collector list \
      -uri https://localhost:8089 -auth admin:"$PASSWORD" 2>&1 | grep -A5 "http://$name")
  fi

  token=$(echo "$token_line" | grep -oP '(?<=token=)[\w-]+')
  tokens["$name"]=$token
  echo "Token for $name is $token"
}

create_hec_token "OTEL-K8S" "Used by OTEL K8S" "k8s-logs"
create_hec_token "OTEL" "Used by OTEL" "main"
create_hec_token "HEC-METRICS" "Metrics from OTel via HEC" "metrics"

# 11. Write tokens to JSON file
echo -n '{' > /tmp/hec_tokens.json
first=1
for key in "${!tokens[@]}"; do
  [[ $first -eq 1 ]] && first=0 || echo -n ',' >> /tmp/hec_tokens.json
  echo -n "\"$key\":\"${tokens[$key]}\"" >> /tmp/hec_tokens.json
done
echo '}' >> /tmp/hec_tokens.json
chmod 644 /tmp/hec_tokens.json

# 12. Final Restart via Systemd
systemctl restart Splunkd

# 13. Disable Transparent Huge Pages (THP)
cat << EOF > /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages (THP)
[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
ExecStart=/bin/bash -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now disable-thp.service

# 14. Enable HTTPS for Splunk Web (required for Splunk 10.2.x and above)
echo "Enabling HTTPS for Splunk Web..."
/opt/splunk/bin/splunk enable web-ssl -auth admin:"$PASSWORD"

echo "Splunk 10.x Installation Complete on Ubuntu 24.04."