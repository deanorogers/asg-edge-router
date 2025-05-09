#!/bin/bash

yum update -y
amazon-linux-extras enable nginx1
# yum install -y nginx
yum-config-manager --add-repo https://openresty.org/package/amazon/openresty.repo
yum install -y openresty
openresty -V

#cat <<'EOF_CONFIG' > /etc/nginx/conf.d/default.conf
cat <<'EOF_CONFIG' > /usr/local/openresty/nginx/conf/nginx.conf

  events {
      worker_connections 1024;
  }

  http {
      log_format basic '$remote_addr - $remote_user [$time_local] "$request" '
                       '$status $body_bytes_sent "$http_referer" '
                       '"$http_user_agent" "$http_x_forwarded_for" "http_x_response_code=$sent_http_x_response_code"';

      access_log /usr/local/openresty/nginx/logs/access.log basic;

      server {
          listen 8080;

          location /salutation {
              default_type text/plain;
              content_by_lua_block {
                  ngx.sleep(0.05)
                  ngx.say("Hello, World from " .. ngx.var.hostname)
              }
          }
      }
  }
EOF_CONFIG

systemctl enable openresty
systemctl start openresty