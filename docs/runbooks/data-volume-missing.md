# Runbook: Data Volume Missing

## Symptom

Bootstrap fails because `/data` is missing or ambiguous.

## Expected Behavior

This is a hard failure by design.

## Recovery Steps

1. Check EC2 volume attachment.
2. Confirm the correct EBS volume is attached.
3. Confirm the device is the intended data volume.
4. Re-run bootstrap after correcting the attachment.

## Do Not

- allow Docker to run from the root volume
- manually format the wrong disk
- ignore ambiguous disk detection
