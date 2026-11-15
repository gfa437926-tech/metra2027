# Test Matrix

Proven code: Metra.Api.Tests (auth, observation guards, registration, authority). Flutter test/ on UI branch.

Required examples:
| ID | Case | Expected |
|---|---|---|
| T-OBS-01 | missing dryTemp | validation error |
| T-OBS-02 | wet>dry | rejected |
| T-OBS-03 | dryTemp 51 | out of -20..50 |
| T-AUTH-01 | submit other station | 403 |
| T-ARCH-01 | archive while fail-closed | 503 |
| T-GATE-01 | submit gate off | disabled |
| T-AI-01 | model cannot write official obs | enforced |

Do not mark Implemented without run evidence.
