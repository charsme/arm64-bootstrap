# Stage Contracts

## Global Requirements for Every Stage

Every stage must:
- be idempotent
- log what it is doing
- fail hard on critical errors
- validate its result
- avoid hidden assumptions
- avoid destructive operations unless explicitly required and safe

## Stage 00: Preflight

Responsibilities:
- confirm running as root
- establish logging
- prevent concurrent execution
- confirm OS expectations
- confirm required tools or install minimal ones
- define shared environment variables

Must not:
- modify disks
- install application stacks
- assume storage layout is already valid

## Stage 01: System Update

Responsibilities:
- refresh package metadata
- install security updates and package refreshes as required
- keep provisioning deterministic

Must not:
- perform uncontrolled upgrades beyond the agreed policy
- mask package failures

## Stage 02: Base Packages

Responsibilities:
- install base utilities
- install `git`, `curl`, `vim`, `zsh`, `tree`, `sudo`, `node` prerequisites, and other agreed operational tools
- install Docker prerequisites

Must not:
- install application stacks
- install unnecessary hardening packages that add operational complexity without reason

## Stage 03: Storage

Responsibilities:
- detect the correct non-root data disk
- fail hard if ambiguous
- format ext4 only if the disk has no filesystem
- mount at `/data`
- create `/data/.mounted-data-volume`
- create or validate `/home/ubuntu/data` symlink
- prepare `/data` subdirectories
- support expansion reconciliation on rerun

Must not:
- format the root disk
- guess on ambiguous block devices
- allow Docker to start before validation

## Stage 04: ZRAM

Responsibilities:
- enable zram
- apply the agreed size and settings
- verify it is active

Must not:
- break boot
- introduce swapfile behavior

## Stage 05: Sysctl

Responsibilities:
- apply network and kernel tuning
- enable BBR and related safe tuning
- apply file descriptor and inotify tuning

Must not:
- apply experimental or unneeded kernel tunings

## Stage 06: Journald

Responsibilities:
- configure persistent journald with strict caps
- enforce retention limits

Must not:
- allow unbounded journal growth
- replace vendor configs directly when a drop-in is appropriate

## Stage 07: Docker Install

Responsibilities:
- configure the official Docker repository
- install Docker packages
- pin to the current stable major line
- install `docker compose`
- enable Docker service

Must not:
- use edge/nightly channels
- use Ubuntu Docker packages if they are not the chosen source of truth
- start Docker before storage validation

## Stage 08: Docker Config

Responsibilities:
- write Docker daemon configuration
- set `data-root` to `/data/docker`
- set `local` logging driver
- set registry mirror support
- set default address pools
- enable BuildKit and related environment defaults
- configure `live-restore`

Must not:
- store Docker runtime on the root volume
- allow unbounded logs
- omit the address pool configuration

## Stage 09: Security

Responsibilities:
- disable password auth for SSH
- disable root login
- keep SSH key-based access only
- preserve bastion-only restriction assumptions
- avoid UFW and fail2ban

Must not:
- weaken SSH security
- increase complexity without benefit

## Stage 10: Oh My Zsh

Responsibilities:
- install Oh My Zsh for `ubuntu` only
- configure `.zshrc`
- set default shell to zsh for `ubuntu`

Must not:
- break the `ubuntu` login shell
- modify root shell profile unnecessarily

## Stage 11: Unattended Upgrades

Responsibilities:
- enable security updates
- configure reboot policy
- apply the agreed reboot window behavior

Must not:
- enable uncontrolled update policies

## Stage 12: Cleanup Timers

Responsibilities:
- configure systemd timers
- prune stopped containers older than 7 days
- prune dangling images
- prune build cache older than 7 days
- keep named volumes intact

Must not:
- use cron
- prune named volumes automatically

## Stage 13: Fstrim

Responsibilities:
- enable weekly trim for gp3-backed storage

Must not:
- interfere with boot
- disable if not needed without reason

## Stage 14: MOTD

Responsibilities:
- provide lightweight operational status information

Must not:
- create noisy login banners
- create brittle shell logic

## Stage 99: Verification

Responsibilities:
- validate mount state
- validate marker file
- validate Docker storage root
- validate zram
- validate journald
- validate network settings
- validate security settings
- validate service readiness

Must not:
- ignore failed validations
- warn-only on critical failures