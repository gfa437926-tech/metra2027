# Roles and Permissions Matrix

## Roles
ROLE-OBSERVER, ROLE-STATION-HEAD, ROLE-AUDITOR, ROLE-NETWORK-DIR, ROLE-TELECOM, ROLE-WORKSHOP, ROLE-IT, ROLE-SYSADMIN, ROLE-CLIMATE, ROLE-AI, ROLE-FORECAST.

## Hard rules
1. Normal user sees only own station.
2. Network director/auditors wider scope only via server grants.
3. Read-all does not imply write/delete.
4. Enforce in .NET API + DB, not Flutter visibility.

## Matrix (target)
| Operation | Observer | Station Head | Auditor | Network Dir | SysAdmin |
|---|---|---|---|---|---|
| Read own station obs | Y | Y | if granted | if granted | Y |
| Read other station | N | N | if granted | if granted | Y |
| Submit own station | Y | Y | if granted | N default | Y |
| Decide observation | N | if granted | if granted | if granted | Y |
| Manage grants | N | N | N | limited | Y |
| Archive read | if gate+grant | same | same | same | same |

Proven partially: station-scoped observation submit/decision/queue + audit endpoints with tests. Full cell runtime proof not claimed.
