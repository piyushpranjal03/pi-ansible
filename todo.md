# TODO: Raspberry Pi Ansible Playbook

## Future Tasks

- [ ] Grafana + Loki + Promtail/Alloy stack for centralized log aggregation
  - Ship journald logs (watchdog, unattended-upgrades, Docker, system) to Loki
  - Grafana dashboards for log visualization and search
  - Grafana alerting rules for notifications (Slack, Telegram, ntfy, etc.) on upgrade events, watchdog triggers, errors

- [ ] Reverse proxy (Caddy/Nginx/Traefik) for clean subdomain-based access to all services

- [ ] Homarr dashboard for a single landing page with links to all services

- [ ] Prometheus + Node Exporter for system metrics
  - CPU load, memory, temperature, disk usage
  - Grafana dashboards for metrics visualization
  - Alert rules for early warnings before watchdog thresholds are hit
