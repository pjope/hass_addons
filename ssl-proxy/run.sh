#!/usr/bin/with-contenv bashio

set -e

CONFIG_PATH=/data/options.json
SSL_DIR="/etc/nginx/ssl"
NGINX_CONF="/etc/nginx/nginx.conf"

# Create SSL directory
mkdir -p "$SSL_DIR"

# Parse configuration
SERVICES=$(bashio::config 'services')
LOG_LEVEL=$(bashio::config 'log_level' 'info')

bashio::log.info "Starting SSL Proxy Add-on..."

# Generate nginx configuration for each service
cat > "$NGINX_CONF" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

EOF

# Process each service
for service in $(echo "$SERVICES" | jq -r '.[] | @base64'); do
    SERVICE_CONFIG=$(echo "$service" | base64 --decode)
    
    NAME=$(echo "$SERVICE_CONFIG" | jq -r '.name')
    TARGET_HOST=$(echo "$SERVICE_CONFIG" | jq -r '.target_host')
    TARGET_PORT=$(echo "$SERVICE_CONFIG" | jq -r '.target_port')
    SSL_PORT=$(echo "$SERVICE_CONFIG" | jq -r '.ssl_port')
    DOMAIN=$(echo "$SERVICE_CONFIG" | jq -r '.domain')
    REMOVE_CSP=$(echo "$SERVICE_CONFIG" | jq -r '.remove_csp // false')
    WEBSOCKET_SUPPORT=$(echo "$SERVICE_CONFIG" | jq -r '.websocket_support // false')
    
    bashio::log.info "Configuring service: $NAME"
    
    # Generate SSL certificate for this service
    CERT_FILE="$SSL_DIR/${NAME}.crt"
    KEY_FILE="$SSL_DIR/${NAME}.key"
    
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        bashio::log.info "Generating SSL certificate for $NAME"
        openssl req -x509 -newkey rsa:4096 -keyout "$KEY_FILE" -out "$CERT_FILE" \
            -days 365 -nodes -subj "/CN=$DOMAIN"
    fi
    
    # Add nginx server block
    cat >> "$NGINX_CONF" << EOF

    server {
        listen $SSL_PORT ssl http2;
        server_name $DOMAIN;
        
        ssl_certificate $CERT_FILE;
        ssl_certificate_key $KEY_FILE;
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout 5m;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        
        # Remove frame restrictions if requested
EOF

    if [ "$REMOVE_CSP" = "true" ]; then
        cat >> "$NGINX_CONF" << EOF
        proxy_hide_header X-Frame-Options;
        proxy_hide_header Content-Security-Policy;
        add_header X-Frame-Options "ALLOWALL";
EOF
    fi

    cat >> "$NGINX_CONF" << EOF
        
        location / {
            proxy_pass http://$TARGET_HOST:$TARGET_PORT;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
EOF

    if [ "$WEBSOCKET_SUPPORT" = "true" ]; then
        cat >> "$NGINX_CONF" << EOF
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
EOF
    fi

    cat >> "$NGINX_CONF" << EOF
        }
    }
EOF

done

# Close the http block
echo "}" >> "$NGINX_CONF"

bashio::log.info "Generated nginx configuration"

# Test nginx configuration
nginx -t

# Start nginx
bashio::log.info "Starting nginx..."
exec nginx -g "daemon off;"
