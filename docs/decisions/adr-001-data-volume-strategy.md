# ADR 001: Persistent `/data` Volume Strategy

## Status

Accepted

## Context

The host is intended to run for a long time and host multiple services, workspaces, and Docker-based operational data.

If all data lives on the root volume, the host becomes more fragile over time and AMI rebakes become less clean.

## Decision

Use a separate encrypted gp3 EBS volume mounted at `/data`.

The bootstrap must:
- detect the data disk safely
- format it as ext4 only if it has no filesystem
- mount it persistently by UUID or label
- create `/data/.mounted-data-volume`
- fail hard if the mount is missing or ambiguous

## Consequences

Positive:
- cleaner separation of OS and operational data
- better AMI rebake flow
- simpler recovery strategy
- safer long-lived host operation

Tradeoffs:
- slightly more bootstrap complexity
- mounting must be validated carefully
- Docker must be made dependent on the mount

## Notes

The data volume is the operational persistence layer for:
- Docker runtime
- compose projects
- workspaces
- repos
- service data
- caches