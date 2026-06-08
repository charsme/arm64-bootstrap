# Ubuntu 24.04 Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the bootstrap to provision on Ubuntu 24.04 LTS (`noble`) in addition to 26.04 LTS (`resolute`), so hosts can run on 24.04 while GitLab lacks 26.04 support.

**Architecture:** The bootstrap is already codename-dynamic — Docker derives its apt codename from `/etc/os-release` at runtime, Node uses NodeSource's distro-agnostic `nodistro` repo, AWS CLI/CloudWatch install from version-independent bundles, unattended-upgrades uses APT's `${distro_codename}` macro, and all RAM/FS sizing derives from live system state. The change set is therefore small: widen the OS allow-list, make one hardcoded motd string version-aware, refresh docs, and — the real gate — validate a full run on a live 24.04 arm64 host. No stage restructure, no new abstraction.

**Tech Stack:** Bash, systemd, apt, `/etc/os-release`, existing `bootstrap/verify/*` suite.

---

## Conventions (read once before starting)

This repo has **no unit-test framework**. CI (`.github/workflows/shellcheck.yml`) runs strict `shellcheck` over `bootstrap scripts user-data`. Runtime correctness is checked by on-host scripts in `bootstrap/verify/`.

Two verification tiers used throughout this plan:

- **Local/CI (runnable now, on any machine):** `shellcheck -x <file>`, `bash -n <file>`. Every code task includes these.
- **On-host (runnable only on a target EC2 instance after a real bootstrap run):** the `bootstrap/verify/*` suite plus the 24.04 acceptance matrix in Task 5. This is the actual acceptance gate, not a per-task gate.

Every new/edited shell file MUST pass strict shellcheck. When a disable is unavoidable, use a scoped `# shellcheck disable=SCXXXX` with a one-line reason, matching existing stage style.

**Idempotency:** every change must survive reruns. The OS gate, motd regen, and docs are all naturally idempotent.

---

## Already portable — DO NOT TOUCH (verified in code during assessment)

These surfaces are version-independent. Changing them is out of scope and risks regression:

| Surface | Why it already works on 24.04 |
|---|---|
| Docker repo — `bootstrap/stages/07-docker-install.sh:30` | codename derived live from `UBUNTU_CODENAME`/`VERSION_CODENAME`; Docker CE publishes `noble` |
| Node — `bootstrap/stages/16-node.sh:25` | NodeSource `node_${NODE_MAJOR}.x nodistro` — distro-agnostic |
| AWS CLI — `bootstrap/stages/17-awscli.sh` | official zip, OS-independent |
| CloudWatch — `bootstrap/stages/18-cloudwatch.sh:36` | single `ubuntu/arm64/<ver>.deb`, not codename-specific |
| unattended-upgrades — `bootstrap/config/unattended-upgrades/50unattended-upgrades:2` | uses APT's `${distro_codename}` macro |
| zram — `bootstrap/stages/04-zram.sh`, pkg `systemd-zram-generator` | package present on 24.04; sizing RAM-derived |
| sysctl / journald sizing — stages 05/06 | derived from live `MemTotal`/FS size |
| base packages — `bootstrap/stages/02-packages.sh` | all names present in both noble + resolute |
| SSH hardening, system-update, user-data, verify suite | no version coupling; verify has no hardcoded version |

---

## File Structure

- `bootstrap/bootstrap.env` — widen `ALLOWED_UBUNTU_VERSIONS` to include `24.04`. (No change to `detect_os` in `bootstrap/lib/system.sh` — it already iterates the array.)
- `bootstrap/stages/14-motd.sh` — replace hardcoded "Ubuntu 26" with the live `PRETTY_NAME` from `/etc/os-release`.
- `CLAUDE.md` — widen the OS line in Core Design Intent.
- `docs/architecture/overview.md` — widen Target Host OS line.
- `docs/operations/deployment-checklist.md` — dual-version AMI line, Docker-note wording, gate text.
- `docs/STATUS.md` — record the dual-OS support + validation matrix.

---

## Task 1: Widen the OS allow-list

**Files:**
- Modify: `bootstrap/bootstrap.env:20-23`

The gate logic in `bootstrap/lib/system.sh:31-40` already loops `ALLOWED_UBUNTU_VERSIONS` and fatals if `VERSION_ID` matches none. Only the array contents change.

- [ ] **Step 1: Add 24.04 to the allow-list**

Replace the existing block:

