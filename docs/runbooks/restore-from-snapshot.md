# Runbook: Restore from Snapshot

## After Restore

1. Attach the restored data volume.
2. Confirm UUID/label consistency.
3. Mount `/data`.
4. Confirm `/data/.mounted-data-volume`.
5. Confirm Docker uses `/data/docker`.
6. Confirm service stacks later, not during base bootstrap.

## Validation

- mount point valid
- marker file present
- no root-volume fallback
