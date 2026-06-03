# arm64-bootstrap — Consolidated Status & Open Items

> Single source of truth for "what's open / left on this project." Answer from this
> file directly; do not re-derive from scattered trackers. Keep current on any status change.
>
> Last updated: 2026-06-03 (Tier 2 done: aws.sh IMDSv2 helpers, stage-15 contract, shellcheck CI gate).

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
| CI: strict shellcheck gate | ✅ `.github/workflows/shellcheck.yml`, tree clean |
| AWS CLI v2 | ⏳ wanted next (Tier 2) |
| First real EC2 launch + AMI bake | ⏳ not yet done |

## Open / left (tiered)

### Tier 1 — Dated / imminent
- None.

### Tier 2 — Open decisions / hygiene
- **AWS CLI v2 package** — wanted next. Not in Ubuntu apt for arm64; needs the official
  AWS bundle install (own stage, mirroring docker/node keyring-style stages). To design.
- ~~`lib/aws.sh` dead placeholder~~ — DONE: filled with IMDSv2 token/metadata helpers.
- ~~stage-15 (logrotate) missing from stage-contracts~~ — DONE.
- ~~No CI gate~~ — DONE: `.github/workflows/shellcheck.yml` (strict). Fixed the SC2154
  false-positives via `external-sources`/`source-path=SCRIPTDIR` + per-stage `source=`
  directives, and a pre-existing SC2310 in stage 15. Tree is shellcheck-clean.

### Tier 3 — Backlog (pick-up basis)
- None open. (B1 motd node entry, B2 NODE_MAJOR bump checklist — both done 2026-06-03.)

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