```bash
# Allowed Ubuntu VERSION_ID values for stage 00 preflight detect_os check.
# Bash array; defaults to the canonical target. Extend (not replace) to
# permit running on additional releases.
ALLOWED_UBUNTU_VERSIONS=("26.04")
```

with:

```bash
# Allowed Ubuntu VERSION_ID values for stage 00 preflight detect_os check.
# Bash array. 24.04 (noble) is supported alongside 26.04 (resolute) so hosts
# can run on 24.04 while tooling (e.g. GitLab) lacks 26.04 support. Extend
# (not replace) to permit further releases.
ALLOWED_UBUNTU_VERSIONS=("24.04" "26.04")
```

- [ ] **Step 2: Shellcheck the env file**

Run: `shellcheck -x bootstrap/bootstrap.env`
Expected: no output (clean). (`bootstrap.env` is sourced, so `-x` follows it where referenced; running it standalone is fine — it is pure assignments.)

- [ ] **Step 3: Confirm the gate accepts both versions and rejects others**

Run:

```bash
bash -c '
source bootstrap/bootstrap.env
source bootstrap/bootstrap.env >/dev/null 2>&1
for v in 24.04 26.04 22.04 25.10; do
  match=0
  for a in "${ALLOWED_UBUNTU_VERSIONS[@]}"; do [[ "$v" == "$a" ]] && match=1; done
  echo "$v -> $([[ $match == 1 ]] && echo ALLOW || echo REJECT)"
done'
```

Expected:

```
24.04 -> ALLOW
26.04 -> ALLOW
22.04 -> REJECT
25.10 -> REJECT
```

- [ ] **Step 4: Commit**

```bash
git add bootstrap/bootstrap.env
git commit -m "feat(preflight): allow Ubuntu 24.04 alongside 26.04"
```

---

## Task 2: Make the motd version-aware

**Files:**
- Modify: `bootstrap/stages/14-motd.sh`

The current stage hardcodes `ARM64 Ubuntu 26 Bootstrap Host` in a quoted heredoc. On 24.04 that line is wrong. Derive the name from `/etc/os-release` `PRETTY_NAME`.

- [ ] **Step 1: Rewrite the stage to source os-release and interpolate PRETTY_NAME**

Replace the entire file with:

```bash
#!/bin/bash
set -Eeuo pipefail

# Derive the OS label from the running system so the motd is correct on every
# supported release (24.04 noble, 26.04 resolute, ...). Quoted-heredoc would
# freeze a single version string; an unquoted heredoc interpolates PRETTY_NAME.
# shellcheck source=/dev/null
. /etc/os-release

# PRETTY_NAME is set by the sourced os-release; shellcheck cannot see it.
# shellcheck disable=SC2154
cat >/etc/motd <<EOF
ARM64 ${PRETTY_NAME:-Ubuntu} Bootstrap Host

/data volume required
Docker runtime stored under /data/docker

Use:
  docker compose
  node
  systemctl
  journalctl

Bootstrap:
  /var/log/bootstrap/bootstrap.log
EOF
```

- [ ] **Step 2: Shellcheck + parse**

Run: `shellcheck -x bootstrap/stages/14-motd.sh && bash -n bootstrap/stages/14-motd.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Smoke-test the interpolation locally**

Run (simulates an os-release without modifying the real one):

```bash
bash -c '
PRETTY_NAME="Ubuntu 24.04.4 LTS"
cat <<EOF
ARM64 ${PRETTY_NAME:-Ubuntu} Bootstrap Host
EOF'
```

Expected first line: `ARM64 Ubuntu 24.04.4 LTS Bootstrap Host`

- [ ] **Step 4: Commit**

```bash
git add bootstrap/stages/14-motd.sh
git commit -m "fix(motd): derive OS label from os-release (24.04/26.04)"
```

---

## Task 3: Refresh docs for dual-OS support

**Files:**
- Modify: `CLAUDE.md` (Core Design Intent OS line)
- Modify: `docs/architecture/overview.md` (Target Host OS line)
- Modify: `docs/operations/deployment-checklist.md` (AMI line, Docker note, gate text)

- [ ] **Step 1: CLAUDE.md — widen the OS line**

Replace:

```markdown
- Ubuntu 26 LTS
```

with:

```markdown
- Ubuntu 24.04 LTS (noble) or 26.04 LTS (resolute)
```

(Leave the existing Graviton-family line directly below unchanged.)

- [ ] **Step 2: overview.md — widen the Target Host OS line**

Replace:

```markdown
- Ubuntu 26 LTS
```

with:

```markdown
- Ubuntu 24.04 LTS (noble) or 26.04 LTS (resolute)
```

- [ ] **Step 3: deployment-checklist.md — AMI line**

Replace:

```
AMI:                  Ubuntu 26.04 LTS arm64 (official Canonical)
```

with:

```
AMI:                  Ubuntu 24.04 LTS (noble) or 26.04 LTS (resolute) arm64,
                      official Canonical. Pick 24.04 where 26.04 tooling support
                      is incomplete (e.g. GitLab).
