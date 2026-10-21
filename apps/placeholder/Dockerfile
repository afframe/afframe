FROM nginxinc/nginx-unprivileged:1.31.6-alpine@sha256:884e0b7f42f303641b0f4e78755aea647521dca0b89ca3be7992ad78b5c07434
USER root
# The base image's 50x.html would be served from the same root and names the server software.
RUN apk upgrade --no-cache && rm -f /usr/share/nginx/html/50x.html
USER 101
ENV PORT=8080
COPY apps/placeholder/default.conf.template /etc/nginx/templates/default.conf.template
COPY apps/placeholder/index.html apps/placeholder/error.html /usr/share/nginx/html/
