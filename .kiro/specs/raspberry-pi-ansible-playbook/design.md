# Design Document

## Overview

This design describes an Ansible project for automating the configuration of a Linux server (currently a Raspberry Pi running a Debian-based OS). The project uses a single, comprehensive playbook — `provision.yml` — that handles all foundational setup concerns: system updates, unattended upgrades, essential software, Docker, boot configuration, and system hardening. Each concern is organized into clearly labeled task sections within the playbook and tagged with Ansible tags, so users can run the entire playbook or selectively execute individual sections.

The project is OS-version-agnostic. It uses Ansible facts to detect the target host's OS release, architecture, and distribution rather than hardcoding values. This makes it portable across Debian-based systems without modification.

All configurable parameters are defined inline in the playbook's `vars:` block, keeping everything self-contained in a single file. Users can override any variable at runtime via `--extra-vars`.

The project structure supports adding more playbooks in the future (e.g., for service deployments), but the initial scope is a single playbook that provisions a fresh system from scratch.

## Architecture

### High-Level Structure

```
raspberry-pi-ansible/
├── ansible.cfg                    # Ansible configuration
├── inventory/
│   └── hosts.yml                  # Inventory with target host(s)
├── playbooks/
│   └── provision.yml              # Full system provisioning playbook
└── README.md                      # Usage documentation
```

### Design Decisions

1. **Single provisioning playbook with tags** — All foundational setup tasks live in `provision.yml`, organized into tagged sections. This gives users a single command to provision a fresh system (`ansible-playbook playbooks/provision.yml`) while still allowing selective execution (`--tags docker` or `--tags hardening`). The project structure still supports adding separate playbooks later for different concerns (e.g., deploying services).

2. **Inline variables with `vars:` block** — All configurable parameters are defined directly in the playbook's `vars:` section. This keeps the project simple and self-contained — one playbook file has everything. Users can still override any variable at runtime with `--extra-vars`. If the project grows and variables need to be shared across multiple playbooks, `group_vars` can be introduced later.

3. **Ansible tags for selective execution** — Each logical section of `provision.yml` is tagged (`packages`, `upgrades`, `essentials`, `docker`, `boot`, `hardening`). Tags allow running subsets without modifying the playbook: `ansible-playbook playbooks/provision.yml --tags "packages,docker"`.

4. **Conditional reboot at the end** — The playbook includes a reboot block at the end that checks `/var/run/reboot-required` or any registered change flags from earlier tasks. This avoids mid-playbook reboots and ensures all configuration is applied before deciding whether to reboot.

5. **Fact-based OS detection** — Tasks use `ansible_distribution`, `ansible_distribution_release`, `ansible_architecture`, and `ansible_os_family` facts instead of hardcoded OS values. This keeps the project portable across Debian-based distributions.

6. **Flat structure, no roles** — Tasks are inline in the playbook. This keeps the project simple for its current scope. Roles can be introduced later if the playbook grows complex enough to warrant extraction.

## Components and Interfaces

### 1. `ansible.cfg` — Project Configuration

Provides project-wide Ansible settings:

```ini
[defaults]
inventory = inventory/hosts.yml
remote_user = pi
host_key_checking = False
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo
```

- `remote_user` defaults to `pi` but is overridable via inventory or CLI
- `become = True` ensures the playbook runs with privilege escalation by default
- `host_key_checking = False` simplifies initial setup (can be tightened later)

### 2. `inventory/hosts.yml` — Inventory

```yaml
all:
  hosts:
    server:
      ansible_host: <target-ip-or-hostname>
      ansible_user: pi
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

- Single host group `all` — the playbook targets this group
- Placeholder values for IP and SSH key path
- Users replace placeholders with their actual connection details

### 3. `playbooks/provision.yml` — Full System Provisioning Playbook

A single playbook containing all foundational setup tasks, organized into tagged sections. Each section maps to a specific concern and can be run independently via `--tags`.

#### Usage Examples

```bash
# Run everything
ansible-playbook playbooks/provision.yml

# Run only system updates and Docker setup
ansible-playbook playbooks/provision.yml --tags "packages,docker"

# Run only hardening
ansible-playbook playbooks/provision.yml --tags hardening

