# CLAUDE.md

## Project Purpose

This repository provisions a reproducible ARM64 Ubuntu 26 EC2 base host for long-lived AI orchestration workloads on AWS.

The target outcome is a clean, safe, rerunnable bootstrap that prepares an instance for later AMI baking and later service-layer deployment.

This repository is not for application stack deployment. It prepares the host only.

## Core Design Intent

The host is expected to run on:
- Ubuntu 26 LTS
- AWS Graviton ARM64
- EC2 `m7g.large`
- Docker Compose
- trusted single-tenant infrastructure
- a persistent `/data` EBS volume for operational state

The root volume is for OS and system concerns only.
The `/data` volume is for persistent operational data, Docker runtime, compose projects, workspaces, repos, and service data.

## Non-Negotiable Invariants

These rules must never be violated.

- Docker must never start unless `/data` is mounted and validated.
- Root disk must never be formatted, repartitioned, or modified destructively.
- Ambiguous block device detection must fail hard.
- Bootstrap must fail immediately on critical errors.
- Docker must never silently fall back to root volume storage.
- Logs must remain bounded.
- Bootstrap scripts must remain modular, not collapse into a single giant file.
- Stages must remain idempotent.
- If a package/config supports drop-in overrides, use a drop-in override instead of replacing vendor-managed main config files.

## Bootstrap Philosophy

Bootstrap is:
- rerunnable
- idempotent
- fail-fast
- modular
- shell-script based
- root-orchestrated
- minimal cloud-init + main bash orchestration

Bootstrap is not:
- enterprise fleet automation
- Kubernetes
- a monolithic shell blob
- best-effort configuration with hidden fallback behavior

## Execution Model

The normal flow is:
1. EC2 launches with a minimal user-data script.
2. User-data clones the public bootstrap repository.
3. User-data runs the main bootstrap entrypoint.
4. Bootstrap provisions the host in stages.
5. Verification must pass at the end.
6. The host is then ready for AMI baking or later service deployment.

Bootstrap reruns must reconcile state safely without destructive side effects.

## Storage Model

Root volume:
- OS
- system packages
- journals
- bootstrap artifacts
- temporary provisioning state

Persistent data volume:
- mounted at `/data`
- encrypted gp3 EBS
- ext4
- label/UUID-based mount
- fails boot if missing
- marker file required:
  - `/data/.mounted-data-volume`

## `/data` Layout Expectations

The bootstrap should prepare a predictable structure under `/data`.

Expected top-level directories include:
- `/data/docker`
- `/data/stacks`
- `/data/volumes`
- `/data/workspaces`
- `/data/repos`
- `/data/cache`
- `/data/backups`
- `/data/logs`
- `/data/tmp`

## Docker Rules

Docker must be installed from the official Docker repository only.

The following policies apply:
- pin to the current stable major version available at implementation time
- avoid nightly or edge channels
- enable BuildKit globally
- enable `docker compose`
- use `local` logging driver
- configure bounded log rotation
- configure explicit default address pools
- configure registry mirror support where applicable
- configure `live-restore`
- Docker data root must be under `/data/docker`

Docker must not start before `/data` is validated.

Docker socket access is allowed for the `ubuntu` user in this project’s trust model.

## Networking Rules

- Leave IPv6 enabled unless a stage explicitly justifies otherwise.
- Disable UFW.
- Disable fail2ban.
- Use AWS Security Groups as the primary perimeter.
- Enable BBR and sane network tuning.
- Preserve Cloudflare real IP behavior in the later application layer, not in this base AMI.

## Security Rules

- Disable password auth for SSH.
- Disable root SSH login.
- Restrict SSH access via Security Groups to bastion-origin traffic.
- Use `systemd-timesyncd`.
- Use UTC as host timezone.
- Do not add unnecessary hardening that creates operational complexity without clear benefit for this trusted single-tenant model.

## Logging Rules

- Persistent journald is allowed only with strict caps.
- Docker logs must be bounded.
- Global wildcard logrotate rules should not be used for container runtime logs.
- Logs must not be allowed to grow without control.

## Update Policy

- Use security updates plus package refresh during provisioning.
- Controlled upgrade during AMI bake is acceptable.
- Do not introduce broad, uncontrolled update behavior that makes provisioning unpredictable.

## Systemd Rules

- Prefer systemd timers over cron.
- Prefer drop-in overrides under `/etc/systemd/system/<unit>.d/*.conf` when a vendor-managed service needs customization.
- Do not replace vendor-managed service files when a drop-in is sufficient.

## User and Shell Rules

- Use the `ubuntu` user as the main operator account.
- Install `zsh` and Oh My Zsh for `ubuntu` only.
- Set `zsh` as the default shell for `ubuntu`.
- Configure `.zshrc` correctly during bootstrap.
- Install `git`, `docker`, `docker compose`, `node`, `sudo`, `tree`, and the other recommended operational utilities.
- Use `vim` as the default editor.

## Repository Governance

The repository must remain structured and readable.
Do not flatten the repository into a single shell script.
Do not rename established stage boundaries casually.
Do not delete validation logic just to reduce line count.
Do not introduce environment-specific assumptions that are not documented.

## Stage Contract Summary

Every stage must:
- be idempotent
- have a clear responsibility
- fail hard on critical errors
- log its work
- validate its result

If a stage cannot guarantee correctness, it must abort rather than guess.

## Acceptance Summary

A run is successful only if:
- `/data` is mounted and marker file exists
- Docker is configured to use `/data/docker`
- Docker does not fall back to root storage
- Docker starts only after mount validation
- journald is bounded
- logs are bounded
- zram is active
- SSH hardening is applied
- unattended security updates are configured
- verification passes

## Implementation Principle

Prefer clarity, safety, and reproducibility over compactness.
Prefer explicit checks over implicit assumptions.
Prefer modular files over one large script.
Prefer failing early over continuing in an unknown state.