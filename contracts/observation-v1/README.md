# Observation contract v1 — shared fixtures

Machine-readable cases used to keep Flutter, Angular, and .NET validation aligned.

- **Source of truth for server enforcement:** `backend/Metra.Api/Features/Observations/ObservationFieldContract.cs` and domain validators.
- **Flutter mirror:** `flutter-app/lib/features/observations/daily_observation_contract.dart` (+ hourly submit validators).
- **Docs:** `docs/contracts/OBSERVATION-FIELD-CONTRACT-V1.md`

## Rules
1. Adding a fixture requires a .NET test pass and a Flutter fixture loader pass.
2. Do not invent field codes not listed in the field contract.
3. `#` means missing observation value when the field permits it.
4. Database schema is out of scope for this folder.

## Run
- .NET: `dotnet test --filter SharedObservationContractFixtures`
- Flutter: `flutter test test/shared_observation_contract_fixtures_test.dart`

## Current client coverage (be precise)

- **.NET:** loads every manifest fixture and runs the canonical server field contract against it.
- **Flutter:** loads the shared manifest and currently evaluates the daily fixtures against `DailyObservationContract`. The hourly fixture is shared in the repository, but this Flutter test does not yet execute the hourly screen validator against it.
- **Angular:** `shared-observation-contract.test.cjs` checks manifest integrity, unique fixture IDs, required-field presence for valid daily report types, canonical always-required hourly keys, declared invalid-case fields, and that documented optional hourly names remain present. These are structural drift checks, not execution of Angular form validators.
- **Browser E2E:** the Chromium test exercises daily/hourly offline queueing, reload recovery, automatic sync, server rejection, transient failure/retry, and cross-form concurrency. Its API and identity provider are mocked and isolated; it does not contact Supabase or prove live persistence.

Keep these distinctions visible in status reports. Do not describe fixture structure checks as cross-client runtime validation parity.
