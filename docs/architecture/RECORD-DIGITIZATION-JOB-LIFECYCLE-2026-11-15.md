# METRA 2027 — Recorder Digitization Job Lifecycle

**Status:** provider-neutral application contract; no endpoint, worker, queue, database table or hosted resource is created by this change.

## State flow

```text
queued -> validating -> running -> succeeded
             |            |-----> failed
             |            |-----> cancelled
             |-----> failed
             |-----> cancelled
queued -----------------> cancelled
```

- `queued`, `validating` and `running` are non-terminal.
- `succeeded`, `failed` and `cancelled` are terminal and immutable.
- A retry is a new attempt under the same logical job; it must not reopen or overwrite a terminal attempt.
- A same-state update is rejected rather than silently accepted.
- Unknown enum values and skipped transitions are rejected.
- The pure .NET transition evaluator is deliberately independent of persistence and background-processing providers.

## Not implemented by this slice

This contract does not schedule work, persist attempts, accept cancellation requests, authorize actors, store logs, expose job status, or run OCR/chart digitization. Those require the approved domain model, scoped authorization, audited application services, and separately selected queue/worker and storage adapters.

## Verification

Unit tests cover all allowed transitions, skipped transitions, terminal immutability, same-state requests, and unknown values. The test suite must pass in GitHub Actions before this slice is considered validated.
