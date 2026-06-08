# Deployment Checklist — arm64-bootstrap

Generated from pre-deployment review. Check each section before and after first launch.

---

## Deployment Readiness

Bootstrap is structurally sound for first EC2 deployment on ARM64 Graviton —
sustained m8g/r8g/c8g/m7g (Graviton3/4) or burstable t4g (Graviton2), sizes
medium–xlarge — with a single attached data EBS. All critical
invariants enforced. Stage boundaries clean.

Docker CE publishes packages for Ubuntu 26 `resolute` — stage 07 installs
docker-ce cleanly without codename pinning.

---

## EC2 Launch Parameters

```
Instance type:        Graviton ARM64. Sustained: m8g (G4 general), r8g (memory),
                      c8g (compute), m7g (G3 general). Burstable: t4g (G2).
                      Sizes medium–xlarge; ≥2 GiB RAM (see Instance Sizing Notes).
Architecture:         arm64
AMI:                  Ubuntu 26.04 LTS arm64 (official Canonical)
Root volume:          30 GB gp3, encrypted, not shared
Data volume:          <workload-sized> gp3, encrypted, /dev/sdf (appears as nvme1n1),
                      NO snapshot, NO existing filesystem
User data:            contents of user-data/user-data.sh
IAM role:             role with AmazonSSMManagedInstanceCore
Security group:       port 22 from operator CIDR only
Key pair:             operator key pair
Metadata:             IMDSv2 enforced (HttpTokens=required)
Placement:            single AZ, same AZ as the data EBS
Shutdown behavior:    stop (not terminate)
Termination protect:  enabled for production
```

**User data:** copy the full contents of `user-data/user-data.sh` into the User Data field.

---

## Instance Sizing Notes

Bootstrap enforces only the `aarch64` architecture gate (plus Ubuntu 26.04) — no
instance-type or family check. Any Graviton size runs. RAM/FS-dependent tuning
(zram, `vm.dirty_bytes`, journald `SystemMaxUse`) auto-derives from live system
state on every run, so it tracks the chosen size with no manual change. See
`docs/runbooks/instance-resize.md` for moving between sizes.

Caveats at the small / burstable end:

- **Minimum RAM:** stage 00 emits a non-fatal WARN below 4 GiB. The host boots and
  runs at 2 GiB (`t4g.small`, `c8g.large`, `m8g.medium`…), but baseline services
  (Docker daemon, CloudWatch agent, Node, zsh) consume a meaningful fraction before
  any workload. Size data EBS and workloads accordingly.
- **Burstable t4g (Graviton2):** zram uses zstd compression. Under sustained memory
  pressure, compression burns CPU → drains **CPU credits** → throttling. Watch the
  instance's `CPUCreditBalance` on swap-heavy workloads. Sustained families (m8g/
  r8g/c8g/m7g) have no credit model and avoid this entirely.
- **Single-vCPU sizes** (`m8g.medium`): zstd + Docker share one core. Acceptable for
  light workloads; prefer ≥2 vCPU for concurrent container builds.
- **Static ceilings** (`fs.file-max`, inotify, TCP buffers, Docker ulimits) are sized
  for up to ~32 GiB RAM (`r8g.xlarge`). Above that, revisit them — see
  `bootstrap/config/sysctl/50-bootstrap.conf` comments.

Sizes/families other than `m7g.large` and `r8g.large` are permitted but **not yet
hardware-validated** — first run on a new size should be watched.

---

## Pre-Launch Checklist

- [ ] Instance type is ARM64 Nitro Graviton — sustained m8g/r8g/c8g/m7g or burstable t4g (see Instance Sizing Notes)
- [ ] Root EBS: 30 GB+ gp3
- [ ] Data EBS: sized for workload, gp3, **unformatted**, attached as second device
- [ ] Security Group: SSH port 22 from bastion/operator IP only — no 0.0.0.0/0
- [ ] IAM role has `AmazonSSMManagedInstanceCore` (out-of-band access if SSH breaks)
- [ ] Operator SSH public key is in the AMI or injected via cloud-init
- [ ] Ubuntu 26 Official ARM64 AMI available in target region
- [ ] Repository `https://github.com/charsme/arm64-bootstrap` is public and reachable
- [ ] Exactly ONE non-root block device attached (more triggers "ambiguous device detection" fatal)
- [ ] VPC CIDR does not overlap `172.30.0.0/16` or `172.20.0.0/16` (Docker address pools)

---

## Validation Commands After First Boot

```bash
# Bootstrap outcome
cat /etc/bootstrap-version
tail -50 /var/log/bootstrap/bootstrap.log

# Storage
mountpoint /data
cat /data/.mounted-data-volume
df -h /data
lsblk

# Docker
systemctl is-active docker
docker info | grep -E 'DockerRootDir|Storage|Server'
docker run --rm hello-world

# Journald bounds
journalctl --disk-usage
journalctl -n 5

# Zram
swapon --show
zramctl

# SSH hardening
sshd -T | grep -E 'passwordauthentication|permitrootlogin|kbdinteractiveauthentication'

# Network tuning
sysctl net.ipv4.tcp_congestion_control
sysctl net.ipv4.ip_forward
lsmod | grep br_netfilter

# Timers
systemctl list-timers --all | grep -E 'cleanup|fstrim|apt'

# Unattended upgrades
systemctl is-active unattended-upgrades
grep Reboot /etc/apt/apt.conf.d/50unattended-upgrades

# Full verify suite
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-bootstrap.sh
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-storage.sh
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-docker.sh
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-network.sh
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-security.sh
```

