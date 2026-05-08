# AMI Baking

## Goal

Bake a clean base AMI after the bootstrap has fully succeeded.

## Before Baking

- Verify `/data` mount state
- Verify marker file
- Verify Docker runtime path
- Verify cleanup timers
- Verify SSH hardening
- Verify bounded logging
- Verify zram and sysctl

## Cleanup Expectations

Before snapshotting:
- no long-running temporary containers
- no accidental build caches
- no stale transient files
- no local development artifacts under root

## Snapshot Philosophy

The root volume contains the OS and bootstrap foundation.
The `/data` volume contains operational persistence.

Treat them separately.

## Bake Rule

Do not bake an AMI from an unverified host.
