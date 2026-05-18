# Emergency Recovery

For an instance that is unreachable, half-booted, or in an unknown state.
The goal is to restore a known-good baseline without destroying `/data`.

---

## Decision Tree

| Symptom | First action |
|---------|--------------|
| SSH dead, instance running | EC2 Instance Connect or SSM Session Manager. |
| Instance status check failing | Stop, detach root volume, attach to a recovery instance, inspect. |
| Boot loop | Get console output from the EC2 console; do NOT terminate. |
| `/data` missing or wrong device | See `docs/runbooks/data-volume-missing.md`. |
| Docker dead | See `docs/runbooks/docker-wont-start.md`. |
| Disk full | See `docs/runbooks/disk-full.md`. |

Never terminate the failing instance until `/data` is confirmed safe
(detached or snapshotted).

## Out-of-band access

- **EC2 Instance Connect** — works if the SSH daemon is up but key-based
  access is broken. Pushes a temporary key.
- **SSM Session Manager** — works if `amazon-ssm-agent` is running and the
  instance has `AmazonSSMManagedInstanceCore` on its role. No SSH required.

If neither works, stop the instance and attach the root volume to a healthy
recovery instance to inspect logs offline.

## Standard sequence

1. Get on the host (SSH, Instance Connect, or SSM).
2. Read `/var/log/user-data.log` and `/var/log/bootstrap/bootstrap.log` —
   look for the last successful stage and the first error.
3. Read `journalctl -b --no-pager | tail -200` for kernel/systemd errors.
4. Stop Docker before doing anything that touches `/data`:
   ```bash
   sudo systemctl stop docker.socket docker.service
   ```
5. Verify disk attachments and labels: `lsblk`, `blkid`, `findmnt /data`.
6. Verify `/data` mount and marker file:
   ```bash
   mountpoint /data
   test -f /data/.mounted-data-volume && echo OK
   ```
7. Verify Docker root: `grep data-root /etc/docker/daemon.json`.
8. Re-run bootstrap only if stages are missing or broken:
   ```bash
   sudo bash /home/ubuntu/arm64-bootstrap/bootstrap/bootstrap.sh
   ```
   Stages are idempotent. A rerun reconciles state; it does not destroy
   data on an existing `/data` filesystem.
9. Run the verify suite:
   ```bash
   for v in bootstrap storage docker network security; do
     sudo bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-$v.sh
   done
   ```
10. If the host baseline drifted (e.g. you hand-patched configs to recover),
    re-bake the AMI per `docs/operations/ami-baking.md`.

## Last-resort: rebuild the instance

If the host cannot be made healthy:

1. Snapshot `/data` immediately.
2. Detach `/data` from the failing instance.
3. Stop, do NOT terminate, the failing instance (preserves console logs).
4. Launch a fresh instance from the last known-good AMI.
5. Attach the same `/data` volume. Bootstrap reruns will reconcile fstab.
6. Validate, then terminate the old instance once you are certain.

## Rules

- Storage correctness first. Never paper over a mount problem by letting
  Docker fall back to `/var/lib/docker`.
- Never run `mkfs` on a device unless you have just confirmed it is the
  intended target with both `lsblk` and `blkid`.
- Never `rm -rf` under `/data` to "free space" without identifying the
  service that owns the path.
- Keep the failing instance around until recovery is validated. Termination
  is irreversible; stop is not.
