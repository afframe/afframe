# TEMPORARY pipeline fixture, no application code. Delete this folder when the real web app lands.
# Unprivileged nginx (runs as uid 101); Alpine packages upgraded at build for current security fixes.
FROM nginxinc/nginx-unprivileged:1.31.0-alpine@sha256:3707417e3304492667a63c90ac0103465330437f9cdfaa38f8cd19f9975cbeed
USER root
RUN apk upgrade --no-cache
USER 101
ENV PORT=8080
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
