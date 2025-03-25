#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Update and upgrade system
sudo apt-get update && sudo apt-get upgrade -y

# Add HAProxy PPA repository (using a more recent version)
sudo add-apt-repository ppa:vbernat/haproxy-2.8 -y
sudo apt-get update

# Install HAProxy
sudo apt-get install -y haproxy

# Backup existing configuration
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.bak

# Write new HAProxy configuration
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
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend http
    bind *:80
    default_backend servers

backend servers
    balance roundrobin
    server server1 127.0.0.1:80 check

# Add stats section
frontend stats
    bind *:9000
    mode http
    stats enable
    stats uri /stats
EOT

# Enable and start HAProxy
sudo systemctl enable haproxy
sudo systemctl restart haproxy

# Confirm HAProxy is running
sudo systemctl status haproxy --no-pager
