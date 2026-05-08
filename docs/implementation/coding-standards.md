# Coding Standards

## Language and Shell Target

All bootstrap logic must be Bash.
Do not write the core bootstrap logic as POSIX sh if Bash is needed.

## Required Shell Settings

Use:
- `set -Eeuo pipefail`
- strict variable handling
- explicit error checks

## Structure Rules

- Keep the bootstrap modular.
- Do not collapse the project into a single file.
- Keep stages separate.
- Keep shared functions in libraries.
- Keep configs in dedicated config files.
- Keep verification separate from provisioning.

## Idempotency Rules

Every stage must be safe to rerun.
Use checks before writes.
Avoid duplicate file creation behavior.
Avoid appending the same config repeatedly.

## Logging Rules

- Log to a bootstrap log file.
- Keep logs structured and readable.
- Log start and end of each stage.
- Surface command failures clearly.

## Config Management Rules

If a package or service supports a drop-in directory, use the drop-in directory.

Examples:
- `/etc/systemd/system/<unit>.d/*.conf`
- do not replace the vendor-managed unit file when a drop-in is enough

## Filesystem Rules

- `/data` is the persistent operational volume.
- The root disk is not for Docker runtime.
- The root disk is not for application state.
- The bootstrap must never format the root disk.

## Docker Rules

- Docker runtime data root must be `/data/docker`.
- BuildKit must be enabled globally.
- `docker compose` is the preferred interface.
- Docker logs must be bounded.
- Do not rely on Docker falling back to the root volume.

## User Rules

- Use `ubuntu` as the primary operator user.
- Add `ubuntu` to the Docker group.
- Install Oh My Zsh for `ubuntu` only.
- Set `vim` as the editor.
- Keep shell customizations minimal and predictable.

## Systemd Rules

- Use systemd timers, not cron.
- Prefer drop-in overrides for service tuning.
- Keep units small and explicit.

## Validation Rules

Do not call a stage complete unless its validation passes.
Critical validation failures must abort the bootstrap.

## Change Control Rules

Do not rename or remove architectural boundaries casually.
Do not replace clear stage structure with convenience-driven shortcuts.
Do not add behavior that was not agreed in the contract.

## Review Rules

Before merging or implementing:
- check for idempotency
- check for destructive disk behavior
- check for Docker storage root correctness
- check for bounded logs
- check for service override correctness