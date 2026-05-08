# Architecture Overview

## Purpose

This repository provisions a base EC2 host for ARM64 Ubuntu 26 on AWS Graviton. The output is a clean, repeatable host foundation for AI orchestration workloads.

The repository prepares the machine only. Application stacks are deployed later.

## Target Host

- Ubuntu 26 LTS
- AWS EC2 `m7g.large`
- ARM64
- Docker Compose
- Single-tenant trusted infrastructure
- Long-lived server

## Main Design Goal

The design separates the machine into two distinct layers:

### Root Volume
Used for:
- OS
- package installation
- journals
- bootstrap scripts
- system runtime

### `/data` Volume
Used for:
- Docker runtime
- compose projects
- service data
- workspaces
- repos
- caches
- persistent operational data

This separation is intentional and central to the design.

## Why the Separation Matters

The machine is intended to live for a long time. If runtime data and OS state are mixed together, the host becomes harder to maintain, harder to back up, and harder to recover.

The `/data` volume makes it possible to:
- rebuild the AMI without losing persistent operational state
- cleanly separate OS lifecycle from application lifecycle
- snapshot data independently
- recover from failures more predictably

## Storage Safety Principle

The system must never guess when storage is ambiguous.

If a data volume cannot be identified safely, the bootstrap must stop.

The host must never:
- format the root disk
- mount the wrong disk
- let Docker write to the root volume when `/data` is missing

## Docker Strategy

Docker is installed from the official Docker repository only.

The Docker runtime is configured to live under `/data/docker`, not under `/var/lib/docker`.

This keeps runtime state aligned with the persistent operational layer.

## Logging Strategy

Logs must be bounded by design.

This includes:
- journald limits
- Docker log limits
- cleanup timers
- build cache pruning

The goal is to prevent hidden disk growth.

## Maintenance Strategy

The host is designed to be rebased periodically into a new AMI.

This means:
- bootstrap must be deterministic
- bootstrap must be rerunnable
- verification must be strict
- runtime cleanup must be automatic but safe

## Security Model

This is a trusted single-tenant environment.

That means:
- Docker socket access is allowed for `ubuntu`
- SSH password auth is disabled
- root SSH login is disabled
- AWS Security Groups are the main perimeter
- UFW and fail2ban are not used

## What This Project Is Not

This repository is not intended to be:
- a Kubernetes bootstrap
- an enterprise fleet manager
- a general-purpose workstation setup
- an application deployment repo
- a one-off manual server checklist

It is a reproducible infrastructure base.