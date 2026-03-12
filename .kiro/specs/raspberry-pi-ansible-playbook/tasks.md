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
  - [ ] 1.3 Create `playbooks/provision.yml` skeleton with vars block and OS compatibility check
    - Define the play targeting `all` hosts
    - Add the full `vars:` block with all configurable parameters (essential_packages, docker vars, boot vars, hardening vars, unattended upgrade vars, reboot_timeout)
    - Add the OS compatibility warning pre-task that checks `ansible_os_family != "Debian"`
    - _Requirements: 1.1, 8.1, 8.3, 4.2, 5.2, 6.2, 3.3, 9.3, 7.2_

- [ ] 2. Implement System Updates section (tag: packages)
  - [ ] 2.1 Add system update tasks to `provision.yml`
    - Task: Update apt package cache (`apt: update_cache=yes`)
    - Task: Full system upgrade (`apt: upgrade=dist`)
    - Task: Remove unused packages (`apt: autoremove=yes, purge=yes`)
    - Task: Clean apt cache (`apt: autoclean=yes`)
    - Tag all tasks with `[packages]`
    - _Requirements: 2.1, 2.2, 2.3, 10.3_
  - [ ]* 2.2 Write property test for system update task completeness
    - **Property 5: System update task completeness**
    - Parse `provision.yml` YAML and verify the `packages`-tagged section contains tasks covering all three phases: cache update, dist upgrade, and autoremove cleanup
    - **Validates: Requirements 2.1, 2.2, 2.3**

- [ ] 3. Implement Automatic Security Updates section (tag: upgrades)
  - [ ] 3.1 Add unattended upgrades tasks to `provision.yml`
    - Task: Install `unattended-upgrades` and `apt-listchanges` packages
    - Task: Deploy `/etc/apt/apt.conf.d/20auto-upgrades` using `ansible.builtin.copy` with `content:` referencing `unattended_update_interval` and `unattended_download_interval` variables
    - Task: Deploy `/etc/apt/apt.conf.d/50unattended-upgrades` using `ansible.builtin.template` or `ansible.builtin.copy` with `content:` referencing `unattended_auto_reboot` and `unattended_auto_reboot_time` variables
    - Tag all tasks with `[upgrades]`
    - _Requirements: 3.1, 3.2, 3.3, 10.3_

- [ ] 4. Implement Essential Software section (tag: essentials)
  - [ ] 4.1 Add essential packages installation task to `provision.yml`
    - Task: Install packages from `{{ essential_packages }}` list variable using `apt` module with `state: present`
    - Tag with `[essentials]`
    - _Requirements: 4.1, 4.2, 4.3, 10.3_

- [ ] 5. Checkpoint - Verify base system sections
  - Ensure all tasks pass `ansible-lint`, ask the user if questions arise.

- [ ] 6. Implement Docker section (tag: docker)
  - [ ] 6.1 Add Docker installation tasks to `provision.yml`
    - Task: Remove conflicting packages from `{{ docker_conflicting_packages }}` list
    - Task: Install Docker prerequisites (`ca-certificates`, `curl`, `gnupg`)
    - Task: Add Docker GPG key using `ansible.builtin.get_url` or `ansible.builtin.apt_key` (with idempotent check)
    - Task: Add Docker apt repository using detected OS facts (`ansible_distribution`, `ansible_distribution_release`, `ansible_architecture` mapped to docker arch)
    - Task: Install Docker packages from `{{ docker_packages }}` list
    - Task: Enable and start Docker service via `ansible.builtin.systemd`
    - Task: Add users from `{{ docker_users }}` to the `docker` group
    - Task: Verify Docker installation with `docker --version` command check
    - Tag all tasks with `[docker]`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 8.2, 10.3, 10.4_
  - [ ]* 6.2 Write property test for OS-fact-based repository configuration
    - **Property 2: OS-fact-based repository configuration**
    - Parse `provision.yml` and verify that any task configuring an apt repository references Ansible facts (`ansible_distribution`, `ansible_distribution_release`, `ansible_architecture`) rather than hardcoded OS values
    - **Validates: Requirements 5.2, 8.2**