# Skip boot configuration
ansible-playbook playbooks/provision.yml --skip-tags boot
```

#### Playbook Structure

The playbook is a single play targeting `all` hosts, with tasks organized into logical sections using comments and tags:

```yaml
---
- name: Provision system
  hosts: all
  vars:
    # ── General ──
    reboot_timeout: 300

    # ── Essential Packages ──
    essential_packages:
      - vim
      - curl
      - wget
      - git
      - htop
      - tmux
      - net-tools
      - jq
      - unzip

    # ── Unattended Upgrades ──
    unattended_update_interval: "1"
    unattended_download_interval: "1"
    unattended_auto_reboot: false
    unattended_auto_reboot_time: "02:00"

    # ── Docker ──
    docker_conflicting_packages:
      - docker.io
      - docker-doc
      - docker-compose
      - podman-docker
      - containerd
      - runc
    docker_packages:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin
    docker_users:
      - "{{ ansible_user }}"

    # ── Boot Configuration ──
    boot_parameters:
      gpu_mem: "128"
    boot_cmdline_parameters:
      - cgroup_enable=cpuset
      - cgroup_memory=1
      - cgroup_enable=memory

    # ── System Hardening ──
    ssh_permit_root_login: "no"
    ssh_password_authentication: "no"
    ssh_max_auth_tries: 3
    firewall_allowed_ports:
      - port: 22
        proto: tcp

  tasks:
    # ──────────────────────────────────────────────
    # Section: System Updates (tag: packages)
    # ──────────────────────────────────────────────
    - name: Update apt package cache
      ansible.builtin.apt:
        update_cache: yes
      tags: [packages]

    # ... more tasks tagged 'packages'

    # ──────────────────────────────────────────────
    # Section: Automatic Security Updates (tag: upgrades)
    # ──────────────────────────────────────────────
    # ... tasks tagged 'upgrades'

    # ──────────────────────────────────────────────
    # Section: Essential Software (tag: essentials)
    # ──────────────────────────────────────────────
    # ... tasks tagged 'essentials'

    # ──────────────────────────────────────────────
    # Section: Docker (tag: docker)
    # ──────────────────────────────────────────────
    # ... tasks tagged 'docker'

    # ──────────────────────────────────────────────
    # Section: Boot Configuration (tag: boot)
    # ──────────────────────────────────────────────
    # ... tasks tagged 'boot'

    # ──────────────────────────────────────────────
    # Section: System Hardening (tag: hardening)
    # ──────────────────────────────────────────────
    # ... tasks tagged 'hardening'

    # ──────────────────────────────────────────────
    # Section: Conditional Reboot (tag: reboot)
    # ──────────────────────────────────────────────
    # ... reboot tasks tagged 'reboot'
```

#### Section Details

**Section: System Updates** (tag: `packages`) — **Validates: Requirement 2**

Tasks:
1. Update apt package cache (`apt: update_cache=yes`)
2. Full system upgrade (`apt: upgrade=dist`)
3. Remove unused packages (`apt: autoremove=yes, purge=yes`)
4. Clean apt cache (`apt: autoclean=yes`)

All tasks use the `apt` module with declarative state, ensuring idempotency.

**Section: Automatic Security Updates** (tag: `upgrades`) — **Validates: Requirement 3**

Tasks:
1. Install `unattended-upgrades` and `apt-listchanges` packages
2. Deploy `/etc/apt/apt.conf.d/20auto-upgrades` with configurable update frequency
3. Deploy `/etc/apt/apt.conf.d/50unattended-upgrades` with configurable origins, auto-reboot policy, and reboot time

Variables (inline `vars:`):
- `unattended_update_interval`: How often to check (default: `"1"`)
- `unattended_download_interval`: How often to download (default: `"1"`)
- `unattended_auto_reboot`: Whether to auto-reboot after updates (default: `false`)
- `unattended_auto_reboot_time`: Reboot time if enabled (default: `"02:00"`)

**Section: Essential Software** (tag: `essentials`) — **Validates: Requirement 4**

Tasks:
1. Install packages from `essential_packages` list variable

Variables (inline `vars:`):
- `essential_packages`: List of package names (default includes `vim`, `curl`, `wget`, `git`, `htop`, `tmux`, `net-tools`, `jq`, `unzip`)

**Section: Docker** (tag: `docker`) — **Validates: Requirement 5**

Tasks:
1. Remove conflicting packages (`docker.io`, `containerd`, `runc`, etc.)
2. Install Docker prerequisites (`ca-certificates`, `curl`, `gnupg`)
3. Add Docker's official GPG key
4. Add Docker apt repository using detected OS facts (`ansible_distribution_release`, `ansible_architecture`)
5. Install Docker packages (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`)
6. Enable and start Docker service
7. Add remote user to `docker` group
8. Verify Docker installation (`docker --version` command check)