```

- [ ] **Step 4: deployment-checklist.md — fix the Docker note wording**

Replace:

```markdown
Docker CE publishes packages for Ubuntu 26 `resolute` — stage 07 installs
docker-ce cleanly without codename pinning.
```

with:

```markdown
Stage 07 derives the apt codename from `/etc/os-release` at runtime, so Docker CE
installs cleanly on any release Docker publishes for — `noble` (24.04) and
`resolute` (26.04) are both available. (The repo line is codename-pinned to the
detected codename, not unpinned.)
```

- [ ] **Step 5: deployment-checklist.md — gate text**

Replace:

```markdown
Bootstrap enforces only the `aarch64` architecture gate (plus Ubuntu 26.04) — no
```

with:

```markdown
Bootstrap enforces only the `aarch64` architecture gate (plus Ubuntu 24.04 or
26.04 via `ALLOWED_UBUNTU_VERSIONS`) — no
```

- [ ] **Step 6: Find any remaining "Ubuntu 26"-only references and confirm scope**

Run: `grep -rniE 'ubuntu 26|26\.04|resolute' docs/ CLAUDE.md README.md | grep -viE '24\.04|noble'`
Expected: review each hit; every remaining reference should be either historical/ADR context (leave) or already dual-version (from steps above). No hard gate or launch instruction may say 26.04-only. Fix any that do, matching the phrasing above.

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md docs/architecture/overview.md docs/operations/deployment-checklist.md
git commit -m "docs: document Ubuntu 24.04 + 26.04 dual support"
```

---

## Task 4: Pre-flight static review (no live host required)

Confirm nothing else statically assumes a single version before spending a live instance.

**Files:** none modified.

- [ ] **Step 1: Re-grep the full tree for version/codename coupling**

Run: `grep -rniE 'resolute|noble|26\.04|24\.04|codename|VERSION_ID|VERSION_CODENAME' bootstrap/ user-data/ | grep -v aws-cli-public-key`
Expected: only (a) `bootstrap.env` allow-list, (b) `lib/system.sh` `detect_os` reading `VERSION_ID`, (c) `07-docker-install.sh` dynamic codename derivation, (d) `14-motd.sh` os-release source. No new hardcoded single-version string. If anything else appears, stop and assess before the live run.

- [ ] **Step 2: Confirm full shellcheck tree is clean**

Run: `shellcheck -x bootstrap/**/*.sh bootstrap/*.sh scripts/*.sh user-data/*.sh 2>/dev/null; echo "exit: $?"`
(Or invoke exactly as CI does — see `.github/workflows/shellcheck.yml`.)
Expected: exit 0.

---

## Task 5: On-host 24.04 acceptance (the real gate — requires a live EC2 instance)

This cannot run from a dev machine. It is the actual sign-off that 24.04 is supported. Run the **same** acceptance on a 26.04 instance too if 26.04 has not yet been hardware-validated (it has not, per STATUS.md), so the matrix is filled in one pass.

**Launch:** one Graviton arm64 instance from the **official Canonical Ubuntu 24.04 LTS arm64 AMI**, per `docs/operations/deployment-checklist.md` (30 GB root, one unformatted data EBS, IAM role, SG, IMDSv2, user-data = `user-data/user-data.sh`). Use the branch carrying this plan's commits.

- [ ] **Step 1: Confirm the run is on 24.04 and bootstrap completed**

Run:

```bash
. /etc/os-release; echo "$VERSION_ID $VERSION_CODENAME"
cat /etc/bootstrap-version
tail -20 /var/log/bootstrap/bootstrap.log
```

Expected: `24.04 noble`; a populated `/etc/bootstrap-version`; the log ends at the verify stage with no fatal.

- [ ] **Step 2: Run the full verify suite**

Run:

```bash
for v in bootstrap storage docker network security cloudwatch; do
  echo "== verify-$v =="; bash bootstrap/verify/verify-$v.sh || echo "FAILED: $v"
done
```