- [ ] 7. Implement Boot Configuration section (tag: boot)
  - [ ] 7.1 Add boot configuration tasks to `provision.yml`
    - Task: Detect boot config file path by checking `/boot/firmware/config.txt` then `/boot/config.txt` using `ansible.builtin.stat`
    - Task: Fail with clear message if neither boot config path exists
    - Task: Apply boot parameters from `{{ boot_parameters }}` dict using `ansible.builtin.lineinfile` with `regexp` to prevent duplicates
    - Task: Apply kernel command-line parameters from `{{ boot_cmdline_parameters }}` to `cmdline.txt` if defined
    - Register change results for use in conditional reboot
    - Tag all tasks with `[boot]`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 10.2_

- [ ] 8. Implement System Hardening section (tag: hardening)
  - [ ] 8.1 Add system hardening tasks to `provision.yml`
    - Task: Ensure `rsyslog` is installed and running
    - Task: Configure SSH hardening via `ansible.builtin.lineinfile` on `/etc/ssh/sshd_config` (PermitRootLogin, PasswordAuthentication, MaxAuthTries) using variables
    - Task: Install and enable `ufw` firewall
    - Task: Set UFW default policies (deny incoming, allow outgoing)
    - Task: Allow ports from `{{ firewall_allowed_ports }}` list through UFW
    - Task: Restart SSH service if config changed (use handler or `notify`)
    - Tag all tasks with `[hardening]`
    - _Requirements: 9.1, 9.2, 9.3, 10.2, 10.3_

- [ ] 9. Checkpoint - Verify all tagged sections
  - Ensure all tasks pass `ansible-lint`, ask the user if questions arise.

- [ ] 10. Implement Conditional Reboot section (tag: reboot)
  - [ ] 10.1 Add conditional reboot tasks to `provision.yml`
    - Task: Check if `/var/run/reboot-required` exists using `ansible.builtin.stat`
    - Task: Reboot with `ansible.builtin.reboot` gated by `when:` condition checking both `reboot_required_file.stat.exists` and any registered boot config changes (`boot_config_result is defined and boot_config_result.changed`)
    - Use `{{ reboot_timeout }}` variable for the reboot timeout
    - Tag all tasks with `[reboot]`
    - _Requirements: 7.1, 7.2, 7.3_
  - [ ]* 10.2 Write property test for conditional reboot safety
    - **Property 6: Conditional reboot safety**
    - Parse `provision.yml` and verify every reboot task has a `when` condition gating execution on a detected reboot requirement
    - **Validates: Requirements 7.1, 7.2, 7.3**

- [ ] 11. Write property tests for cross-cutting correctness properties
  - [ ]* 11.1 Write property test for variable-driven configuration
    - **Property 1: Variable-driven configuration**
    - Parse `provision.yml` and verify that tasks referencing configurable parameters use Jinja2 variable references (`{{ variable_name }}`) rather than hardcoded literal values
    - **Validates: Requirements 3.3, 4.1, 4.3, 6.1, 7.2, 9.3**
  - [ ]* 11.2 Write property test for idempotent module usage
    - **Property 3: Idempotent module usage**
    - Parse `provision.yml` and verify all state-modifying tasks use declarative Ansible modules (`apt`, `lineinfile`, `copy`, `template`, `systemd`, `ufw`, `user`, `get_url`). Any `shell`/`command` task must have `creates`, `removes`, or `when` condition
    - **Validates: Requirements 10.2, 10.3, 10.4**

- [ ] 12. Create README.md documentation
  - [ ] 12.1 Write `README.md` with usage instructions
    - Document project structure
    - Document how to configure inventory with real host details
    - Document how to run the full playbook and individual tags
    - Document how to override variables with `--extra-vars`
    - Include tag reference table
    - _Requirements: 1.5, 1.6_

- [ ] 13. Final checkpoint - Full project validation
  - Ensure all files pass `ansible-lint` and `yamllint`, ensure property tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate structural correctness by parsing the playbook YAML
- The design specifies `pytest` with `hypothesis` and `pyyaml`/`ruamel.yaml` for property-based tests
