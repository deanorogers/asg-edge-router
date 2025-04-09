#!/bin/bash

yum update -y
amazon-linux-extras enable nginx1
yum install -y nginx

cat <<'EOF_CONFIG' > /etc/nginx/conf.d/default.conf

  log_format basic '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for" "http_x_response_code=$sent_http_x_response_code"';

   access_log /var/log/nginx/access.log basic;

   server {
        listen 8080;

        location /salutation {
            add_header Content-Type text/plain;
            return 200 'Hello, World from $hostname \n';
        }
    }
EOF_CONFIG

systemctl start nginx