#!/bin/bash

# 1. Error handling and non-interactive mode
set -e
export DEBIAN_FRONTEND=noninteractive

# 2. Use variables for easier maintenance
HAPROXY_VERSION="3.0"

echo "Starting HAProxy installation and logging setup..."

# 3. Optimize package management
sudo apt-get update
sudo apt-get install -y software-properties-common rsyslog

# Add HAProxy PPA
sudo add-apt-repository ppa:vbernat/haproxy-$HAPROXY_VERSION -y
sudo apt-get update
sudo apt-get install -y haproxy

# 4. Configure System Logging (rsyslog)
# This directs HAProxy logs to a dedicated file instead of cluttering /var/log/syslog
echo "Configuring rsyslog for HAProxy..."
sudo tee /etc/rsyslog.d/49-haproxy.conf > /dev/null <<EOF
# Log local0 (traffic) and local1 (errors/notices) to haproxy.log
local0.* -/var/log/haproxy.log
local1.* -/var/log/haproxy.log

# Stop processing these logs so they don't also go to /var/log/syslog
& stop
EOF

# Restart rsyslog to apply changes
sudo systemctl restart rsyslog

# 5. Configure Log Rotation
# Prevents the VM disk from filling up by keeping only 7 days of logs
echo "Configuring log rotation..."
sudo tee /etc/logrotate.d/haproxy > /dev/null <<EOF
/var/log/haproxy.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF

# 6. Enhanced HAProxy Configuration
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak.$(date +%F_%T)

sudo tee /etc/haproxy/haproxy.cfg > /dev/null <<EOT
global
    # Send logs to the local syslog (rsyslog)
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
    # Use global log settings
    log     global
    mode    http
    # option httplog provides detailed info (Client IP, timers, status codes)
    option  httplog
    # dontlognull prevents logging of empty/prober connections (reduces noise)
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
    http-response set-header X-Frame-Options SAMEORIGIN
    default_backend servers

backend servers
    balance roundrobin
    server server1 127.0.0.1:80 check

frontend stats
    bind *:9000
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
EOT

# 7. Validate and Start
echo "Validating HAProxy configuration..."
if sudo haproxy -c -f /etc/haproxy/haproxy.cfg; then
    sudo systemctl enable haproxy
    sudo systemctl restart haproxy
    echo "HAProxy started successfully with logging enabled."
else
    echo "Configuration error detected!"
    exit 1
fi

# 8. Final status check
sudo systemctl status haproxy --no-pager
echo "Logs are being written to /var/log/haproxy.log"