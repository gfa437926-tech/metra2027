# Flutter Test Environment Report

## Baseline
- Branch: `work/backend-db-integration-phase`
- HEAD: `66f576239b30f0fc585b1b1ca54f545dd542dab6` (verified)

## Host resources
| Resource | Value |
|----------|--------|
| RAM | **1225 MiB** total (~900 MiB available) |
| Swap | **0** — `swapon` failed (`Invalid argument`; container without swap support) |
| CPU | 2 |
| Disk | ~19 GiB free on overlay |

## Tooling attempts
1. Full Flutter SDK clone + `flutter --version` → **exit 137 (SIGKILL/OOM)** while building flutter_tools JIT snapshot.
2. User-space 2 GiB swapfile → **swapon failed**.
3. Dart SDK from Flutter cache + `dart pub get` in `mobile/metra_mobile` → **Flutter SDK not detected** for `flutter_test` from SDK (incomplete tool bootstrap after OOM).
4. Wrapper `bin/flutter` for `--version` only → does not enable `flutter_test` resolution.

## Minimum environment to close C7
| Requirement | Suggested minimum |
|-------------|-------------------|
| RAM | **≥ 4 GiB** available (8 GiB recommended) |
| Swap | ≥ 2 GiB if RAM ≤ 4 GiB |
| Flutter | Stable matching project (SDK ≥ 3.6 per pubspec) |
| Disk | ≥ 5 GiB free for SDK + pub-cache |

## Conclusion
**This sandbox cannot run `flutter test` or `flutter analyze`.** Not a project defect; an environment limit.
