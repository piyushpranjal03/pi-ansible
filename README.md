# Raspberry Pi Ansible

Ansible project for provisioning and deploying services on a Raspberry Pi running Debian-based OS (Pi OS).

## Project Structure

```
├── ansible.cfg                  # Ansible configuration (inventory path, SSH, privilege escalation)
├── inventory/hosts.yml          # Target host definitions
├── group_vars/
│   ├── all.yml                  # Shared variables across all playbooks
│   ├── provision.yml            # Variables for the provision playbook
│   ├── frigate.yml              # Variables for the frigate playbook
│   ├── calibre-web.yml          # Variables for the calibre-web playbook
│   ├── netbird.yml              # Variables for the netbird playbook
│   └── dockmon.yml              # Variables for the dockmon playbook
├── playbooks/
│   ├── provision.yml            # System provisioning playbook
│   ├── frigate.yml              # Frigate NVR deployment playbook
│   ├── calibre-web.yml          # Calibre-Web Automated deployment playbook
│   ├── netbird.yml              # NetBird installation playbook
│   └── dockmon.yml              # Dockmon deployment playbook
├── frigate/
│   ├── docker-compose.yml       # Frigate container services
│   ├── config.yml               # Frigate NVR configuration
│   └── scripts/
│       ├── main.py              # Automated S3 video export script
│       └── memory-monitor.sh    # Frigate memory watchdog script
└── calibre-web/
    └── docker-compose.yml       # Calibre-Web Automated container service
├── dockmon/
│   └── docker-compose.yml       # Dockmon container service
```

## Prerequisites

- Ansible installed on your control machine
- SSH key-based access to the Pi (`~/.ssh/id_rsa` by default)
- Pi running Debian-based OS (Pi OS Bookworm+ recommended)

## Inventory Setup

Edit `inventory/hosts.yml` with your Pi's IP and SSH details:

```yaml
all:
  hosts:
    raspberry-pi-a:
      ansible_host: 192.168.18.100
      ansible_user: pi
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

## Playbooks

### Provision (`playbooks/provision.yml`)

Handles full system setup with tagged sections that can be run independently.

| Tag | What it does |
|-----|-------------|
| `packages` | System update, dist-upgrade, autoremove, cache clean |
| `essentials` | Install essential packages (vim, curl, btop) |
| `upgrades` | Configure unattended-upgrades with syslog logging |
| `docker` | Install Docker from official repo, cgroup memory support for Pi |
| `watchdog` | Enable hardware watchdog with health monitoring (load, memory, temperature) |
| `logging` | Persistent journald logging (survives reboots, 1GB cap, 30-day retention) |
| `hardening` | SSH hardening (disable root login, password auth, limit auth tries) |
| `reboot` | Conditional reboot if required by any earlier section |

Run the full playbook:

```bash
ansible-playbook playbooks/provision.yml
```

Run specific sections using tags:

```bash
ansible-playbook playbooks/provision.yml --tags "docker,watchdog"
```

### Frigate NVR (`playbooks/frigate.yml`)

Deploys Frigate NVR with an S3 video export sidecar. Prompts for credentials at runtime.

```bash
ansible-playbook playbooks/frigate.yml
```

You'll be prompted for:
- Camera username and password (RTSP)
- AWS Access Key ID and Secret Access Key
- S3 bucket name

The playbook creates the directory structure at `/opt/frigate`, deploys config files, creates a `.env` with secrets (restricted permissions), and starts the containers.

#### Services

- **frigate** — Frigate NVR with hardware-accelerated video processing, 10-day recording retention
- **frigate-memory-monitor** — Sidecar that monitors frigate memory usage and restarts it at 80% threshold (workaround for known memory leak)
- **frigate-video-export** — Sidecar that exports 10-minute video clips to S3 (Glacier Instant Retrieval) on a schedule

### Calibre-Web Automated (`playbooks/calibre-web.yml`)

Deploys Calibre-Web Automated — a self-hosted ebook library with automatic book ingestion.

```bash
ansible-playbook playbooks/calibre-web.yml
```

The playbook creates the directory structure at `/opt/calibre-web` with data directories for config, ingest, library, and plugins, then starts the container.

### NetBird (`playbooks/netbird.yml`)

Installs the NetBird client and registers the Pi with your NetBird network. Prompts for a setup key at runtime.

```bash
ansible-playbook playbooks/netbird.yml
```

You'll be prompted for a setup key (generate one from the [NetBird dashboard](https://app.netbird.io)). The playbook skips registration if the peer is already connected, so re-runs are safe.

### Dockmon (`playbooks/dockmon.yml`)

Deploys Dockmon — a Docker container monitoring dashboard.

```bash
ansible-playbook playbooks/dockmon.yml
```

Accessible at `https://<pi-ip>:8001` after deployment.

## Configuration

All variables are in `group_vars/` with descriptive comments. Key files:

- `group_vars/provision.yml` — Tweak unattended-upgrades policy, watchdog thresholds, SSH settings, Docker users, journald limits
- `group_vars/frigate.yml` — Frigate deployment directory, AWS region
- `group_vars/calibre-web.yml` — CWA deployment directory, data subdirectories
- `group_vars/netbird.yml` — NetBird repository and GPG key URLs
- `group_vars/dockmon.yml` — Dockmon deployment directory
- `group_vars/all.yml` — Shared settings (reboot timeout)

## Notes

- The provision playbook is designed for a Pi on a local network — no UFW or fail2ban (Docker bypasses iptables-based firewalls anyway)
- SSH hardening disables root login and password auth — make sure you have a non-root user with SSH key access before running
- The conditional reboot section uses `is defined` guards so individual tags can be run safely without triggering unrelated reboots
