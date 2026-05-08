# Acceptance Criteria

A bootstrap run is successful only if all of the following are true:

## Storage
- `/data` is mounted correctly
- `/data/.mounted-data-volume` exists
- the mount is persistent
- the mount is validated before Docker starts
- Docker does not use root volume storage
- `/home/ubuntu/data` points to `/data`
- conflicting paths cause failure

## Docker
- Docker is installed from the official Docker repository
- Docker is pinned to the current stable major line
- Docker uses `/data/docker` as its data root
- Docker uses bounded logging
- Docker Compose is available
- BuildKit is enabled globally
- default address pools are configured
- Docker service only starts after mount validation

## Logging
- journald has a bounded size and retention policy
- Docker logs are bounded
- bootstrap logs are captured
- logs do not grow without control

## System Configuration
- zram is enabled and active
- sysctl tuning is applied
- SSH password auth is disabled
- SSH root login is disabled
- system timezone is UTC
- `systemd-timesyncd` is enabled and verified

## User Experience
- `ubuntu` exists and is usable
- `ubuntu` has zsh as the default shell
- Oh My Zsh is installed for `ubuntu`
- the editor is set to `vim`
- the expected operational tools are installed

## Maintenance
- unattended security updates are configured
- reboot policy is configured as agreed
- systemd timers are used for cleanup
- build cache is pruned after 7 days
- stopped containers older than 7 days are pruned
- dangling images are pruned
- named volumes are preserved

## Reliability
- rerunning bootstrap reconciles safely
- ambiguous block device detection fails hard
- root disk is never formatted or modified destructively
- critical stage failures abort the bootstrap
- verification failures abort the bootstrap

## Final Outcome
The instance is ready to be baked into a base AMI and later used as the foundation for service-layer deployment.