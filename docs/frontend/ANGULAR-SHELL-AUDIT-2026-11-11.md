# Angular Shell Audit — 2026-11-11

## Scope
Task: `UI-IMPL-001` — inspect the Angular application shell, routing, navigation sidebar, design tokens, and current test/build setup before implementation changes.

Inspected branch: `work/legacy-ui-migration-audit`.
Documentation branch receiving this audit: `docs/metra-all-ui-specification`.
No application source code, database, Supabase project, or deployment target was modified during this audit.

## Files inspected

| File | Findings |
|---|---|
| `angular-app/package.json` | Angular 20; scripts: `start`, `build`, `test`, `test:browser`. The test script compiles the daily utility tests and runs three Node test suites. |
| `angular-app/angular.json` | One Angular application named `metra2027`; global stylesheet is `src/styles.scss`; production build budget is configured. |
| `angular-app/src/main.ts` | Bootstraps one standalone `AppComponent`, provides router and HTTP client, registers service worker only in secure contexts. |
| `angular-app/src/index.html` | Arabic document language and RTL direction are set at the document root; Tajawal and Font Awesome are loaded externally. |
| `angular-app/src/app/app.component.ts` | The only current web Sidebar is embedded in the root component template and styles. It contains the app navigation, authenticated-user summary, sign-out action, mobile menu and backdrop. |
| `angular-app/src/app/app.routes.ts` | Lazy standalone feature routes; most operational routes use `requireAuthenticatedUser`. Unknown routes redirect to the protected dashboard. |
| `angular-app/src/app/core/supabase/auth.guard.ts` | Browser navigation guard checks the current authenticated user and redirects to login; its own comment correctly states that API/database authorization is authoritative. |
| `angular-app/src/styles.scss` | Global base styles and a small set of shared state/UTC classes exist, but no consolidated token system for spacing, typography, colors, elevation or breakpoints is defined. |
| `angular-app/src/app/features/dashboard/dashboard.component.ts` | Dashboard is a standalone feature with its own styles. Greeting period is calculated using the browser's local `getHours()`; user role/station display data is read from localStorage. These values must not be treated as authoritative identity or authorization. |
| `angular-app/tsconfig.app.json`, `angular-app/tsconfig.tests.json` | App and test TypeScript configurations are separate; the current test TypeScript config targets the daily submission utility. |
| `angular-app/tests/shared-observation-contract.test.cjs` | Contract fixture tests cover hourly/daily required fields and UTC-hour conditional validation. |

## Verified current shell and route findings

1. There is one Sidebar in the Angular root shell; no separate reusable Sidebar component was found at the inspected paths. It is not duplicated in each page.
2. The Sidebar is currently an inline template/style section in `AppComponent`, not a standalone shared component.
3. Responsive behavior is implemented at a 992px breakpoint with an off-canvas sidebar, mobile menu button and backdrop.
4. The current shell uses a fixed 300px desktop sidebar and a right-side content offset, consistent with RTL layout.
5. The root component refreshes the displayed auth email on initialization and after navigation. Sidebar visibility is based on whether an email is present, not on an approved role/permission matrix.
6. Routes present include login/register, dashboard, station directory/detail, forecasting, hourly/daily/monthly/annual/climate/rainfall reports, phenomena, agriculture, soil temperature, users, observation workflow, electronic auditor, equipment faults, support incidents, registration review, station assignments, manual archive, and observation status.
7. The authentication guard establishes only a browser navigation boundary. It does not replace server-side authorization.
8. Some navigation labels and route coverage remain inconsistent with the full UI catalogue; profile/password recovery and a Climatol operations route were not found in the inspected route file.
9. Global style tokens are incomplete. Several root-shell colors, dimensions and typography values are hard-coded in the component stylesheet; `.nav-footnote` is also declared both globally and within the component.
10. Dashboard greeting uses local device time. It is a presentation greeting rather than an observation timestamp, but it is inconsistent with the project's UTC-only interface rule and should be removed or changed to UTC-derived wording in a focused follow-up.
11. Dashboard role/station details are read from localStorage for presentation. They must never grant access or determine server-side permissions.
12. Mobile navigation currently has a labelled trigger and backdrop, but should be checked for `aria-expanded`, Escape-to-close and focus behavior during accessibility work.

## Implementation decision

No visual shell refactor was made in this audit. The current Sidebar is singular and responsive, and the project requirement explicitly says to preserve the working original navigation rather than replace it with a second implementation. A component extraction or visual redesign without the approved original screenshot/acceptance reference would create unnecessary regression risk.

Recommended next task: `UI-IMPL-002` — define and implement a single shared, responsive RTL shell and navigation architecture while preserving the current navigation behavior and validating against the original visual reference. First extract/centralize existing tokens and remove duplicate declarations in a small reviewable change; do not change labels or route semantics without matching the approved catalogue.

## Verification status

- Source inspection: complete for the files listed above.
- Build/test commands: identified from `package.json`; not executed in this audit session.
- CI: not claimed by this audit.
- Database/Supabase: not accessed or modified.
- Legacy repository/database: not accessed or modified.
- Deployment: none.

## Task completion

`UI-IMPL-001` is complete as a source audit and file inventory. This does not mean the Angular shell or the METRA UI implementation is complete.
