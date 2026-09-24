# TEMPORARY pipeline fixture, no application code. Delete this folder together with the
# `placeholder` block in .railway/railway.ts (see docs/railway.md, "Remove the placeholder").
FROM nginx:1.30.5-alpine
ENV PORT=8080
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
