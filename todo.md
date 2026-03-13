# TODO: Raspberry Pi Ansible Playbook

## Future Tasks

- [ ] Grafana + Loki + Promtail/Alloy stack for centralized log aggregation
  - Ship journald logs (watchdog, unattended-upgrades, Docker, system) to Loki
  - Grafana dashboards for log visualization and search
  - Grafana alerting rules for notifications (Slack, Telegram, ntfy, etc.) on upgrade events, watchdog triggers, errors

- [ ] Docker container log persistence via logging driver configuration (e.g., json-file with max-size/max-file, or journald driver)

- [ ] Calibre-Web Automated docker service deployment

- [ ] Prometheus + Node Exporter for system metrics
  - CPU load, memory, temperature, disk usage
  - Grafana dashboards for metrics visualization
  - Alert rules for early warnings before watchdog thresholds are hit
