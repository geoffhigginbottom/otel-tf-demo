#! /bin/bash
# Version 2.2 - Final KV Store SSL Fix

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

/usr/bin/mkdir -p $CERTPATH

## 1. Generate CA Key and Certificate (CA:TRUE) ##
echo "Generating Root CA..."
/opt/splunk/bin/splunk cmd openssl genrsa -aes256 -passout pass:$PASSPHRASE -out $CERTPATH/myCAPrivateKey.key 2048

# Create Extension Config
cat > $CERTPATH/ssl-extensions-x509.cnf <<EOF
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[v3_server]
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:$FQDN
EOF

/opt/splunk/bin/splunk cmd openssl req -new -key $CERTPATH/myCAPrivateKey.key -out $CERTPATH/myCACertificate.csr -passin pass:$PASSPHRASE -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=MyCustomCA"

/opt/splunk/bin/splunk cmd openssl x509 -req -in $CERTPATH/myCACertificate.csr -signkey $CERTPATH/myCAPrivateKey.key -passin pass:$PASSPHRASE -extensions v3_ca -extfile $CERTPATH/ssl-extensions-x509.cnf -out $CERTPATH/myCACertificate.pem -days 3650

## Ensure Splunk App Store is still trusted
echo "Appending Splunk Apps CA to custom CA bundle"
/usr/bin/cat /opt/splunk/etc/auth/appsCA.pem >> $CERTPATH/myCACertificate.pem

## 2. Generate Server Key and Certificate (CA:FALSE + Auth Extensions) ##
echo "Generating Server Certificate..."
/opt/splunk/bin/splunk cmd openssl genrsa -out $CERTPATH/mySplunkWebPrivateKey.key 2048

/opt/splunk/bin/splunk cmd openssl req -new -key $CERTPATH/mySplunkWebPrivateKey.key -out $CERTPATH/mySplunkWebCert.csr -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=$FQDN"

/opt/splunk/bin/splunk cmd openssl x509 -req -in $CERTPATH/mySplunkWebCert.csr -CA $CERTPATH/myCACertificate.pem -CAkey $CERTPATH/myCAPrivateKey.key -passin pass:$PASSPHRASE -CAcreateserial -extensions v3_server -extfile $CERTPATH/ssl-extensions-x509.cnf -out $CERTPATH/mySplunkWebCert.pem -days 1095

## 3. Combine into Final PEM ##
echo "Creating myFinalCert.pem..."
/usr/bin/cat $CERTPATH/mySplunkWebCert.pem $CERTPATH/myCACertificate.pem $CERTPATH/mySplunkWebPrivateKey.key > $CERTPATH/myFinalCert.pem

## 4. Update Permissions ##
/usr/bin/chown -R splunk:splunk $CERTPATH
/usr/bin/chmod 644 $CERTPATH/*.pem
/usr/bin/chmod 600 $CERTPATH/*.key

## 5. Update Splunk Configuration (The Critical Part) ##
echo "Updating server.conf..."
CONF_FILE="/opt/splunk/etc/system/local/server.conf"

# Remove old SSL settings to prevent conflicts
/usr/bin/sed -i '/serverCert =/d' "$CONF_FILE"
/usr/bin/sed -i '/sslRootCAPath =/d' "$CONF_FILE"
/usr/bin/sed -i '/caCertFile =/d' "$CONF_FILE"
/usr/bin/sed -i '/sslPassword =/d' "$CONF_FILE"

# Add new settings under [sslConfig]
# Note: We set sslPassword to 'password' because we decrypted the key in step 2
/usr/bin/sed -i "/\[sslConfig\]/a serverCert = $CERTPATH/myFinalCert.pem\nsslRootCAPath = $CERTPATH/myCACertificate.pem\ncaCertFile = $CERTPATH/myCACertificate.pem\nsslPassword = password" "$CONF_FILE"

# Restart Splunk
echo "Restarting Splunk..."
/opt/splunk/bin/splunk restart