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
