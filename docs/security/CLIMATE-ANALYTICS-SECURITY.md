# Climate Analytics Security Controls

**Status:** initial controls for the isolated R worker; integration controls remain open.

## Implemented in worker

- No database credentials or direct database client.
- No HTTP listener.
- Explicit workspace root requirement.
- Canonical path containment for input/output directories and source files.
- Strict variable identifier and year-range validation.
- Required non-empty .dat and .est files.
- Per-job output directory and staged source copies.
- Original input paths are not used as the Climatol working directory.

## Required before production

- .NET authorization on every job submission and result read.
- Private network access only; authenticated service-to-service identity.
- Request schema validation and maximum payload/file sizes.
- CPU, memory, disk, process, and wall-clock limits.
- Safe job cancellation and cleanup.
- Immutable audit log and SHA-256 hashes for input and output artifacts.
- Malware scanning and quarantine for uploaded files before processing.
- Output content validation; do not trust filenames or worker-produced paths.
- No arbitrary R expressions or user-provided function names/parameters.
- Secrets supplied only through a managed runtime secret store, never source control.
- Security review of container user, filesystem permissions, and network egress.

## Data integrity

The worker creates derived artifacts only. It must not write to original observation tables or publish corrected values. Human review and a separately authorized publication path are mandatory.
