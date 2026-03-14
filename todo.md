# TODO: Raspberry Pi Ansible Playbook

## Future Tasks

- [ ] Reverse proxy (Caddy/Nginx/Traefik) for clean subdomain-based access to all services

- [ ] Homarr dashboard for a single landing page with links to all services

- [ ] Correct logging level for Grafana alerts

- [ ] Review `handle_stuck_exports` ordering in `main.py` — re-submit then delete could cause duplicates if delete fails, and losing footage if re-submit fails after retries

- [ ] Cloudflare Tunnel playbook for secure external access without exposing ports

- [ ] Investigate provision.yml reboot idempotency — ensure second run doesn't trigger unnecessary reboot when cgroup and watchdog configs are already applied
