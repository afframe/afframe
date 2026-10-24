# Not in apps/: integration.sh must not depend on an app that a PR can delete.
FROM nginxinc/nginx-unprivileged:1.31.7-alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e
ENV PORT=8080
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY error.html /srv/
