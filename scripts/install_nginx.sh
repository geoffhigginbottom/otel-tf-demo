#! /bin/bash

# Download and Install the Latest Updates for the OS
apt-get update
apt-get upgrade -y

# Install Nginx
apt install nginx -y
systemctl start nginx
systemctl enable nginx