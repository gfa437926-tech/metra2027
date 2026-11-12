# Stage C8 — Flutter Test Closure (C7 barrier)

## Environment (this sandbox)
| Resource | Value |
|----------|--------|
| RAM | **1.2 GiB** total, ~0.9 GiB available |
| Swap | **0 B** (cannot create: no `sudo`) |
| Flutter CLI | **Not installed** at run time (`/opt/flutter` missing after prior OOM kill) |
| Prior failure | Flutter tool killed while building JIT snapshot as root |

## Attempts
1. Reinstall Flutter + `flutter test` in C7 → process **Killed** during snapshot.
2. C8: no sudo for swap; Flutter binary absent; cannot claim green suite.

## Contract verification (source, not runtime Flutter)
| Check | Evidence |
|-------|----------|
| Archive path | `metra_api_client.dart` uses `/observation-archive` |
| Error JSON `code`/`error` | `_send` maps status + body code |
| 503 not success | throws `MetraApiException`; test case added for `archive_service_unavailable` |
| Mock vs live | `service_readiness.dart` keeps AI/Climatol/forecast on mock |

## Operator command (required outside this sandbox)
```bash
cd mobile/metra_mobile
flutter pub get
flutter test test/metra_api_client_test.dart
flutter test
flutter analyze
```

**Status:** Flutter automated suite = **not executed here** (environment limitation). Not claimed green.
