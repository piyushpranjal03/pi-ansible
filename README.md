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
│   ├── dockmon.yml              # Variables for the dockmon playbook
│   ├── prometheus.yml           # Variables for the prometheus playbook
│   └── restic.yml               # Variables for the restic backup playbook
├── playbooks/
│   ├── provision.yml            # System provisioning playbook
│   ├── restic.yml               # Restic backup setup playbook
│   ├── frigate.yml              # Frigate NVR deployment playbook
│   ├── calibre-web.yml          # Calibre-Web Automated deployment playbook
│   ├── netbird.yml              # NetBird installation playbook
│   ├── dockmon.yml              # Dockmon deployment playbook
│   └── prometheus.yml           # Prometheus + Node Exporter deployment playbook
├── services/
│   ├── frigate/
│   │   ├── docker-compose.yml   # Frigate container services
│   │   ├── config.yml           # Frigate NVR configuration
│   │   └── scripts/
│   │       ├── main.py          # Automated S3 video export script
│   │       └── memory-monitor.sh # Frigate memory watchdog script
│   ├── calibre-web/
│   │   ├── docker-compose.yml   # Calibre-Web Automated container service
│   │   └── backup.sh            # CWA Restic backup script
│   ├── dockmon/
│   │   ├── docker-compose.yml   # Dockmon container service
│   │   └── backup.sh            # Dockmon Restic backup script
│   └── prometheus/
│       ├── docker-compose.yml   # Prometheus + Node Exporter services
│       ├── prometheus.yml       # Prometheus scrape configuration
│       └── backup.sh            # Prometheus Restic backup script
```

## Prerequisites

- Ansible installed on your control machine
- SSH key-based access to the Pi (`~/.ssh/id_rsa` by default)
- Pi running Debian-based OS (Pi OS Bookworm+ recommended)
- AWS IAM user with appropriate permissions (see [AWS IAM Setup](#aws-iam-setup) below)

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

### Restic Backup (`playbooks/restic.yml`)

Installs Restic and initializes an encrypted S3 backup repository. Run this once after provision — service playbooks use the credentials it sets up for per-service backup and restore.

```bash
ansible-playbook playbooks/restic.yml
```

You'll be prompted for:
- Restic repository password (encrypts all backups)
- AWS Access Key ID and Secret Access Key
- S3 bucket name

The playbook writes credentials to `/etc/restic/` (root-only access) so automated backup timers can run without human input.

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

If the Restic playbook has been run, the playbook will restore from the latest S3 backup on fresh deployments and set up a daily backup timer at 3:30 AM.

### NetBird (`playbooks/netbird.yml`)

Installs the NetBird client and registers the Pi with your NetBird network. Prompts for a setup key at runtime.

```bash
ansible-playbook playbooks/netbird.yml
```

You'll be prompted for a setup key (generate one from the [NetBird dashboard](https://app.netbird.io)). The playbook skips registration if the peer is already connected, so re-runs are safe.

### Dockmon (`playbooks/dockmon.yml`)

Deploys Dockmon — a Docker container monitoring dashboard. Includes automated backup and restore via Restic.

```bash
ansible-playbook playbooks/dockmon.yml
```

Accessible at `https://<pi-ip>:8001` after deployment.

If the Restic playbook has been run, the dockmon playbook will:
- Restore from the latest S3 backup on fresh deployments (so you get your config back after a crash)
- Set up a daily systemd timer (3 AM) that backs up the `dockmon_data` Docker volume to S3
- Retain 7 daily, 4 weekly, and 2 monthly backup snapshots

Check backup logs with `journalctl -u dockmon-backup.service` and timer status with `systemctl status dockmon-backup.timer`.

### Prometheus + Node Exporter (`playbooks/prometheus.yml`)

Deploys Prometheus for metrics collection and Node Exporter for system metrics (CPU, memory, disk, temperature).

```bash
ansible-playbook playbooks/prometheus.yml
```

Prometheus UI at `http://<pi-ip>:9090`, Node Exporter metrics at `http://<pi-ip>:9100/metrics`. Scrapes system metrics every 15 seconds with 30-day retention. Includes Restic backup/restore (daily at 4 AM).

## Configuration

All variables are in `group_vars/` with descriptive comments. Key files:

- `group_vars/provision.yml` — Tweak unattended-upgrades policy, watchdog thresholds, SSH settings, Docker users, journald limits
- `group_vars/frigate.yml` — Frigate deployment directory, AWS region
- `group_vars/calibre-web.yml` — CWA deployment directory, data subdirectories, backup schedule
- `group_vars/netbird.yml` — NetBird repository and GPG key URLs
- `group_vars/dockmon.yml` — Dockmon deployment directory, backup schedule
- `group_vars/prometheus.yml` — Prometheus deployment directory, backup schedule
- `group_vars/restic.yml` — Restic backup AWS region
- `group_vars/all.yml` — Shared settings (reboot timeout)

## Notes

- The provision playbook is designed for a Pi on a local network — no UFW or fail2ban (Docker bypasses iptables-based firewalls anyway)
- SSH hardening disables root login and password auth — make sure you have a non-root user with SSH key access before running
- The conditional reboot section uses `is defined` guards so individual tags can be run safely without triggering unrelated reboots

## AWS IAM Setup

The Frigate video export and Restic backup playbooks require AWS credentials. Create a dedicated IAM user with the minimum permissions needed.

### IAM Policy for Restic Backups

Restic needs to read, write, list, and delete objects in the backup prefix of your S3 bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR_BUCKET_NAME",
        "arn:aws:s3:::YOUR_BUCKET_NAME/restic/*"
      ]
    }
  ]
}
```

### IAM Policy for Frigate Video Export

The video export sidecar uploads recordings to S3 with Glacier Instant Retrieval storage class:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR_BUCKET_NAME",
        "arn:aws:s3:::YOUR_BUCKET_NAME/*"
      ]
    }
  ]
}
```

If using a single IAM user for both, combine the policies. Replace `YOUR_BUCKET_NAME` with your actual S3 bucket name.
