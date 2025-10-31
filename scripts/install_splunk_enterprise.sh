#! /bin/bash
# Version 2.0

PASSWORD=$1
VERSION=$2
FILENAME=$3
LO_CONNECT_PASSWORD=$4

# wget -O /tmp/$FILENAME "https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=$VERSION&product=splunk&filename=$FILENAME&wget=true"
wget -O /tmp/$FILENAME "https://download.splunk.com/products/splunk/releases/$VERSION/linux/$FILENAME"
dpkg -i /tmp/$FILENAME
/opt/splunk/bin/splunk cmd splunkd rest --noauth POST /services/authentication/users "name=admin&password=$PASSWORD&roles=admin"
/opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd $PASSWORD
/opt/splunk/bin/splunk enable boot-start

#Enable Token Auth
curl -k -u admin:$PASSWORD -X POST https://localhost:8089/services/admin/token-auth/tokens_auth -d disabled=false

#Enable Receiver
/opt/splunk/bin/splunk enable listen 9997 -auth admin:$PASSWORD

#Add LOC Role
curl -k -u admin:$PASSWORD https://localhost:8089/services/admin/roles \
  -d name=lo_connect\
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

#Add LOC User
/opt/splunk/bin/splunk add user LO-Connect -role lo_connect -password $LO_CONNECT_PASSWORD -auth admin:$PASSWORD

#Add Indexes
/opt/splunk/bin/splunk add index k8s-logs -auth admin:$PASSWORD
/opt/splunk/bin/splunk add index metrics -datatype metric -auth admin:$PASSWORD

#Change webport to 8000 to avoid conflict with Splunk Offices WiFi Restrictons
/opt/splunk/bin/splunk set web-port 80

#Enable HEC
/opt/splunk/bin/splunk http-event-collector enable -uri https://localhost:8089 -enable-ssl 0 -port 8088 -auth admin:$PASSWORD

#Create HEC Tokens
declare -A tokens

function create_hec_token() {
  local name=$1
  local description=$2
  local index=$3

  echo "Creating or fetching token for $name..."

  # Try to create the token and capture output (including errors)
  token_line=$(/opt/splunk/bin/splunk http-event-collector create "$name" \
    -uri https://localhost:8089 \
    -description "$description" \
    -disabled 0 \
    -index "$index" \
    -indexes "$index" \
    -auth admin:$PASSWORD 2>&1)

  # If token already exists, fetch token info using list command
  if echo "$token_line" | grep -q 'already exists'; then
    echo "Token $name already exists, fetching existing token..."
    token_line=$(/opt/splunk/bin/splunk http-event-collector list \
      -uri https://localhost:8089 -auth admin:$PASSWORD 2>&1 | grep -A5 "http://$name")
  fi

  # Extract the token UUID from output (look for token=UUID)
  token=$(echo "$token_line" | grep -oP '(?<=token=)[\w-]+')

  # Save token in associative array
  tokens["$name"]=$token

  echo "Token for $name is $token"
}

# Create or get tokens
create_hec_token "OTEL-K8S" "Used by OTEL K8S" "k8s-logs"
create_hec_token "OTEL" "Used by OTEL" "main"
create_hec_token "HEC-METRICS" "Metrics from OTel via HEC" "metrics"

# Write tokens to JSON file for Terraform to consume
echo -n '{' > /tmp/hec_tokens.json
first=1
for key in "${!tokens[@]}"; do
  [[ $first -eq 1 ]] && first=0 || echo -n ',' >> /tmp/hec_tokens.json
  echo -n "\"$key\":\"${tokens[$key]}\"" >> /tmp/hec_tokens.json
done
echo '}' >> /tmp/hec_tokens.json

echo "Tokens written to /tmp/hec_tokens.json"