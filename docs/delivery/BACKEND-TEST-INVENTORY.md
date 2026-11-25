# Backend test inventory (Metra.Api.Tests)

**Date:** 2026-11-25  
**Note:** Inventory only. These tests were **not executed** in the agent sandbox (`dotnet` binary absent).

## Test classes present

- AccessContextServiceTests
- ApiAuthenticationTests
- DailyObservationValidatorTests
- HourlyDailySubmissionEndpointTests
- HourlyObservationValidatorTests
- ObservationAuthorizationPolicyTests
- ObservationDecisionRequestGuardTests
- ObservationQueueIdorTests
- ObservationQueueRequestGuardTests
- ObservationSubmissionDomainValidatorTests
- ObservationSubmissionRequestGuardTests
- ObservationValidationRequestGuardTests
- ObservationWorkflowTests
- PhenomenonSubmissionDomainValidatorTests
- PhenomenonSubmissionGuardChainTests
- RegistrationDecisionRequestGuardTests
- RegistrationDecisionRpcResultTests
- RegistrationSubmissionRequestGuardTests
- StationAssignmentRequestGuardTests
- StationAuditRequestGuardTests
- StationCatalogueReviewRequestGuardTests
- StationDirectoryVisibilityTests
- SupabaseAuthorityAccessServiceTests
- SupabaseRegistrationReviewServiceTests
- SupabaseStationAuthorizationServiceTests
- SupabaseStationDirectoryServiceTests
- WeatherPhenomenonValidatorTests

## Required to claim pass

```
cd backend && dotnet test Metra.Api.Tests/Metra.Api.Tests.csproj --no-restore
```
(or CI job equivalent on GitHub Actions)
