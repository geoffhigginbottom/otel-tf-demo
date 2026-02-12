#! /bin/bash
# Version 2.5 - Added LetsEncrypt Certificate Generation and Integration for Splunk Web and HEC

## Variables ##
SLOC_CERTPATH=$1
PASSPHRASE=$2
FQDN=$3
COUNTRY=$4
STATE=$5
LOCATION=$6
ORG=$7
LE_CERTPATH=$8

if [ -z "$8" ]; then
    echo "Usage: $0 <sloc_certpath> <passphrase> <fqdn> <country> <state> <location> <org> <le_certpath>"
    exit 1
fi

## CREATE CERT CHAIN FOR SPLUNK LOG OBSERVER CONNECT / SPLUNK INTERCOMMUNICATIONS ##
# LetsEncrypt Certs do not support Subject Alternative Name (SAN) with 127.0.0.1 or localhost, which is required for LOC and Splunk intercommunications.
# So we have to create a Self Signed CA and Server Certificate.
# Starting splunk 10.2.0 kvstore forces the use of the cert listed in [sslConfig] and cannot be overridden in server.conf.

# Create directory and set ownership
/usr/bin/mkdir -p "$SLOC_CERTPATH"
/usr/bin/chown splunk:splunk "$SLOC_CERTPATH"

## Generate Root CA ##
echo "Generating Root CA..."
sudo -u splunk /opt/splunk/bin/splunk cmd openssl genrsa -aes256 -passout pass:"$PASSPHRASE" -out "$SLOC_CERTPATH/myCAPrivateKey.key" 2048

# Create Extension Config
cat > "$SLOC_CERTPATH/ssl-extensions-x509.cnf" <<EOF
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[v3_server]
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:$FQDN
EOF
chown splunk:splunk "$SLOC_CERTPATH/ssl-extensions-x509.cnf"

# Create CA CSR and Self-Sign
sudo -u splunk /opt/splunk/bin/splunk cmd openssl req -new -key "$SLOC_CERTPATH/myCAPrivateKey.key" -out "$SLOC_CERTPATH/myCACertificate.csr" -passin pass:"$PASSPHRASE" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=MyCustomCA"

sudo -u splunk /opt/splunk/bin/splunk cmd openssl x509 -req -in "$SLOC_CERTPATH/myCACertificate.csr" -signkey "$SLOC_CERTPATH/myCAPrivateKey.key" -passin pass:"$PASSPHRASE" -extensions v3_ca -extfile "$SLOC_CERTPATH/ssl-extensions-x509.cnf" -out "$SLOC_CERTPATH/myCACertificate.pem" -days 3650

## Generate Server Key and Certificate ##
echo "Generating Server Certificate..."
# Generate Server Key (Unencrypted for Splunk compatibility)
sudo -u splunk /opt/splunk/bin/splunk cmd openssl genrsa -out "$SLOC_CERTPATH/mySplunkWebPrivateKey.key" 2048

sudo -u splunk /opt/splunk/bin/splunk cmd openssl req -new -key "$SLOC_CERTPATH/mySplunkWebPrivateKey.key" -out "$SLOC_CERTPATH/mySplunkWebCert.csr" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=$FQDN"

# Sign Server Cert with the CA
sudo -u splunk /opt/splunk/bin/splunk cmd openssl x509 -req -in "$SLOC_CERTPATH/mySplunkWebCert.csr" -CA "$SLOC_CERTPATH/myCACertificate.pem" -CAkey "$SLOC_CERTPATH/myCAPrivateKey.key" -passin pass:"$PASSPHRASE" -CAcreateserial -extensions v3_server -extfile "$SLOC_CERTPATH/ssl-extensions-x509.cnf" -out "$SLOC_CERTPATH/mySplunkWebCert.pem" -days 1095

## Combine into Final PEM (CORRECT ORDER) ##
echo "Creating myFinalCert.pem..."
# Order: [Server Cert] [Private Key] [CA Chain]
/usr/bin/cat "$SLOC_CERTPATH/mySplunkWebCert.pem" "$SLOC_CERTPATH/mySplunkWebPrivateKey.key" "$SLOC_CERTPATH/myCACertificate.pem" > "$SLOC_CERTPATH/myFinalCert.pem"

# Create the CA Bundle for trust (Custom CA + Splunk Apps CA)
/usr/bin/cp "$SLOC_CERTPATH/myCACertificate.pem" "$SLOC_CERTPATH/myCABundle.pem"
/usr/bin/cat /opt/splunk/etc/auth/appsCA.pem >> "$SLOC_CERTPATH/myCABundle.pem"

