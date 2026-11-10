# METRA 2027 — Page implementation status (live repository audit)

**Audited tip:** `work/legacy-ui-migration-audit`  
**Spec source:** `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md`  
**Method:** route/feature/API inventory in repo (not prior chat reports)  
**Legend:** `Done` = wired to backend and usable · `Partial` = UI and/or API incomplete · `Missing` = no real route/workflow · `Scaffold` = page exists without authoritative API data

| Spec ID | Page | Angular | Flutter | Backend API | Notes |
|---|---|---|---|---|---|
| AC-01 Login | تسجيل الدخول | Partial | Partial | Auth via Supabase JWT | Exists; not full session matrix |
| AC-02 Registration | طلب تسجيل | Partial | Missing | Yes (registration endpoints) | Angular registration present |
| AC-03 Registration review | مراجعة الطلبات | Partial | Missing | Yes | Angular UI at `/admin/registration-review` wired to API |
| AC-04 Password recovery | استعادة كلمة المرور | Missing | Missing | External/Supabase | Not found as app page |
| AC-05 Profile | الملف الشخصي | Missing | Missing | TBD | Not found |
| AC-06 User management | إدارة المستخدمين | Scaffold | Missing | Partial | Static role list only |
| AC-07 Roles/permissions | الأدوار والصلاحيات | Scaffold | Missing | Partial | Labels only; server grants exist |
| AC-08 Station assignment | تعيين المحطات | Done | Missing | Yes | request / pending decide / revoke UI |
| ST-01 Station directory | دليل المحطات | Done | Partial | Yes `GET /api/v1/stations` | Angular `/stations` + links to detail |
| ST-02 Station detail | تفاصيل المحطة | Done | Missing | Partial (from directory list) | Angular `/stations/:stationId` |
| ST-03 Station status | حالة المحطة | Partial | Partial | Partial | observation-status route |
| HR-01 Hourly entry | إدخال ساعي | Done | Done | Yes | UTC; offline queue Angular |
| HR-02 Hourly list | قائمة ساعية | Partial | Partial | Partial | Local/offline-oriented |
| HR-03 Hourly detail | تفاصيل | Partial | Partial | Partial | |
| HR-04 Hourly review queue | طابور التدقيق | Partial | Partial | Yes | observation workflow |
| HR-05 Decision | اعتماد/إرجاع | Partial | Partial | Yes | SoD on server |
| DY-01 Daily entry | إدخال يومي | Done | Done | Yes | 24h / 06utc / 18utc types |
| DY-02–05 Daily list/review | يومي | Partial | Partial | Yes | |
| AD-* Auditor workspace | مساحة المدقق | Partial | Missing | Partial | No monthly archive confirmation page |
| RP-03..10 Specialist reports | شهري/سنوي/مناخ/مطر/زراعة/تربة/ظواهر | Scaffold/Partial | Missing | Missing/Partial | climate/monthly/annual/users scaffolds |
| OP Maintenance/Support | أعطال/دعم | Partial | Partial | Yes | Station-scoped |

## Constraints verified in code comments / docs
- UTC-only requirement documented in spec and observation contracts.
- 06/18 UTC treated as hourly bulletin times in daily vs hourly product rules (spec).
- No archive DB connection mandated; not introduced.
- No legacy DB writes in this branch work.
- DB migrations require owner approval before apply.

## Next implementation priority (no DB apply)
1. Station detail + assignment UI on existing APIs  
2. Registration review UI  
3. Auditor archive confirmation (manual Excel) page without auto-migration  
4. Replace report scaffolds with API-backed lists only when endpoints exist  
5. Password recovery / profile after identity product decision


## Phase A closure notes (admin + stations)
- Registration review UI: `/admin/registration-review`
- Station assignment UI with pending decisions: `/admin/station-assignments`
- Station directory + detail: `/stations`, `/stations/:stationId`
- Password recovery / profile remain product decisions (Supabase Auth); not invented as custom pages without owner rule set
- Flutter admin parity still open
