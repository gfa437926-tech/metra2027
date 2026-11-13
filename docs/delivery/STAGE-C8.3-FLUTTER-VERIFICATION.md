# Stage C8.3 — Flutter Verification

**App path:** `mobile/metra_mobile/` only  

## CI evidence (authoritative for this stage)

| Item | Value |
|------|--------|
| Branch | `work/backend-db-integration-phase` |
| HEAD tested | `c6d9a9f7dc332afdd54ca0ee859fa712f4153d12` |
| Run | https://github.com/gfa437926-tech/metra2027/actions/runs/43337342656 |
| `flutter pub get` | success |
| `flutter analyze --no-fatal-infos` | success |
| `flutter test --concurrency=1` | **16 passed, 0 failed, 0 skipped** |

## C7 regression guards retained

- Station directory modal closed via `Navigator.pop` (not `pageBack`).
- Forecast centre selection via `CheckboxListTile`; comparison title `المقارنة الجغرافية` after two selections.
- Live readings remain non-synthesized (card text asserts offline feed).

## Local sandbox

This agent environment still cannot run Flutter CLI (1.2 GiB RAM). CI run is the execution evidence for C8.3.
