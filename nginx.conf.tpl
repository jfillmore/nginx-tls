worker_processes 1;

error_log /dev/null crit;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 30;
    gzip on;
    access_log off;

    # no http, please!
    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    # catch-all for hostnames we don't recognize... just punt the traffic away
    server {
        listen 443 ssl;

        server_name _;

        include ssl-includes.conf;

        location / {
            return 301 https://www.duckduckgo.com/;
        }
    }

    # and everything else
    proxy_connect_timeout 30s;
    proxy_send_timeout 900s;
    proxy_read_timeout 900s;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto 'https';
    proxy_set_header Host $host;
    send_timeout 900s;
    include sites-enabled/*.conf;
}
