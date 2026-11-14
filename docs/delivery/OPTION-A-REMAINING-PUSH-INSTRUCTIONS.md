# Option A remaining files — apply safely

Remote HEAD at packaging: `4c056b9d54a1c50cb7e17967719167b07a359bfb`  
Local complete commit: `e7c889d9a6264ec4a4137f1f414c77c08f8800c8`  
Backup branch (local): `backup/option-a-e7c889d`

## Status

Already on GitHub:
- `metra_home.dart` wires `UserManagementScreen(api:, stationId:)`
- readiness + docs for non-scientific live reads

Still local only (must push):
- `mobile/metra_mobile/lib/core/api/metra_api_client.dart`
- `mobile/metra_mobile/lib/features/admin/user_management_screen.dart`
- `mobile/metra_mobile/test/metra_api_client_test.dart`

## SHA-256 of local complete files

- `metra_api_client.dart`: `055032e92aed6168882affb7caed91b2e5b56bb7843eeae54108afb15e7bcd8b`
- `user_management_screen.dart`: `309b51315438df76c624ee292afc80894bcf0e6472b611f67d47e3f84d8a2be8`
- `metra_api_client_test.dart`: `d330f1d8ec7cc87234f5974005085fd846911760c47269c6e97aa826ad7a64c0`

## Safe push from machine with GitHub credentials (no force)

```bash
git fetch origin
git checkout work/execution-master-2026-11-14
git branch backup/option-a-e7c889d e7c889d9a6264ec4a4137f1f414c77c08f8800c8  # if not exists

# Preferred: rebase local complete commit onto remote tip
git rebase origin/work/execution-master-2026-11-14
# If metra_home.dart conflicts: both sides already pass api/stationId — keep either
git push origin work/execution-master-2026-11-14
```

## Verify after push

```bash
git fetch origin
git rev-parse origin/work/execution-master-2026-11-14
git show origin/work/execution-master-2026-11-14:mobile/metra_mobile/lib/core/api/metra_api_client.dart | grep -c getStationUsers
git show origin/work/execution-master-2026-11-14:mobile/metra_mobile/lib/features/admin/user_management_screen.dart | grep -c 'required this.api'
```

Then confirm Flutter CI on the new SHA. Do not merge to main. Do not touch Supabase.
