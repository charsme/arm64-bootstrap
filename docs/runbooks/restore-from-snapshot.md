# Runbook: Restore `/data` from EBS Snapshot

Use when the live `/data` EBS volume is lost, corrupted, or you need to roll
back to a point-in-time snapshot. The root volume is not in scope here — see
`docs/runbooks/emergency-recovery.md` for instance-level recovery.

---

## Pre-flight

- Identify the snapshot ID and target AZ. The new volume must be created in
  the same AZ as the EC2 instance.
- Confirm the snapshot is the `/data` snapshot, not a root-disk snapshot.
  Verify by tag, description, or volume size.
- Decide: in-place replace (stop instance, swap volume) or side-by-side
  (attach as second volume, copy needed paths). In-place is the default.

## Procedure (in-place replace)

1. Stop Docker so it releases `/data/docker`.
   ```bash
   sudo systemctl stop docker.socket docker.service
   ```
2. Unmount `/data`.
   ```bash
   sudo umount /data
   ```
3. In AWS: detach the current `/data` EBS volume from the instance. Do NOT
   delete it yet — keep it as a fallback until restore is validated.
4. Create a new EBS volume from the snapshot, gp3, encrypted, in the
   instance AZ.
5. Attach the new volume as the data device (same device name expected by
   stage 03, typically `/dev/sdf` → `nvme1n1`).
6. SSH back in. The fstab entry from the previous volume is stale (UUID
   mismatch). Strip and re-run stage 03:
   ```bash
   sudo sed -i '\,^[^#].*[[:space:]]/data[[:space:]],d' /etc/fstab
   sudo bash /home/ubuntu/arm64-bootstrap/bootstrap/stages/03-storage.sh
   ```
   Stage 03 is idempotent: detects the existing ext4 filesystem on the
   restored volume, refuses to reformat, writes the new UUID into fstab,
   mounts at `/data`.
7. Start Docker.
   ```bash
   sudo systemctl start docker.service
   ```

## Validation

- `mountpoint /data` returns `is a mountpoint`.
- `test -f /data/.mounted-data-volume` returns 0.
- `findmnt /data` shows the new volume UUID, matching `/etc/fstab`.
- `docker info | grep DockerRootDir` returns `/data/docker`.
- Sample container starts: `docker run --rm hello-world`.
- Application data spot-check: known files present at expected paths under
  `/data/stacks` and `/data/volumes`.

## Rollback

If validation fails:

1. Stop Docker, unmount `/data`.
2. Detach the restored volume.
3. Re-attach the original volume.
4. Strip the stale fstab entry again and re-run stage 03.

## Do Not

- Re-attach the snapshot-restored volume as the root device.
- Run `mkfs` on the restored volume — stage 03 must skip format for an
  existing filesystem; if it tries to format, abort and investigate.
- Leave the old volume attached as a third block device while bootstrapping
  — stage 03 fails "ambiguous device detection" by design.
