# arm64-bootstrap

Bootstrap repository for a reproducible Ubuntu 26 ARM64 EC2 base host.

## Purpose

This repository prepares a clean EC2 instance for later AMI baking and later application-stack deployment.

It provisions:
- `/data` persistent storage
- Docker runtime configuration
- OS-level tuning
- security baseline
- cleanup timers
- validation checks

It does not deploy application stacks.

## Target

- Ubuntu 26 LTS
- AWS Graviton ARM64
- EC2 `m7g.large`
- Docker Compose
- single-tenant trusted infrastructure

## Structure

- `user-data/` — minimal EC2 launch bootstrap
- `bootstrap/` — main provisioning logic
- `docs/` — contracts, decisions, and operational docs
- `scripts/` — helper scripts for local use and AMI baking

## Execution Model

The expected flow is:

1. EC2 launch with user-data
2. clone this repository
3. execute `bootstrap/bootstrap.sh`
4. verify the host
5. bake a base AMI later

## Design Rules

- fail fast on critical errors
- never format the root disk
- never let Docker fall back to root storage
- keep logs bounded
- keep stages modular
- keep bootstrap rerunnable
