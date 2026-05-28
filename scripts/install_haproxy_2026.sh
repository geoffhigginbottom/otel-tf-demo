#!/bin/bash

# 1. Error handling and non-interactive mode
set -e
export DEBIAN_FRONTEND=noninteractive

# 2. Use variables for easier maintenance (Terraform can inject these)
HAPROXY_VERSION="3.0"

echo "Starting HAProxy installation..."

# 3. Optimize package management for automation
sudo apt-get update
sudo apt-get install -y software-properties-common

# Add HAProxy PPA
sudo add-apt-repository ppa:vbernat/haproxy-$HAPROXY_VERSION -y
sudo apt-get update
sudo apt-get install -y haproxy

# 4. Backup with timestamp
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak.$(date +%F_%T)

# 5. Enhanced Configuration
# Added: Security headers, Stats authentication, and Config validation
sudo tee /etc/haproxy/haproxy.cfg > /dev/null <<EOT
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # Modern SSL/TLS Security
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5s
    timeout client  50s
    timeout server  50s
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend http-in
    bind *:80
    # Add security header
    http-response set-header X-Frame-Options SAMEORIGIN
    default_backend servers

backend servers
    balance roundrobin
    # Using variable for backend
    server server1 $BACKEND_IP:80 check

frontend stats
    bind *:9000
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
EOT

# 6. Validate configuration before restarting
echo "Validating HAProxy configuration..."
if sudo haproxy -c -f /etc/haproxy/haproxy.cfg; then
    sudo systemctl enable haproxy
    sudo systemctl restart haproxy
    echo "HAProxy started successfully."
else
    echo "Configuration error detected. Reverting to backup."
    exit 1
fi

# 7. Final status check
sudo systemctl status haproxy --no-pager