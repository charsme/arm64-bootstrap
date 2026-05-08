# Runbook: Disk Full

## Symptom

Logs or runtime data are consuming too much disk space.

## Likely Areas

- `/var/log`
- `/data/docker`
- `/data/cache`
- `/data/workspaces`

## Checks

- `df -h`
- `docker system df`
- `journalctl --disk-usage`

## Cleanup Order

1. prune build cache
2. prune stopped containers
3. review `/data/cache`
4. review logs
5. expand `/data` if necessary

## Do Not

- delete Docker volumes blindly
- remove persistent service data without understanding the workload
