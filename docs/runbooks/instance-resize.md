# Instance Resize

Scenario: scale an existing arm64-bootstrap host between Graviton instance types
(e.g., `m7g.large` ↔ `r8g.large` ↔ `c8g.large`). Tuning that depends on
RAM or root filesystem size must be re-derived after resize.

This runbook does not cover changing CPU architecture, AMI, or Ubuntu version.

## What re-derives automatically

Bootstrap stages are idempotent and read live system state on every run.
A rerun produces correct values for the new instance:

| Knob | Source | Stage |
|------|--------|-------|
| `zram-size` | `MemTotal` via systemd-zram-generator formula | 04 |
| `vm.dirty_bytes`, `vm.dirty_background_bytes` | `MemTotal` × 10% capped 512 MiB | 05 |
| `SystemMaxUse` (journald) | filesystem size × 2% capped 1 GiB | 06 |

Static knobs (`fs.file-max`, inotify limits, TCP socket buffer ceilings,
Docker ulimits) do not depend on instance size and require no rerun.

## Pre-resize

1. Confirm the instance is in a state where a stop is acceptable.
2. The `/data` EBS is independent of the AMI/instance — no action needed.
3. No fstab change required; `/data` is mounted by UUID.

## Resize steps

1. Stop the instance from the AWS console or CLI:
   ```
   aws ec2 stop-instances --instance-ids <id>
   ```
2. Modify instance type:
   ```
   aws ec2 modify-instance-attribute --instance-id <id> \
     --instance-type '{"Value":"r8g.large"}'
   ```
3. Start the instance:
   ```
   aws ec2 start-instances --instance-ids <id>
   ```
4. SSH in. Confirm `/data` is mounted and the marker file is present:
   ```
   mountpoint /data
   cat /data/.mounted-data-volume
   ```

## Post-resize: re-run bootstrap

Re-run the relevant stages to re-derive RAM/FS-dependent tuning:

```
sudo bash /home/ubuntu/arm64-bootstrap/bootstrap/stages/04-zram.sh
sudo bash /home/ubuntu/arm64-bootstrap/bootstrap/stages/05-sysctl.sh
sudo bash /home/ubuntu/arm64-bootstrap/bootstrap/stages/06-journald.sh
```

Or simply re-run the full bootstrap (every stage is idempotent):

```
sudo bash /home/ubuntu/arm64-bootstrap/bootstrap/bootstrap.sh
```

## zram live-resize gotcha

`systemctl restart systemd-zram-setup@zram0.service` alone fails with
`Device or resource busy` because the kernel rejects `comp_algorithm`
changes on a device that is still attached to swap. Stage 04 hands off to
the zram-generator unit, which does not include a stop-time `swapoff`.

To resize zram in place without rebooting:

```
sudo swapoff /dev/zram0
echo 1 | sudo tee /sys/block/zram0/reset
sudo systemctl restart systemd-zram-setup@zram0.service
```

Verify:

```
zramctl
swapon --show
```

On the next reboot the zram-generator reads
`/etc/systemd/zram-generator.conf` from scratch, so the in-place dance is
only needed when you want the new size active in the current boot.

## Verify

```
free -h
zramctl
sysctl vm.dirty_bytes vm.dirty_background_bytes
cat /etc/systemd/journald.conf.d/50-bootstrap.conf | grep SystemMaxUse
journalctl --disk-usage
```

## When you scale down

Scaling down (e.g., `r8g.large` → `m7g.large`) follows the same procedure.
Confirm before stopping the instance that committed RAM (`free -h` Used)
plus zram-resident pages will fit in the smaller RAM size; otherwise the
post-resize host risks OOM on cold start.
