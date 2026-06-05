# Update Strategy

Three update surfaces, three different cadences. Each has its own
mechanism — do not blend them.

---

## 1. Bootstrap repository

The repository defines the host baseline. Update by pulling `main` and
re-running bootstrap; all stages are idempotent.

```bash
cd /home/ubuntu/arm64-bootstrap
git fetch origin
git log --oneline HEAD..origin/main    # review what is incoming
git pull --ff-only origin main
sudo bash bootstrap/bootstrap.sh
```

Cadence: on demand, driven by repository changes. After a non-trivial
bootstrap change, bake a new AMI rather than relying on every instance
re-running the bootstrap on next boot.

For a fleet of hosts: re-bake the AMI from one canary host, validate, then
roll the new AMI to the rest by relaunching instances (not by SSH-ing into
each one to `git pull`).

## 2. Base host packages

Two channels:

| Channel | Trigger | Scope |
|---------|---------|-------|
| Unattended security updates | systemd timer (stage 11) | security only |
| Controlled refresh | stage 01 during bootstrap | broader package set |

`apt-get upgrade` is not run from cron outside the unattended-upgrades
window. Broader upgrades happen only during a bootstrap run, which means
they happen during AMI bake. This keeps in-place hosts predictable.

Auto-reboot from unattended-upgrades is disabled by default — kernel and
glibc updates take effect at the next planned reboot or AMI relaunch.

## 3. AMI policy

Prefer regular AMI rebakes over uncontrolled in-place drift.

- Re-bake when: bootstrap changes, Ubuntu point release, Docker minor
  version bump, kernel CVE that warrants a reboot anyway.
- Tag every AMI with `bootstrap-version`, `ubuntu-version`, `date`,
  `arch=arm64`.
- Keep the last 2–3 AMIs (see `docs/operations/snapshot-strategy.md`).
- New launches always use the current AMI. Old instances roll forward by
  relaunch, not by in-place upgrade.

The AMI bake procedure is in `docs/operations/ami-baking.md`. The bake
script stops cleanup timers, prunes Docker, and strips the `/data` fstab
entry so the AMI is portable across data volumes.

## 4. Docker

- Pin to the current stable major version of Docker CE. The repository
  installs from the official Docker apt repo (stage 07) — no edge or
  nightly channels.
- Docker minor and patch upgrades come in via the unattended-upgrades
  security channel and the controlled refresh in stage 01.
- Major version bumps are deliberate, gated by a bootstrap change and a
  fresh AMI bake. They are not silent.

## 5. Node.js

- Pin to a Node.js LTS major via `NODE_MAJOR` in `bootstrap/bootstrap.env`
  (stage 16, installed from the official NodeSource apt repo). Default is
  the current active LTS line — no `current`/odd or floating `lts` channel.
- Minor and patch upgrades come in via the unattended-upgrades security
  channel and the controlled refresh in stage 01, same as Docker.
- Major bumps are deliberate. Checklist before bumping `NODE_MAJOR`:
  1. Confirm the target major is an LTS line still in active/maintenance
     support, and that NodeSource publishes it for `arm64`.
  2. Update `NODE_MAJOR` in `bootstrap.env`; rerun stage 16 (idempotent).
  3. Bake a fresh AMI and roll forward by relaunch — not silent in-place.

## 6. AWS CLI

- Pin to an exact AWS CLI v2 version via `AWSCLI_VERSION` in
  `bootstrap/bootstrap.env` (stage 17, official zip bundle — not in the
  Ubuntu arm64 apt repo, so it is not covered by unattended-upgrades).
- The bundle is GPG-verified before install against AWS's published signing
  key, committed at `bootstrap/config/awscli/aws-cli-public-key.asc`.
- Because apt does not patch it, AWS CLI moves only when `AWSCLI_VERSION`
  is bumped. Checklist before bumping:
  1. Confirm the target version publishes an `aarch64` bundle
     (`awscli-exe-linux-aarch64-<version>.zip`) and its `.sig`.
  2. Update `AWSCLI_VERSION`; rerun stage 17 (`aws/install --update` is
     idempotent — installs or updates in place).
  3. Bake a fresh AMI and roll forward by relaunch.
- Signing key rotation: the committed key (fingerprint
  `FB5D B77F D5C1 18B8 0511 ADA8 A631 0ACC 4672 475C`) has an expiry
  (currently 2026-07-07). When AWS rotates it, refresh the committed `.asc`
  from the official install docs and re-verify before committing — otherwise
  stage 17 will start failing verification on new bundles.

## 7. CloudWatch agent

- Pin to an exact agent version via `CWAGENT_VERSION` in
  `bootstrap/bootstrap.env` (stage 18, official S3 `.deb` bundle — not in the
  Ubuntu arm64 apt repo, so it is not covered by unattended-upgrades).
- The `.deb` is GPG-verified before install against AWS's published signing
  key, committed at `bootstrap/config/cloudwatch/amazon-cloudwatch-agent.gpg`.
- Because apt does not patch it, the agent moves only when `CWAGENT_VERSION`
  is bumped. Checklist before bumping:
  1. Confirm the target version publishes an `arm64` bundle and its `.sig` at
     `https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/arm64/<version>/amazon-cloudwatch-agent.deb`.
     The current published version is at
     `https://amazoncloudwatch-agent.s3.amazonaws.com/info/latest/CWAGENT_VERSION`.
  2. Update `CWAGENT_VERSION`; rerun stage 18 (`dpkg -i` of the pinned version
     plus the idempotent `install`/`enable` steps reconcile in place).
  3. Bake a fresh AMI and roll forward by relaunch.
- Signing key rotation: the committed key (fingerprint
  `9376 16F3 450B 7D80 6CBD 9725 D581 6730 3B78 9C72`, uid "Amazon CloudWatch
  Agent") has no listed expiry. If AWS rotates it, refresh the committed
  `.gpg` from `https://amazoncloudwatch-agent.s3.amazonaws.com/assets/amazon-cloudwatch-agent.gpg`
  and re-verify the fingerprint before committing — otherwise stage 18 will
  start failing verification on new bundles.

## Cadence summary

| Surface | Cadence | Mechanism |
|---------|---------|-----------|
| OS security patches | Continuous | unattended-upgrades timer |
| OS broader refresh | At AMI bake | stage 01 in bootstrap |
| Bootstrap repo | On demand | `git pull` + rerun bootstrap |
| Docker | Stable major, minor via security | Docker apt repo |
| Node.js | LTS major (`NODE_MAJOR`), minor via security | NodeSource apt repo |
| AWS CLI | Pinned exact (`AWSCLI_VERSION`), bump deliberate | Official zip bundle |
| CloudWatch agent | Pinned exact (`CWAGENT_VERSION`), bump deliberate | Official S3 `.deb` bundle |
| AMI | Per change or quarterly minimum | bake script |
| Kernel reboot | Planned, via AMI relaunch | manual |

## Rules

- Do not introduce broad uncontrolled `apt-get upgrade` into cron. It
  makes provisioning unpredictable and breaks the "rerunnable bootstrap"
  contract.
- Do not use Docker's edge or nightly channels in this repo.
- Do not in-place upgrade Ubuntu major versions on a long-lived host —
  re-bake the AMI on the new release.
- Do not skip the verify suite after an update. "It applied cleanly" is
  not "it works".
