# arm64-bootstrap — Consolidated Status & Open Items

> Single source of truth for "what's open / left on this project." Answer from this
> file directly; do not re-derive from scattered trackers. Keep current on any status change.
>
> Last updated: 2026-06-03 (added Node.js stage 16 + docker gpg idempotency fix; bootstrapped this file).

## Status

Host bootstrap is feature-complete and pushed to `main`. All 18 stages wired and
idempotent; verify suite in place. Not yet exercised on a real first EC2 launch / AMI bake.

| Area | State |
|------|-------|
| Stage pipeline (00–16, 99) | ✅ complete, registered in `bootstrap.sh` |
| Verify suite (bootstrap/storage/docker/network/security) | ✅ in place |
| Docker on `/data`, mount-gated | ✅ implemented |
| zram / sysctl / journald / logrotate caps | ✅ implemented (env-driven sizing) |
| SSH hardening + unattended upgrades | ✅ implemented |
| Node.js LTS (stage 16) | ✅ added 2026-06-03 |
| First real EC2 launch + AMI bake | ⏳ not yet done |

## Open / left (tiered)

### Tier 1 — Dated / imminent
- None.

### Tier 2 — Open decisions / hygiene
- **`bootstrap/lib/aws.sh` is an empty placeholder**, sourced nowhere. Decide: fill with
  intended AWS helpers (IMDS/tags/EBS detection) or delete the dead stub.
- **`docs/implementation/stage-contracts.md` skips stage 15 (logrotate)** — doc lists
  00–14, 16, 99. Code exists; add the missing contract section.
- **No CI gate.** Strict `.shellcheckrc` (`enable=all`) implies intent to enforce, but
  shellcheck only runs manually. Consider a GitHub Action running shellcheck on stages/lib.

### Tier 3 — Backlog (pick-up basis)
| id | item | effort | note |
|----|------|--------|------|
| B1 | MOTD show node version | XS | if stage 14 already surfaces docker version, mirror for node |
| B2 | Pin Node minor or verify NodeSource arm64 availability per bump | XS | `NODE_MAJOR` bump checklist |

### Tier 4 — Watches / deferred (dormant)
- AWS helper layer (`lib/aws.sh`) — only build if a stage actually needs IMDS/tag/EBS logic.
- Application/service layer — explicitly out of scope for this repo (host prep only).

## Git / deploy state
- Branch `main`, in sync with `origin/main` (`8cf942d`).
- Not yet deployed to a live first-launch instance; no AMI baked from current `main`.

## Detailed sources (drill-down only)
- Stage specs: `docs/implementation/stage-contracts.md`
- Acceptance: `docs/implementation/acceptance-criteria.md`
- ADRs: `docs/decisions/adr-00{1..4}-*.md`
- Ops: `docs/operations/` (ami-baking, deployment-checklist, disaster-recovery, snapshot-strategy)
- Runbooks: `docs/runbooks/`
- loreKeeper topic: `arm64-bootstrap` (private/infra)
