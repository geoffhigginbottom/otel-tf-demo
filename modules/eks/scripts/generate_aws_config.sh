#! /bin/bash
# Version 2.0

AWS_ACCESS_KEY_ID=$1
AWS_SECRET_ACCESS_KEY=$2
AWS_SESSION_TOKEN=$3
REGION=$4

mkdir /home/ubuntu/.aws

cat << EOF > /home/ubuntu/.aws/credentials
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
aws_session_token = $AWS_SESSION_TOKEN
EOF

cat << EOF > /home/ubuntu/.aws/config
[default]
region = $REGION
output = json
EOF