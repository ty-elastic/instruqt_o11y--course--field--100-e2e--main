ARG NGINX_VERSION=1.23.1

FROM nginx:${NGINX_VERSION}

COPY nginx.conf /etc/nginx/nginx.conf

COPY default.conf /etc/nginx/conf.d/default.conf
COPY cors.conf /etc/nginx/cors.conf

