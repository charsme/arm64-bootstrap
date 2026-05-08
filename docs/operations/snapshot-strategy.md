# Snapshot Strategy

## Root Volume

The root volume supports the base OS and bootstrap layer.

## `/data` Volume

The `/data` volume contains persistent operational data and should be snapshotted independently.

## Suggested Policy

- daily snapshots
- retain at least 7 days
- test restore periodically
- verify that the marker file survives restore

## Restore Rule

After restore:
- validate mount UUID or label
- validate `/data/.mounted-data-volume`
- validate Docker does not fall back to root storage
