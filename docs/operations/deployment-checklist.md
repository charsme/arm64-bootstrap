# Deployment Checklist — arm64-bootstrap

Generated from pre-deployment review. Check each section before and after first launch.

---

## Deployment Readiness

Bootstrap is structurally sound for first EC2 deployment on m7g.large ARM64 with a
single attached data EBS. All critical invariants enforced. Stage boundaries clean.

**Blocking uncertainty:** Docker CE does not yet publish packages for Ubuntu 26 (codename
unknown until release, expected April 2026). Bootstrap succeeds through stage 06, fails
at `apt-get install docker-ce` in stage 07. Once Docker CE ships Ubuntu 26 packages,
deployment is unblocked. Workaround: temporarily pin `CODENAME=noble` in stage 07 and
test on Ubuntu 24.04 first.

---

## EC2 Launch Parameters

```
Instance type:        m7g.large (or r8g.large for memory-intensive workloads)
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

## Pre-Launch Checklist

- [ ] Instance type is ARM64 Nitro (m7g.large or compatible)
- [ ] Root EBS: 30 GB+ gp3
- [ ] Data EBS: sized for workload, gp3, **unformatted**, attached as second device
- [ ] Security Group: SSH port 22 from bastion/operator IP only — no 0.0.0.0/0
- [ ] IAM role has `AmazonSSMManagedInstanceCore` (out-of-band access if SSH breaks)
- [ ] Operator SSH public key is in the AMI or injected via cloud-init
- [ ] Ubuntu 26 Official ARM64 AMI available in target region
- [ ] Docker CE repo has packages for Ubuntu 26 codename (check download.docker.com)
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

## Known Risks (Residual)

| Severity | Risk |
|----------|------|
| Blocking | Docker CE may not have Ubuntu 26 packages at launch time |
| Medium | SSM agent not explicitly installed — if custom AMI lacks it, no out-of-band access if SSH breaks |
| Medium | Bootstrap log (`/var/log/bootstrap/bootstrap.log`) has no logrotate — grows across reruns |
| Low | `172.30.0.0/16` Docker pool conflicts with custom VPCs in that range |
| Low | `Seal=yes` in journald config has no effect without `journalctl --setup-keys` |
| Low | Docker image cleanup timer prunes images older than 7 days — staged/standby images may be removed |
