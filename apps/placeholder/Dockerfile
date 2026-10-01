# TEMPORARY pipeline fixture, no application code. Delete this folder when the real web app lands.
FROM nginx:1.31.0-alpine
ENV PORT=8080
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
