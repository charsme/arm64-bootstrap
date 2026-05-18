# Runbook: Docker Will Not Start

The docker service is configured to start only after `/data` is mounted and
validated (stage 08 writes a systemd drop-in with `RequiresMountsFor=/data`
and a marker-file `ConditionPathExists`). Most failures are storage-layer,
not Docker-layer.

---

## Triage (in order)

### 1. Read the most recent error first

```bash
systemctl status docker.service --no-pager -l
journalctl -u docker.service -n 80 --no-pager
```

Pay attention to the last 5–10 lines before the failure. Most root causes
print there verbatim.

### 2. Is `/data` mounted and validated?

```bash
mountpoint /data && echo MOUNTED || echo MISSING
test -f /data/.mounted-data-volume && echo MARKER_OK || echo MARKER_MISSING
findmnt /data
lsblk
```

If `/data` is not mounted: see `docs/runbooks/data-volume-missing.md`. Do
not start Docker until `/data` and the marker file are both present —
Docker will create state on the root volume and break the invariant.

### 3. Is the systemd drop-in valid?

```bash
systemctl cat docker.service | sed -n '/Drop-In/,$p'
ls -la /etc/systemd/system/docker.service.d/
```

Expect `override.conf` referencing `/data`. If missing or malformed:

```bash
sudo bash /home/ubuntu/arm64-bootstrap/bootstrap/stages/08-docker-config.sh
sudo systemctl daemon-reload
```

### 4. Is `daemon.json` valid JSON and pointing at `/data/docker`?

```bash
sudo cat /etc/docker/daemon.json
sudo python3 -c 'import json,sys; json.load(open("/etc/docker/daemon.json"))' \
  && echo JSON_OK || echo JSON_INVALID
```

If invalid: re-run stage 08; do NOT hand-edit unless the stage cannot fix
it. Confirm `data-root` is `/data/docker`.

### 5. Address-pool or IPv6 conflicts

If the daemon logs complain about pool overlap (`172.30.0.0/16` or
`172.20.0.0/16`) with an existing VPC route or `docker0` interface:

```bash
ip route | grep -E '172\.(20|30)\.'
docker network ls
```

Resolve by changing `DOCKER_POOL_1_BASE` / `DOCKER_POOL_2_BASE` in
`bootstrap/bootstrap.env`, re-running stage 08, restarting the daemon.

### 6. Disk full

```bash
df -h /data /var/lib
```

Docker may fail to start if `/data` is at 100%. See
`docs/runbooks/disk-full.md`.

## Recovery

Once the underlying cause is fixed:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker.service
sudo systemctl status docker.service --no-pager
docker info | grep -E 'DockerRootDir|Live Restore|Storage Driver'
```

`DockerRootDir` must be `/data/docker`. If it shows `/var/lib/docker`, stop
the daemon immediately — Docker is on the root volume in violation of the
core invariant.

## Escalation

If the daemon will not start after the storage layer is clean and configs
are valid:

1. Capture `journalctl -u docker.service -b --no-pager` to a file.
2. Capture `docker info` output (if it runs).
3. Capture `/etc/docker/daemon.json` and the drop-in.
4. Roll the AMI back rather than experimenting in place.

## Do Not

- Set `data-root` to `/var/lib/docker` to "make it start". That breaks the
  storage invariant and silently fills the root volume.
- Disable the `RequiresMountsFor=/data` ordering — the protection exists
  precisely for the failure case in front of you.
- Run `docker system prune -af` before identifying the cause; you may
  destroy the evidence.
