#!/usr/bin/env bash
# Local verification helper for METRA 2027 work branch (no DB apply, no deploy).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "== Backend tests =="
dotnet test "$ROOT/backend/Metra.Api.Tests/Metra.Api.Tests.csproj" --nologo
echo "== Angular build =="
(cd "$ROOT/angular-app" && npm ci --no-audit --no-fund && npm run build)
echo "== Flutter analyze/test =="
(cd "$ROOT/flutter-app" && flutter pub get && flutter analyze && flutter test)
echo "OK: local verification finished (does not prove hosted DB or production)."
