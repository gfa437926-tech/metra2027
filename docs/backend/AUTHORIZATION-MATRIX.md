# Authorization Matrix (Backend)

| Capability | Server source | Station scoped | Notes |
|------------|---------------|----------------|-------|
| observation.create / edit / submit | RPC `metra_user_has_station_permission` + Domain policy | Assignment required | Owner checks for edit/submit |
| observation.review / approve | Same | Assignment required | Not sufficient for archive |
| observation.archive.read | Domain archive policy + explicit grant | **Grant station must match** | Role/authority alone denied |
| Authority membership / grants | Authority access RPCs | Authority id in route | Pending→decide→revoke lifecycle |
| Station assignments | Assignment RPCs | Station id in route | |
| Registration review | Station-scoped RPCs | Station id | |

**Never** trust client-supplied roles. Archive endpoint checks permission then returns **503** if archive service unconfigured.
