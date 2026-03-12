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

