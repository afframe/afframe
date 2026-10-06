# Not in apps/: integration.sh must not depend on an app that a PR can delete.
FROM nginxinc/nginx-unprivileged:1.31.5-alpine@sha256:19c132c9ab02d3b783f478743dafc7a7f42e27aa7d2bdcbec1bb1128ca8f2a07
ENV PORT=8080
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY error.html /srv/
