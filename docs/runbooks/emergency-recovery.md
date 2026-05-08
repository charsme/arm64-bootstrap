# Emergency Recovery

## Priority

Restore storage correctness first.

## Sequence

1. Stop Docker.
2. Verify disk attachments.
3. Verify `/data` mount.
4. Verify marker file.
5. Verify Docker root path.
6. Re-run bootstrap only if needed.
7. Re-bake AMI if the host baseline changed.

## Rule

Do not work around a broken mount by using the root volume.
