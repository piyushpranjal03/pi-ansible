# TODO: Raspberry Pi Ansible Playbook

## Provision Playbook Tasks

- [x] Configure persistent journald logging (tag: logging)
- [x] System Hardening — SSH (tag: hardening)
- [x] Conditional Reboot section (tag: reboot)

## Future Playbooks

- [ ] Grafana + Loki + Promtail/Alloy stack for centralized log aggregation
  - Ship journald logs (watchdog, unattended-upgrades, Docker, system) to Loki
  - Grafana dashboards for log visualization and search
  - Grafana alerting rules for notifications (Slack, Telegram, ntfy, etc.) on upgrade events, watchdog triggers, errors

- [ ] Prometheus + Node Exporter for system metrics
  - CPU load, memory, temperature, disk usage
  - Grafana dashboards for metrics visualization
  - Alert rules for early warnings before watchdog thresholds are hit