Variables (inline `vars:`):
- `docker_conflicting_packages`: List of packages to remove before install
- `docker_packages`: List of Docker packages to install
- `docker_users`: List of users to add to the docker group (default: `["{{ ansible_user }}"]`)

The Docker apt repository URL is constructed dynamically:
```
deb [arch={{ docker_arch }}] https://download.docker.com/linux/{{ ansible_distribution | lower }} {{ ansible_distribution_release }} stable
```
Where `docker_arch` is mapped from `ansible_architecture` (e.g., `aarch64` → `arm64`, `x86_64` → `amd64`).

**Section: Boot Configuration** (tag: `boot`) — **Validates: Requirement 6**

Tasks:
1. Detect boot config file path (check for `/boot/firmware/config.txt`, fall back to `/boot/config.txt`)
2. Apply boot parameters from `boot_parameters` variable using `ansible.builtin.lineinfile`
3. Apply kernel command-line parameters to `cmdline.txt` if defined
4. Register whether any changes were made (used by the reboot section)

Variables (inline `vars:`):
- `boot_parameters`: Dictionary of config.txt parameters (e.g., `gpu_mem: "128"`, `dtoverlay: "vc4-kms-v3d"`)
- `boot_cmdline_parameters`: List of kernel command-line additions (e.g., `cgroup_enable=cpuset`, `cgroup_memory=1`, `cgroup_enable=memory`)

**Section: System Hardening** (tag: `hardening`) — **Validates: Requirement 9**

Tasks:
1. Ensure `rsyslog` (or `systemd-journald`) is installed and running
2. Configure SSH hardening via `ansible.builtin.lineinfile` on `/etc/ssh/sshd_config`:
   - Disable root login (`PermitRootLogin no`)
   - Disable password authentication (`PasswordAuthentication no`)
   - Set max auth tries
3. Install and enable `ufw` firewall
4. Configure UFW default policies (deny incoming, allow outgoing)
5. Allow SSH through UFW
6. Restart SSH service if config changed

Variables (inline `vars:`):
- `ssh_permit_root_login`: (default: `"no"`)
- `ssh_password_authentication`: (default: `"no"`)
- `ssh_max_auth_tries`: (default: `3`)
- `firewall_allowed_ports`: List of ports to allow (default: `[{port: 22, proto: tcp}]`)

**Section: Conditional Reboot** (tag: `reboot`) — **Validates: Requirement 7**

Placed at the end of the playbook so all configuration is applied before deciding whether to reboot:

```yaml
- name: Check if reboot is required
  ansible.builtin.stat:
    path: /var/run/reboot-required
  register: reboot_required_file
  tags: [reboot]

- name: Reboot if required
  ansible.builtin.reboot:
    reboot_timeout: "{{ reboot_timeout | default(300) }}"
  when: reboot_required_file.stat.exists or (boot_config_result is defined and boot_config_result.changed)
  tags: [reboot]
```

This checks both the system-level reboot indicator and any registered task changes from earlier sections (e.g., boot configuration changes).

### Tag Reference

| Tag | Section | What It Does |
|-----|---------|-------------|
| `packages` | System Updates | apt update, dist-upgrade, autoremove, autoclean |
| `upgrades` | Automatic Security Updates | Install and configure unattended-upgrades |
| `essentials` | Essential Software | Install configurable package list |
| `docker` | Docker | Remove conflicts, install Docker from official repo |
| `boot` | Boot Configuration | Apply boot/kernel parameters |
| `hardening` | System Hardening | SSH hardening, firewall, logging |
| `reboot` | Conditional Reboot | Reboot if needed, wait for reconnection |

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Playbook files | `snake_case.yml` descriptive noun | `provision.yml` |
| Variable names | `snake_case` | `essential_packages` |
| Task names | Sentence case, descriptive | `Install essential packages` |
| Tags | Lowercase, single word | `docker`, `hardening` |
| Inventory hosts | Logical name | `server` |

