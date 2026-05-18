# Disaster Recovery

This document covers loss scenarios beyond a single failed boot. For the
single-instance "it broke, fix it" path, use
`docs/runbooks/emergency-recovery.md` first.

---

## Scenarios

| Loss | Source of truth for restore |
|------|-----------------------------|
| Instance only | Last known-good AMI + existing `/data` EBS. |
| Root volume only | Last known-good AMI; relaunch and re-attach `/data`. |
| `/data` volume only | Most recent `/data` snapshot. |
| Both root and `/data` | Last known-good AMI + most recent `/data` snapshot. |
| AZ outage | Restore `/data` snapshot into a different AZ in the same region. |
| Region outage | Out of scope for this bootstrap. Track in the service-layer DR plan. |

The two recovery artifacts you must always have are:

- a current AMI built from a successful bootstrap (see
  `docs/operations/ami-baking.md`),
- a recent `/data` EBS snapshot (see
  `docs/operations/snapshot-strategy.md`).

If either is missing or stale, recovery degrades from "restore" to
"rebuild from source" — slower and lossier.

## Recovery priorities

1. **Preserve `/data`.** Snapshot it before any destructive action if it is
   still attached and accessible.
2. **Restore mount correctness.** The `/data` filesystem, fstab UUID, and
   marker file must agree before Docker is started.
3. **Restore Docker runtime path.** `data-root` must be `/data/docker`.
   Never let Docker fall back to root.
4. **Verify the host baseline.** Run the full verify suite before
   re-introducing services.
5. **Re-deploy services.** Application-layer recovery is outside this
   repository's scope.

## Standard flows

### Instance lost, `/data` survived

1. Launch a fresh instance from the last known-good AMI in the same AZ.
2. Attach the surviving `/data` EBS as the data device.
3. Boot. User-data reruns bootstrap; stage 03 sees the existing
   filesystem, updates fstab UUID, mounts.
4. Run the verify suite. Restart services.

### `/data` lost, instance survived

1. Stop Docker, unmount `/data` if still mounted.
2. Restore the most recent snapshot per
   `docs/runbooks/restore-from-snapshot.md`.
3. Validate.

### Both lost

1. Launch a fresh instance from the last known-good AMI.
2. Create a new EBS volume from the most recent `/data` snapshot in the
   instance AZ. Attach as the data device.
3. Boot. Bootstrap reconciles fstab to the new UUID.
4. Validate. Replay any data missing since the snapshot from upstream
   sources owned by the service layer.

### AZ outage

1. Copy the `/data` snapshot to another AZ in the same region (if not
   already replicated).
2. Launch a fresh instance from the AMI in the new AZ.
3. Restore `/data` from the cross-AZ snapshot.
4. Update DNS or load-balancer pointers in the service layer.

## RPO / RTO expectations

These are baseline targets for the base host; service-layer SLAs may be
tighter and need their own DR.

- **RPO** ≈ snapshot interval (default daily, see
  `docs/operations/snapshot-strategy.md`).
- **RTO** ≈ AMI launch + bootstrap reconcile + verify. Typically a few
  minutes on m7g/r8g once snapshots are warm.

## Rules

- Never format disks blindly during recovery — confirm device identity
  with `lsblk` and `blkid` first.
- Never let Docker auto-create state on the root volume. The whole storage
  contract is built on `/data/docker` being the only data root.
- Never assume the instance is healthy without running the verify suite.
- Keep at least one prior AMI tagged "known good" so rollback is possible
  even mid-restore.
