# ADR 004: Bootstrap Execution Model

## Status

Accepted

## Context

The user-data bootstrap must prepare a fresh EC2 instance quickly and safely. The repo should remain suitable for AMI rebakes and repeated runs.

## Decision

Use:
- minimal cloud-init
- user-data as a launcher
- git-based bootstrap repository
- root orchestration
- modular bash stages
- idempotent rerunnable bootstrap

The user-data script should fetch and run the latest `main` branch from the public repository.

## Consequences

Positive:
- easy to update
- easy to debug
- easy to rebake
- clean separation between launcher and logic

Tradeoffs:
- requires git availability
- main branch changes can affect future launches

## Notes

The repository is the source of truth for bootstrap logic.