## Data Models

### Variable Schema

All variables are defined inline in the playbook's `vars:` block. They are organized by concern using comments. Users can override any variable at runtime using `--extra-vars`. The full variable schema is shown in the playbook structure above.

### Inventory Data Model

```yaml
all:
  hosts:
    server:
      ansible_host: <ip-or-hostname>    # Target host address
      ansible_user: pi                   # SSH user
      ansible_ssh_private_key_file: ~/.ssh/id_rsa  # SSH key path
```

The inventory supports adding multiple hosts or host groups in the future without structural changes.


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Variable-driven configuration

*For any* tagged section in `provision.yml` and any configurable parameter (package lists, boot parameters, hardening settings, reboot timeouts, update intervals), the task YAML should reference a variable name rather than contain a hardcoded literal value. Specifically, for any task that uses a value defined in the playbook's `vars:` block, the task should contain a Jinja2 variable reference (`{{ variable_name }}`).

**Validates: Requirements 3.3, 4.1, 4.3, 6.1, 7.2, 9.3**

### Property 2: OS-fact-based repository configuration

*For any* task in `provision.yml` that configures an external package repository (apt source), the repository URL or configuration should reference Ansible facts (`ansible_distribution`, `ansible_distribution_release`, `ansible_architecture`) rather than hardcoded OS names, version codenames, or architecture strings.

**Validates: Requirements 5.2, 8.2**

### Property 3: Idempotent module usage

*For any* task in `provision.yml` that modifies system state (installs packages, modifies config files, manages services, adds repositories), the task should use a declarative Ansible module (`apt`, `lineinfile`, `copy`, `template`, `systemd`, `ufw`, `user`, `get_url`) with explicit state parameters rather than imperative `shell`/`command` modules. When `shell`/`command` is used, it must have a `creates`, `removes`, or `when` condition to ensure idempotency.

**Validates: Requirements 10.2, 10.3, 10.4**

### Property 4: Double-run idempotency

*For any* tag selection (full playbook or any individual tag), executing `provision.yml` twice consecutively against the same already-configured target host should result in zero changed tasks on the second execution.

**Validates: Requirements 10.1**

### Property 5: System update task completeness

*For any* playbook claiming to perform system updates (the `packages`-tagged section of `provision.yml`), parsing its YAML should reveal tasks that cover all three phases: package cache update (`update_cache`), full upgrade (`upgrade: dist`), and cleanup (`autoremove`). The absence of any phase means the section is incomplete.

**Validates: Requirements 2.1, 2.2, 2.3**

### Property 6: Conditional reboot safety

*For any* reboot task in `provision.yml`, the task must have a `when` condition that gates execution on a detected reboot requirement (either a registered change variable or the existence of `/var/run/reboot-required`). A reboot task without a `when` condition is a correctness violation.

**Validates: Requirements 7.1, 7.2, 7.3**

## Error Handling

### OS Compatibility Warnings

The playbook should include a pre-task check at the top:

```yaml
- name: Warn if not running a Debian-based OS
  ansible.builtin.debug:
    msg: "WARNING: This playbook is designed for Debian-based systems. Detected: {{ ansible_os_family }}"
  when: ansible_os_family != "Debian"
```

This emits a warning but does not fail, allowing the user to proceed at their own risk.

### SSH Connectivity Failures

- `ansible.cfg` disables host key checking for initial setup convenience
- The reboot task uses `reboot_timeout` to avoid hanging indefinitely if the host doesn't come back
- If SSH fails mid-playbook, Ansible's default retry behavior applies — the user re-runs the playbook

### Package Installation Failures

- The `apt` module will fail the task if a package name is invalid or unavailable
- Ansible's default behavior stops the playbook on failure, which is the desired behavior — partial configuration is visible in the output
- Users fix the variable (typo in package name, missing repo) and re-run

