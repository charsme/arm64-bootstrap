# Runbook: Docker Will Not Start

## Checks

1. Confirm `/data` is mounted.
2. Confirm `/data/.mounted-data-volume` exists.
3. Confirm Docker daemon config points to `/data/docker`.
4. Confirm no invalid daemon.json syntax.
5. Confirm systemd drop-in is valid.
6. Confirm mount is present before Docker service start.

## Recovery

- fix mount
- fix Docker config
- restart Docker only after storage validation passes
