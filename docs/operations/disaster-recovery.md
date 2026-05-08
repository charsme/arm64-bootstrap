# Disaster Recovery

## Recovery Priorities

1. Preserve `/data`
2. Restore mount correctness
3. Restore Docker runtime path
4. Verify host baseline
5. Re-deploy services later

## Expected Recovery Flow

- attach the correct `/data` EBS volume
- boot the host
- run bootstrap again if needed
- verify mount and Docker state
- only then proceed with service-layer deployment

## Do Not

- format disks blindly
- let Docker auto-create state on the root volume
- assume the instance is healthy without verification
