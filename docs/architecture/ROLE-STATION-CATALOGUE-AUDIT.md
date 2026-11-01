# METRA 2027 — Role and Station Catalogue Audit

Status: evidence inventory only. No canonical role catalogue, station master or permission matrix is approved by this document.

Sources inspected on the legacy `main` branch:
- `index.html` registration form.
- `login.js` station selector, registration submission and role-based redirect map.
- `user-data.js` display defaults and a small station metadata map.
- `stations-data.js` shared station data file.
- `docs/architecture/IDENTITY-MIGRATION.md`.

## 1. Role labels found in the legacy application

### Registration form options (`index.html`)

These are the exact values offered to a new registrant:
1. راصد جوي
2. متنبئ جوي
3. رئيس محطة
4. مدير مركز
5. مدير النظام
6. رئيس دائرة الشبكات

### Role redirect map (`login.js`)

The legacy redirect map recognizes:
1. مدير النظام
2. راصد جوي
3. رئيس محطة
4. مدير مركز
5. مبرمج الدعم الفني
6. رئيس الاتصالات
7. رئيس الورشات
8. مدقق
9. متنبئ في محطات الرصد
10. رئيس دائرة الشبكات

### Confirmed inconsistency

The registration form uses `متنبئ جوي`, while the redirect map uses `متنبئ في محطات الرصد`. Both strings must be preserved as observed until the business owner confirms whether they represent one role with an outdated label or two distinct roles. Do not silently normalize either value.

The four roles found only in the redirect map (`مبرمج الدعم الفني`, `رئيس الاتصالات`, `رئيس الورشات`, `مدقق`) may represent existing user populations or legacy screens. Their absence from the public registration form does not prove they are obsolete. They should be mapped against actual user records and management workflows before any migration or deactivation.

## 2. Station names found in the registration selector

The `initializeStations()` function in `login.js` hard-codes these 32 display values:

1. حلب
2. اللاذقية
3. طرطوس
4. حمص
5. حماه
6. دير الزور
7. الحسكة
8. الرقة
9. السويداء
10. درعا
11. القنيطرة
12. إدلب
13. دمشق
14. الإدارة العامة
15. حينة
16. صافيتا
17. جرابلس
18. الكريم
19. بانياس
20. القدموس
21. حمام واصل
22. سلمية
23. القرداحة
24. القامشلي
25. حلب الجامعية
26. البوكمال
27. صحنايا
28. بوقا
29. طرطوس الزراعي
30. عين العرب الجنوبية
31. زاهد
32. مطار اللاذقية

These are observed legacy labels, not a verified complete or current station master. In particular, do not infer station coordinates, codes, operational status, hierarchy or administrative region from this list.

## 3. Conflicting station representations

- `login.js` contains a 32-item registration list of plain Arabic display names.
- `user-data.js` contains a small illustrative metadata map for دمشق، حلب، اللاذقية and a fallback that synthesizes a code/location for unknown station names. This is not an authoritative catalogue.
- `user-data.js` also maps selected city names to short codes (e.g. DAM, ALP, LAT, TAR, HOM, HAM, DEZ, HAS, RAQ, SWE, DAR, QUN, IDL); these mappings do not cover the 32 registration entries and are not proven official station identifiers.
- `stations-data.js` is explicitly incomplete: it contains a few sample rows and comments saying the remaining original data should be copied into the file. It must not be treated as a full station inventory.

Therefore the repository currently does not provide a complete, internally consistent station master suitable for production assignment or map plotting.

## 4. Role names are not permissions

The legacy redirect map associates roles with pages, but that is only navigation behavior. It does not establish a reliable permission matrix. In the replacement:
- Keep Arabic display labels as labels.
- Use stable, approved role codes only after the role catalogue is approved.
- Define permissions as explicit capabilities, not inferred from a role name or target page.
- Keep a user's requested role separate from the role actually granted.
- Keep role grants separate from active station assignments.
- Enforce all permissions and station scope in ASP.NET Core for every protected operation.
- Do not let client-side route redirects or hidden menu items authorize an operation.

## 5. Required reconciliation before building administration screens

The following source material is required for an authoritative catalogue:
1. The complete original station master (not the abbreviated `stations-data.js` placeholder), including official station code, Arabic name, coordinates, elevation, station type, parent/region and active/closed status where those fields exist.
2. Existing user records with their current role and station values, exported without passwords, tokens or other secrets.
3. The full administration pages/workflows for managing users, roles, station assignments and approval.
4. Confirmation of the `متنبئ جوي` versus `متنبئ في محطات الرصد` distinction.
5. Confirmation of the four roles that appear only in the redirect map and whether they remain operational.
6. Confirmation whether `الإدارة العامة` is an organizational unit, a station-like scope, or a separate assignment type.

Do not create new station IDs, coordinates, role codes, permission grants or replacement Arabic labels to fill gaps.

## 6. Proposed future catalogue model (conceptual only)

The approved model should distinguish:
- Station: immutable identifier, official code, Arabic display name, coordinates, elevation and operational metadata.
- Organizational unit: optional parent/region/administration relationship, distinct from a meteorological station where appropriate.
- Role definition: stable code, Arabic display label, lifecycle state.
- Permission definition: stable capability code and description.
- User-role grant: user, role, scope, validity period, granting actor and audit reference.
- Station assignment: user, station, assignment type, validity period, active state and authorizing actor.

This is a conceptual separation, not a proposed SQL schema. No Supabase schema or RLS changes are authorized.

## 7. Acceptance checks for the eventual migration

- Every original role string is accounted for in a reviewed mapping; no role disappears silently.
- Every original station name is accounted for in a reviewed station mapping; no station is dropped because it is absent from the placeholder data file.
- Station coordinates and codes come from an authoritative source, not guessed values.
- A user can have only the approved active assignments for the relevant period.
- An organizational unit cannot accidentally be treated as a weather station.
- UI navigation and role labels never substitute for API permission checks.
- Angular and Flutter render the same server-provided catalogue and assignment context.
- Migration reports unresolved names and duplicates instead of silently merging them.
