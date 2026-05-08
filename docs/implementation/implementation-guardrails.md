# Implementation Guardrails

- Keep bootstrap modular.
- Do not convert the project into a single monolithic script.
- Preserve stage boundaries.
- Preserve the root/data storage split.
- Preserve Docker dependency on `/data`.
- Preserve bounded logging.
- Preserve idempotency.
- Preserve systemd drop-in usage when service customization is needed.
- Preserve hard-fail behavior on ambiguous storage detection.
- Preserve rerunnable reconciliation behavior.
