#! /bin/bash
# Version 2.0

UNIVERSAL_FORWARDER_FILENAME=$1
VERSION=$2
PASSWORD=$3
SPLUNK_IP=$4
HOSTNAME=$5

DOWNLOAD_URL="https://download.splunk.com/products/universalforwarder/releases/$VERSION/linux/$UNIVERSAL_FORWARDER_FILENAME"
DOWNLOAD_PATH="/tmp/$UNIVERSAL_FORWARDER_FILENAME"
DOWNLOAD_MAX_RETRIES=5
DOWNLOAD_RETRY_COUNT=0
DOWNLOAD_SLEEP_TIME=10

download_file() {
    while [ $DOWNLOAD_RETRY_COUNT -lt $DOWNLOAD_MAX_RETRIES ]; do
        echo "Downloading Splunk Universal Forwarder (Attempt $((DOWNLOAD_RETRY_COUNT + 1))/$DOWNLOAD_MAX_RETRIES)..."
        wget -O "$DOWNLOAD_PATH" "$DOWNLOAD_URL"

        if [ $? -eq 0 ] && [ -f "$DOWNLOAD_PATH" ]; then
            echo "Download successful!"
            return 0
        fi

        echo "Download failed. Retrying in $DOWNLOAD_SLEEP_TIME seconds..."
        ((DOWNLOAD_RETRY_COUNT++))
        sleep $DOWNLOAD_SLEEP_TIME
    done

    echo "Error: Download failed after $DOWNLOAD_MAX_RETRIES attempts."
    exit 1
}

# Start the download process
download_file

sudo dpkg -i /tmp/$UNIVERSAL_FORWARDER_FILENAME
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

sudo /opt/splunkforwarder/bin/splunk add forward-server $SPLUNK_IP:9997 -auth admin:$PASSWORD    # adds to /opt/splunkforwarder/etc/system/local/outputs.conf
sudo /opt/splunkforwarder/bin/splunk add monitor /var/log/syslog -auth admin:$PASSWORD           # adds to /opt/splunkforwarder/etc/apps/search/local/inputs.conf
sudo /opt/splunkforwarder/bin/splunk add monitor /var/log/mysql -auth admin:$PASSWORD          # adds to /opt/splunkforwarder/etc/apps/search/local/inputs.conf
sudo /opt/splunkforwarder/bin/splunk add monitor /var/lib/mysql -auth admin:$PASSWORD

sudo touch /opt/splunkforwarder/etc/system/local/inputs.conf
echo -e "[default]\n_meta = host.name::$HOSTNAME" | sudo tee /opt/splunkforwarder/etc/system/local/inputs.conf > /dev/null

sudo /opt/splunkforwarder/bin/splunk restart