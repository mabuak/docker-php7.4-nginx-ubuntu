#!/bin/bash

# Environment
# - DOMAIN_(1,2,3,...)=domain_name|domain_path|type|ssl
# - PHP_FPM_SERVER=php-host:9000

# Nginx Configuration
NGINX_DIR=/etc/nginx
CONF_DIR="$NGINX_DIR/conf.d"
NGINX_WORKER=$(grep -c "processor" /proc/cpuinfo)

cat > "$NGINX_DIR/nginx.conf" <<END
user root;
worker_processes $NGINX_WORKER;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections 1024;
    multi_accept on;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    include /etc/nginx/upstream.conf;
    include /etc/nginx/conf.d/*.conf;
}
END

if [ -z $PHP_FPM_SERVER ]; then
    FPM_SERVER="unix:/run/php/php7.4-fpm.sock;"
else
    FPM_SERVER="$PHP_FPM_SERVER;"
fi

cat > "$NGINX_DIR/upstream.conf" <<END
upstream upstream {
    server $FPM_SERVER
}
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 1100;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
client_max_body_size 50M;
client_body_buffer_size 1m;
client_body_timeout 15;
client_header_timeout 15;
keepalive_timeout 15;
send_timeout 15;
sendfile on;
tcp_nopush on;
tcp_nodelay on;
open_file_cache max=2000 inactive=20s;
open_file_cache_valid 60s;
open_file_cache_min_uses 5;
open_file_cache_errors off;
fastcgi_buffers 256 16k;
fastcgi_buffer_size 128k;
fastcgi_connect_timeout 3s;
fastcgi_send_timeout 120s;
fastcgi_read_timeout 120s;
fastcgi_busy_buffers_size 256k;
fastcgi_temp_file_write_size 256k;
reset_timedout_connection on;
END

# Create virtualhost directory if not exists
[ -d $CONF_DIR ] || mkdir -p $CONF_DIR

# Creating virtualhost
count="0"

while [ true ]
do
    (( count++ ))
    DOMAIN="DOMAIN_$count"
    DOMAIN=${!DOMAIN}
    # Check total domain
    if [ -z ${DOMAIN} ]; then
        break
    fi

    # Check domain format
    DETAIL=(${DOMAIN//|/ })
    if [ ! ${#DETAIL[@]}  -eq 4 ]; then
        echo "Invalid format DOMAIN_$count, format: domain_name|path|ssl|type" >&2
    fi

    DOMAIN_NAME=${DETAIL[0]}
    DOMAIN_PATH=${DETAIL[1]}
    DOMAIN_TYPE=${DETAIL[2]}
    SSL=${DETAIL[3]}

    # Continue if vhost exists
    [ -f "$CONF_DIR/$DOMAIN_NAME.conf" ] && continue

    if [ $DOMAIN_TYPE = "php" ]; then
    cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
    server {
        listen 80;
        server_name $DOMAIN_NAME;
        root $DOMAIN_PATH;
        index index.php;

        location / {
            # try to serve file directly, fallback to index.php
            try_files \$uri /index.php\$is_args\$args;
        }

        location ~ /\.ht {
            deny all;
        }

        location ~ \.php\$ {
            fastcgi_keep_conn on;
            fastcgi_pass upstream;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
            fastcgi_param DOCUMENT_ROOT \$realpath_root;
            include fastcgi_params;
        }
    }
END
    elif [ $DOMAIN_TYPE = "static" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen       80;
    server_name  $DOMAIN_NAME;
    location / {
      root   $DOMAIN_PATH;
      index  index.html;
      try_files \$uri \$uri/ /index.html;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
      root   /usr/share/nginx/html;
    }
}
END
    else
        echo "Invalid type DOMAIN_$count = $DOMAIN_TYPE, available type (php|static)" >&2
    fi

    if [ "$SSL" = "ssl" ] && [ "$DOMAIN_TYPE" = "php" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.ssl.conf" <<END
server {
    listen 443 ssl;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH;
    index index.php;

    ssl on;
    ssl_certificate /etc/nginx/certificate/$DOMAIN_NAME.crt;
    ssl_certificate_key /etc/nginx/certificate/$DOMAIN_NAME.key;

    location / {
        # try to serve file directly, fallback to index.php
        try_files \$uri /index.php\$is_args\$args;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php\$ {
        fastcgi_keep_conn on;
        fastcgi_pass upstream;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
        include fastcgi_params;
    }

    #ssl_stapling on;
    #ssl_stapling_verify on;
    # config to enable HSTS(HTTP Strict Transport Security) https://developer.mozilla.org/en-US/docs/Security/HTTP_Strict_Transport_Security
    # to avoid ssl stripping https://en.wikipedia.org/wiki/SSL_stripping#SSL_stripping
    # also https://hstspreload.org/
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
}
END
    elif [ "$SSL" = "ssl" ] && [ "$DOMAIN_TYPE" = "static" ]; then
cat > "$CONF_DIR/$DOMAIN_NAME.ssl.conf" << END
server {
    listen 443 ssl;
    server_name $DOMAIN_NAME;

    location / {
      root   $DOMAIN_PATH;
      index  index.html;
      try_files $uri $uri/ /index.html;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
      root   /usr/share/nginx/html;
    }

    #ssl on;
    ssl_certificate /etc/nginx/certificate/$DOMAIN_NAME.crt;
    ssl_certificate_key /etc/nginx/certificate/$DOMAIN_NAME.key;

    #ssl_stapling on;
    #ssl_stapling_verify on;

    # config to enable HSTS(HTTP Strict Transport Security) https://developer.mozilla.org/en-US/docs/Security/HTTP_Strict_Transport_Security
    # to avoid ssl stripping https://en.wikipedia.org/wiki/SSL_stripping#SSL_stripping
    # also https://hstspreload.org/
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
}
END
    else
        echo "Url type DOMAIN_$count non ssl type" >&2
    fi

    echo "127.1.0.1 $DOMAIN_NAME" >> /etc/hosts
done

echo "Ready To Start" >&2

# Start PHP and NGINX
php-fpm7.4 -R && nginx -g 'daemon off;'
