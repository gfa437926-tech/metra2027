# Stage C8 — Security and Regression

Covered by re-run of Metra.Api.Tests (264) including:
- Security headers / rate limit / HTTP pipeline / JWT-related authz cases
- Domain archive station scope
- Grant conflict 409 detector

Isolated SQL:
- Archive A allow / B deny / role-only deny / revoke / expired assignment / audit immutability
- Active grant uniqueness (23505)

Archive HTTP remains **503** fail-closed. Hosted R4/indexes **not applied**.
