# Stage 18 — CloudWatch Agent for Compute Optimizer Memory Metrics

Date: 2026-06-05
Status: Approved (design)

## Purpose

EC2's default CloudWatch metrics are hypervisor-side only (CPU, network, disk
I/O). Memory utilization lives inside the guest and is invisible to AWS without
an in-guest agent. AWS Compute Optimizer therefore cannot produce memory-based
right-sizing recommendations unless a memory metric is published to CloudWatch.

This stage installs and configures the Amazon CloudWatch agent to publish
`mem_used_percent` (plus `swap_used_percent` and `disk_used_percent`) to the
`CWAgent` namespace, so Compute Optimizer can ingest memory data for this host.

The stage must not break AMI baking when no IAM role is present, and must
self-heal on instances launched from the AMI if a role is attached later.

## Scope

In scope (host preparation only — this repo's mandate):

- Install the CloudWatch agent (pinned version, GPG-verified, arm64).
- Stage the metrics config (mem + swap + disk) without starting the agent.
- A boot-time IAM gate that starts the agent only when an IAM role is present.
- A dynamic login hint (motd) describing live agent state and the fix path.
- Artifact-only verification that keeps the AMI bake clean.

Out of scope (cannot be done from inside the host; documented as prerequisites):

- Account/region-level Compute Optimizer opt-in (one-time, AWS account concern).
- IAM instance-profile creation and attachment (launch-time concern).
- Enhanced infrastructure metrics (paid Compute Optimizer opt-in).

## Behavior Contract

| Case | Outcome |
|------|---------|
| Bake, no IAM role | Agent installed + configured, service enabled but cleanly skipped at boot (ExecCondition fails). Verify checks artifacts only. AMI bakes clean. |
| Launch with IAM role | Boot gate passes → agent starts → publishes mem/swap/disk to `CWAgent`. Compute Optimizer ingests memory once data accrues. motd: running. |
| Launch, forgot role | Agent stays idle (condition-skipped, not failed). Login motd shows idle state + fix instructions. Attach role + reboot → self-heals. |

## Design

### Boot-time gate (systemd ExecCondition, drop-in)

The gate is a native systemd `ExecCondition`, not a separate polling service.
Drop-in (does not replace the vendor unit, per CLAUDE.md systemd rules):

```
/etc/systemd/system/amazon-cloudwatch-agent.service.d/iam-gate.conf
  [Unit]
  After=network-online.target
  Wants=network-online.target
  [Service]
  ExecCondition=/opt/arm64-bootstrap/bin/cloudwatch-iam-gate
```

`ExecCondition` exiting non-zero (1–254) causes systemd to skip the unit
cleanly — marked condition-failed, NOT failed, so no error noise. The condition
is re-evaluated every boot, which is what makes a forgotten-then-attached role
self-heal after a reboot.

`network-online.target` ordering ensures IMDS is reachable before the gate runs.

### Gate script

Path: `/opt/arm64-bootstrap/bin/cloudwatch-iam-gate` (new persistent artifact
dir `/opt/arm64-bootstrap/bin`, introduced by this stage).

Self-contained (runs at boot, does not source repo libs). Behavior:

1. Acquire an IMDSv2 session token (token-based; IMDSv1 assumed disabled).
2. GET `meta-data/iam/security-credentials/`.
3. Exit 0 if a non-empty role name is returned; exit 1 on HTTP 404 / empty /
   curl failure.

Detects role *presence* only — see Known Limitations.

### Install (mirrors stage 17 — pinned + GPG-verified)

- New pinned env var `CWAGENT_VERSION` in `bootstrap.env`.
- AWS agent signing key committed at
  `config/cloudwatch/amazon-cloudwatch-agent.gpg`.
- Stage downloads the arm64 `.deb` and its `.deb.sig`, imports the key into an
  isolated `GNUPGHOME`, `gpg --verify`s the deb (fail hard on bad/missing
  signature under `set -e`), then `dpkg -i`. Idempotent on rerun.

### Metrics config

`config/cloudwatch/amazon-cloudwatch-agent.json`, applied via
`amazon-cloudwatch-agent-ctl -a fetch-config` WITHOUT `-s` (configure only; the
gate owns start/stop):

```json
{ "agent": { "metrics_collection_interval": 60 },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": { "InstanceId": "${aws:InstanceId}" },
    "aggregation_dimensions": [["InstanceId"]],
    "metrics_collected": {
      "mem":  { "measurement": ["mem_used_percent"] },
      "swap": { "measurement": ["swap_used_percent"] },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/", "/data"] }
    } } }
```

The `InstanceId` dimension is mandatory: Compute Optimizer only associates
`mem_used_percent` with an instance when that dimension is present.

After fetch-config, the stage `systemctl enable`s the agent (so boot attempts
it) but does NOT start it — the ExecCondition decides at boot.

### Operator hint (dynamic update-motd.d)

`/etc/update-motd.d/50-cloudwatch-agent`, rendered each login. Static
`/etc/motd` from stage 14 is untouched.

- agent active → `CloudWatch agent: running (mem/swap/disk → CWAgent)`.
- inactive + no IAM role → idle banner: attach an instance profile with
  `CloudWatchAgentServerPolicy`, then reboot; note that memory data will not
  reach Compute Optimizer until then.

### Verification + wiring

- New `verify/verify-cloudwatch.sh` — artifact-only checks: agent binary
  present, config staged, drop-in present, gate script present + executable,
  motd snippet present. Does NOT assert the service is running or that metrics
  flow (there is no IAM role at bake time), keeping the bake clean.
- `verify-cloudwatch.sh` added to the `99-verify.sh` suite.
- `18-cloudwatch.sh` added to the `bootstrap.sh` STAGES array, after
  `17-awscli.sh`, before `99-verify.sh`.

### Documentation

- `docs/operations/deployment-checklist.md`: add the IAM instance-profile
  (`CloudWatchAgentServerPolicy`) and account-level Compute Optimizer opt-in as
  launch/account prerequisites.

## New / Changed Files

- `bootstrap/bootstrap.env` — add `CWAGENT_VERSION`.
- `bootstrap/bootstrap.sh` — add stage 18 to STAGES.
- `bootstrap/stages/18-cloudwatch.sh` — new stage.
- `bootstrap/config/cloudwatch/amazon-cloudwatch-agent.gpg` — committed signing key.
- `bootstrap/config/cloudwatch/amazon-cloudwatch-agent.json` — metrics config.
- `bootstrap/config/cloudwatch/cloudwatch-iam-gate.sh` — gate script source
  (installed to `/opt/arm64-bootstrap/bin/cloudwatch-iam-gate`).
- `bootstrap/config/cloudwatch/50-cloudwatch-agent` — update-motd.d snippet source.
- `bootstrap/config/systemd/amazon-cloudwatch-agent.service.d/iam-gate.conf` — drop-in.
- `bootstrap/verify/verify-cloudwatch.sh` — artifact verification.
- `bootstrap/stages/99-verify.sh` — add verify-cloudwatch.sh.
- `docs/operations/deployment-checklist.md` — prerequisites.

## Stage Contract Compliance

- Idempotent: `dpkg -i` re-installs same pinned version; fetch-config and file
  installs overwrite deterministically; enable is idempotent.
- Fail hard: arch check, missing signing key, signature verification failure all
  abort under `set -Eeuo pipefail`.
- Logs its work via `lib/logging.sh`.
- Validates its result via `verify-cloudwatch.sh`.
- Bake-clean: no runtime/metric assertions at provisioning time.

## Known Limitations

- The gate detects IAM role *presence*, not whether the role grants
  `cloudwatch:PutMetricData`. A role present but under-permissioned lets the
  agent start; `PutMetricData` then returns 403 (visible in the agent log) while
  motd still reports "running". Surfaced in the deployment checklist.
- Compute Optimizer needs a minimum observation window (days) of memory data
  before it emits a memory recommendation. The stage only guarantees the metric
  is published once a role is present.