---

## AMI Bake Checklist

1. Confirm bootstrap completed: `cat /etc/bootstrap-version`
2. Run full verify suite — all five checks must pass
3. Confirm Docker data root: `docker info | grep DockerRootDir` → must be `/data/docker`
4. Confirm `/data` is mounted and marker file present
5. Stop any running containers: `docker stop $(docker ps -q) 2>/dev/null || true`
6. Run `bash /home/ubuntu/arm64-bootstrap/scripts/bake-ami.sh`
   - Stops cleanup/fstrim timers
   - Re-runs full verify suite
   - Prunes Docker
   - **Strips `/data` fstab entry** (required — prevents UUID conflict on AMI instances)
7. Confirm fstab has no `/data` entry: `grep /data /etc/fstab` → must return nothing
8. Stop the instance — do NOT terminate
9. Create AMI from AWS console or `aws ec2 create-image --no-reboot`
10. Tag AMI: `bootstrap-version`, `ubuntu-version`, `date`, `arch=arm64`
11. Do NOT include the data EBS in the snapshot

**Post-bake:** First launch from AMI runs user-data, which re-runs bootstrap. Stage 03
finds the fresh EBS, formats it, adds the correct UUID to fstab. All stages are
idempotent — already-complete stages skip safely.

---

## Rollback Strategy

### Bootstrap fails mid-run
```bash
# Check logs
cat /var/log/user-data.log
cat /var/log/bootstrap/bootstrap.log

# Re-run (all stages are idempotent)
cd /home/ubuntu/arm64-bootstrap
bash bootstrap/bootstrap.sh
```
If SSH access is lost: use EC2 Instance Connect or SSM Session Manager.

### Docker won't start after reboot
```bash
systemctl status docker
journalctl -u docker -n 30
lsblk
mountpoint /data
cat /etc/fstab
```
If UUID mismatch in fstab (replaced EBS):
```bash
sed -i '\,^[^#].*[[:space:]]/data[[:space:]],d' /etc/fstab
bash /home/ubuntu/arm64-bootstrap/bootstrap/stages/03-storage.sh
```
If EBS is detached: re-attach in AWS console (keep same device name), then `mount /data`.

### AMI instance fatals "fstab has existing entry for /data with different UUID"
AMI was baked before the fstab-strip fix. One-time manual fix:
```bash
sed -i '\,^[^#].*[[:space:]]/data[[:space:]],d' /etc/fstab
bash bootstrap/bootstrap.sh
```

### Roll back to previous AMI
Keep prior AMI version tagged. Launch new instance from prior AMI tag.
Data EBS is decoupled from AMI — workload data on the EBS is preserved.

---

## CloudWatch Agent / Compute Optimizer Prerequisites (Stage 18)

Stage 18 installs and configures the CloudWatch agent but starts it only when an IAM
role is attached — a boot-time systemd `ExecCondition` gate re-checks on every boot.
The following account- and instance-level steps are required for memory metrics to
reach Compute Optimizer; the host cannot perform them on its own.

- [ ] Attach an instance profile whose role includes the AWS managed policy
  `CloudWatchAgentServerPolicy` (grants `cloudwatch:PutMetricData` and related
  permissions required by the agent).
- [ ] If the role was attached **after** first boot, reboot the instance — the
  `ExecCondition` gate runs at boot time and will start the agent on the next boot
  once a role is present.
- [ ] Enable AWS Compute Optimizer for the account and region (one-time opt-in):
  AWS Console → Compute Optimizer → Get Started, **or**
  `aws compute-optimizer update-enrollment-status --status Active`.
- [ ] Allow the observation window: Compute Optimizer requires several days of
  `mem_used_percent` data before emitting a memory rightsizing recommendation.

**Known limitation:** the gate detects role *presence* only — it does not verify
that the attached role grants `cloudwatch:PutMetricData`. A present-but-under-permissioned
role lets the agent start while `PutMetricData` returns 403. The login motd will still
report the agent as "running". Check
`/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log` for permission
errors if Compute Optimizer shows no memory data after the observation window.

---

## Known Risks (Residual)

| Severity | Risk |
|----------|------|
| Medium | SSM agent not explicitly installed — if custom AMI lacks it, no out-of-band access if SSH breaks |
| Low | `172.30.0.0/16` Docker pool conflicts with custom VPCs in that range |
| Low | `Seal=yes` in journald config has no effect without `journalctl --setup-keys` |
| Low | Docker image cleanup timer prunes images older than 7 days — staged/standby images may be removed |
| Low | CloudWatch agent IAM gate detects role presence only — a present-but-under-permissioned role starts the agent while `PutMetricData` returns 403 (silent from motd) |
