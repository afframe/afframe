# Not in apps/: integration.sh must not depend on an app that a PR can delete.
FROM nginxinc/nginx-unprivileged:1.31.6-alpine@sha256:884e0b7f42f303641b0f4e78755aea647521dca0b89ca3be7992ad78b5c07434
ENV PORT=8080
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY error.html /srv/
