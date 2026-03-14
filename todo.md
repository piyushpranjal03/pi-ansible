# TODO: Raspberry Pi Ansible Playbook

## Future Tasks

- [ ] Pin Docker image versions instead of using `latest` tags for reproducible deployments

- [ ] Reverse proxy (Caddy/Nginx/Traefik) for clean subdomain-based access to all services

- [ ] Homarr dashboard for a single landing page with links to all services

- [ ] Correct logging level for Grafana alerts

- [ ] Document backup strategy: why monitoring scripts stop containers before backup (database consistency) while CWA and Dockmon don't need it
