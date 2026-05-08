# ADR 003: Logging and Retention Strategy

## Status

Accepted

## Context

The host will run long-lived services. Without strict retention, logs and build artifacts can consume disk over time.

## Decision

Use bounded retention everywhere:
- journald with strict limits
- Docker `local` logging driver
- build cache prune after 7 days
- stopped container prune after 7 days
- dangling image cleanup
- no automatic named volume pruning

## Consequences

Positive:
- disk growth remains controlled
- operational troubleshooting remains possible
- long-lived host stays manageable

Tradeoffs:
- logs are not retained indefinitely
- cleanup behavior must be carefully tested

## Notes

Log growth should be visible, bounded, and predictable.