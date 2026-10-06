FROM nginxinc/nginx-unprivileged:1.31.5-alpine@sha256:19c132c9ab02d3b783f478743dafc7a7f42e27aa7d2bdcbec1bb1128ca8f2a07
USER root
# The base image's 50x.html would be served from the same root and names the server software.
RUN apk upgrade --no-cache && rm -f /usr/share/nginx/html/50x.html
USER 101
ENV PORT=8080
COPY apps/placeholder/default.conf.template /etc/nginx/templates/default.conf.template
COPY apps/placeholder/index.html apps/placeholder/error.html /usr/share/nginx/html/
