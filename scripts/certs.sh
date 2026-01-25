#! /bin/bash
# Version 2.4 - Fixed Chain Order & Password Logic

## Variables ##
CERTPATH=$1
PASSPHRASE=$2
FQDN=$3
COUNTRY=$4
STATE=$5
LOCATION=$6
ORG=$7

if [ -z "$7" ]; then
    echo "Usage: $0 <path> <passphrase> <fqdn> <country> <state> <location> <org>"
    exit 1
fi

# Create directory and set ownership
/usr/bin/mkdir -p "$CERTPATH"
/usr/bin/chown splunk:splunk "$CERTPATH"

## 1. Generate Root CA ##
echo "Generating Root CA..."
# Generate CA Key (Encrypted)
sudo -u splunk /opt/splunk/bin/splunk cmd openssl genrsa -aes256 -passout pass:"$PASSPHRASE" -out "$CERTPATH/myCAPrivateKey.key" 2048

# Create Extension Config
cat > "$CERTPATH/ssl-extensions-x509.cnf" <<EOF
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[v3_server]
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:$FQDN
EOF
chown splunk:splunk "$CERTPATH/ssl-extensions-x509.cnf"

# Create CA CSR and Self-Sign
sudo -u splunk /opt/splunk/bin/splunk cmd openssl req -new -key "$CERTPATH/myCAPrivateKey.key" -out "$CERTPATH/myCACertificate.csr" -passin pass:"$PASSPHRASE" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=MyCustomCA"

sudo -u splunk /opt/splunk/bin/splunk cmd openssl x509 -req -in "$CERTPATH/myCACertificate.csr" -signkey "$CERTPATH/myCAPrivateKey.key" -passin pass:"$PASSPHRASE" -extensions v3_ca -extfile "$CERTPATH/ssl-extensions-x509.cnf" -out "$CERTPATH/myCACertificate.pem" -days 3650

## 2. Generate Server Key and Certificate ##
echo "Generating Server Certificate..."
# Generate Server Key (Unencrypted for Splunk compatibility)
sudo -u splunk /opt/splunk/bin/splunk cmd openssl genrsa -out "$CERTPATH/mySplunkWebPrivateKey.key" 2048

sudo -u splunk /opt/splunk/bin/splunk cmd openssl req -new -key "$CERTPATH/mySplunkWebPrivateKey.key" -out "$CERTPATH/mySplunkWebCert.csr" -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=$FQDN"

# Sign Server Cert with the CA
sudo -u splunk /opt/splunk/bin/splunk cmd openssl x509 -req -in "$CERTPATH/mySplunkWebCert.csr" -CA "$CERTPATH/myCACertificate.pem" -CAkey "$CERTPATH/myCAPrivateKey.key" -passin pass:"$PASSPHRASE" -CAcreateserial -extensions v3_server -extfile "$CERTPATH/ssl-extensions-x509.cnf" -out "$CERTPATH/mySplunkWebCert.pem" -days 1095

## 3. Combine into Final PEM (CORRECT ORDER) ##
echo "Creating myFinalCert.pem..."
# Order: [Server Cert] [Private Key] [CA Chain]
/usr/bin/cat "$CERTPATH/mySplunkWebCert.pem" "$CERTPATH/mySplunkWebPrivateKey.key" "$CERTPATH/myCACertificate.pem" > "$CERTPATH/myFinalCert.pem"

# Create the CA Bundle for trust (Custom CA + Splunk Apps CA)
/usr/bin/cp "$CERTPATH/myCACertificate.pem" "$CERTPATH/myCABundle.pem"
/usr/bin/cat /opt/splunk/etc/auth/appsCA.pem >> "$CERTPATH/myCABundle.pem"

## 4. Update Permissions ##
/usr/bin/chown -R splunk:splunk "$CERTPATH"
/usr/bin/chmod 644 "$CERTPATH"/*.pem
/usr/bin/chmod 600 "$CERTPATH"/*.key

## 5. Update Splunk Configuration ##
echo "Updating server.conf..."
CONF_FILE="/opt/splunk/etc/system/local/server.conf"

# Cleanup old settings
/usr/bin/sed -i '/serverCert =/d' "$CONF_FILE"
/usr/bin/sed -i '/sslRootCAPath =/d' "$CONF_FILE"
/usr/bin/sed -i '/sslPassword =/d' "$CONF_FILE"

# Add new settings. Note: sslPassword is omitted because the server key is unencrypted.
# If you must use a password, encrypt the key in Step 2 and add sslPassword here.
/usr/bin/sed -i "/\[sslConfig\]/a serverCert = $CERTPATH/myFinalCert.pem\nsslRootCAPath = $CERTPATH/myCABundle.pem" "$CONF_FILE"

echo "Restarting Splunk..."
systemctl restart Splunkd