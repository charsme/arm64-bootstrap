# ADR 002: Docker Runtime Strategy

## Status

Accepted

## Context

The host is intended to run Docker Compose services for AI orchestration and related tooling.

Docker runtime state must not be mixed into the root volume in a way that creates hidden drift or causes the OS volume to fill unexpectedly.

## Decision

Configure Docker to use `/data/docker` as its data root.

Use:
- official Docker repository only
- stable major version pinning
- BuildKit enabled globally
- `docker compose` as the preferred command path
- `local` logging driver
- bounded log size
- explicit default address pools
- `live-restore` enabled

## Consequences

Positive:
- runtime is aligned with persistent storage
- easier lifecycle management
- less risk of root disk filling unexpectedly
- cleaner AMI rebakes

Tradeoffs:
- Docker must not start until `/data` is validated
- storage stage becomes critical

## Notes

Docker must never fall back silently to the root volume.