## Update Permissions ##
/usr/bin/chown -R splunk:splunk "$SLOC_CERTPATH"
/usr/bin/chmod 600 "$SLOC_CERTPATH"/*.pem
/usr/bin/chmod 600 "$SLOC_CERTPATH"/*.key

# Cleanup old settings
/usr/bin/sed -i '/serverCert =/d' "/opt/splunk/etc/system/local/server.conf"
/usr/bin/sed -i '/sslRootCAPath =/d' "/opt/splunk/etc/system/local/server.conf"
/usr/bin/sed -i '/sslPassword =/d' "/opt/splunk/etc/system/local/server.conf"

# Add new settings. Note: sslPassword is omitted because the server key is unencrypted.
# If you must use a password, encrypt the key in Step 2 and add sslPassword here.
/usr/bin/sed -i "/\[sslConfig\]/a serverCert = $SLOC_CERTPATH/myFinalCert.pem\nsslRootCAPath = $SLOC_CERTPATH/myCABundle.pem\nenableSplunkdSSL = true" "/opt/splunk/etc/system/local/server.conf"

## Create copy in /tmp for easy access for setting up Log Observer Conect
cp /opt/splunk/etc/auth/sloccerts/mySplunkWebCert.pem /tmp/mySplunkWebCert.pem
chown ubuntu:ubuntu /tmp/mySplunkWebCert.pem





## CREATE CERT CHAIN FOR WEB AND HEC USNG LetsEncrypt ##
# To enable integraions such ThoudsandEyes, we need a valid cert for HEC so are using LetsEncrypt. 
# We will use the same cert for Splunk Web to keep things simple, but you could use the self signed for Splunk Web and LetsEncrypt for HEC if you wanted to avoid cert renewals impacting Splunk Web.
# LetsEncrypt Certs only last for 90 days.  These environments are unlilely to be up for 90 days so this is not a problem.
# However running terraform again with tfa -replace="module.instances[0].null_resource.splunk_cert_gen[0]" will trigger regeneration of the certs if they have expired.

echo "Setting up LetsEncrypt integration..."

apt-get update
apt-get install certbot -y

certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "ghigginb@cisco.com" \
    --no-eff-email \
    -d "$FQDN"

echo "Let's Encrypt setup complete."

# Create directory and set ownership
/usr/bin/mkdir -p "$LE_CERTPATH"
/usr/bin/chown splunk:splunk "$LE_CERTPATH"

## Copy the certs for use with Splunk Web ##
sudo cp /etc/letsencrypt/live/$FQDN/privkey.pem /opt/splunk/etc/auth/letsencrypt/
sudo cp /etc/letsencrypt/live/$FQDN/fullchain.pem /opt/splunk/etc/auth/letsencrypt/

sudo cp /etc/letsencrypt/live/splunk.geoffh.co.uk/privkey.pem /opt/splunk/etc/auth/letsencrypt/
sudo cp /etc/letsencrypt/live/splunk.geoffh.co.uk/fullchain.pem /opt/splunk/etc/auth/letsencrypt/

## Create Chain for HEC ##
cat /etc/letsencrypt/live/$FQDN/privkey.pem /etc/letsencrypt/live/$FQDN/fullchain.pem > $LE_CERTPATH/splunk_hec_combined.pem

## Update Permissions ##
/usr/bin/chown -R splunk:splunk "$LE_CERTPATH"
/usr/bin/chmod 600 "$LE_CERTPATH/"*.pem



## Secure Splunk Web ##
# Cleanup old settings
/usr/bin/sed -i '/sslPassword =/d' "/opt/splunk/etc/system/local/web.conf"

# Add new settings. Note: sslPassword is omitted because the server key is unencrypted.
/usr/bin/sed -i "/\[settings\]/a privKeyPath = $LE_CERTPATH/privkey.pem\ncaCertPath = $LE_CERTPATH/fullchain.pem" "/opt/splunk/etc/system/local/web.conf"



## Secure HEC ##
### Create the file if it does not exist
if [ ! -f /opt/splunk/etc/system/local/inputs.conf ]; then
    sudo touch /opt/splunk/etc/system/local/inputs.conf
    /usr/bin/chown -R splunk:splunk /opt/splunk/etc/system/local/inputs.conf
    /usr/bin/chmod 600 /opt/splunk/etc/system/local/inputs.conf
fi

### Ensure the [http] stanza exists
if ! grep -q "^\[http\]" /opt/splunk/etc/system/local/inputs.conf; then
    echo -e "\n[http]" | sudo tee -a /opt/splunk/etc/system/local/inputs.conf
fi

### Update or Add 'port'
if grep -q "^port =" /opt/splunk/etc/system/local/inputs.conf; then
    sudo sed -i "s|^port =.*|port = 8088|" /opt/splunk/etc/system/local/inputs.conf
else
    sudo sed -i "/^\[http\]/a port = 8088" /opt/splunk/etc/system/local/inputs.conf
fi

### Update or Add 'serverCert'
if grep -q "^serverCert =" /opt/splunk/etc/system/local/inputs.conf; then
    sudo sed -i "s|^serverCert =.*|serverCert = $LE_CERTPATH/splunk_hec_combined.pem|" /opt/splunk/etc/system/local/inputs.conf
else
    sudo sed -i "/^\[http\]/a serverCert = $LE_CERTPATH/splunk_hec_combined.pem" /opt/splunk/etc/system/local/inputs.conf
fi

### Update or Add 'enableSSL'
if grep -q "^enableSSL =" /opt/splunk/etc/system/local/inputs.conf; then
    sudo sed -i "s|^enableSSL =.*|enableSSL = 1|" /opt/splunk/etc/system/local/inputs.conf
else
    sudo sed -i "/^\[http\]/a enableSSL = 1" /opt/splunk/etc/system/local/inputs.conf
fi

echo "Splunk inputs.conf has been updated."

# Restart Splunk to apply changes
echo "Restarting Splunk to apply changes..."
systemctl restart Splunkd