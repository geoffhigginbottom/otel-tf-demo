#! /bin/bash
# Version 2.0

## Variables ##
CERTPATH=$1
PASSPHRASE=$2
FQDN=$3
COUNTRY=$4
STATE=$5
LOCATION=$6
ORG=$7

## Create folder for scripts ##
echo "Creating folder $CERTPATH"
/usr/bin/mkdir $CERTPATH

## Generate a new root certificate to be your Certificate Authority ##
echo "Generating root cert for CA"
/opt/splunk/bin/splunk cmd openssl genrsa -aes256 -passout pass:$PASSPHRASE -out $CERTPATH/myCAPrivateKey.key 2048

## Generate a certificate signing request using the root certificate private key myCAPrivateKey.key ##
echo "Gemerating CSR"
/opt/splunk/bin/splunk cmd openssl req -new \
  -key $CERTPATH/myCAPrivateKey.key \
  -out $CERTPATH/myCACertificate.csr \
  -passin pass:$PASSPHRASE \
  -passout pass:$PASSPHRASE \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=$FQDN"


## Use the CSR file to generate a new root certificate and sign it with myCAPrivateKey.key ##
echo "Generate new signed root cert"
echo -e "# ssl-extensions-x509.cnf\n[v3_ca]\nbasicConstraints = CA:FALSE\nkeyUsage = digitalSignature, keyEncipherment\nsubjectAltName = DNS:$FQDN" > $CERTPATH/ssl-extensions-x509.cnf

/opt/splunk/bin/splunk cmd openssl x509 -req \
  -in $CERTPATH/myCACertificate.csr \
  -signkey $CERTPATH/myCAPrivateKey.key \
  -passin pass:$PASSPHRASE \
  -extensions v3_ca \
  -extfile $CERTPATH/ssl-extensions-x509.cnf \
  -out $CERTPATH/myCACertificate.pem \
  -days 3650

## Create a new private key ##
echo "Creating new private key"
/opt/splunk/bin/splunk cmd openssl genrsa \
  -aes256 \
  -passout pass:$PASSPHRASE \
  -out $CERTPATH/mySplunkWebPrivateKey.key 2048 \

## Remove Password from mySplunkWebPrivateKey.key ##
echo "Removing password from private key"
/opt/splunk/bin/splunk cmd openssl rsa \
  -in $CERTPATH/mySplunkWebPrivateKey.key \
  -passin pass:$PASSPHRASE \
  -out $CERTPATH/mySplunkWebPrivateKey.key

## Create a new certificate signature request using mySplunkWebPrivateKey.key ##
echo "Creating new csr using private key"
/opt/splunk/bin/splunk cmd openssl req -new \
  -key $CERTPATH/mySplunkWebPrivateKey.key \
  -passin pass:$PASSPHRASE \
  -out $CERTPATH/mySplunkWebCert.csr \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORG/CN=$FQDN"

## Sign the CSR with the root certificate private key myCAPrivateKey.key ##
echo "Signing cst with root cert private key"
/opt/splunk/bin/splunk cmd openssl x509 -req \
  -in $CERTPATH/mySplunkWebCert.csr \
  -passin pass:$PASSPHRASE \
  -CA $CERTPATH/myCACertificate.pem \
  -extensions v3_ca \
  -extfile $CERTPATH/ssl-extensions-x509.cnf \
  -CAkey $CERTPATH/myCAPrivateKey.key \
  -CAcreateserial \
  -out $CERTPATH/mySplunkWebCert.pem \
  -days 1095

## Combine the server certificate and public certificates into a single certificate file ##
echo "Combining certs into a single pem file"
/usr/bin/cat $CERTPATH/mySplunkWebCert.pem $CERTPATH/myCACertificate.pem > $CERTPATH/mySplunkWebCertificate.pem
/usr/bin/cat $CERTPATH/mySplunkWebCertificate.pem $CERTPATH/mySplunkWebPrivateKey.key > $CERTPATH/myFinalCert.pem

## Fix permissions ##
echo "Updating permissions"
/usr/bin/chown -R splunk:splunk $CERTPATH

## Update /opt/splunk/etc/system/local/server.conf
echo "Updating Splunk config to use certs"
/usr/bin/sed -i "/^sslPassword.*/a serverCert = $CERTPATH/myFinalCert.pem" /opt/splunk/etc/system/local/server.conf
/usr/bin/sed -i "/^serverCert.*/a requireClientCert = false" /opt/splunk/etc/system/local/server.conf
/usr/bin/sed -i "/^pass4SymmKey.*/a serverName = $FQDN" /opt/splunk/etc/system/local/server.conf

# Restart Splunk
echo "restarting Splunk"
/opt/splunk/bin/splunk restart