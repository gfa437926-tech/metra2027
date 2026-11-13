# Stage C8 — Flutter Test Closure (C7 barrier)

## Environment
| Resource | Value |
|----------|--------|
| RAM | **1.2 GiB** total |
| Swap | **0 B** (no privilege to add) |
| Flutter CLI | Not persistently available; prior install **Killed** during JIT snapshot |
| Conclusion | Cannot complete `flutter test` or `flutter analyze` **in this sandbox** |

## Source contract checks (static)
| Check | Result |
|-------|--------|
| Path `/observation-archive` | Present in client + unit test expectation |
| JSON error `code`/`error` | Present in `_send` |
| 503 → exception | Test source includes `archive_service_unavailable` |
| Mock classification | AI/Climatol/forecast mock in `service_readiness.dart` |

## Operator-required (outside sandbox)
```bash
cd mobile/metra_mobile
flutter pub get
flutter test test/metra_api_client_test.dart --concurrency=1
flutter test --concurrency=1
flutter analyze
```

**Do not treat Flutter as green until those commands succeed with recorded output.**
