#! /bin/bash
# Version 2.0

UNIVERSAL_FORWARDER_FILENAME=$1
UNIVERSAL_FORWARDER_URL=$2
PASSWORD=$3
HOSTNAME=$4

wget -O $UNIVERSAL_FORWARDER_FILENAME $UNIVERSAL_FORWARDER_URL
sudo dpkg -i $UNIVERSAL_FORWARDER_FILENAME
sudo /opt/splunkforwarder/bin/splunk cmd splunkd rest --noauth POST /services/authentication/users "name=admin&password=$PASSWORD&roles=admin"
sudo /opt/splunkforwarder/bin/splunk start --accept-license
sudo /opt/splunkforwarder/bin/splunk stop
sudo /opt/splunkforwarder/bin/splunk enable boot-start
sudo /opt/splunkforwarder/bin/splunk start

# Wait for Splunk to be ready with a max number of retries
MAX_RETRIES=10
RETRY_COUNT=0
while ! sudo /opt/splunkforwarder/bin/splunk status && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 5
    ((RETRY_COUNT++))
    echo "Retrying... ($RETRY_COUNT/$MAX_RETRIES)"
done

# If the maximum retries are reached and Splunk is still not running, exit with an error
if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Error: Splunk did not start after $MAX_RETRIES attempts."
    exit 1
fi

sudo /opt/splunkforwarder/bin/splunk add monitor /var/log/syslog -auth admin:$PASSWORD          # adds to /opt/splunkforwarder/etc/apps/search/local/inputs.conf

sudo /opt/splunkforwarder/bin/splunk install app /tmp/splunkclouduf.spl -auth admin:$PASSWORD

sudo touch /opt/splunkforwarder/etc/system/local/inputs.conf
echo -e "[default]\n_meta = host.name::$HOSTNAME" | sudo tee /opt/splunkforwarder/etc/system/local/inputs.conf > /dev/null

sudo /opt/splunkforwarder/bin/splunk restart