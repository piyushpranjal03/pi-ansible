# TODO: Raspberry Pi Ansible Playbook

## Provision Playbook Tasks

- [ ] Configure persistent journald logging (tag: logging)
  - Set `Storage=persistent` in `/etc/systemd/journald.conf`
  - Configure `SystemMaxUse=200M` to cap log size on SD card
  - Configure `MaxRetentionSec=30d` for log retention
  - Needed so logs survive reboots for watchdog, unattended-upgrades, and all other services

- [ ] System Hardening — SSH (tag: hardening)
  - Disable root login (`PermitRootLogin no`)
  - Disable password authentication (`PasswordAuthentication no`)
  - Set max auth tries (`MaxAuthTries 3`)
  - Disable empty passwords
  - Restart SSH service if config changes
  - Variables: `ssh_permit_root_login`, `ssh_password_authentication`, `ssh_max_auth_tries`

- [ ] System Hardening — Firewall / UFW (tag: hardening)
  - Install and enable `ufw`
  - Default policy: deny incoming, allow outgoing
  - Allow SSH (port 22)
  - Allow configurable list of additional ports for container services on local network
  - Variables: `firewall_allowed_ports`

- [ ] System Hardening — Logging (tag: hardening)
  - Ensure `rsyslog` is installed and running

- [ ] Conditional Reboot section (tag: reboot)
  - Check `/var/run/reboot-required` and registered change flags (boot config, cmdline, watchdog)
  - Reboot if needed, wait for reconnection with configurable timeout

## Future Playbooks

- [ ] Grafana + Loki + Promtail/Alloy stack for centralized log aggregation
  - Ship journald logs (watchdog, unattended-upgrades, Docker, system) to Loki
  - Grafana dashboards for log visualization and search
  - Grafana alerting rules for notifications (Slack, Telegram, ntfy, etc.) on upgrade events, watchdog triggers, errors

- [ ] Prometheus + Node Exporter for system metrics
  - CPU load, memory, temperature, disk usage
  - Grafana dashboards for metrics visualization
  - Alert rules for early warnings before watchdog thresholds are hit
