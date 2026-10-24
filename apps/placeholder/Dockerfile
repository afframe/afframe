FROM nginxinc/nginx-unprivileged:1.31.7-alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e
USER root
# The base image's 50x.html would be served from the same root and names the server software.
RUN apk upgrade --no-cache && rm -f /usr/share/nginx/html/50x.html
USER 101
ENV PORT=8080
COPY apps/placeholder/default.conf.template /etc/nginx/templates/default.conf.template
COPY apps/placeholder/index.html apps/placeholder/error.html /usr/share/nginx/html/