### Docker Repository Issues

- If the Docker GPG key URL is unreachable, the task fails explicitly
- If the repository is misconfigured (wrong architecture), `apt update` will fail, surfacing the issue early
- The architecture mapping (`aarch64` → `arm64`) handles the most common cases; unsupported architectures will fail at the repository add step with a clear error

### Boot Configuration

- The playbook detects the boot config path via `stat` checks — if neither `/boot/firmware/config.txt` nor `/boot/config.txt` exists, the playbook should fail with a clear message
- `lineinfile` with `regexp` ensures we don't duplicate entries on re-runs

### Tag Interaction

- Running `--tags reboot` alone is safe — the reboot section checks for conditions that may not have been set, and the `when` clause handles undefined variables gracefully (using `is defined` checks)
- Running `--tags docker` without first running `--tags packages` is fine — Docker tasks manage their own prerequisites (installing `ca-certificates`, `curl`, etc.)

## Testing Strategy

### Approach

Testing an Ansible project has two layers: **static analysis** (linting, YAML validation, structural checks) and **integration testing** (running the playbook against a real or simulated host). This project uses both.

### Static Analysis (Automated, No Host Required)

1. **YAML Syntax Validation** — The playbook and inventory files must be valid YAML. Use `yamllint` with a project-level config.

2. **Ansible Lint** — Run `ansible-lint` against `provision.yml` to catch anti-patterns, deprecated modules, and style issues.

3. **Structural Property Tests** — Property-based tests that parse `provision.yml` YAML and verify correctness properties:
   - **Library**: `pytest` with `hypothesis` (Python) for property-based testing
   - **Minimum iterations**: 100 per property test
   - **Tag format**: `Feature: raspberry-pi-ansible-playbook, Property {N}: {description}`

   These tests load `provision.yml`, parse it, and verify structural properties:
   - Property 1: Variable references exist where configurable values are expected
   - Property 2: Repository tasks use Ansible fact references
   - Property 3: State-modifying tasks use declarative modules
   - Property 5: The `packages`-tagged section contains all required update phases
   - Property 6: Reboot tasks have `when` conditions

4. **Variable Completeness Check** — Verify that every variable referenced in `provision.yml` tasks has a default defined in the playbook's `vars:` block.

### Integration Testing (Requires Host or VM)

1. **Molecule Testing** (recommended for CI) — Use Molecule with a Docker or Vagrant driver to spin up a Debian-based container/VM and run `provision.yml` against it. Individual tags can be tested in isolation.

2. **Idempotency Testing** (Property 4) — Run `provision.yml` twice against the same Molecule instance. The second run must report 0 changed tasks. This can also be done per-tag: run `--tags docker` twice and verify zero changes on the second run.

3. **Smoke Tests** — After running the full playbook, verify:
   - Docker is installed and running (`docker --version`)
   - Essential packages are present (`which vim`, `which curl`)
   - SSH config has expected values
   - UFW is active with expected rules
   - Unattended upgrades config files exist with expected content

### Unit Tests vs Property Tests

| Test Type | What It Covers | Example |
|-----------|---------------|---------|
| Unit (example) | Specific file exists with expected content | `inventory/hosts.yml` contains `ansible_host` key |
| Unit (example) | Specific task exists in playbook | `provision.yml` has a `docker --version` check task |
| Unit (edge case) | Boot config path detection | Playbook handles missing `/boot/firmware/config.txt` |
| Property | Variable-driven config across all tagged sections | No hardcoded configurable values in any task |
| Property | Idempotent modules across all tasks | All state-modifying tasks use declarative modules |
| Property (integration) | Double-run idempotency | Second run = 0 changes for full playbook and per-tag |

### Property-Based Testing Configuration

- **Library**: `hypothesis` (Python) for generating test inputs, `pytest` as test runner
- **YAML parsing**: `ruamel.yaml` or `pyyaml` for loading `provision.yml`
- **Iterations**: Minimum 100 per property test
- **Each property test references its design property via comment tag**:
  ```python
  # Feature: raspberry-pi-ansible-playbook, Property 1: Variable-driven configuration
  ```
- Each correctness property is implemented by a single property-based test
