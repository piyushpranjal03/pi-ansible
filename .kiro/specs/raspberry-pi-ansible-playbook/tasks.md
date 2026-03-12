# Implementation Plan: Raspberry Pi Ansible Playbook

## Overview

Build a single-playbook Ansible project that provisions a Debian-based Linux server (Raspberry Pi). All tasks live in `provision.yml` with tagged sections, inline variables, and fact-based OS detection. Implementation proceeds bottom-up: project scaffolding → individual tagged sections → reboot logic → documentation.

## Tasks

- [ ] 1. Set up project structure and configuration
  - [x] 1.1 Create `ansible.cfg` with inventory path, remote user, SSH settings, and privilege escalation defaults
    - Configure `inventory = inventory/hosts.yml`, `remote_user = pi`, `host_key_checking = False`
    - Set `become = True` and `become_method = sudo` under `[privilege_escalation]`
    - _Requirements: 1.1, 1.4_
  - [x] 1.2 Create `inventory/hosts.yml` with placeholder connection details
    - Define `all` group with a `server` host entry
    - Include `ansible_host`, `ansible_user`, and `ansible_ssh_private_key_file` placeholders
    - _Requirements: 1.2_
  - [x] 1.3 Create `playbooks/provision.yml` skeleton and `group_vars/all.yml` for shared variables
    - Define the play targeting `all` hosts with an empty tasks section
    - Move `reboot_timeout` (set to 120s) into `group_vars/all.yml` as a shared variable across playbooks
    - Vars block and OS compatibility pre-task deferred — playbook is being built incrementally from a clean slate
    - _Requirements: 1.1, 1.3, 7.2_
  - [x] 1.4 Add essential packages installation to `provision.yml`
    - Created `group_vars/provision.yml` with `essential_packages` var (`vim`, `curl`, `btop`)
    - Added `vars_files` reference in `provision.yml` to load provision-specific vars from `group_vars/provision.yml`
    - Added task to install packages from the list using `apt` module with `state: present`
    - Tagged with `[essentials]`
    - _Requirements: 4.1, 4.2, 4.3_


- [ ] 2. Implement Automatic Security Updates section (tag: upgrades)
  - [x] 2.1 Add unattended upgrades tasks to `provision.yml`
    - Install `unattended-upgrades` and `apt-listchanges` packages
    - Deploy `/etc/apt/apt.conf.d/20auto-upgrades` with configurable periodic settings (update interval, download interval, autoclean interval)
    - Deploy `/etc/apt/apt.conf.d/50unattended-upgrades` with allowed origins, package blacklist, auto-reboot policy, reboot time, unused dependency removal, syslog, and verbose logging
    - Add variables to `group_vars/provision.yml`: `unattended_update_interval`, `unattended_download_interval`, `unattended_autoclean_interval`, `unattended_auto_reboot`, `unattended_auto_reboot_time`, `unattended_remove_unused_deps`, `unattended_syslog_enable`, `unattended_syslog_facility`, `unattended_verbose`
    - Removed mail notification variables (`unattended_mail`, `unattended_mail_report`) — notifications will be handled via Grafana/Loki log aggregation instead
    - Moved upgrades section after essentials section in playbook for logical ordering
    - Added descriptive comments to all variables in `group_vars/provision.yml`
    - Applied consistent section separator formatting across all vars files (`group_vars/all.yml`, `group_vars/provision.yml`)
    - Tag all tasks with `[upgrades]`
    - _Requirements: 3.1, 3.2, 3.3_

- [ ] 3. Implement Docker Installation section (tag: docker)
  - [x] 3.1 Add Docker installation tasks to `provision.yml`
    - Remove conflicting container runtime packages using `docker_conflicting_packages` variable
    - Install Docker prerequisites (`ca-certificates`, `curl`, `gnupg`)
    - Add Docker GPG key using `get_url` (idempotent, replaces `shell: curl` from sample)
    - Add Docker apt repository using `apt_repository` with Ansible facts (`ansible_distribution`, `ansible_distribution_release`, `docker_arch_map[ansible_architecture]`)
    - Install Docker packages from `docker_packages` variable with `update_cache: yes`
    - Enable and start Docker service via `systemd` module
    - Add users from `docker_users` list to docker group using loop
    - Verify installation with `docker --version` (`changed_when: false` for idempotency)
    - Dropped `hello-world` test from sample — pulls an image every run, not idempotent
    - Add variables to `group_vars/provision.yml`: `docker_conflicting_packages`, `docker_packages`, `docker_users`, `docker_arch_map`
    - Tag all tasks with `[docker]`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 8.2_

- [ ] 4. Implement Hardware Watchdog section (tag: watchdog)
  - [ ] 4.1 Add hardware watchdog tasks to `provision.yml`
    - Enable hardware watchdog in boot config (`dtparam=watchdog=on`)
    - Detect config.txt path (Bookworm+ vs older Pi OS)
    - Install `watchdog` package
    - Deploy `/etc/watchdog.conf` with configurable settings (device, timeout, load, memory, temperature, interval)
    - Enable and start `watchdog` systemd service
    - Add variables to `group_vars/provision.yml`: `watchdog_timeout`, `watchdog_max_load`, `watchdog_min_memory`, `watchdog_max_temperature`, `watchdog_interval`
    - Tag all tasks with `[watchdog]`
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

## Future Tasks (separate playbooks)

- [ ] Enable persistent journald logging (`Storage=persistent` in `/etc/systemd/journald.conf`) — needed so logs survive reboots for watchdog, unattended-upgrades, and all other services
- [ ] Set up Grafana + Loki + Promtail/Alloy stack for centralized log aggregation
  - Ship journald logs (watchdog, unattended-upgrades, Docker, system) to Loki
  - Grafana dashboards for log visualization and search
  - Grafana alerting rules for notifications (Slack, Telegram, ntfy, etc.) on upgrade events, watchdog triggers, errors
- [ ] Set up Prometheus + Node Exporter for system metrics
  - CPU load, memory, temperature, disk usage
  - Grafana dashboards for metrics visualization
  - Alert rules for early warnings before watchdog thresholds are hit
