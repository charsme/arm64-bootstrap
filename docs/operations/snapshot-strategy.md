# Snapshot Strategy

Two independent backup domains: the root volume (host baseline) and the
`/data` volume (operational state). Treat them differently.

---

## Root Volume

The root volume holds the OS and the bootstrap layer. It is reproducible
from the repository, so root-volume snapshots are not the primary backup
artifact — the **AMI** is.

- Bake an AMI after each meaningful bootstrap change
  (see `docs/operations/ami-baking.md`).
- Keep the last 2–3 AMIs tagged: one "current", one "previous", optionally
  one "known-good baseline".
- Do NOT include `/data` in the AMI snapshot (the AMI bake script strips
  the `/data` fstab entry to prevent UUID conflicts on relaunch).

Ad-hoc root-volume snapshots are useful right before a risky in-place
upgrade. Delete them once a fresh AMI is baked.

## `/data` Volume

`/data` holds persistent operational state: Docker data root, compose
stacks, named volumes, workspaces, caches, logs, backups. Snapshots of
`/data` are the only authoritative backup for anything that lives here.

### Policy

| Setting | Value |
|---------|-------|
| Cadence | Daily |
| Retention | At least 7 daily snapshots |
| Schedule | Off-peak (e.g. 03:00 UTC) |
| Encryption | Same KMS key as the source volume |
| Cross-region | Optional; required only if regional DR is in scope |
| Tags | `volume=data`, `instance=<id>`, `date=<YYYY-MM-DD>` |

Recommended implementation: **AWS Backup** or **DLM (Data Lifecycle
Manager)** with a tag-based selection rule. Avoid hand-rolled cron-based
snapshots — they drift.

### Pre-snapshot hygiene

EBS snapshots are crash-consistent, not application-consistent. For
single-tenant trusted workloads this is acceptable for most cases. For
workloads with weak crash-recovery, quiesce them before the snapshot
window in the service layer.

`fstrim` runs on a weekly timer (stage 13) so snapshots stay small.

## Restore testing

A snapshot you have not restored is a snapshot you do not have. Schedule a
periodic restore drill:

1. Pick a recent snapshot.
2. Create a new volume from it in a test AZ.
3. Attach to a throwaway instance, boot through bootstrap.
4. Confirm `mountpoint /data`, marker file, and a known sentinel file
   present.
5. Tear down. Record the drill date.

Target cadence: quarterly at minimum, monthly for fast-moving workloads.

## Restore Rules

After any restore:

- Validate the mount UUID or label matches what stage 03 wrote to fstab.
- Validate `/data/.mounted-data-volume` is present (bootstrap rewrites it
  on a successful reconcile).
- Validate Docker does not fall back to root storage:
  `docker info | grep DockerRootDir` must return `/data/docker`.
- Run the full verify suite before declaring the host healthy.

See `docs/runbooks/restore-from-snapshot.md` for the step-by-step
procedure.

## What snapshots do not cover

- Secrets and credentials that live outside `/data` (e.g. injected via
  IAM, SSM Parameter Store, or Secrets Manager). Back those up at the
  source of truth.
- Configuration drift on the root volume. Re-bake AMIs instead.
- In-flight transactions or unflushed writes. Crash-consistent snapshots
  capture the on-disk state at snapshot time, not in-memory state.
