ARG BUILD_FROM=ghcr.io/hassio-addons/base:15.0.7
FROM $BUILD_FROM

# Install nginx and openssl
RUN apk add --no-cache \
    nginx \
    openssl \
    jq

# Copy configuration files
COPY run.sh /

# Make run script executable
RUN chmod a+x /run.sh

# Create directories
RUN mkdir -p /etc/nginx/ssl /var/log/nginx /var/lib/nginx/tmp

CMD [ "/run.sh" ]
