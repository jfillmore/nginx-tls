upstream demo-backend {
    server %%DEMO_APP_HOST%% max_fails=0;
}

# e.g. python back-end API (standalone)
server {
    listen 443 ssl;
    server_name %%DEMO_APP%%;
    include ssl-includes.conf;

    location / {
        proxy_pass http://demo-backend;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host $host;
    }
}


# website
server {
    listen 443 ssl;
    server_name %%DEMO_WEBSITE%%;
    include ssl-includes.conf;

    location / {
        proxy_pass http://%%DEMO_WEBSITE_HOST%%;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host $host;
    }
    location /api {
        proxy_pass http://demo-backend;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host $host;
    }
}
