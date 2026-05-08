# Bootstrap Debugging

## Primary Logs

- `/var/log/user-data.log`
- `/var/log/bootstrap/bootstrap.log`
- `journalctl -u docker`
- `journalctl -u unattended-upgrades`
- `journalctl -u systemd-journald`

## Recommended Checks

1. Confirm the instance received the expected user-data.
2. Confirm the bootstrap repo cloned correctly.
3. Confirm `/data` mounted.
4. Confirm `/data/.mounted-data-volume` exists.
5. Confirm Docker data-root is `/data/docker`.
6. Confirm no stage skipped verification.

## Common Failure Patterns

### `/data` missing
The storage stage must fail hard. Do not allow Docker to start.

### Docker starts on the root volume
This indicates mount validation was bypassed or broken. Treat it as a critical defect.

### Storage detection ambiguous
The bootstrap must stop and not attempt recovery by guessing.

### Package install failure
Re-run bootstrap only after fixing the root cause. The bootstrap is rerunnable, but it is not a substitute for broken package sources.

## Recovery Rule

Do not patch over a broken storage model manually unless the cause is fully understood. Fix the mount path, volume attachment, or detection logic first.