Expected: every script exits 0; no `FAILED:` line.

- [ ] **Step 3: Confirm Docker installed from the noble repo**

Run:

```bash
grep -r download.docker.com /etc/apt/sources.list.d/
docker info | grep -E 'Server Version|DockerRootDir'
docker run --rm hello-world
```

Expected: the docker.list line contains `noble`; `DockerRootDir` is `/data/docker`; hello-world runs.

- [ ] **Step 4: Confirm zram is active and correctly sized (24.04's zram-generator)**

This is the highest-risk surface — 24.04 was the release that introduced the `zram-size = min(...)` expression form. Confirm the expression evaluated, not silently defaulted.

Run:

```bash
zramctl
swapon --show | grep zram
free -h
```

Expected: a `/dev/zram0` device exists; its DISKSIZE equals `min(RAM/2, 8 GiB)` for this instance (e.g. 8 GiB RAM → 4 GiB zram); zram appears in `swapon`. If zram is absent or mis-sized, capture `systemctl status systemd-zram-setup@zram0` and `zram-generator --version`, and treat as a blocker.

- [ ] **Step 5: Confirm logrotate config validates against 24.04 vendor state**

The committed `/etc/logrotate.d/*` copies all use `missingok`, so missing paths are tolerated; this step confirms no syntax/`su` errors against 24.04's logrotate.

Run:

```bash
logrotate --debug /etc/logrotate.conf 2>&1 | grep -iE '^error|error:' || echo "no errors"
```

Expected: `no errors`. If any error appears, record the offending file; fix the committed copy under `bootstrap/config/logrotate/` and re-run.

- [ ] **Step 6: Confirm the motd shows the right release**

Run: `cat /etc/motd | head -1`
Expected: `ARM64 Ubuntu 24.04...  Bootstrap Host` (not "Ubuntu 26").

- [ ] **Step 7: Confirm Node and the rest of the toolchain**

Run:

```bash
node --version
sshd -T | grep -E 'passwordauthentication|permitrootlogin'
systemctl is-active unattended-upgrades
```

Expected: Node major matches `NODE_MAJOR`; password auth `no`, root login `no`/`prohibit-password`; unattended-upgrades active.

- [ ] **Step 8: Record results in the validation matrix (Task 6).**

---

## Task 6: Record dual-OS state in STATUS.md

**Files:**
- Modify: `docs/STATUS.md`

- [ ] **Step 1: Update the status table + validation matrix**

Add/refresh an OS-support row and a validation matrix reflecting Task 5 results, e.g.:

```markdown
| Ubuntu 24.04 (noble) + 26.04 (resolute) | ✅ code supports both (`ALLOWED_UBUNTU_VERSIONS`); 24.04 hardware-validated <date>, 26.04 <state> |
```

Record, per (OS × representative instance) actually booted: bootstrap pass/fail, zram size, logrotate clean, motd correct. Update the `Last updated` line.

- [ ] **Step 2: Commit**

```bash
git add docs/STATUS.md
git commit -m "docs(status): record Ubuntu 24.04 support + validation matrix"
```

---

## Acceptance Summary

24.04 support is complete only when:

- `ALLOWED_UBUNTU_VERSIONS` includes `24.04` and the gate accepts it (Task 1).
- motd reflects the live release (Task 2).
- Docs name both releases with no 26.04-only hard gate or launch instruction (Task 3).
- Static review finds no other single-version coupling; full shellcheck clean (Task 4).
- A real 24.04 arm64 instance completes bootstrap, passes the full verify suite, installs Docker from `noble`, brings up correctly-sized zram, validates logrotate, and shows the right motd (Task 5).
- STATUS.md records the validation matrix (Task 6).

---

## Self-Review (completed at authoring)

- **Spec coverage:** every assessment item maps to a task — OS gate (T1), motd (T2), docs incl. Docker-note wording + AMI + gate text (T3), zram-generator expression risk (T5 S4), logrotate divergence (T5 S5), validation matrix (T6). Already-portable surfaces explicitly fenced as out-of-scope.
- **Placeholders:** none — every code step shows full content; on-host steps show exact commands + expected output. Task 6's STATUS rows are illustrative because the values come from the live run (by nature unknowable at authoring).
- **Consistency:** `ALLOWED_UBUNTU_VERSIONS` array form matches `lib/system.sh:31-40` loop; motd `PRETTY_NAME` matches `/etc/os-release`; codename derivation references match `07-docker-install.sh:30`.
