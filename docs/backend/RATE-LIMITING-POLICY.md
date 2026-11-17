# METRA API Rate Limiting Policy

Implemented via ASP.NET Core `RateLimiter` (fixed window, no queue).

| Policy | Permit / window | Partition | Applied to |
|--------|-----------------|-----------|------------|
| `metra-anonymous-probe` | 60 / 1 min | user:sub or ip | `/api/v1/health`, `/api/v1/ready` |
| `metra-read` | 120 / 1 min | user:sub or ip | Observation archive list |
| `metra-write` | 40 / 1 min | user:sub or ip | Reserved for mutation routes as they are annotated |
| `metra-sensitive` | 15 / 1 min | user:sub or ip | Authority grant/membership lifecycle; registration submit |

**Rationale:** probes must stay available for orchestrators but not unbounded; sensitive grant/registration paths are low-volume admin actions; reads are higher but still bounded.

**Response:** HTTP **429** JSON `{ "error": "rate_limit_exceeded", ... }` — no stack traces.

**Identity:** authenticated `sub` preferred over IP so shared NAT does not starve distinct users; unauthenticated traffic keys by IP.

**Forwarded headers:** not trusted by default (no automatic `X-Forwarded-For` partition) to avoid spoofing; enable only behind a known reverse proxy configuration in deployment.
