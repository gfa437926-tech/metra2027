# C9 — Security Acceptance Report

| Control | Status |
|---------|--------|
| JWT validation (local Program) | Present in local Backend |
| Station-scoped authorization | Tests + isolated SQL |
| ArchiveRead station bind (R4) | Proposal + isolated tests; **not applied hosted** |
| Grant uniqueness / 23505 → HTTP 409 | Detector + SQL suite |
| Rate limiting | Registered in local Program |
| Security headers (e.g. X-Frame-Options) | Local middleware |
| Archive endpoint | **503 Fail-Closed** until real service |
| No role-only archive grant | Isolation suite denies |
| Secrets in repo | Must remain absent (dart-define / env only) |

**Accepted for local/RC review. Not accepted as hosted production security posture until R4/indexes applied under change control.**
