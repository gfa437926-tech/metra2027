# 05 — سير العمل

## W1 الرصد
```mermaid
stateDiagram-v2
  [*] --> Draft
  Draft --> LocalValidated
  LocalValidated --> ServerValidated
  ServerValidated --> Submitted: FeatureGate
  Submitted --> UnderReview
  UnderReview --> Approved
  UnderReview --> Rejected
  Rejected --> Draft
  Approved --> Archived: حالياً 503
```
Submit: Observer · Decide: Head/Auditor · Archive: 503 حتى الاعتماد.

## W2 أعطال
Report→Assign→InProgress→Resolved→Closed

## W3 تسجيل / W4 منح صلاحية
انظر Authority/Registration endpoints.
