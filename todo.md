# TODO: Raspberry Pi Ansible Playbook

## Future Tasks

- [ ] Pin Docker image versions instead of using `latest` tags for reproducible deployments

- [ ] Reverse proxy (Caddy/Nginx/Traefik) for clean subdomain-based access to all services

- [ ] Homarr dashboard for a single landing page with links to all services

- [ ] Correct logging level for Grafana alerts

- [ ] Review `handle_stuck_exports` ordering in `main.py` — re-submit then delete could cause duplicates if delete fails, and losing footage if re-submit fails after retries
